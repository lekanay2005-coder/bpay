/**
 * One-time setup: creates PayFlex's own BMONI user + NGN smart wallet to
 * act as the platform treasury account (see src/treasury/treasury.service.ts
 * for why this exists — loan disbursement needs a server-held signer,
 * since there's no end user present to sign it).
 *
 * Confirmed live (2026-09-04): proposal creation/signing works against a
 * smart wallet regardless of KYC/rail-onboarding status (our Phase 3 test
 * users transferred CNGN with no KYC at all) — so the treasury does NOT
 * need to run the KYC wizard or start-nigeria, just user + smart wallet
 * creation, same as scripts/sandbox-lifecycle.ts's first few steps.
 *
 * Run with: npm run provision:treasury
 * Then copy PAYFLEX_TREASURY_BMONI_USER_ID and
 * PAYFLEX_TREASURY_OWNER_PRIVATE_KEY from the output into .env.
 *
 * SECURITY: the printed private key controls real (sandbox) treasury
 * funds. In production this key must live in a KMS/HSM, never in a
 * plain .env file or terminal scrollback — see TreasuryService's doc
 * comment.
 */
import { NestFactory } from '@nestjs/core';
import { Wallet } from 'ethers';
import { AppModule } from '../src/app.module';
import { UsersService } from '../src/users/users.service';
import { OnboardingService } from '../src/onboarding/onboarding.service';

async function main() {
  const app = await NestFactory.createApplicationContext(AppModule);

  try {
    const users = app.get(UsersService);
    const onboarding = app.get(OnboardingService);

    const appUser = await users.getOrCreate({
      firstName: 'PayFlex',
      lastName: 'Treasury',
      email: `payflex.treasury.${Date.now()}@payflex.test`,
      phoneNumber: `+2347${String(Date.now()).slice(-8)}9`,
    });
    console.log('Treasury AppUser:', { id: appUser.id, bmoniUserId: appUser.bmoniUserId });

    const ownerWallet = Wallet.createRandom();
    await users.setOwnerAddress(appUser.id, ownerWallet.address);

    const challenge = await onboarding.requestOwnerProofChallenge(appUser.id, 'CNGN');
    const signature = await ownerWallet.signMessage(challenge.message);
    const smartWallet = await onboarding.createSmartWallet(appUser.id, {
      currency: 'CNGN',
      ownerProofChallengeId: challenge.challengeId,
      ownerProofSignature: signature,
    });

    console.log('\nTreasury NGN smart wallet:', {
      id: smartWallet.id,
      currency: smartWallet.currency,
      walletAddress: smartWallet.walletAddress,
    });

    console.log('\n' + '='.repeat(72));
    console.log('Add these to backend/.env:');
    console.log(`PAYFLEX_TREASURY_BMONI_USER_ID=${appUser.bmoniUserId}`);
    console.log(`PAYFLEX_TREASURY_OWNER_PRIVATE_KEY=${ownerWallet.privateKey}`);
    console.log('='.repeat(72));
    console.log(
      '\nNote: this treasury wallet has zero balance in sandbox (same limitation as every\n' +
        'other wallet in this build — see backend/README.md "Phase 3 findings"), so a real\n' +
        'disbursement will create and sign a valid proposal but will not execute on-chain.',
    );
  } finally {
    await app.close();
  }
}

main().catch((err) => {
  console.error('\n❌ Treasury provisioning failed:', err);
  process.exit(1);
});
