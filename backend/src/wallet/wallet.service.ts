import { Injectable } from '@nestjs/common';
import { BmoniClientService } from '../bmoni/bmoni-client.service';
import { UsersService } from '../users/users.service';

@Injectable()
export class WalletService {
  constructor(
    private readonly bmoni: BmoniClientService,
    private readonly users: UsersService,
  ) {}

  async listWallets(appUserId: string) {
    const user = await this.users.findById(appUserId);
    return this.bmoni.listWallets(user.bmoniUserId);
  }

  async listBalances(appUserId: string) {
    const user = await this.users.findById(appUserId);
    return this.bmoni.listBalances(user.bmoniUserId);
  }

  async getWalletDetail(appUserId: string, smartWalletId: string) {
    const user = await this.users.findById(appUserId);
    return this.bmoni.getWalletDetail(user.bmoniUserId, smartWalletId);
  }

  async getTransactions(
    appUserId: string,
    smartWalletId: string,
    params?: { page?: number; perPage?: number },
  ) {
    const user = await this.users.findById(appUserId);
    return this.bmoni.getTransactions(user.bmoniUserId, smartWalletId, params);
  }
}
