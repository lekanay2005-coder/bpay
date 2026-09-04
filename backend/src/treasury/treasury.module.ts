import { Module } from '@nestjs/common';
import { TreasuryService } from './treasury.service';

@Module({
  providers: [TreasuryService],
  exports: [TreasuryService],
})
export class TreasuryModule {}
