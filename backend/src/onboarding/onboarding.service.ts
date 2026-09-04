import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BmoniClientService } from '../bmoni/bmoni-client.service';
import { BmoniApiError } from '../bmoni/bmoni.errors';
import { UsersService } from '../users/users.service';
import { Prisma } from '@prisma/client';

@Injectable()
export class OnboardingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly bmoni: BmoniClientService,
    private readonly users: UsersService,
  ) {}

  getSupportedCurrencies() {
    return this.bmoni.getSupportedCurrencies();
  }

  async requestOwnerProofChallenge(appUserId: string, currency: string) {
    const user = await this.users.findById(appUserId);
    if (!user.ownerAddress) {
      throw new Error(
        `AppUser ${appUserId} has no ownerAddress yet — call PATCH /users/${appUserId}/owner-address ` +
          `with the device-generated EVM address before requesting a challenge.`,
      );
    }
    return this.bmoni.requestOwnerProofChallenge(user.bmoniUserId, {
      currency,
      userOwnerAddress: user.ownerAddress,
    });
  }

  async createSmartWallet(
    appUserId: string,
    params: { currency: string; ownerProofChallengeId: string; ownerProofSignature: string },
  ) {
    const user = await this.users.findById(appUserId);
    if (!user.ownerAddress) {
      throw new Error(`AppUser ${appUserId} has no ownerAddress yet.`);
    }

    const wallet = await this.bmoni.createManagedSmartWallet(user.bmoniUserId, {
      currency: params.currency,
      userOwnerAddress: user.ownerAddress,
      ownerProofChallengeId: params.ownerProofChallengeId,
      ownerProofSignature: params.ownerProofSignature,
    });

    await this.prisma.smartWallet.upsert({
      where: { bmoniWalletId: wallet.id },
      create: {
        appUserId: user.id,
        bmoniWalletId: wallet.id,
        currency: wallet.currency,
        address: wallet.walletAddress,
        status: wallet.isActive ? 'active' : 'inactive',
      },
      update: {
        currency: wallet.currency,
        address: wallet.walletAddress,
        status: wallet.isActive ? 'active' : 'inactive',
      },
    });

    return wallet;
  }

  async getStatus(appUserId: string) {
    const user = await this.users.findById(appUserId);
    return this.bmoni.getOnboardingStatus(user.bmoniUserId);
  }

  private async findSmartWalletByCurrency(appUserId: string, currency: string) {
    const wallet = await this.prisma.smartWallet.findFirst({ where: { appUserId, currency } });
    if (!wallet) {
      throw new NotFoundException(
        `No ${currency} smart wallet on file for user ${appUserId} — create one first via ` +
          `POST /users/${appUserId}/smart-wallets.`,
      );
    }
    return wallet;
  }

  /**
   * Resolves ngnWalletAddress from the user's already-provisioned NGN
   * smart wallet rather than requiring the caller to pass it again — the
   * app already knows it from Phase 1's create-managed-wallet response,
   * and BMONI's raw endpoint takes it as a plain string with no
   * server-side ownership check, so there's no safety reason to make
   * every caller re-supply it.
   */
  async startNigeria(appUserId: string, params: { bvn: string; ngnWalletIndex: number }) {
    const user = await this.users.findById(appUserId);
    const wallet = await this.findSmartWalletByCurrency(appUserId, 'NGN');
    if (!wallet.address) {
      throw new Error(`NGN smart wallet ${wallet.id} has no address on file.`);
    }
    const result = await this.bmoni.startNigeria(user.bmoniUserId, {
      bvn: params.bvn,
      ngnWalletAddress: wallet.address,
      ngnWalletIndex: params.ngnWalletIndex,
    });
    await this.prisma.railOnboarding.upsert({
      where: { appUserId_currency: { appUserId, currency: 'NGN' } },
      create: {
        appUserId,
        currency: 'NGN',
        status: 'submitted',
        workflowId: result.workflowId,
        metadata: result as unknown as Prisma.InputJsonValue,
      },
      update: {
        status: 'submitted',
        workflowId: result.workflowId,
        metadata: result as unknown as Prisma.InputJsonValue,
      },
    });
    return result;
  }

  async startUsa(appUserId: string) {
    const user = await this.users.findById(appUserId);
    const wallet = await this.findSmartWalletByCurrency(appUserId, 'USD');
    try {
      const result = await this.bmoni.startUsa(user.bmoniUserId, {
        smartWalletId: wallet.bmoniWalletId,
      });
      await this.prisma.railOnboarding.upsert({
        where: { appUserId_currency: { appUserId, currency: 'USD' } },
        create: { appUserId, currency: 'USD', status: 'submitted', workflowId: result.workflowId },
        update: { status: 'submitted', workflowId: result.workflowId },
      });
      return result;
    } catch (err) {
      // Confirmed live: BMONI returns 422 with { kycStatus, fieldsToAction,
      // ... } when the underlying Sumsub check isn't approved yet — record
      // that as a distinct status rather than leaving no trace locally.
      if (err instanceof BmoniApiError && err.status === 422) {
        await this.prisma.railOnboarding.upsert({
          where: { appUserId_currency: { appUserId, currency: 'USD' } },
          create: {
            appUserId,
            currency: 'USD',
            status: 'action_required',
            metadata: err.rawBody as Prisma.InputJsonValue,
          },
          update: {
            status: 'action_required',
            metadata: err.rawBody as Prisma.InputJsonValue,
          },
        });
      }
      throw err;
    }
  }

  async getVbaUsdStatus(appUserId: string) {
    const user = await this.users.findById(appUserId);
    const status = await this.bmoni.getVbaUsdStatus(user.bmoniUserId);
    await this.prisma.railOnboarding.updateMany({
      where: { appUserId, currency: 'USD' },
      data: { status: status.status },
    });
    return status;
  }
}
