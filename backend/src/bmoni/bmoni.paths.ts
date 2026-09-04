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
  vbaNgn: (userId: string) => `/v1/users/${userId}/vba/ngn`,
  vbaEu: (userId: string) => `/v1/users/${userId}/vba/eu`,
  verifyNigerianAccount: () => `/v1/bank-accounts/verify-nigerian-account`,
  withdrawalAccountsNigeria: () => `/v1/bank-accounts/withdrawal-accounts/nigeria`,
  offrampNigeria: (smartWalletId: string) =>
    `/v1/smart-wallets/${smartWalletId}/offramp/nigeria`,
  payoutsValidateAccount: (userId: string) => `/v1/users/${userId}/payouts/validate-account`,
  payouts: (userId: string) => `/v1/users/${userId}/payouts`,
  exchangeRate: (from: string, to: string) => `/v1/exchange/rate/${from}/${to}`,
  exchangeConvert: (userId: string) => `/v1/users/${userId}/exchange/convert`,
  createProposal: (smartWalletId: string) => `/v1/smart-wallets/${smartWalletId}/proposals`,
  rejectProposal: (proposalId: string) => `/v1/proposals/${proposalId}/reject`,
  approveProposal: (proposalId: string) => `/v1/proposals/${proposalId}/approve`,
  proposalSignPayload: (proposalId: string) => `/v1/proposals/${proposalId}/sign-payload`,
  signProposal: (proposalId: string) => `/v1/proposals/${proposalId}/sign`,
  transactions: (userId: string, smartWalletId: string) =>
    `/v1/users/${userId}/transactions/${smartWalletId}`,
} as const;
