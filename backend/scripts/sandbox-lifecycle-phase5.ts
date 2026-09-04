/**
 * Phase 5 verification harness: split-bill and send-via-link/escrow, end
 * to end against the live BMONI sandbox, using the real SplitBillService
 * / LinksService / TreasuryService.
 *
 * Same simulated-signer caveat as every earlier script for end-user
 * signing. The escrow release in step 4 below is signed by
 * TreasuryService server-side, same as loan disbursement in Phase 4 — no
 * simulated end-user signing involved there.
 *
 * Run with: npm run sandbox:phase5 (requires PAYFLEX_TREASURY_* in .env
 * for the escrow steps — run `npm run provision:treasury` first if you
 * haven't).
 */
import { NestFactory } from '@nestjs/core';
import { SigningKey, Wallet } from 'ethers';
import { AppModule } from '../src/app.module';
import { UsersService } from '../src/users/users.service';
import { OnboardingService } from '../src/onboarding/onboarding.service';
import { TransferService } from '../src/transfer/transfer.service';
import { PayTagService } from '../src/transfer/paytag.service';
import { SplitBillService } from '../src/split-bill/split-bill.service';
import { LinksService } from '../src/links/links.service';
import { BmoniApiError } from '../src/bmoni/bmoni.errors';

function signRawDigest(privateKey: string, digestHex: string): string {
  return new SigningKey(privateKey).sign(digestHex).serialized;
}

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

async function provisionNgnWallet(
  users: UsersService,
  onboarding: OnboardingService,
  label: string,
) {
  const appUser = await users.getOrCreate({
    firstName: 'Samson',
    lastName: 'Jabo',
    email: `payflex.phase5.${label}.${Date.now()}@payflex.test`,
    phoneNumber: `+2347${String(Date.now()).slice(-8)}${Math.floor(Math.random() * 10)}`,
  });
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

async function signAndSubmit(
  transfers: TransferService,
  appUserId: string,
  privateKey: string,
  proposalId: string,
) {
  const signPayload = await waitForSignPayload(transfers, appUserId, proposalId);
  const signature = signRawDigest(privateKey, signPayload.signingPayloadHash);
  return transfers.submitSignature(appUserId, proposalId, signature);
}

async function main() {
  const app = await NestFactory.createApplicationContext(AppModule);

  try {
    const users = app.get(UsersService);
    const onboarding = app.get(OnboardingService);
    const transfers = app.get(TransferService);
    const payTags = app.get(PayTagService);
    const splitBills = app.get(SplitBillService);
    const links = app.get(LinksService);

    console.log('\n== 1. Provision a payer and two contributors ==');
    const payer = await provisionNgnWallet(users, onboarding, 'payer');
    const c1 = await provisionNgnWallet(users, onboarding, 'c1');
    const c2 = await provisionNgnWallet(users, onboarding, 'c2');
    const c1Tag = `c1${Date.now().toString().slice(-6)}`;
    const c2Tag = `c2${Date.now().toString().slice(-6)}`;
    await payTags.register(c1.appUser.id, c1Tag);
    await payTags.register(c2.appUser.id, c2Tag);

    console.log('\n== 2. Create a split bill (payer is creator, c1 + c2 owe shares) ==');
    const { splitBill, qrToken } = await splitBills.create(payer.appUser.id, {
      description: 'Dinner',
      currency: 'NGN',
      totalAmount: '50.00',
      contributors: [
        { payTag: c1Tag, shareAmount: '30.00' },
        { payTag: c2Tag, shareAmount: '20.00' },
      ],
    });
    console.log('split bill:', { id: splitBill.id, status: splitBill.status });
    console.log('QR token (truncated):', qrToken.slice(0, 40) + '...');

    console.log('\n== 3. Resolve the QR token, both contributors pay their share ==');
    const viaToken = await splitBills.getByToken(qrToken);
    console.log('resolved via QR:', { id: viaToken.id, contributors: viaToken.contributors.length });

    const c1Proposal = await splitBills.pay(c1.appUser.id, splitBill.id);
    await signAndSubmit(transfers, c1.appUser.id, c1.ownerWallet.privateKey, c1Proposal.id);
    console.log('c1 paid their share:', c1Proposal.amount);

    const c2Proposal = await splitBills.pay(c2.appUser.id, splitBill.id);
    await signAndSubmit(transfers, c2.appUser.id, c2.ownerWallet.privateKey, c2Proposal.id);
    console.log('c2 paid their share:', c2Proposal.amount);

    const finalBill = await splitBills.getDetail(splitBill.id);
    console.log('final split bill status:', finalBill.status);
    if (finalBill.status !== 'COMPLETED') {
      throw new Error(`Expected split bill COMPLETED once all shares are paid, got ${finalBill.status}`);
    }

    console.log('\n== 4. Send-via-link: recipient already has a bmoniUserId -> plain transfer ==');
    const directResult = await links.sendViaLink(payer.appUser.id, {
      toBmoniUserId: c1.appUser.bmoniUserId,
      amount: '5.00',
      currency: 'NGN',
    });
    console.log('direct result type:', directResult.type);
    if (directResult.type !== 'DIRECT_TRANSFER') {
      throw new Error(`Expected DIRECT_TRANSFER for a known recipient, got ${directResult.type}`);
    }
    await signAndSubmit(
      transfers,
      payer.appUser.id,
      payer.ownerWallet.privateKey,
      directResult.proposal.id,
    );
    console.log('direct send-via-link signed.');

    console.log('\n== 5. Send-via-link: unknown recipient -> escrow ==');
    const escrowResult = await links.sendViaLink(payer.appUser.id, {
      amount: '10.00',
      currency: 'NGN',
    });
    console.log('escrow result type:', escrowResult.type);
    if (escrowResult.type !== 'ESCROW') {
      throw new Error(`Expected ESCROW for an unknown recipient, got ${escrowResult.type}`);
    }
    await signAndSubmit(
      transfers,
      payer.appUser.id,
      payer.ownerWallet.privateKey,
      escrowResult.escrowProposal.id,
    );
    console.log('escrow proposal (sender -> treasury) signed.');

    const preview = await links.previewClaim(escrowResult.claimToken);
    console.log('claim preview:', preview);
    if (preview.status !== 'ESCROWED') {
      throw new Error(`Expected ESCROWED, got ${preview.status}`);
    }

    console.log('\n== 6. Recipient onboards (needs an NGN wallet before they can claim) ==');
    const recipient = await provisionNgnWallet(users, onboarding, 'recipient');

    console.log('\n== 7. Recipient claims — treasury signs the release server-side ==');
    const claimed = await links.claim(recipient.appUser.id, escrowResult.claimToken);
    console.log('claimed link:', {
      status: claimed.status,
      releaseProposalId: claimed.releaseProposalId,
      claimedByAppUserId: claimed.claimedByAppUserId,
    });
    if (claimed.status !== 'CLAIMED') {
      throw new Error(`Expected CLAIMED, got ${claimed.status}`);
    }
    console.log(
      '✅ Treasury signed the escrow release server-side — no simulated end-user signing involved.',
    );

    console.log('\n✅ Phase 5 split-bill and send-via-link/escrow verified end-to-end against the live sandbox.');
  } finally {
    await app.close();
  }
}

main().catch((err) => {
  console.error('\n❌ Phase 5 sandbox script failed:', err);
  process.exit(1);
});
