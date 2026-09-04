import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from '../users/users.service';
import { TransferService } from '../transfer/transfer.service';
import { TreasuryService } from '../treasury/treasury.service';
import { HmacTokenService } from '../common/hmac-token.service';
import { BmoniApiError } from '../bmoni/bmoni.errors';
import { SendViaLinkDto } from './dto/send-via-link.dto';

interface ClaimTokenPayload {
  claimableLinkId: string;
  expiresAt: string;
}

/**
 * Send-via-link (build brief section 4.4 / section 3). BMONI has no
 * claimable-balance primitive at all, so a link to someone without a
 * BMONI account routes through PayFlex's own treasury account as an
 * escrow holder. See the LONG doc comment on the ClaimableLink model in
 * schema.prisma before changing anything here — this is a real
 * liability/compliance surface per the brief, not a normal feature.
 */
@Injectable()
export class LinksService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly transfers: TransferService,
    private readonly treasury: TreasuryService,
    private readonly tokens: HmacTokenService,
  ) {}

  async sendViaLink(senderAppUserId: string, dto: SendViaLinkDto) {
    if (dto.toBmoniUserId) {
      const recipient = await this.prisma.appUser.findUnique({
        where: { bmoniUserId: dto.toBmoniUserId },
      });
      if (recipient) {
        // Brief section 4.4: "If the recipient already has a bmoniUserId,
        // it's a normal transfer" — no escrow, no ClaimableLink row.
        const proposal = await this.transfers.createTransfer(senderAppUserId, {
          toBmoniUserId: recipient.bmoniUserId,
          amount: dto.amount,
          currency: dto.currency,
          description: 'Send via link',
        });
        return { type: 'DIRECT_TRANSFER' as const, proposal };
      }
    }

    return this.createEscrowedLink(senderAppUserId, dto);
  }

  private async createEscrowedLink(senderAppUserId: string, dto: SendViaLinkDto) {
    await this.treasury.getWalletId(dto.currency); // fail fast if treasury lacks this wallet

    const link = await this.prisma.claimableLink.create({
      data: {
        senderAppUserId,
        amount: dto.amount,
        currency: dto.currency,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
      },
    });

    const escrowProposal = await this.transfers.createTransfer(senderAppUserId, {
      toBmoniUserId: this.treasury.getBmoniUserId(),
      amount: dto.amount,
      currency: dto.currency,
      description: `Send via link (escrow): ${link.id}`,
    });

    await this.prisma.claimableLink.update({
      where: { id: link.id },
      data: { status: 'ESCROWED', escrowProposalId: escrowProposal.id },
    });

    const claimToken = this.tokens.sign<ClaimTokenPayload>({
      claimableLinkId: link.id,
      expiresAt: link.expiresAt.toISOString(),
    });

    return {
      type: 'ESCROW' as const,
      // The sender still has to sign/submit escrowProposal via the normal
      // transfer endpoints — creating it here doesn't move any funds yet.
      escrowProposal,
      claimToken,
    };
  }

  /** Public preview for a claim landing page, before the recipient necessarily has an account. */
  async previewClaim(token: string) {
    const { claimableLinkId } = this.tokens.verify<ClaimTokenPayload>(token);
    const link = await this.prisma.claimableLink.findUnique({
      where: { id: claimableLinkId },
      include: { sender: true },
    });
    if (!link) throw new NotFoundException(`No claimable link ${claimableLinkId}.`);
    return {
      amount: link.amount,
      currency: link.currency,
      senderName: `${link.sender.firstName} ${link.sender.lastName}`,
      status: link.status,
      expiresAt: link.expiresAt,
    };
  }

  /**
   * Releases the escrowed funds to the claimant — signed by PayFlex's
   * treasury server-side (same pattern as loan disbursement), since it's
   * the treasury's own escrowed balance moving out under its own
   * authority. The claimant needs a PayFlex account (and thus a
   * bmoniUserId) to reach this at all — until then they only have
   * `previewClaim`'s read-only view.
   */
  async claim(claimantAppUserId: string, token: string) {
    const { claimableLinkId } = this.tokens.verify<ClaimTokenPayload>(token);
    const link = await this.prisma.claimableLink.findUnique({ where: { id: claimableLinkId } });
    if (!link) throw new NotFoundException(`No claimable link ${claimableLinkId}.`);
    if (link.status !== 'ESCROWED') {
      throw new BadRequestException(`This link is ${link.status.toLowerCase()}, not claimable.`);
    }
    if (link.expiresAt.getTime() < Date.now()) {
      await this.prisma.claimableLink.update({
        where: { id: link.id },
        data: { status: 'EXPIRED' },
      });
      throw new BadRequestException('This link has expired.');
    }

    const claimant = await this.users.findById(claimantAppUserId);
    const treasuryAppUserId = await this.treasury.getAppUserId();

    const releaseProposal = await this.transfers.createTransfer(treasuryAppUserId, {
      toBmoniUserId: claimant.bmoniUserId,
      amount: link.amount,
      currency: link.currency,
      description: `Claimable link release: ${link.id}`,
    });

    const signPayload = await this.waitForSignPayload(treasuryAppUserId, releaseProposal.id);
    const signature = this.treasury.signDigest(signPayload.signingPayloadHash);
    await this.transfers.submitSignature(treasuryAppUserId, releaseProposal.id, signature);

    return this.prisma.claimableLink.update({
      where: { id: link.id },
      data: {
        status: 'CLAIMED',
        claimedByAppUserId: claimantAppUserId,
        claimedAt: new Date(),
        releaseProposalId: releaseProposal.id,
      },
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
}
