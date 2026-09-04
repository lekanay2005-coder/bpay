/**
 * Every BMONI path here already starts with "/v1/" (or is otherwise a full
 * path fragment). The configured base URL is origin-only — see
 * src/config/bmoni.config.ts. Do not prefix these with an extra "/v1".
 */
export const BmoniPaths = {
  // --- Core lifecycle (section 2.1) -----------------------------------------
  createUser: () => `/v1/users`,
  listUsers: () => `/v1/users`,
  ownerProofChallenge: (userId: string) =>
    `/v1/users/${userId}/smart-wallets/owner-proof-challenges`,
  createManagedSmartWallet: (userId: string) =>
    `/v1/users/${userId}/smart-wallets/create-managed`,
  supportedCurrencies: () => `/v1/smart-wallets/supported-currencies`,
  onboardingStatus: (userId: string) => `/v1/users/${userId}/onboarding/status`,

  // --- KYC wizard (section 2.2) ----------------------------------------------
  kycOptions: (userId: string) => `/v1/users/${userId}/kyc/options`,
  kycOccupations: (userId: string) => `/v1/users/${userId}/kyc/occupations`,
  kycDocIdentification: (userId: string) =>
    `/v1/users/${userId}/kyc/documents/identification`,
  kycDocProofOfAddress: (userId: string) =>
    `/v1/users/${userId}/kyc/documents/proof-of-address`,
  kycDocBiometric: (userId: string) =>
    `/v1/users/${userId}/kyc/documents/biometric`,
  kycPatch: (userId: string) => `/v1/users/${userId}/kyc`,
  kycReadiness: (userId: string) => `/v1/users/${userId}/kyc/readiness`,
  kycActivate: (userId: string) => `/v1/users/${userId}/kyc/activate`,
  kycUsdReadiness: (userId: string) => `/v1/users/${userId}/kyc/usd-readiness`,
  kycBvnLookup: (userId: string, bvn: string) =>
    `/v1/users/${userId}/kyc/bvn-lookup/${bvn}`,

  // --- Rail-specific onboarding (section 2.3) --------------------------------
  startNigeria: (userId: string) => `/v1/users/${userId}/onboarding/start-nigeria`,
  startUsa: (userId: string) => `/v1/users/${userId}/onboarding/start-usa`,
  startCanada: (userId: string) => `/v1/users/${userId}/onboarding/start-canada`,
  startMonerium: (userId: string) => `/v1/users/${userId}/onboarding/start-monerium`,
  vbaUsd: (userId: string) => `/v1/users/${userId}/vba/usd`,
  latamMxKycActivate: (userId: string) => `/v1/users/${userId}/latam/mx/kyc/activate`,
  latamMxAgreements: (userId: string) => `/v1/users/${userId}/latam/mx/kyc/launch/agreements`,
  latamMxKycStatus: (userId: string) => `/v1/users/${userId}/latam/mx/kyc/status`,

  // --- Wallet home (section 2.4) ----------------------------------------------
  listWallets: (userId: string) => `/v1/users/${userId}/smart-wallets/account/wallets`,
  listBalances: (userId: string) => `/v1/users/${userId}/smart-wallets/account/balances`,
  walletDetail: (userId: string, smartWalletId: string) =>
    `/v1/users/${userId}/smart-wallets/${smartWalletId}`,
  depositWalletAddress: (userId: string) => `/v1/users/${userId}/deposit/wallet`,
  depositSupportedAssets: () => `/v1/deposit/supported-assets`,

  /**
   * Confirmed against BMONI's own OpenAPI spec (GET /docs/openapi.json on
   * the sandbox host) on 2026-09-04 — the brief's `/vba/ngn` and `/vba/eu`
   * do not exist. The real onramp-VBA endpoints are nested under a
   * specific smart wallet, not top-level.
   */
  onrampVbaNigeria: (userId: string, smartWalletId: string) =>
    `/v1/users/${userId}/smart-wallets/${smartWalletId}/onramp/vba/nigeria`,
  onrampVbaEu: (userId: string, smartWalletId: string) =>
    `/v1/users/${userId}/smart-wallets/${smartWalletId}/onramp/vba/eu`,

  // Confirmed live: needs the /v1/users/{userId} prefix the brief omits.
  nigerianBanks: (userId: string) => `/v1/users/${userId}/bank-accounts/nigerian-banks`,
  verifyNigerianAccount: (userId: string) =>
    `/v1/users/${userId}/bank-accounts/verify-nigerian-account`,
  withdrawalAccountsNigeria: (userId: string) =>
    `/v1/users/${userId}/bank-accounts/withdrawal-accounts/nigeria`,
  offrampNigeria: (userId: string, smartWalletId: string) =>
    `/v1/users/${userId}/smart-wallets/${smartWalletId}/offramp/nigeria`,
  /**
   * The simpler one-call NGN withdrawal path (confirmed live): creates the
   * offramp proposal, auto-approves it, and returns the sign payload in
   * one round trip, vs. offrampNigeria's separate
   * create-proposal -> sign-payload -> sign sequence.
   */
  withdrawalWalletNigeria: (userId: string) => `/v1/users/${userId}/withdrawal/wallet/nigeria`,

  payoutsValidateAccount: (userId: string) => `/v1/users/${userId}/payouts/validate-account`,
  payouts: (userId: string) => `/v1/users/${userId}/payouts`,
  exchangeRate: (userId: string, from: string, to: string) =>
    `/v1/users/${userId}/exchange/rate/${from}/${to}`,
  exchangeConvert: (userId: string) => `/v1/users/${userId}/exchange/convert`,

  /**
   * Proposal endpoints confirmed against BMONI's own OpenAPI spec AND live
   * testing on 2026-09-04 — several diverge from the brief:
   *  - createProposal/listProposals DO need the /v1/users/{userId} prefix
   *    the brief omits.
   *  - There is no separate "approve" endpoint at all, despite the brief
   *    (and even BMONI's own endpoint descriptions) mentioning one —
   *    reject/sign/sign-payload/get are the only proposal-mutation routes
   *    that exist. Signing IS the approval action.
   *  - reject/sign/sign-payload/get are addressed by proposalId alone,
   *    NOT nested under a specific smartWalletId.
   */
  createProposal: (userId: string, smartWalletId: string) =>
    `/v1/users/${userId}/smart-wallets/${smartWalletId}/proposals`,
  listProposals: (userId: string, smartWalletId: string) =>
    `/v1/users/${userId}/smart-wallets/${smartWalletId}/proposals`,
  getProposal: (userId: string, proposalId: string) =>
    `/v1/users/${userId}/smart-wallets/proposals/${proposalId}`,
  rejectProposal: (userId: string, proposalId: string) =>
    `/v1/users/${userId}/smart-wallets/proposals/${proposalId}/reject`,
  proposalSignPayload: (userId: string, proposalId: string) =>
    `/v1/users/${userId}/smart-wallets/proposals/${proposalId}/sign-payload`,
  signProposal: (userId: string, proposalId: string) =>
    `/v1/users/${userId}/smart-wallets/proposals/${proposalId}/sign`,

  transactions: (userId: string, smartWalletId: string) =>
    `/v1/users/${userId}/transactions/${smartWalletId}`,
} as const;
