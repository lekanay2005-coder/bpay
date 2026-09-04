/**
 * Phase 4 verification harness: savings goals, loan application +
 * credit-scored disbursement, and agent cash-in/cash-out, end to end
 * against the live BMONI sandbox, using the real SavingsService /
 * LoansService / AgentService / TreasuryService.
 *
 * Same simulated-signer caveat as the earlier scripts for CUSTOMER-side
 * signing (ethers.Wallet standing in for bmoni_embedded_sdk). Loan
 * disbursement is different: TreasuryService signs it for real,
 * server-side, with the actual key from .env — that IS how the real app
 * will do it too, since there's no end user present to sign a payout of
 * PayFlex's own money. See src/treasury/treasury.service.ts.
 *
 * Every proposal created here can be signed but, same as Phases 3, will
 * not execute on-chain — this sandbox has no way to fund a wallet.
 *
 * Run with: npm run sandbox:phase4 (requires PAYFLEX_TREASURY_* in .env
 * — run `npm run provision:treasury` first if you haven't).
 */
import { NestFactory } from '@nestjs/core';
import { SigningKey, Wallet } from 'ethers';
import { AppModule } from '../src/app.module';
import { UsersService } from '../src/users/users.service';
import { OnboardingService } from '../src/onboarding/onboarding.service';
import { TransferService } from '../src/transfer/transfer.service';
import { SavingsService } from '../src/savings/savings.service';
import { LoansService } from '../src/loans/loans.service';
import { AgentService } from '../src/agent/agent.service';
import { PrismaService } from '../src/prisma/prisma.service';
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
    email: `payflex.phase4.${label}.${Date.now()}@payflex.test`,
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

async function main() {
  const app = await NestFactory.createApplicationContext(AppModule);

  try {
    const users = app.get(UsersService);
    const onboarding = app.get(OnboardingService);
    const transfers = app.get(TransferService);
    const savings = app.get(SavingsService);
    const loans = app.get(LoansService);
    const agent = app.get(AgentService);
    const prisma = app.get(PrismaService);

    console.log('\n== 1. Provision customer and agent NGN wallets ==');
    const customer = await provisionNgnWallet(users, onboarding, 'customer');
    const agentUser = await provisionNgnWallet(users, onboarding, 'agent');
    console.log('customer:', customer.appUser.id, customer.appUser.bmoniUserId);
    console.log('agent:', agentUser.appUser.id, agentUser.appUser.bmoniUserId);
    await agent.setAgentStatus(agentUser.appUser.id, true);

    console.log('\n== 2. Create a savings goal for the customer ==');
    const goal = await savings.createGoal(customer.appUser.id, {
      name: 'Rent fund',
      currency: 'NGN',
      targetAmount: '1000.00',
      contributionAmount: '50.00',
      frequency: 'DAILY',
    });
    console.log('goal:', { id: goal.id, nextContributionAt: goal.nextContributionAt });

    // Test-only: back-date nextContributionAt so the due-check below finds
    // it immediately rather than waiting a day. The scheduler itself
    // (SavingsSchedulerService) needs no such help in production — it runs
    // hourly and just checks whatever's actually due.
    await prisma.savingsGoal.update({
      where: { id: goal.id },
      data: { nextContributionAt: new Date(Date.now() - 1000) },
    });

    console.log('\n== 3. Run the due-check and contribute ==');
    const dueCheck = await savings.runDueCheck();
    console.log('due-check result:', dueCheck);
    const due = await savings.listDueContributions(customer.appUser.id);
    console.log(`${due.length} contribution(s) due`);
    const contributionProposal = await savings.contribute(customer.appUser.id, due[0].id);
    console.log('contribution proposal:', {
      id: contributionProposal.id,
      toUserId: contributionProposal.toUserId,
      amount: contributionProposal.amount,
    });
    const contribSignPayload = await waitForSignPayload(
      transfers,
      customer.appUser.id,
      contributionProposal.id,
    );
    const contribSignature = signRawDigest(
      customer.ownerWallet.privateKey,
      contribSignPayload.signingPayloadHash,
    );
    const contribSignResult = await transfers.submitSignature(
      customer.appUser.id,
      contributionProposal.id,
      contribSignature,
    );
    console.log('contribution signed:', {
      currentSignatures: contribSignResult.proposal?.currentSignatures,
      status: contribSignResult.proposal?.status,
    });

    console.log('\n== 4a. Loan application — fresh account, expect REJECTED ==');
    const rejectedLoan = await loans.apply(customer.appUser.id, {
      requestedAmount: '500.00',
      currency: 'NGN',
    });
    console.log('rejected loan:', {
      status: rejectedLoan.status,
      creditScore: rejectedLoan.creditScore,
      reasoning: rejectedLoan.scoringReasoning,
    });
    if (rejectedLoan.status !== 'REJECTED') {
      throw new Error(`Expected REJECTED for a fresh account, got ${rejectedLoan.status}`);
    }

    console.log('\n== 4b. Loan application — backdated account, expect APPROVED + DISBURSED ==');
    // Test-only: backdate createdAt to simulate an account with enough
    // history to clear the score threshold. This sandbox has no funded
    // wallets, so real transaction-history signal (the other half of the
    // score) is unavailable no matter which account we use — see
    // backend/README.md "Phase 4 findings".
    await prisma.appUser.update({
      where: { id: customer.appUser.id },
      data: { createdAt: new Date(Date.now() - 90 * 24 * 60 * 60 * 1000) },
    });
    const approvedLoan = await loans.apply(customer.appUser.id, {
      requestedAmount: '500.00',
      currency: 'NGN',
    });
    console.log('approved loan:', {
      status: approvedLoan.status,
      creditScore: approvedLoan.creditScore,
      approvedAmount: approvedLoan.approvedAmount,
      disbursementProposalId: approvedLoan.disbursementProposalId,
      reasoning: approvedLoan.scoringReasoning,
    });
    if (approvedLoan.status !== 'DISBURSED') {
      throw new Error(`Expected DISBURSED, got ${approvedLoan.status}`);
    }
    console.log(
      '✅ Treasury signed the disbursement server-side — no simulated end-user signing involved.',
    );

    console.log('\n== 5. Repay the loan (customer signs) ==');
    const repayments = await loans.listRepayments(approvedLoan.id);
    console.log('repayment due:', repayments[0]);
    const repayProposal = await loans.payRepayment(customer.appUser.id, repayments[0].id);
    const repaySignPayload = await waitForSignPayload(
      transfers,
      customer.appUser.id,
      repayProposal.id,
    );
    const repaySignature = signRawDigest(
      customer.ownerWallet.privateKey,
      repaySignPayload.signingPayloadHash,
    );
    const repaySignResult = await transfers.submitSignature(
      customer.appUser.id,
      repayProposal.id,
      repaySignature,
    );
    console.log('repayment signed:', {
      currentSignatures: repaySignResult.proposal?.currentSignatures,
      status: repaySignResult.proposal?.status,
    });

    console.log('\n== 6. Agent cash-in (agent -> customer) ==');
    const cashInProposal = await agent.cashIn(agentUser.appUser.id, {
      toBmoniUserId: customer.appUser.bmoniUserId,
      amount: '20.00',
      currency: 'NGN',
    });
    const cashInSignPayload = await waitForSignPayload(
      transfers,
      agentUser.appUser.id,
      cashInProposal.id,
    );
    const cashInSignature = signRawDigest(
      agentUser.ownerWallet.privateKey,
      cashInSignPayload.signingPayloadHash,
    );
    await transfers.submitSignature(agentUser.appUser.id, cashInProposal.id, cashInSignature);
    console.log('cash-in proposal signed:', cashInProposal.id);

    console.log('\n== 7. Agent cash-out (customer -> agent) ==');
    const cashOutProposal = await agent.cashOut(customer.appUser.id, {
      agentBmoniUserId: agentUser.appUser.bmoniUserId,
      amount: '15.00',
      currency: 'NGN',
    });
    const cashOutSignPayload = await waitForSignPayload(
      transfers,
      customer.appUser.id,
      cashOutProposal.id,
    );
    const cashOutSignature = signRawDigest(
      customer.ownerWallet.privateKey,
      cashOutSignPayload.signingPayloadHash,
    );
    await transfers.submitSignature(customer.appUser.id, cashOutProposal.id, cashOutSignature);
    console.log('cash-out proposal signed:', cashOutProposal.id);

    const agentLedger = await agent.listTransactions(agentUser.appUser.id);
    console.log(`\nAgent ledger has ${agentLedger.length} entries:`, agentLedger.map((t) => t.type));
    if (agentLedger.length !== 2) {
      throw new Error(`Expected 2 agent ledger entries, got ${agentLedger.length}`);
    }

    console.log('\n✅ Phase 4 microfinance layer verified end-to-end against the live sandbox.');
  } finally {
    await app.close();
  }
}

main().catch((err) => {
  console.error('\n❌ Phase 4 sandbox script failed:', err);
  process.exit(1);
});
