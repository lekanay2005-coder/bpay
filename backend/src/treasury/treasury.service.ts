import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SigningKey } from 'ethers';
import { BmoniClientService } from '../bmoni/bmoni-client.service';
import { PrismaService } from '../prisma/prisma.service';
import { stablecoinForFiat } from '../common/currency.util';

/**
 * PayFlex's own BMONI account — a business/platform wallet, not a user
 * wallet. This is the ONE deliberate exception to "never generate/store
 * keys outside bmoni_embedded_sdk" (see docs/BUILD_PROMPT.md section 7):
 * that rule protects END-USER key custody, where signing must happen
 * on-device because only the user should ever be able to authorize their
 * own funds moving. A loan disbursement is the opposite case — it's
 * PayFlex's own money, moving under PayFlex's own authority, with no
 * user present to sign anything. Something has to hold that key
 * server-side for that to be possible at all.
 *
 * PRODUCTION WARNING: `PAYFLEX_TREASURY_OWNER_PRIVATE_KEY` in a plain env
 * var is fine for this sandbox build and nothing else. A real deployment
 * must hold this in a proper KMS/HSM (AWS KMS, GCP Cloud KMS, etc.) and
 * sign through that service's API rather than materializing the raw key
 * in application memory at all. Treat `signingKey` below as the one place
 * that assumption would need to change.
 *
 * Config is validated lazily (on first real use), not in the
 * constructor: this service is wired into the same AppModule every
 * sandbox script and the HTTP server boot through, including
 * `scripts/provision-treasury.ts` itself, which creates the treasury
 * BMONI account these env vars point at in the first place. Throwing
 * eagerly here would make it impossible to ever run that script.
 */
@Injectable()
export class TreasuryService {
  private readonly logger = new Logger(TreasuryService.name);
  private readonly walletIdByCurrency = new Map<string, string>();
  private cachedAppUserId: string | undefined;
  private cachedSigningKey: SigningKey | undefined;

  constructor(
    private readonly configService: ConfigService,
    private readonly bmoni: BmoniClientService,
    private readonly prisma: PrismaService,
  ) {}

  getBmoniUserId(): string {
    const bmoniUserId = this.configService.get<string>('PAYFLEX_TREASURY_BMONI_USER_ID');
    if (!bmoniUserId) {
      throw new Error(
        'PAYFLEX_TREASURY_BMONI_USER_ID is not set. Run `npm run provision:treasury` once ' +
          'against the sandbox and copy its output into .env.',
      );
    }
    return bmoniUserId;
  }

  private getSigningKey(): SigningKey {
    if (this.cachedSigningKey) return this.cachedSigningKey;
    const privateKey = this.configService.get<string>('PAYFLEX_TREASURY_OWNER_PRIVATE_KEY');
    if (!privateKey) {
      throw new Error(
        'PAYFLEX_TREASURY_OWNER_PRIVATE_KEY is not set. Run `npm run provision:treasury` once ' +
          'against the sandbox and copy its output into .env.',
      );
    }
    this.cachedSigningKey = new SigningKey(privateKey);
    return this.cachedSigningKey;
  }

  /** The treasury's own local AppUser row id — created by `npm run provision:treasury`. */
  async getAppUserId(): Promise<string> {
    if (this.cachedAppUserId) return this.cachedAppUserId;
    const bmoniUserId = this.getBmoniUserId();
    const appUser = await this.prisma.appUser.findUnique({ where: { bmoniUserId } });
    if (!appUser) {
      throw new Error(
        `No local AppUser row for treasury bmoniUserId ${bmoniUserId} — this usually means ` +
          `.env points at a different database than the one \`npm run provision:treasury\` wrote to.`,
      );
    }
    this.cachedAppUserId = appUser.id;
    return appUser.id;
  }

  /** Treasury's smart-wallet id for a fiat currency (e.g. "NGN"), cached after first lookup. */
  async getWalletId(fiatCurrency: string): Promise<string> {
    const cached = this.walletIdByCurrency.get(fiatCurrency);
    if (cached) return cached;

    const bmoniUserId = this.getBmoniUserId();
    const wallets = await this.bmoni.listWallets(bmoniUserId);
    const wallet = wallets.find((w) => w.currency === fiatCurrency);
    if (!wallet) {
      throw new Error(
        `PayFlex treasury has no ${fiatCurrency} smart wallet — provision one via the normal ` +
          `owner-proof-challenge/create-managed flow for the treasury's bmoniUserId first ` +
          `(stablecoin: ${stablecoinForFiat(fiatCurrency)}).`,
      );
    }
    this.walletIdByCurrency.set(fiatCurrency, wallet.id);
    return wallet.id;
  }

  /**
   * Signs a BMONI proposal's `signingPayloadHash` as a raw digest —
   * confirmed live (see backend/README.md "Phase 3 findings") that this,
   * not the EIP-712 hash of the accompanying `typedData`, is what BMONI
   * actually verifies against the registered owner address.
   */
  signDigest(digestHex: string): string {
    this.logger.log(`Treasury signing digest ${digestHex}`);
    return this.getSigningKey().sign(digestHex).serialized;
  }
}
