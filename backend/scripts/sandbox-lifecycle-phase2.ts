/**
 * Phase 2 verification harness: KYC wizard + NGN rail onboarding + wallet
 * home, end to end against the live BMONI sandbox, using the real
 * KycService / OnboardingService / WalletService (the exact classes the
 * HTTP API uses).
 *
 * Same caveat as scripts/sandbox-lifecycle.ts: owner-wallet keygen and
 * EIP-191 signing are simulated with a plain ethers.Wallet because there's
 * no mobile device/emulator in this backend-only environment — that is
 * NOT how the real Flutter app works, which always goes through
 * bmoni_embedded_sdk on-device.
 *
 * The KYC document images are a real (but content-meaningless) PNG
 * fixture — BMONI validates that uploads are genuine JPEG/PNG/PDF files
 * (confirmed live: plain random bytes are rejected with "not a valid
 * JPEG, PNG, or PDF"), but does not appear to validate that a NGN-path
 * document's *contents* depict an actual ID/utility bill/face. The
 * USD/Sumsub path is stricter still — see backend/README.md "Phase 2
 * findings" (start-usa returned 422 BAD_SELFIE/DOCUMENT_PAGE_MISSING
 * against this same fixture). This script only exercises the NGN rail
 * for that reason.
 *
 * Run with: npm run sandbox:phase2
 * Requires: Postgres + Redis up and `npx prisma migrate dev` already run.
 */
import { NestFactory } from '@nestjs/core';
import { Wallet } from 'ethers';
import { readFileSync } from 'fs';
import { join } from 'path';
import { AppModule } from '../src/app.module';
import { UsersService } from '../src/users/users.service';
import { OnboardingService } from '../src/onboarding/onboarding.service';
import { KycService } from '../src/kyc/kyc.service';
import { WalletService } from '../src/wallet/wallet.service';

/** A real (but content-meaningless) PNG — BMONI rejects non-image bytes
 * outright and anything under ~2KB, but see the header comment above for
 * why plain content validity is as far as the NGN path checks. */
const FIXTURE = readFileSync(join(__dirname, 'fixtures/test-document.png'));

function testFile(label: string) {
  return {
    buffer: FIXTURE,
    filename: `${label}.png`,
    contentType: 'image/png',
  };
}

async function main() {
  const app = await NestFactory.createApplicationContext(AppModule);

  try {
    const users = app.get(UsersService);
    const onboarding = app.get(OnboardingService);
    const kyc = app.get(KycService);
    const wallet = app.get(WalletService);

    console.log('\n== 1. Create (or reuse) the persona user ==');
    const dto = {
      firstName: 'Samson',
      lastName: 'Jabo',
      email: `payflex.phase2.${Date.now()}@payflex.test`,
      phoneNumber: `+234704${String(Date.now()).slice(-7)}`,
    };
    const appUser = await users.getOrCreate(dto);
    console.log('AppUser:', { id: appUser.id, bmoniUserId: appUser.bmoniUserId });

    console.log('\n== 2. On-device owner wallet + CNGN smart wallet (SIMULATED signer) ==');
    const ownerWallet = Wallet.createRandom();
    await users.setOwnerAddress(appUser.id, ownerWallet.address);
    const challenge = await onboarding.requestOwnerProofChallenge(appUser.id, 'CNGN');
    const signature = await ownerWallet.signMessage(challenge.message);
    const smartWallet = await onboarding.createSmartWallet(appUser.id, {
      currency: 'CNGN',
      ownerProofChallengeId: challenge.challengeId,
      ownerProofSignature: signature,
    });
    console.log('SmartWallet:', { id: smartWallet.id, currency: smartWallet.currency, walletAddress: smartWallet.walletAddress });

    console.log('\n== 3. KYC options + occupations ==');
    const options = await kyc.getOptions(appUser.id);
    console.log('genders:', options.genders, '| fundsSources:', options.fundsSources);
    const occupations = await kyc.getOccupations(appUser.id, 'Accountant');
    const occupationCode = occupations[0]?.id;
    console.log('occupationCode:', occupationCode, occupations[0]?.displayName);

    console.log('\n== 4. Submit identification document ==');
    await kyc.submitIdentification(
      appUser.id,
      { type: 'national_id', documentNumber: 'A1234567', issuingCountry: 'NGA' },
      testFile('id-front'),
    );

    console.log('\n== 5. Submit proof of address ==');
    await kyc.submitProofOfAddress(appUser.id, { type: 'utility_bill' }, testFile('poa'));

    console.log('\n== 6. Submit biometric (selfie) ==');
    await kyc.submitBiometric(appUser.id, { type: 'selfie' }, testFile('selfie'));

    console.log('\n== 7. PATCH kyc with persona details ==');
    const patchResult = await kyc.patch(appUser.id, {
      personalInfo: { dateOfBirth: '1995-07-07', gender: 'male' },
      address: {
        streetLine1: '123 Paul Gas Avenue',
        city: 'Lagos',
        state: 'Lagos',
        postalCode: '100001',
        countryCode: 'NGA',
      },
      employment: {
        employmentStatus: 'employed',
        occupationCode,
        employerName: 'PayFlex Test Employer',
        monthlySalary: 500000,
      },
      sourceOfFunds: 'salary',
      accountPurpose: 'personal',
      estimatedMonthlyVolume: 5000,
    });
    console.log('patch result:', patchResult);

    console.log('\n== 8. Readiness ==');
    const readiness = await kyc.getReadiness(appUser.id);
    console.log('readiness:', readiness);
    if (!readiness.ready) throw new Error('Expected readiness.ready === true at this point');

    console.log('\n== 9. Activate KYC (id-and-liveness, currency=NGN) ==');
    const activation = await kyc.activate(appUser.id, 'NGN', 'id-and-liveness');
    console.log('activation:', activation);

    console.log('\n== 10. start-nigeria with persona BVN ==');
    const startResult = await onboarding.startNigeria(appUser.id, {
      bvn: '22222222222',
      ngnWalletIndex: 0,
    });
    console.log('start-nigeria:', startResult);

    console.log('\n== 11. Onboarding status (polling — confirmed live: anchorStatus flips to' +
      ' "active" asynchronously a few seconds after start-nigeria returns, not immediately) ==');
    let status = await onboarding.getStatus(appUser.id);
    for (let attempt = 0; attempt < 10 && status.anchorStatus !== 'active'; attempt++) {
      await new Promise((r) => setTimeout(r, 2000));
      status = await onboarding.getStatus(appUser.id);
      console.log(`  poll ${attempt + 1}: anchorStatus=${status.anchorStatus}`);
    }
    console.log('status:', status);
    if (status.anchorStatus !== 'active') {
      throw new Error(`Expected anchorStatus === "active" within ~20s, got "${status.anchorStatus}"`);
    }

    console.log('\n== 12. Wallet home: wallets / balances / transactions ==');
    console.log('wallets:', await wallet.listWallets(appUser.id));
    console.log('balances:', await wallet.listBalances(appUser.id));
    console.log(
      'transactions:',
      await wallet.getTransactions(appUser.id, smartWallet.id),
    );

    console.log('\n✅ Phase 2 NGN KYC + onboarding verified end-to-end against the live sandbox.');
  } finally {
    await app.close();
  }
}

main().catch((err) => {
  console.error('\n❌ Phase 2 sandbox script failed:', err);
  process.exit(1);
});
