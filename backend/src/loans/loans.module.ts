import { Module } from '@nestjs/common';
import { LoansService, CreditScoringProvider } from './loans.service';
import { LoansController } from './loans.controller';
import { UsersModule } from '../users/users.module';
import { TransferModule } from '../transfer/transfer.module';
import { TreasuryModule } from '../treasury/treasury.module';

@Module({
  imports: [UsersModule, TransferModule, TreasuryModule],
  providers: [LoansService, CreditScoringProvider],
  controllers: [LoansController],
})
export class LoansModule {}
