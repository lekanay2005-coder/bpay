import { Module } from '@nestjs/common';
import { LinksService } from './links.service';
import { LinksController } from './links.controller';
import { UsersModule } from '../users/users.module';
import { TransferModule } from '../transfer/transfer.module';
import { TreasuryModule } from '../treasury/treasury.module';

@Module({
  imports: [UsersModule, TransferModule, TreasuryModule],
  providers: [LinksService],
  controllers: [LinksController],
})
export class LinksModule {}
