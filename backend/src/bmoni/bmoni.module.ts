import { Global, Module } from '@nestjs/common';
import { BmoniClientService } from './bmoni-client.service';

@Global()
@Module({
  providers: [BmoniClientService],
  exports: [BmoniClientService],
})
export class BmoniModule {}
