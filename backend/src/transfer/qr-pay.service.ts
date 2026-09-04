import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac, timingSafeEqual } from 'crypto';
import { UsersService } from '../users/users.service';
import { TransferService } from './transfer.service';

export interface QrPayload {
  recipientAppUserId: string;
  recipientBmoniUserId: string;
  amount: string;
  currency: string;
  expiresAt: string;
}

/**
 * App-layer QR Pay (build brief section 4.1) — a short-lived, HMAC-signed
 * payload naming a recipient/amount/currency. This has nothing to do with
 * BMONI's own signing; it's just tamper-evidence for a QR code that
 * ultimately hands off to TransferService.createTransfer once scanned.
 */
@Injectable()
export class QrPayService {
  private readonly secret: string;

  constructor(
    configService: ConfigService,
    private readonly users: UsersService,
    private readonly transfers: TransferService,
  ) {
    this.secret = configService.get<string>('QR_SIGNING_SECRET') ?? '';
    if (!this.secret) {
      throw new Error(
        'QR_SIGNING_SECRET is not set — required to sign QR Pay tokens. Set it in .env ' +
          '(any long random string; see .env.example).',
      );
    }
  }

  async generate(
    appUserId: string,
    params: { amount: string; currency: string; expiresInSeconds?: number },
  ): Promise<{ token: string; payload: QrPayload }> {
    const user = await this.users.findById(appUserId);
    const expiresAt = new Date(
      Date.now() + (params.expiresInSeconds ?? 300) * 1000,
    ).toISOString();
    const payload: QrPayload = {
      recipientAppUserId: user.id,
      recipientBmoniUserId: user.bmoniUserId,
      amount: params.amount,
      currency: params.currency,
      expiresAt,
    };
    return { token: this.encode(payload), payload };
  }

  /** Scanning a QR resolves to this — a pre-filled confirm screen shows this before paying. */
  decode(token: string): QrPayload {
    const [body, sig] = token.split('.');
    if (!body || !sig) throw new BadRequestException('Malformed QR token.');

    const expectedSig = this.sign(body);
    const sigBuf = Buffer.from(sig);
    const expectedBuf = Buffer.from(expectedSig);
    if (sigBuf.length !== expectedBuf.length || !timingSafeEqual(sigBuf, expectedBuf)) {
      throw new BadRequestException('Invalid QR token signature.');
    }

    const payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8')) as QrPayload;
    if (new Date(payload.expiresAt).getTime() < Date.now()) {
      throw new BadRequestException('This QR code has expired.');
    }
    return payload;
  }

  /** Runs the actual proposal flow once a payer confirms a scanned QR. */
  async pay(payerAppUserId: string, token: string) {
    const payload = this.decode(token);
    return this.transfers.createTransfer(payerAppUserId, {
      toBmoniUserId: payload.recipientBmoniUserId,
      amount: payload.amount,
      currency: payload.currency,
      description: 'QR Pay',
    });
  }

  private encode(payload: QrPayload): string {
    const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
    return `${body}.${this.sign(body)}`;
  }

  private sign(body: string): string {
    return createHmac('sha256', this.secret).update(body).digest('base64url');
  }
}
