import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac, timingSafeEqual } from 'crypto';

/**
 * Generic short-lived, HMAC-signed opaque token — tamper-evidence for
 * anything embedded in a QR code or link, nothing to do with BMONI's own
 * signing. Originally lived inside QrPayService; pulled out in Phase 5
 * once split-bill QR codes and claimable-link tokens needed the exact
 * same encode/verify/expiry mechanics.
 */
@Injectable()
export class HmacTokenService {
  private readonly secret: string;

  constructor(configService: ConfigService) {
    this.secret = configService.get<string>('QR_SIGNING_SECRET') ?? '';
    if (!this.secret) {
      throw new Error(
        'QR_SIGNING_SECRET is not set — required to sign QR/link tokens. Set it in .env ' +
          '(any long random string; see .env.example).',
      );
    }
  }

  sign<T extends { expiresAt: string }>(payload: T): string {
    const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
    return `${body}.${this.hmac(body)}`;
  }

  verify<T extends { expiresAt: string }>(token: string): T {
    const [body, sig] = token.split('.');
    if (!body || !sig) throw new BadRequestException('Malformed token.');

    const expectedSig = this.hmac(body);
    const sigBuf = Buffer.from(sig);
    const expectedBuf = Buffer.from(expectedSig);
    if (sigBuf.length !== expectedBuf.length || !timingSafeEqual(sigBuf, expectedBuf)) {
      throw new BadRequestException('Invalid token signature.');
    }

    const payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8')) as T;
    if (new Date(payload.expiresAt).getTime() < Date.now()) {
      throw new BadRequestException('This token has expired.');
    }
    return payload;
  }

  private hmac(body: string): string {
    return createHmac('sha256', this.secret).update(body).digest('base64url');
  }
}
