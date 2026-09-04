import { Module } from '@nestjs/common';
import { SplitBillService } from './split-bill.service';
import { SplitBillController } from './split-bill.controller';
import { UsersModule } from '../users/users.module';
import { TransferModule } from '../transfer/transfer.module';

@Module({
  imports: [UsersModule, TransferModule],
  providers: [SplitBillService],
  controllers: [SplitBillController],
})
export class SplitBillModule {}
