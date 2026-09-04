/**
 * Confirmed against the live sandbox (2026-09-04):
 *   GET /v1/smart-wallets/supported-currencies -> { currencies: string[] }
 *   returned ["USDB","CNGN","CADC","EURe","GBPe","MEXe"] — these are
 *   stablecoin codes, NOT fiat codes. Always resolve the target stablecoin
 *   for a fiat rail through this endpoint rather than hardcoding the list,
 *   in case BMONI adds/renames one.
 *
 * The owner-proof-challenge / create-managed shapes below follow section
 * 2.1 of the build brief; they have not yet been exercised against a live
 * response in this pass (that requires a working on-device-style EIP-191
 * signer — see scripts/sandbox-lifecycle.ts) and should be reconciled with
 * BMONI's official API reference if a field name here turns out wrong.
 */
export interface SupportedCurrenciesResponse {
  currencies: string[];
}

export interface OwnerProofChallengeRequest {
  currency: string;
  userOwnerAddress: string;
}

/**
 * Confirmed live (2026-09-04): the message is a plain-text block with a
 * User ID / Currency / Owner Address / Nonce / Expires At layout, and the
 * response also carries a `groupId` alongside `challengeId`.
 */
export interface OwnerProofChallengeResponse {
  challengeId: string;
  groupId: string;
  message: string;
  expiresAt: string;
}

export interface CreateManagedSmartWalletRequest {
  currency: string;
  userOwnerAddress: string;
  ownerProofChallengeId: string;
  ownerProofSignature: string;
}

/**
 * Confirmed live (2026-09-04) from POST create-managed with currency
 * "CNGN": the returned object labels `currency` by the *fiat* rail name
 * ("NGN"), not the stablecoin code sent in the request, and uses
 * `walletAddress`/`isActive` rather than `address`/`status`. Send the
 * stablecoin code on the way in (per GET supported-currencies); read the
 * fiat-style currency label back out.
 */
export interface SmartWallet {
  id: string;
  currency: string;
  walletAddress: string;
  isActive: boolean;
  pendingDeployUserOperation: unknown;
  deploySigningPayloadHash: string | null;
  createdByUserId: string;
  createdAt: string;
  updatedAt: string;
}

/**
 * Confirmed live (2026-09-04) for a brand-new user with a smart wallet but
 * no rail onboarding started yet: a fixed set of per-rail-provider status
 * strings, all "not_started". Values presumably progress through
 * provider-specific states as onboarding proceeds (Phase 2+) — treat this
 * union as provisional until observed mid-flow.
 */
export interface OnboardingStatusResponse {
  anchorStatus: string;
  bridgeStatus: string;
  moneriumStatus: string;
  paytrieStatus: string;
  etherfuseStatus: string;
  [key: string]: unknown;
}
