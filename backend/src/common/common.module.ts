import { Global, Module } from '@nestjs/common';
import { HmacTokenService } from './hmac-token.service';

@Global()
@Module({
  providers: [HmacTokenService],
  exports: [HmacTokenService],
})
export class CommonModule {}
