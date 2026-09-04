import { Injectable } from '@nestjs/common';
import {
  CreditScoreInput,
  CreditScoreResult,
  CreditScoringStrategy,
} from './credit-scoring-strategy.interface';

/**
 * A deliberately simple first-pass heuristic — not a real underwriting
 * model. Rewards account age, transaction activity, and inflow volume;
 * approves a fraction of requested amount scaled by score once a minimum
 * bar is cleared. Swap this out (or add a second strategy and pick
 * between them in LoanService) once there's real data to tune against —
 * that's the entire point of it sitting behind an interface.
 */
@Injectable()
export class SimpleCreditScoringStrategy implements CreditScoringStrategy {
  private static readonly APPROVAL_THRESHOLD = 30;

  score(input: CreditScoreInput): CreditScoreResult {
    const reasoning: string[] = [];

    const ageScore = Math.min(30, Math.floor(input.accountAgeDays / 3));
    reasoning.push(`Account age ${input.accountAgeDays}d -> ${ageScore}/30 pts`);

    const txCountScore = Math.min(30, input.transactions.length * 3);
    reasoning.push(`${input.transactions.length} transaction(s) on file -> ${txCountScore}/30 pts`);

    const totalInflow = input.transactions
      .filter((t) => t.direction === 'IN')
      .reduce((sum, t) => sum + (parseFloat(t.amount) || 0), 0);
    const inflowScore = Math.min(40, Math.floor(totalInflow / 100));
    reasoning.push(`Total inflow ${totalInflow} ${input.currency} -> ${inflowScore}/40 pts`);

    const score = Math.min(100, ageScore + txCountScore + inflowScore);
    const approved = score >= SimpleCreditScoringStrategy.APPROVAL_THRESHOLD;

    let approvedAmount = '0';
    if (approved) {
      const requested = parseFloat(input.requestedAmount) || 0;
      // Approve a larger fraction of the request as score climbs toward 100.
      const fraction = Math.min(1, score / 100);
      const amount = Math.min(requested, requested * fraction + 1);
      approvedAmount = amount.toFixed(2);
      reasoning.push(
        `Score ${score} >= threshold ${SimpleCreditScoringStrategy.APPROVAL_THRESHOLD} -> approved ${approvedAmount} of ${input.requestedAmount} requested`,
      );
    } else {
      reasoning.push(
        `Score ${score} < threshold ${SimpleCreditScoringStrategy.APPROVAL_THRESHOLD} -> rejected`,
      );
    }

    return { score, approved, approvedAmount, reasoning };
  }
}
