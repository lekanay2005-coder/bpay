/**
 * Phase 3 verification harness: QR Pay and PayTag transfers, end to end
 * against the live BMONI sandbox, using the real TransferService /
 * PayTagService / QrPayService / OnboardingService (the exact classes
 * the HTTP API uses).
 *
 * Same caveat as the earlier sandbox-lifecycle scripts: owner-wallet
 * keygen and signing are simulated with a plain ethers.Wallet because
 * there's no mobile device/emulator here. The Flutter app must always go
 * through bmoni_embedded_sdk for real key material.
 *
 * CRITICAL and non-obvious (see backend/README.md "Phase 3 findings" for
 * the full story): the value signed below is `signingPayloadHash` from
 * GET sign-payload, taken as a RAW digest — NOT the EIP-712 hash of the
 * accompanying `typedData` object. Signing the properly-computed EIP-712
 * digest was tested against this sandbox and REJECTED ("signature does
 * not match your registered owner address"); signing `signingPayloadHash`
 * directly was accepted. This is exactly what bmoni_embedded_sdk's
 * `signTransactionHash` does (no prefix, no additional hashing — sign the
 * supplied hash directly), so the real Flutter app needs no EIP-712
 * encoder despite BMONI returning full `typedData`.
 *
 * This sandbox has no way to fund a test wallet (no faucet endpoint, and
 * crypto deposit — the one funding path that exists — 502'd from BMONI's
 * own upstream bridge provider on every attempt during Phase 3 testing).
 * So this script proves proposal creation and signing succeed, but the
 * proposal will not progress past PENDING_APPROVALS to on-chain execution
 * — that is an expected sandbox limitation, not a bug here.
 *
 * Run with: npm run sandbox:phase3
 */
import { NestFactory } from '@nestjs/core';
import { SigningKey, Wallet } from 'ethers';
import { AppModule } from '../src/app.module';
import { UsersService } from '../src/users/users.service';
import { OnboardingService } from '../src/onboarding/onboarding.service';
import { TransferService } from '../src/transfer/transfer.service';
import { PayTagService } from '../src/transfer/paytag.service';
import { QrPayService } from '../src/transfer/qr-pay.service';
import { BmoniApiError } from '../src/bmoni/bmoni.errors';

/**
 * Confirmed live: the sign payload is prepared asynchronously after
 * proposal creation — an immediate GET can 409 with "Signing payload is
 * not ready yet. Wait until approvals complete and the transfer is
 * prepared." Poll rather than assuming it's ready right away.
 */
async function waitForSignPayload(
  transfers: TransferService,
  appUserId: string,
  proposalId: string,
) {
  for (let attempt = 0; attempt < 10; attempt++) {
    try {
      return await transfers.getSignPayload(appUserId, proposalId);
    } catch (err) {
      if (err instanceof BmoniApiError && err.status === 409 && attempt < 9) {
        await new Promise((r) => setTimeout(r, 1500));
        continue;
      }
      throw err;
    }
  }
  throw new Error('sign-payload never became ready');
}

async function provisionCngnWallet(
  users: UsersService,
  onboarding: OnboardingService,
  label: string,
) {
  const dto = {
    firstName: 'Samson',
    lastName: 'Jabo',
    email: `payflex.phase3.${label}.${Date.now()}@payflex.test`,
    phoneNumber: `+2347${String(Date.now()).slice(-8)}${Math.floor(Math.random() * 10)}`,
  };
  const appUser = await users.getOrCreate(dto);
  const ownerWallet = Wallet.createRandom();
  await users.setOwnerAddress(appUser.id, ownerWallet.address);
  const challenge = await onboarding.requestOwnerProofChallenge(appUser.id, 'CNGN');
  const signature = await ownerWallet.signMessage(challenge.message);
  const smartWallet = await onboarding.createSmartWallet(appUser.id, {
    currency: 'CNGN',
    ownerProofChallengeId: challenge.challengeId,
    ownerProofSignature: signature,
  });
  return { appUser, ownerWallet, smartWallet };
}

/** Signs a BMONI proposal's `signingPayloadHash` as a raw digest — see
 * the header comment above for why this, and not EIP-712 hashing. */
function signRawDigest(privateKey: string, digestHex: string): string {
  return new SigningKey(privateKey).sign(digestHex).serialized;
}

async function main() {
  const app = await NestFactory.createApplicationContext(AppModule);

  try {
    const users = app.get(UsersService);
    const onboarding = app.get(OnboardingService);
    const transfers = app.get(TransferService);
    const payTags = app.get(PayTagService);
    const qrPay = app.get(QrPayService);

    console.log('\n== 1. Provision sender (A) and recipient (B) with CNGN wallets ==');
    const a = await provisionCngnWallet(users, onboarding, 'a');
    const b = await provisionCngnWallet(users, onboarding, 'b');
    console.log('A:', { appUserId: a.appUser.id, bmoniUserId: a.appUser.bmoniUserId });
    console.log('B:', { appUserId: b.appUser.id, bmoniUserId: b.appUser.bmoniUserId });

    console.log('\n== 2. Register a PayTag for B ==');
    const tag = `samson${Date.now().toString().slice(-6)}`;
    await payTags.register(b.appUser.id, tag);
    const resolved = await payTags.resolve(tag);
    console.log(`@${tag} resolves to bmoniUserId:`, resolved.bmoniUserId);
    if (resolved.bmoniUserId !== b.appUser.bmoniUserId) {
      throw new Error('PayTag resolved to the wrong user');
    }

    console.log('\n== 3. Direct transfer A -> B via PayTag (through TransferController logic) ==');
    const directProposal = await transfers.createTransfer(a.appUser.id, {
      toBmoniUserId: resolved.bmoniUserId, // TransferController would resolve toPayTag to this
      amount: '1.00',
      currency: 'NGN',
      description: 'Phase 3 PayTag transfer test',
    });
    console.log('proposal:', {
      id: directProposal.id,
      status: directProposal.status,
      nextAction: directProposal.nextAction,
    });

    console.log('\n== 4. Sign that proposal ==');
    const signPayload = await waitForSignPayload(transfers, a.appUser.id, directProposal.id);
    console.log('signingPayloadHash:', signPayload.signingPayloadHash);
    const directSignature = signRawDigest(a.ownerWallet.privateKey, signPayload.signingPayloadHash);
    const signResult = await transfers.submitSignature(
      a.appUser.id,
      directProposal.id,
      directSignature,
    );
    console.log('after signing:', {
      currentSignatures: signResult.proposal?.currentSignatures,
      requiredSignatures: signResult.proposal?.requiredSignatures,
      status: signResult.proposal?.status,
      nextAction: signResult.proposal?.nextAction,
    });

    console.log('\n== 5. QR Pay: A generates a QR for themselves, B "scans" and pays ==');
    // Reuse A as the QR recipient this time to exercise the generate/decode
    // path independently of the direct-transfer test above.
    const qr = await qrPay.generate(a.appUser.id, { amount: '2.50', currency: 'NGN' });
    console.log('QR token (truncated):', qr.token.slice(0, 40) + '...');
    const decoded = qrPay.decode(qr.token);
    console.log('decoded payload:', decoded);
    const qrProposal = await qrPay.pay(b.appUser.id, qr.token);
    console.log('QR-initiated proposal:', {
      id: qrProposal.id,
      toUserId: qrProposal.toUserId,
      amount: qrProposal.amount,
      status: qrProposal.status,
    });
    if (qrProposal.toUserId !== a.appUser.bmoniUserId) {
      throw new Error('QR Pay proposal targeted the wrong recipient');
    }

    console.log('\n== 6. Sign the QR-initiated proposal (payer is B) ==');
    const qrSignPayload = await waitForSignPayload(transfers, b.appUser.id, qrProposal.id);
    const qrSignature = signRawDigest(b.ownerWallet.privateKey, qrSignPayload.signingPayloadHash);
    const qrSignResult = await transfers.submitSignature(
      b.appUser.id,
      qrProposal.id,
      qrSignature,
    );
    console.log('after signing:', {
      currentSignatures: qrSignResult.proposal?.currentSignatures,
      status: qrSignResult.proposal?.status,
    });

    console.log('\n== 7. Reject a fresh third proposal, to exercise that path too ==');
    const rejectMe = await transfers.createTransfer(a.appUser.id, {
      toBmoniUserId: b.appUser.bmoniUserId,
      amount: '0.50',
      currency: 'NGN',
    });
    const rejected = await transfers.reject(a.appUser.id, rejectMe.id, 'Phase 3 reject test');
    console.log('after reject:', { status: rejected.proposal?.status });

    console.log('\n== 8. List A\'s CNGN proposals ==');
    const list = await transfers.listProposals(a.appUser.id, 'NGN');
    console.log(`A has ${list.proposals.length} CNGN proposal(s) on file.`);

    console.log(
      '\n✅ Phase 3 transfer/QR/PayTag wiring verified end-to-end against the live sandbox\n' +
        '   (proposal creation + signing confirmed working; on-chain execution is not\n' +
        '   observable here because this sandbox has no way to fund a test wallet).',
    );
  } finally {
    await app.close();
  }
}

main().catch((err) => {
  console.error('\n❌ Phase 3 sandbox script failed:', err);
  process.exit(1);
});
