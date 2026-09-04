import { Module } from '@nestjs/common';
import { TransferService } from './transfer.service';
import { PayTagService } from './paytag.service';
import { QrPayService } from './qr-pay.service';
import { TransferController } from './transfer.controller';
import { QrPayController } from './qr-pay.controller';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [UsersModule],
  providers: [TransferService, PayTagService, QrPayService],
  controllers: [TransferController, QrPayController],
  exports: [TransferService],
})
export class TransferModule {}
