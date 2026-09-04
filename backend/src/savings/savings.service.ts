import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { TransferService } from '../transfer/transfer.service';
import { TreasuryService } from '../treasury/treasury.service';
import { CreateSavingsGoalDto } from './dto/create-savings-goal.dto';

const FREQUENCY_MS: Record<string, number> = {
  DAILY: 24 * 60 * 60 * 1000,
  WEEKLY: 7 * 24 * 60 * 60 * 1000,
  MONTHLY: 30 * 24 * 60 * 60 * 1000,
};

/**
 * App-level savings ledger (build brief section 3 — no BMONI savings
 * product exists). See the schema.prisma doc comment on SavingsGoal for
 * why contributions can only ever be scheduled, not executed
 * automatically: every transfer needs the user's live on-device
 * signature, so "scheduled" means "marked due," not "silently debited."
 */
@Injectable()
export class SavingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly transfers: TransferService,
    private readonly treasury: TreasuryService,
  ) {}

  async createGoal(appUserId: string, dto: CreateSavingsGoalDto) {
    const nextContributionAt = new Date(Date.now() + FREQUENCY_MS[dto.frequency]);
    return this.prisma.savingsGoal.create({
      data: { appUserId, ...dto, nextContributionAt },
    });
  }

  listGoals(appUserId: string) {
    return this.prisma.savingsGoal.findMany({
      where: { appUserId },
      include: { contributions: { orderBy: { dueAt: 'desc' }, take: 10 } },
      orderBy: { createdAt: 'desc' },
    });
  }

  /** Contributions this user still needs to sign, across all their goals. */
  async listDueContributions(appUserId: string) {
    return this.prisma.savingsContribution.findMany({
      where: { status: 'DUE', savingsGoal: { appUserId } },
      include: { savingsGoal: true },
      orderBy: { dueAt: 'asc' },
    });
  }

  /**
   * The scheduler's only job: for every ACTIVE goal whose
   * nextContributionAt has passed, create a DUE contribution row and
   * advance nextContributionAt. Nothing here touches BMONI — see
   * `contribute()` for the step that actually creates a signable
   * proposal, which only ever happens when the user is present in the
   * app to trigger it.
   */
  async runDueCheck(): Promise<{ goalsChecked: number; contributionsCreated: number }> {
    const now = new Date();
    const dueGoals = await this.prisma.savingsGoal.findMany({
      where: { status: 'ACTIVE', nextContributionAt: { lte: now } },
    });

    for (const goal of dueGoals) {
      await this.prisma.$transaction([
        this.prisma.savingsContribution.create({
          data: { savingsGoalId: goal.id, amount: goal.contributionAmount, dueAt: now },
        }),
        this.prisma.savingsGoal.update({
          where: { id: goal.id },
          data: { nextContributionAt: new Date(now.getTime() + FREQUENCY_MS[goal.frequency]) },
        }),
      ]);
    }

    return { goalsChecked: dueGoals.length, contributionsCreated: dueGoals.length };
  }

  /**
   * Creates the actual signable TRANSFER proposal for a due contribution
   * — customer's wallet -> PayFlex treasury. The caller signs/submits it
   * through the normal transfer endpoints
   * (`/users/:id/transfers/:proposalId/sign-payload` then `/sign`), same
   * as any other transfer; this just resolves "who, how much."
   */
  async contribute(appUserId: string, contributionId: string) {
    const contribution = await this.prisma.savingsContribution.findUnique({
      where: { id: contributionId },
      include: { savingsGoal: true },
    });
    if (!contribution || contribution.savingsGoal.appUserId !== appUserId) {
      throw new NotFoundException(`No due contribution ${contributionId} for this user.`);
    }
    if (contribution.status !== 'DUE') {
      throw new BadRequestException(`Contribution ${contributionId} is already ${contribution.status}.`);
    }

    // Fail fast with a clear error if the treasury has no wallet in this
    // currency yet, rather than letting BMONI's own resolution error
    // surface as a generic 400 further down.
    await this.treasury.getWalletId(contribution.savingsGoal.currency);

    const proposal = await this.transfers.createTransfer(appUserId, {
      toBmoniUserId: this.treasury.getBmoniUserId(),
      amount: contribution.amount,
      currency: contribution.savingsGoal.currency,
      description: `Savings contribution: ${contribution.savingsGoal.name}`,
    });

    await this.prisma.savingsContribution.update({
      where: { id: contributionId },
      data: { status: 'PROPOSED', bmoniProposalId: proposal.id },
    });

    return proposal;
  }
}
