import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BmoniClientService } from '../bmoni/bmoni-client.service';
import { UsersService } from '../users/users.service';
import { TransferService } from '../transfer/transfer.service';
import { TreasuryService } from '../treasury/treasury.service';
import { BmoniApiError } from '../bmoni/bmoni.errors';
import { CreditScoringStrategy } from './credit-scoring/credit-scoring-strategy.interface';
import { SimpleCreditScoringStrategy } from './credit-scoring/simple-credit-scoring.strategy';
import { ApplyLoanDto } from './dto/apply-loan.dto';

export const CREDIT_SCORING_STRATEGY = Symbol('CREDIT_SCORING_STRATEGY');

const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;

/**
 * Build brief section 3: BMONI has no loan product at all — this is
 * entirely PayFlex's own logic on top of BMONI transaction history and
 * the transfer primitive. Approval decides synchronously inside
 * `apply()`; a DISBURSED loan's outbound transfer is signed by
 * TreasuryService server-side (see its doc comment) since PayFlex is the
 * one moving its own money here, not the borrower.
 */
@Injectable()
export class LoansService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly bmoni: BmoniClientService,
    private readonly users: UsersService,
    private readonly transfers: TransferService,
    private readonly treasury: TreasuryService,
    @Inject(CREDIT_SCORING_STRATEGY) private readonly scoring: CreditScoringStrategy,
  ) {}

  async apply(appUserId: string, dto: ApplyLoanDto) {
    const user = await this.users.findById(appUserId);
    const wallet = await this.prisma.smartWallet.findFirst({
      where: { appUserId, currency: dto.currency },
    });
    if (!wallet) {
      throw new NotFoundException(
        `No ${dto.currency} smart wallet on file for user ${appUserId} — a loan needs a wallet ` +
          `to score and to disburse into.`,
      );
    }

    const history = await this.bmoni.getTransactions(user.bmoniUserId, wallet.bmoniWalletId, {
      perPage: 100,
    });
    const accountAgeDays = Math.floor(
      (Date.now() - user.createdAt.getTime()) / (24 * 60 * 60 * 1000),
    );

    const result = this.scoring.score({
      accountAgeDays,
      transactions: history.transactions,
      requestedAmount: dto.requestedAmount,
      currency: dto.currency,
    });

    const loan = await this.prisma.loanApplication.create({
      data: {
        appUserId,
        requestedAmount: dto.requestedAmount,
        currency: dto.currency,
        status: result.approved ? 'APPROVED' : 'REJECTED',
        approvedAmount: result.approved ? result.approvedAmount : null,
        creditScore: result.score,
        scoringReasoning: result.reasoning,
      },
    });

    if (!result.approved) return loan;
    return this.disburse(loan.id);
  }

  listForUser(appUserId: string) {
    return this.prisma.loanApplication.findMany({
      where: { appUserId },
      include: { repayments: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  private async disburse(loanApplicationId: string) {
    const loan = await this.prisma.loanApplication.findUniqueOrThrow({
      where: { id: loanApplicationId },
    });
    if (!loan.approvedAmount) {
      throw new Error(`Loan ${loanApplicationId} has no approvedAmount — cannot disburse.`);
    }

    const customer = await this.users.findById(loan.appUserId);
    const treasuryAppUserId = await this.treasury.getAppUserId();
    await this.treasury.getWalletId(loan.currency); // fail fast if treasury lacks this wallet

    const proposal = await this.transfers.createTransfer(treasuryAppUserId, {
      toBmoniUserId: customer.bmoniUserId,
      amount: loan.approvedAmount,
      currency: loan.currency,
      description: `Loan disbursement: ${loanApplicationId}`,
    });

    const signPayload = await this.waitForSignPayload(treasuryAppUserId, proposal.id);
    const signature = this.treasury.signDigest(signPayload.signingPayloadHash);
    await this.transfers.submitSignature(treasuryAppUserId, proposal.id, signature);

    return this.prisma.loanApplication.update({
      where: { id: loanApplicationId },
      data: {
        status: 'DISBURSED',
        disbursementProposalId: proposal.id,
        repayments: {
          create: {
            amount: loan.approvedAmount,
            dueAt: new Date(Date.now() + THIRTY_DAYS_MS),
          },
        },
      },
      include: { repayments: true },
    });
  }

  /** Sign payload is prepared asynchronously — see backend/README.md "Phase 3 findings". */
  private async waitForSignPayload(appUserId: string, proposalId: string) {
    for (let attempt = 0; attempt < 8; attempt++) {
      try {
        return await this.transfers.getSignPayload(appUserId, proposalId);
      } catch (err) {
        if (err instanceof BmoniApiError && err.status === 409 && attempt < 7) {
          await new Promise((r) => setTimeout(r, 1500));
          continue;
        }
        throw err;
      }
    }
    throw new Error(`Sign payload for proposal ${proposalId} never became ready.`);
  }

  async listRepayments(loanApplicationId: string) {
    return this.prisma.loanRepayment.findMany({ where: { loanApplicationId } });
  }

  /** Customer signs/submits this via the normal transfer sign-payload/sign endpoints. */
  async payRepayment(appUserId: string, repaymentId: string) {
    const repayment = await this.prisma.loanRepayment.findUnique({
      where: { id: repaymentId },
      include: { loanApplication: true },
    });
    if (!repayment || repayment.loanApplication.appUserId !== appUserId) {
      throw new NotFoundException(`No repayment ${repaymentId} for this user.`);
    }
    if (repayment.status !== 'DUE') {
      throw new Error(`Repayment ${repaymentId} is already ${repayment.status}.`);
    }

    const proposal = await this.transfers.createTransfer(appUserId, {
      toBmoniUserId: this.treasury.getBmoniUserId(),
      amount: repayment.amount,
      currency: repayment.loanApplication.currency,
      description: `Loan repayment: ${repayment.loanApplicationId}`,
    });

    await this.prisma.loanRepayment.update({
      where: { id: repaymentId },
      data: { status: 'PROPOSED', bmoniProposalId: proposal.id },
    });

    return proposal;
  }
}

export const CreditScoringProvider = {
  provide: CREDIT_SCORING_STRATEGY,
  useClass: SimpleCreditScoringStrategy,
};
