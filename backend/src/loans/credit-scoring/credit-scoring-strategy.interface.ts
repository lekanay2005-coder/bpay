import { Transaction } from '../../bmoni/dto/wallet-home.dto';

export interface CreditScoreInput {
  accountAgeDays: number;
  transactions: Transaction[];
  requestedAmount: string;
  currency: string;
}

export interface CreditScoreResult {
  /** 0-100. */
  score: number;
  approved: boolean;
  /** Decimal string, always <= requestedAmount. "0" when not approved. */
  approvedAmount: string;
  reasoning: string[];
}

/**
 * Build brief section 3: BMONI has no credit product or scoring
 * endpoint — this is entirely PayFlex's own logic, built on top of
 * BMONI's transaction history as the only available signal. Kept
 * pluggable per the brief ("you'll want to iterate on it") rather than
 * hardcoding a formula into LoanService.
 */
export interface CreditScoringStrategy {
  score(input: CreditScoreInput): CreditScoreResult;
}
