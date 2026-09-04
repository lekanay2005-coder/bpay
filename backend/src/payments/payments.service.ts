import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BmoniClientService } from '../bmoni/bmoni-client.service';
import { UsersService } from '../users/users.service';
import { DepositChain, DepositCurrency } from '../bmoni/dto/wallet-home.dto';

/**
 * Deposits and NGN bank withdrawal (build brief section 5, Phase 3).
 * Both are real BMONI functionality — see backend/README.md "Phase 3
 * findings" for what was actually confirmed working vs. blocked by
 * sandbox limitations (crypto deposit 502'd from BMONI's own upstream
 * bridge provider; NGN account verification needs a real NUBAN this
 * sandbox has no test value for).
 */
@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly bmoni: BmoniClientService,
    private readonly users: UsersService,
  ) {}

  private async findSmartWallet(appUserId: string, currency: string) {
    const wallet = await this.prisma.smartWallet.findFirst({ where: { appUserId, currency } });
    if (!wallet) {
      throw new NotFoundException(`No ${currency} smart wallet on file for user ${appUserId}.`);
    }
    return wallet;
  }

  getSupportedDepositAssets() {
    return this.bmoni.getSupportedDepositAssets();
  }

  /**
   * Confirmed live: only works for a USDB wallet ("Group wallet must be
   * for USDB currency" for anything else) — crypto bridges into USDB
   * specifically. Resolve the caller's USDB wallet locally rather than
   * asking them for a smartWalletId they'd have to look up themselves.
   */
  async createDepositAddress(appUserId: string, chain: DepositChain, currency: DepositCurrency) {
    const user = await this.users.findById(appUserId);
    const wallet = await this.findSmartWallet(appUserId, 'USD');
    return this.bmoni.createDepositWalletAddress(user.bmoniUserId, {
      smartWalletId: wallet.bmoniWalletId,
      chain,
      currency,
    });
  }

  getNigerianBanks(appUserId: string) {
    return this.users.findById(appUserId).then((u) => this.bmoni.getNigerianBanks(u.bmoniUserId));
  }

  async verifyNigerianAccount(appUserId: string, bankCode: string, accountNumber: string) {
    const user = await this.users.findById(appUserId);
    return this.bmoni.verifyNigerianAccount(user.bmoniUserId, { bankCode, accountNumber });
  }

  async createNigerianWithdrawalAccount(
    appUserId: string,
    params: { accountNumber: string; bankCode: string; bankName: string; accountHolderName: string },
  ) {
    const user = await this.users.findById(appUserId);
    return this.bmoni.createNigerianWithdrawalAccount(user.bmoniUserId, params);
  }

  /**
   * The simpler one-call NGN withdrawal path. `sourceCurrency` selects
   * which of the user's wallets to debit — USDB (auto-swapped to NGN) or
   * NGN (sent directly), per BMONI's own description of this endpoint.
   */
  async withdrawToNigerianBank(
    appUserId: string,
    params: { sourceCurrency: 'NGN' | 'USD'; bankAccountId: string; fromAmount: string },
  ) {
    const user = await this.users.findById(appUserId);
    const wallet = await this.findSmartWallet(appUserId, params.sourceCurrency);
    return this.bmoni.withdrawWalletNigeria(user.bmoniUserId, {
      sourceSmartWalletId: wallet.bmoniWalletId,
      bankAccountId: params.bankAccountId,
      fromAmount: params.fromAmount,
    });
  }
}
