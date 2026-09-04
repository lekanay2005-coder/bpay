/**
 * Phase 1 verification harness: proves the full core-lifecycle sequence
 * (section 2.1 of the build brief) actually works end-to-end against the
 * live BMONI sandbox, using the real BmoniClientService/UsersService/
 * OnboardingService wired up exactly as the app runtime uses them.
 *
 * IMPORTANT — this script's ONLY deviation from the real app is step 5
 * below: there is no physical/emulated mobile device in this backend-only
 * environment, so we can't run bmoni_embedded_sdk to generate the owner
 * keypair and produce the EIP-191 signature. We simulate exactly that one
 * step with `ethers.Wallet` (a plain EVM keypair + personal_sign, which
 * *is* what EIP-191 signing is). This is a sandbox test stand-in only —
 * the Flutter app must never do this itself; production key generation
 * and signing goes through bmoni_embedded_sdk on-device, full stop.
 *
 * Run with: npm run sandbox:lifecycle
 * Requires: Postgres + Redis up (docker compose up -d) and
 * `npx prisma migrate dev` already run once.
 */
import { NestFactory } from '@nestjs/core';
import { Wallet } from 'ethers';
import { AppModule } from '../src/app.module';
import { UsersService } from '../src/users/users.service';
import { OnboardingService } from '../src/onboarding/onboarding.service';
import { BmoniClientService } from '../src/bmoni/bmoni-client.service';

async function main() {
  const app = await NestFactory.createApplicationContext(AppModule);

  try {
    const users = app.get(UsersService);
    const onboarding = app.get(OnboardingService);
    const bmoni = app.get(BmoniClientService);

    console.log('\n== 1. Create (or reuse) the persona user ==');
    // NOTE: the canonical persona phone +2348000000001 from the build
    // brief was already registered by another team when this was tested —
    // this sandbox key ("BMONI Hackathon") is shared across many
    // developers, and BMONI enforces phoneNumber uniqueness globally, not
    // per-partner-key. Using a distinct sandbox-only phone number here so
    // this script is re-runnable; the persona's firstName/lastName are
    // kept exactly as specified since that's what actually matters for
    // identity-matching behavior later in KYC (Phase 2).
    const dto = {
      firstName: 'Samson',
      lastName: 'Jabo',
      email: `payflex.sandbox.${Date.now()}@payflex.test`,
      phoneNumber: `+234700${String(Date.now()).slice(-7)}`,
    };
    const appUser = await users.getOrCreate(dto);
    console.log('AppUser:', { id: appUser.id, bmoniUserId: appUser.bmoniUserId });

    console.log('\n== 2. bvn-lookup preview (fetch-only, safe) ==');
    const bvnPreview = await bmoni.bvnLookup(appUser.bmoniUserId, '22222222222');
    console.log('bvn-lookup result:', bvnPreview);

    console.log('\n== 3. Generate on-device owner wallet (SIMULATED — see header comment) ==');
    const ownerWallet = Wallet.createRandom();
    console.log('ownerAddress:', ownerWallet.address);
    await users.setOwnerAddress(appUser.id, ownerWallet.address);

    console.log('\n== 4. List supported stablecoins, pick CNGN (NGN rail) ==');
    const { currencies } = await onboarding.getSupportedCurrencies();
    console.log('supported currencies:', currencies);
    const currency = currencies.includes('CNGN') ? 'CNGN' : currencies[0];

    console.log('\n== 5. Request owner-proof challenge ==');
    const challenge = await onboarding.requestOwnerProofChallenge(appUser.id, currency);
    console.log('challenge:', challenge);

    console.log('\n== 6. Sign challenge message (SIMULATED on-device signing) ==');
    const signature = await ownerWallet.signMessage(challenge.message);
    console.log('signature:', signature);

    console.log('\n== 7. Create managed smart wallet ==');
    const wallet = await onboarding.createSmartWallet(appUser.id, {
      currency,
      ownerProofChallengeId: challenge.challengeId,
      ownerProofSignature: signature,
    });
    console.log('SmartWallet:', wallet);

    console.log('\n== 8. Onboarding status ==');
    const status = await onboarding.getStatus(appUser.id);
    console.log('status:', status);

    console.log('\n✅ Phase 1 lifecycle verified end-to-end against the live sandbox.');
  } finally {
    await app.close();
  }
}

main().catch((err) => {
  console.error('\n❌ Sandbox lifecycle script failed:', err);
  process.exit(1);
});
