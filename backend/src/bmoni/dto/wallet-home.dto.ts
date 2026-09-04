import { SmartWallet } from './smart-wallets.dto';

export interface ListWalletsResponse {
  wallets: SmartWallet[];
}

export interface Balance {
  currency: string;
  smartWalletId: string;
  amount: string; // minor units as string, per the brief — do not parse to float
}

export interface ListBalancesResponse {
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

export interface TransactionsResponse {
  transactions: Transaction[];
}
