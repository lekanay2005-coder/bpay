/**
 * The build brief (docs/BUILD_PROMPT.md section 6) says BVN verification
 * checks both the number AND the submitted name, and asks for "at least
 * one automated test for the deliberate-mismatch case (valid persona BVN
 * + wrong name)" since it's supposedly deterministic in sandbox.
 *
 * This script runs exactly that scenario end to end against the live
 * sandbox: a user registered under a name that does NOT match BVN
 * 22222222222 (which belongs to "Samson Jabo" — see kyc/bvn-lookup),
 * carried through owner-wallet + CNGN smart-wallet provisioning, then
 * POST onboarding/start-nigeria with that real BVN.
 *
 * IMPORTANT — what we actually found (2026-09-04), and why this is a
 * script with a loud PASS/WARNING report rather than a Jest test that
 * silently asserts one direction: in manual testing, this sandbox's
 * start-nigeria did NOT synchronously reject the mismatch — it returned
 * 200 with a workflowId, and onboarding/status's anchorStatus flipped to
 * "active" immediately, exactly as it does for a correctly-matched name.
 * That's a real, compliance-relevant deviation from what the brief
 * describes, not a bug in this codebase — see backend/README.md "Phase 2
 * findings". It's possible BMONI enforces the name match later,
 * asynchronously, out-of-band from this endpoint (e.g. a subsequent
 * kyc.action_required webhook) — this script only checks the synchronous
 * response, which is all that's observable without a live webhook
 * receiver wired to a public URL.
 *
 * Run with: npm run sandbox:kyc-mismatch
 */
import { NestFactory } from '@nestjs/core';
import { Wallet } from 'ethers';
import { AppModule } from '../src/app.module';
import { UsersService } from '../src/users/users.service';
import { OnboardingService } from '../src/onboarding/onboarding.service';
import { BmoniClientService } from '../src/bmoni/bmoni-client.service';
import { BmoniApiError } from '../src/bmoni/bmoni.errors';

const SAMSON_JABO_BVN = '22222222222';

async function main() {
  const app = await NestFactory.createApplicationContext(AppModule);

  try {
    const users = app.get(UsersService);
    const onboarding = app.get(OnboardingService);
    const bmoni = app.get(BmoniClientService);

    console.log('\n== Create a user with a name that does NOT match the BVN ==');
    const appUser = await users.getOrCreate({
      firstName: 'Deliberately',
      lastName: 'Mismatched',
      email: `payflex.mismatch.${Date.now()}@payflex.test`,
      phoneNumber: `+234705${String(Date.now()).slice(-7)}`,
    });
    console.log('AppUser (wrong name on purpose):', {
      id: appUser.id,
      bmoniUserId: appUser.bmoniUserId,
      firstName: appUser.firstName,
      lastName: appUser.lastName,
    });

    console.log('\n== Confirm the BVN actually belongs to someone else (Samson Jabo) ==');
    const bvnRecord = await bmoni.bvnLookup(appUser.bmoniUserId, SAMSON_JABO_BVN);
    console.log('bvn-lookup name on file:', bvnRecord.firstName, bvnRecord.lastName);

    console.log('\n== Provision owner wallet + CNGN smart wallet (SIMULATED signer) ==');
    const ownerWallet = Wallet.createRandom();
    await users.setOwnerAddress(appUser.id, ownerWallet.address);
    const challenge = await onboarding.requestOwnerProofChallenge(appUser.id, 'CNGN');
    const signature = await ownerWallet.signMessage(challenge.message);
    await onboarding.createSmartWallet(appUser.id, {
      currency: 'CNGN',
      ownerProofChallengeId: challenge.challengeId,
      ownerProofSignature: signature,
    });

    console.log('\n== Attempt start-nigeria with the mismatched name + real BVN ==');
    let rejected = false;
    let rejection: unknown;
    try {
      const result = await onboarding.startNigeria(appUser.id, {
        bvn: SAMSON_JABO_BVN,
        ngnWalletIndex: 0,
      });
      console.log('start-nigeria did NOT reject the mismatch. Response:', result);
    } catch (err) {
      rejected = true;
      rejection = err instanceof BmoniApiError ? err.message : err;
      console.log('start-nigeria REJECTED the mismatch:', rejection);
    }

    // anchorStatus is confirmed asynchronous and can pass through an
    // intermediate "pending" state before settling — poll past both
    // "not_started" and "pending" rather than checking once or stopping
    // at the first non-"not_started" value.
    const UNSETTLED = new Set(['not_started', 'pending']);
    let status = await onboarding.getStatus(appUser.id);
    for (let attempt = 0; attempt < 15 && UNSETTLED.has(status.anchorStatus) && !rejected; attempt++) {
      await new Promise((r) => setTimeout(r, 2000));
      status = await onboarding.getStatus(appUser.id);
      console.log(`  poll ${attempt + 1}: anchorStatus=${status.anchorStatus}`);
    }
    console.log('final onboarding status:', status);

    const settledAsActive = status.anchorStatus === 'active';

    console.log('\n' + '='.repeat(72));
    if (rejected) {
      console.log('PASS: sandbox rejected a BVN/name mismatch, matching the build brief.');
    } else if (!settledAsActive) {
      console.log(
        `INCONCLUSIVE: start-nigeria accepted the mismatch synchronously, and anchorStatus ` +
          `did not settle to "active" within the poll window (last seen: "${status.anchorStatus}") ` +
          `— this MIGHT mean an async rejection is still in flight. Re-run with a longer poll ` +
          `or check for a kyc.action_required webhook before concluding either way.`,
      );
    } else {
      console.log(
        'WARNING: sandbox did NOT reject a BVN/name mismatch at start-nigeria.\n' +
          'anchorStatus is now "' +
          status.anchorStatus +
          '" for a user whose name does not\n' +
          "match the BVN's name on file. This contradicts the build brief's claim\n" +
          'that BVN verification checks the name — treat this as a live finding to\n' +
          're-verify before relying on start-nigeria alone as a compliance control.\n' +
          'See backend/README.md "Phase 2 findings".',
      );
    }
    console.log('='.repeat(72));
  } finally {
    await app.close();
  }
}

main().catch((err) => {
  console.error('\n❌ kyc-bvn-mismatch-check script crashed unexpectedly:', err);
  process.exit(1);
});
