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

/**
 * Confirmed live (2026-09-04): crypto deposit is a bridge into USDB only
 * ("Group wallet must be for USDB currency" — a CNGN wallet was rejected)
 * — `chain`/`currency` enums are from BMONI's own OpenAPI spec. Only
 * USDC was actually enabled per chain in this sandbox at the time of
 * testing (GET deposit/supported-assets), despite the wider enum below.
 * The live call itself returned a 502 from BMONI's upstream bridge
 * provider on every attempt — plumbing is wired and typed correctly, but
 * this endpoint could not be verified working end-to-end in this sandbox.
 */
export type DepositChain =
  | 'Arbitrum'
  | 'Avalanche'
  | 'Base'
  | 'Ethereum'
  | 'Optimism'
  | 'Polygon'
  | 'Solana'
  | 'Stellar' // a deposit SOURCE chain option only — not a BMONI settlement rail
  | 'Tron';

export type DepositCurrency = 'DAI' | 'EURC' | 'PYUSD' | 'USDB' | 'USDC' | 'USDP' | 'USDT';

export interface WalletDepositAddressRequest {
  smartWalletId: string;
  chain: DepositChain;
  currency: DepositCurrency;
}

export interface WalletDepositAddressResponse {
  address: string;
  chain: DepositChain;
  currency: DepositCurrency;
}

export interface SupportedDepositAssetsResponse {
  items: Array<{ chain: DepositChain; currencies: DepositCurrency[] }>;
}

export interface NigerianBank {
  bankName: string;
  bankCode: string;
}

export interface NigerianBanksResponse {
  banks: NigerianBank[];
}

export interface VerifyNigerianAccountRequest {
  bankCode: string;
  /** Exactly 10 digits (NUBAN). */
  accountNumber: string;
}

export interface VerifyNigerianAccountResponse {
  accountNumber: string;
  accountName: string;
  bankName: string;
  bankCode: string;
}

export interface CreateNigerianWithdrawalAccountRequest {
  accountNumber: string;
  bankCode: string;
  bankName: string;
  /** Use the exact name verify-nigerian-account returned, not a user-typed one. */
  accountHolderName: string;
}

export interface NigerianWithdrawalAccountResponse {
  id: string;
  accountName: string;
  bankName: string;
  currency: string;
  depositMessage?: string;
  accountNumber: string;
  bankCode: string;
}

/**
 * The lower-level offramp path (build brief's version): create a TRANSFER
 * offramp proposal against a specific smart wallet, then walk it through
 * the normal proposal sign-payload/sign flow. Not exercised end-to-end in
 * this sandbox — verify-nigerian-account requires a real NUBAN we don't
 * have a sandbox test value for (unlike the persona BVN in section 6).
 */
export interface OfframpNigeriaRequest {
  bankAccountId: string;
  amount: string;
}

export interface OfframpProposalResponse {
  proposal: Proposal;
}

/**
 * The simpler one-call NGN withdrawal path (confirmed to exist via
 * BMONI's own OpenAPI spec, not exercised end-to-end for the same reason
 * as above): creates the offramp proposal, auto-approves it, and returns
 * a sign payload in one round trip.
 */
export interface WalletNigeriaWithdrawalRequest {
  sourceSmartWalletId: string;
  bankAccountId: string;
  fromAmount: string;
}

export interface OfframpWithSignPayloadResponse {
  proposalId: string;
  /** Absent when signPayloadPending is true — poll GET sign-payload instead. */
  signPayload?: { signingPayloadHash?: string; typedData?: unknown; [key: string]: unknown };
  signPayloadPending?: boolean;
  signPayloadHint?: string;
  signPayloadError?: string;
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

/**
 * Proposal shapes confirmed live (2026-09-04) via a real TRANSFER
 * proposal created, signed, and polled against the sandbox. See
 * BmoniClientService and backend/README.md "Phase 3 findings" for the
 * full writeup — most importantly: creating a proposal needs the
 * `/v1/users/{userId}` prefix the brief omits, there is no separate
 * "approve" endpoint (signing IS the approval action), and the value to
 * sign is `signingPayloadHash` taken RAW — NOT the full EIP-712 hash of
 * the accompanying `typedData` object. Signing the properly-computed
 * EIP-712 digest was tested and REJECTED ("signature does not match your
 * registered owner address"); signing `signingPayloadHash` directly was
 * accepted. This matches bmoni_embedded_sdk's `signTransactionHash`
 * exactly (its docstring: "no prefix and no additional hashing is
 * applied — the supplied hash is signed directly").
 */
export interface CreateProposalRequest {
  type: 'TRANSFER';
  toAddress?: string;
  toUserId?: string;
  /** Decimal string, e.g. "1.00" — NOT minor units. */
  amount: string;
  /** Stablecoin code; required to disambiguate a multi-token wallet. */
  currency?: string;
  description?: string;
}

/** Deliberately loose beyond the fields this app actually reads — the
 * live object has ~35 fields (Safe/ERC-4337 execution metadata) that
 * aren't relevant to the transfer UX. */
export interface Proposal {
  id: string;
  groupWalletId: string;
  proposalType: string;
  status: string;
  toAddress: string | null;
  toUserId: string | null;
  amount: string;
  currency: string;
  requiredApprovals: number;
  currentApprovals: number;
  requiredSignatures: number;
  currentSignatures: number;
  nextAction: string;
  expiresAt: string;
  executedAt: string | null;
  blockchainTxHash: string | null;
  createdAt: string;
  updatedAt: string;
  [key: string]: unknown;
}

/** Confirmed live: `{ proposal }`, not the OpenAPI doc's `{success,message,data:{proposal}}` envelope. */
export interface CreateProposalResponse {
  proposal: Proposal;
}

export interface ListProposalsResponse {
  proposals: Proposal[];
}

export interface RejectProposalRequest {
  reason?: string;
}

/** Confirmed live: matches CreateProposalResponse's envelope, not a bare Proposal. */
export interface ProposalMutationResponse {
  proposal: Proposal;
}

/**
 * Confirmed live — quite different from the brief's assumed
 * `{ message }` and from the OpenAPI spec's documented
 * `{method,walletIndex,workflowId,hashToSign,payload,deadline}` shape.
 * Sign `signingPayloadHash` directly (see CreateProposalRequest doc
 * comment) — `typedData` is provided for transparency/verification only.
 */
export interface ProposalSignPayloadResponse {
  signingPayloadHash: string;
  typedData: unknown;
  signatureExpiresAt: string;
  proposalStatus: string;
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
