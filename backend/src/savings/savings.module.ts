import { Module } from '@nestjs/common';
import { SavingsService } from './savings.service';
import { SavingsSchedulerService } from './savings-scheduler.service';
import { SavingsController } from './savings.controller';
import { SavingsAdminController } from './savings-admin.controller';
import { TransferModule } from '../transfer/transfer.module';
import { TreasuryModule } from '../treasury/treasury.module';

@Module({
  imports: [TransferModule, TreasuryModule],
  providers: [SavingsService, SavingsSchedulerService],
  controllers: [SavingsController, SavingsAdminController],
})
export class SavingsModule {}
