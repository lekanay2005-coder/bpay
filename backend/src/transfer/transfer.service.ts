import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BmoniClientService } from '../bmoni/bmoni-client.service';
import { UsersService } from '../users/users.service';
import { Proposal } from '../bmoni/dto/wallet-home.dto';
import { stablecoinForFiat } from '../common/currency.util';

/**
 * The single wrapper around BMONI's proposal -> sign-payload -> sign
 * primitive (build brief section 2.4). Every transfer mode — QR, PayTag,
 * send-via-link, split-bill (Phase 5) — resolves "who, how much" and then
 * calls into this service; nothing else in the app talks to the proposal
 * endpoints directly.
 *
 * Confirmed live (2026-09-04) mechanics this service encodes — see
 * backend/README.md "Phase 3 findings" for the full writeup:
 *  - There is no separate "approve" endpoint. Submitting a valid
 *    signature via signProposal IS the approval action.
 *  - The value to sign is `signingPayloadHash` from getSignPayload, taken
 *    RAW as a digest (e.g. via bmoni_embedded_sdk's signTransactionHash)
 *    — NOT the full EIP-712 hash of the accompanying `typedData`. Signing
 *    the properly-computed EIP-712 digest was tested and rejected by
 *    BMONI ("signature does not match your registered owner address").
 *  - A proposal can remain at PENDING_APPROVALS/WAIT_APPROVALS
 *    indefinitely after being fully signed if the underlying wallet can't
 *    actually fund the transfer (e.g. zero balance in this sandbox) —
 *    that is not a bug in this integration.
 */
@Injectable()
export class TransferService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly bmoni: BmoniClientService,
    private readonly users: UsersService,
  ) {}

  private async findSmartWallet(appUserId: string, currency: string) {
    const wallet = await this.prisma.smartWallet.findFirst({ where: { appUserId, currency } });
    if (!wallet) {
      throw new NotFoundException(
        `No ${currency} smart wallet on file for user ${appUserId} — create one first via ` +
          `POST /users/${appUserId}/smart-wallets.`,
      );
    }
    return wallet;
  }

  private async persistProposal(appUserId: string, smartWalletId: string, proposal: Proposal) {
    await this.prisma.transferProposal.upsert({
      where: { bmoniProposalId: proposal.id },
      create: {
        appUserId,
        smartWalletId,
        bmoniProposalId: proposal.id,
        toBmoniUserId: proposal.toUserId,
        toAddress: proposal.toAddress,
        amount: proposal.amount,
        currency: proposal.currency,
        status: proposal.status,
        nextAction: proposal.nextAction,
      },
      update: {
        status: proposal.status,
        nextAction: proposal.nextAction,
      },
    });
  }

  /**
   * Creates a TRANSFER proposal debiting the caller's wallet in
   * `currency`. Exactly one of `toBmoniUserId` / `toAddress` should be
   * set — BMONI resolves the recipient's wallet server-side from
   * `toUserId` when given.
   *
   * `currency` here is the FIAT label our SmartWallet rows are keyed by
   * (e.g. "NGN") — same as everywhere else in this app — not the
   * stablecoin code BMONI's proposal body actually wants (e.g. "CNGN").
   * See src/common/currency.util.ts for why those differ and why we
   * translate here rather than asking every caller to know the mapping.
   */
  async createTransfer(
    appUserId: string,
    params: {
      toBmoniUserId?: string;
      toAddress?: string;
      amount: string;
      currency: string;
      description?: string;
    },
  ): Promise<Proposal> {
    const user = await this.users.findById(appUserId);
    const wallet = await this.findSmartWallet(appUserId, params.currency);

    const proposal = await this.bmoni.createProposal(user.bmoniUserId, wallet.bmoniWalletId, {
      type: 'TRANSFER',
      toUserId: params.toBmoniUserId,
      toAddress: params.toAddress,
      amount: params.amount,
      currency: stablecoinForFiat(params.currency),
      description: params.description,
    });

    await this.persistProposal(appUserId, wallet.bmoniWalletId, proposal);
    return proposal;
  }

  async getSignPayload(appUserId: string, proposalId: string) {
    const user = await this.users.findById(appUserId);
    return this.bmoni.getProposalSignPayload(user.bmoniUserId, proposalId);
  }

  async submitSignature(appUserId: string, proposalId: string, signature: string) {
    const user = await this.users.findById(appUserId);
    const result = await this.bmoni.signProposal(user.bmoniUserId, proposalId, { signature });
    if (result.proposal) {
      await this.persistProposal(appUserId, result.proposal.groupWalletId, result.proposal);
    }
    return result;
  }

  async reject(appUserId: string, proposalId: string, reason?: string) {
    const user = await this.users.findById(appUserId);
    const result = await this.bmoni.rejectProposal(user.bmoniUserId, proposalId, { reason });
    if (result.proposal) {
      await this.persistProposal(appUserId, result.proposal.groupWalletId, result.proposal);
    }
    return result;
  }

  async getProposal(appUserId: string, proposalId: string): Promise<Proposal> {
    const user = await this.users.findById(appUserId);
    return this.bmoni.getProposal(user.bmoniUserId, proposalId);
  }

  async listProposals(appUserId: string, currency: string) {
    const user = await this.users.findById(appUserId);
    const wallet = await this.findSmartWallet(appUserId, currency);
    return this.bmoni.listProposals(user.bmoniUserId, wallet.bmoniWalletId);
  }
}
