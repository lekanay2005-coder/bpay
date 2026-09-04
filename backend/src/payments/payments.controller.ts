import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { PaymentsService } from './payments.service';
import { CreateDepositAddressDto } from './dto/create-deposit-address.dto';
import { VerifyNigerianAccountDto } from './dto/verify-nigerian-account.dto';
import { CreateWithdrawalAccountDto } from './dto/create-withdrawal-account.dto';
import { WithdrawNigeriaDto } from './dto/withdraw-nigeria.dto';

@Controller()
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}

  @Get('deposit/supported-assets')
  supportedAssets() {
    return this.payments.getSupportedDepositAssets();
  }

  @Post('users/:id/deposit/wallet')
  createDepositAddress(@Param('id') id: string, @Body() dto: CreateDepositAddressDto) {
    return this.payments.createDepositAddress(id, dto.chain, dto.currency);
  }

  @Get('users/:id/bank-accounts/nigerian-banks')
  nigerianBanks(@Param('id') id: string) {
    return this.payments.getNigerianBanks(id);
  }

  @Post('users/:id/bank-accounts/verify-nigerian-account')
  verifyNigerianAccount(@Param('id') id: string, @Body() dto: VerifyNigerianAccountDto) {
    return this.payments.verifyNigerianAccount(id, dto.bankCode, dto.accountNumber);
  }

  @Post('users/:id/bank-accounts/withdrawal-accounts/nigeria')
  createWithdrawalAccount(@Param('id') id: string, @Body() dto: CreateWithdrawalAccountDto) {
    return this.payments.createNigerianWithdrawalAccount(id, dto);
  }

  @Post('users/:id/withdrawal/nigeria')
  withdrawToNigerianBank(@Param('id') id: string, @Body() dto: WithdrawNigeriaDto) {
    return this.payments.withdrawToNigerianBank(id, dto);
  }
}
