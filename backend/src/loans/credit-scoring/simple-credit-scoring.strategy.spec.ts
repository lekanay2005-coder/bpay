import { SimpleCreditScoringStrategy } from './simple-credit-scoring.strategy';
import { Transaction } from '../../bmoni/dto/wallet-home.dto';

function tx(overrides: Partial<Transaction>): Transaction {
  return {
    id: 'tx-1',
    smartWalletId: 'wallet-1',
    amount: '0',
    currency: 'NGN',
    direction: 'IN',
    status: 'completed',
    createdAt: new Date().toISOString(),
    ...overrides,
  };
}

describe('SimpleCreditScoringStrategy', () => {
  const strategy = new SimpleCreditScoringStrategy();

  it('rejects a brand-new account with no history', () => {
    const result = strategy.score({
      accountAgeDays: 0,
      transactions: [],
      requestedAmount: '500.00',
      currency: 'NGN',
    });

    expect(result.approved).toBe(false);
    expect(result.score).toBe(0);
    expect(result.approvedAmount).toBe('0');
  });

  it('approves an established account with inflow history', () => {
    const result = strategy.score({
      accountAgeDays: 180,
      transactions: [
        tx({ direction: 'IN', amount: '1000' }),
        tx({ direction: 'IN', amount: '2000' }),
        tx({ direction: 'OUT', amount: '500' }),
      ],
      requestedAmount: '500.00',
      currency: 'NGN',
    });

    expect(result.approved).toBe(true);
    expect(result.score).toBeGreaterThanOrEqual(30);
    expect(parseFloat(result.approvedAmount)).toBeGreaterThan(0);
    expect(parseFloat(result.approvedAmount)).toBeLessThanOrEqual(500);
  });

  it('never approves more than the requested amount', () => {
    const result = strategy.score({
      accountAgeDays: 3650,
      transactions: Array.from({ length: 50 }, () => tx({ direction: 'IN', amount: '100000' })),
      requestedAmount: '100.00',
      currency: 'NGN',
    });

    expect(result.score).toBe(100);
    expect(parseFloat(result.approvedAmount)).toBeLessThanOrEqual(100);
  });

  it('only counts inflow (direction IN) toward the volume score', () => {
    const onlyOutflow = strategy.score({
      accountAgeDays: 0,
      transactions: [tx({ direction: 'OUT', amount: '100000' })],
      requestedAmount: '500.00',
      currency: 'NGN',
    });

    expect(onlyOutflow.approved).toBe(false);
  });
});
