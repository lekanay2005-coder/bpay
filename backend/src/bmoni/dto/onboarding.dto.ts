export interface StartNigeriaRequest {
  bvn: string;
  ngnWalletAddress: string;
  ngnWalletIndex: number;
}

/**
 * Confirmed live (2026-09-04). Note: onboarding/status's `anchorStatus`
 * flipped to "active" immediately on a successful call here, with NO
 * observed synchronous rejection for a BVN/name mismatch — see
 * backend/README.md "Phase 2 findings" for the full writeup and why that
 * matters (it's a real deviation from what the build brief describes).
 */
export interface StartNigeriaResponse {
  workflowId: string;
  isNigeria: boolean;
  status: {
    hasBvn: boolean;
    hasLocalWallet: boolean;
    hasInternationalWallet: boolean;
  };
}

export interface StartUsaRequest {
  smartWalletId: string;
}

export interface StartUsaResponse {
  workflowId: string;
}

/**
 * Confirmed live: BMONI returns HTTP 422 (not the workflowId shape) when
 * the underlying Sumsub identity check hasn't actually passed yet, e.g.
 * after submitting synthetic/non-photorealistic document images:
 *   { kycStatus: "action_required", fieldsToAction: ["BAD_SELFIE", ...],
 *     code: "E101", message: "...", statusCode: 422 }
 * BmoniApiError surfaces this as a 422; callers should branch on
 * `err.status === 422` and surface `fieldsToAction` to the user rather
 * than treating it as a generic failure.
 */
export interface StartUsaActionRequiredResponse {
  kycStatus: string;
  fieldsToAction: string[];
  code: string;
  message: string;
  statusCode: number;
}

/** Confirmed live shape — richer than the brief's bare `{ status }`. */
export interface VbaUsdStatusResponse {
  status: string;
  account: Record<string, unknown> | null;
  reason: string | null;
}

export interface LatamMxAgreementsResponse {
  [key: string]: unknown;
}

export interface LatamMxKycStatusResponse {
  status: string;
  [key: string]: unknown;
}
