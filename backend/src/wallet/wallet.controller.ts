import { Controller, Get, Param, Query } from '@nestjs/common';
import { WalletService } from './wallet.service';

@Controller('users/:id')
export class WalletController {
  constructor(private readonly wallet: WalletService) {}

  @Get('wallets')
  listWallets(@Param('id') id: string) {
    return this.wallet.listWallets(id);
  }

  @Get('balances')
  listBalances(@Param('id') id: string) {
    return this.wallet.listBalances(id);
  }

  @Get('wallets/:smartWalletId')
  walletDetail(@Param('id') id: string, @Param('smartWalletId') smartWalletId: string) {
    return this.wallet.getWalletDetail(id, smartWalletId);
  }

  @Get('wallets/:smartWalletId/transactions')
  transactions(
    @Param('id') id: string,
    @Param('smartWalletId') smartWalletId: string,
    @Query('page') page?: string,
    @Query('perPage') perPage?: string,
  ) {
    return this.wallet.getTransactions(id, smartWalletId, {
      page: page ? Number(page) : undefined,
      perPage: perPage ? Number(perPage) : undefined,
    });
  }
}
