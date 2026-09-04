import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from '../users/users.service';
import { PayTagService } from '../transfer/paytag.service';
import { TransferService } from '../transfer/transfer.service';
import { HmacTokenService } from '../common/hmac-token.service';
import { CreateSplitBillDto } from './dto/create-split-bill.dto';

interface SplitBillQrPayload {
  splitBillId: string;
  expiresAt: string;
}

/**
 * Build brief section 4.3 — split-bill. Pure orchestration: BMONI has no
 * group-payment primitive, so this table just tracks who owes what, and
 * each contributor's payment is an independent TransferService proposal
 * they sign themselves, exactly like any other transfer.
 */
@Injectable()
export class SplitBillService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly payTags: PayTagService,
    private readonly transfers: TransferService,
    private readonly tokens: HmacTokenService,
  ) {}

  async create(creatorAppUserId: string, dto: CreateSplitBillDto) {
    await this.users.findById(creatorAppUserId);

    const resolvedContributors = await Promise.all(
      dto.contributors.map(async (c) => {
        if (c.payTag) return this.payTags.resolve(c.payTag);
        if (c.bmoniUserId) {
          const user = await this.prisma.appUser.findUnique({
            where: { bmoniUserId: c.bmoniUserId },
          });
          if (!user) {
            throw new BadRequestException(`No PayFlex user found for bmoniUserId ${c.bmoniUserId}.`);
          }
          return user;
        }
        throw new BadRequestException('Each contributor needs a payTag or bmoniUserId.');
      }),
    );

    const splitBill = await this.prisma.splitBill.create({
      data: {
        creatorAppUserId,
        description: dto.description,
        currency: dto.currency,
        totalAmount: dto.totalAmount,
        contributors: {
          create: resolvedContributors.map((user, i) => ({
            appUserId: user.id,
            shareAmount: dto.contributors[i].shareAmount,
          })),
        },
      },
      include: { contributors: true },
    });

    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
    const token = this.tokens.sign<SplitBillQrPayload>({ splitBillId: splitBill.id, expiresAt });

    return { splitBill, qrToken: token };
  }

  getDetail(splitBillId: string) {
    return this.requireBill(splitBillId);
  }

  /** Scanning the split-bill QR resolves to this — same idea as QR Pay's decode step. */
  getByToken(token: string) {
    const payload = this.tokens.verify<SplitBillQrPayload>(token);
    return this.getDetail(payload.splitBillId);
  }

  listForUser(appUserId: string) {
    return this.prisma.splitBill.findMany({
      where: {
        OR: [{ creatorAppUserId: appUserId }, { contributors: { some: { appUserId } } }],
      },
      include: { contributors: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  /** Creates THIS caller's own share proposal — they sign/submit it via the normal transfer endpoints. */
  async pay(contributorAppUserId: string, splitBillId: string) {
    const bill = await this.requireBill(splitBillId);
    const contributor = bill.contributors.find((c) => c.appUserId === contributorAppUserId);
    if (!contributor) {
      throw new NotFoundException(`${contributorAppUserId} is not a contributor on this bill.`);
    }
    if (contributor.status !== 'PENDING') {
      throw new BadRequestException(`Your share is already ${contributor.status}.`);
    }

    const creator = await this.users.findById(bill.creatorAppUserId);
    const proposal = await this.transfers.createTransfer(contributorAppUserId, {
      toBmoniUserId: creator.bmoniUserId,
      amount: contributor.shareAmount,
      currency: bill.currency,
      description: `Split bill: ${bill.description}`,
    });

    await this.prisma.splitBillContributor.update({
      where: { id: contributor.id },
      data: { status: 'PROPOSED', bmoniProposalId: proposal.id },
    });

    const remaining = bill.contributors.filter(
      (c) => c.id !== contributor.id && c.status === 'PENDING',
    );
    if (remaining.length === 0) {
      await this.prisma.splitBill.update({
        where: { id: splitBillId },
        data: { status: 'COMPLETED' },
      });
    }

    return proposal;
  }

  private async requireBill(splitBillId: string) {
    const bill = await this.prisma.splitBill.findUnique({
      where: { id: splitBillId },
      include: { contributors: true },
    });
    if (!bill) throw new NotFoundException(`No split bill ${splitBillId}.`);
    return bill;
  }
}
