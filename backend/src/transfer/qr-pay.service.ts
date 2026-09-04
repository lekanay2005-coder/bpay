import { Injectable } from '@nestjs/common';
import { HmacTokenService } from '../common/hmac-token.service';
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
 * payload naming a recipient/amount/currency (see HmacTokenService). This
 * has nothing to do with BMONI's own signing; it's just tamper-evidence
 * for a QR code that ultimately hands off to
 * TransferService.createTransfer once scanned.
 */
@Injectable()
export class QrPayService {
  constructor(
    private readonly tokens: HmacTokenService,
    private readonly users: UsersService,
    private readonly transfers: TransferService,
  ) {}

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
    return { token: this.tokens.sign(payload), payload };
  }

  /** Scanning a QR resolves to this — a pre-filled confirm screen shows this before paying. */
  decode(token: string): QrPayload {
    return this.tokens.verify<QrPayload>(token);
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
}
