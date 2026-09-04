import { SmartWallet } from './smart-wallets.dto';

/**
 * Confirmed live (2026-09-04): a bare array, NOT `{ wallets: [...] }` as
 * the brief's shape suggested.
 */
export type ListWalletsResponse = SmartWallet[];

/** Confirmed live. `balance` is a plain decimal string, not minor units — do NOT run it through money.util.ts's minor-unit helpers. `error` is set per-wallet when a balance lookup failed. */
export interface Balance {
  smartWalletId: string;
  currency: string;
  balance: string;
  error: string | null;
}

export interface ListBalancesResponse {
  smartAccountAddress: string;
  balances: Balance[];
}

export interface DepositWalletAddressResponse {
  address: string;
  currency: string;
  [key: string]: unknown;
}

export interface VbaAccountResponse {
  accountNumber: string;
  bankName?: string;
  status: string;
  [key: string]: unknown;
}

export interface VerifyNigerianAccountRequest {
  accountNumber: string;
  bankCode: string;
}

export interface VerifyNigerianAccountResponse {
  accountName: string;
  accountNumber: string;
  bankCode: string;
}

export interface WithdrawalAccountNigeriaRequest {
  accountNumber: string;
  bankCode: string;
  accountName: string;
}

export interface WithdrawalAccountNigeriaResponse {
  id: string;
  [key: string]: unknown;
}

export interface OfframpNigeriaRequest {
  withdrawalAccountId: string;
  amount: string; // minor units as string
}

export interface PayoutsValidateAccountRequest {
  [key: string]: unknown;
}

export interface PayoutsRequest {
  amount: string; // minor units as string, e.g. USDB
  currency: string;
  destinationAccountId: string;
  [key: string]: unknown;
}

export interface SignatureRequest {
  signatureRequestId: string;
  message: string;
  [key: string]: unknown;
}

export interface ExchangeRateResponse {
  from: string;
  to: string;
  rate: string;
}

export interface ExchangeConvertRequest {
  fromCurrency: string;
  toCurrency: string;
  amount: string; // minor units as string
}

export interface CreateProposalRequest {
  type: 'TRANSFER';
  toAddress?: string;
  toUserId?: string;
  amount: string; // minor units as string
  currency: string;
  memo?: string;
}

export interface Proposal {
  id: string;
  smartWalletId: string;
  type: string;
  status: string;
  [key: string]: unknown;
}

export interface ProposalSignPayloadResponse {
  message: string;
  [key: string]: unknown;
}

export interface SignProposalRequest {
  signature: string;
}

export interface Transaction {
  id: string;
  smartWalletId: string;
  amount: string;
  currency: string;
  direction: 'IN' | 'OUT';
  status: string;
  createdAt: string;
  [key: string]: unknown;
}

/** Confirmed live: paginated, not a bare `{ transactions }` array. */
export interface TransactionsResponse {
  transactions: Transaction[];
  page: number;
  perPage: number;
  total: number;
  pageCount: number;
  hasNextPage: boolean;
  hasPreviousPage: boolean;
}
