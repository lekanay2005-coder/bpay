import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BmoniClientService } from '../bmoni/bmoni-client.service';
import { UsersService } from '../users/users.service';

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
}
