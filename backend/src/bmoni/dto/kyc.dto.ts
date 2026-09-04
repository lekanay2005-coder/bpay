/**
 * Shapes below follow section 2.2 / 2.6 of the build brief and have not
 * all been exercised against live sandbox responses yet (documents
 * endpoints are multipart and destructive to run repeatedly against a
 * shared sandbox identity — do that deliberately, per persona, not in
 * automated smoke tests). bvn-lookup IS safe to call repeatedly (fetch
 * only, no identity match required) and is exercised in
 * scripts/sandbox-lifecycle.ts.
 */
export interface KycOptionsResponse {
  [key: string]: unknown;
}

export interface KycOccupation {
  code: string;
  label: string;
}

export interface IdentificationDocumentRequest {
  type: string;
  documentNumber: string;
  issuingCountry: string;
  expirationDate?: string;
  issueDate?: string;
  // file provided as multipart form field, not part of this JSON shape
}

export interface KycPatchRequest {
  personal?: Record<string, unknown>;
  address?: Record<string, unknown>;
  employment?: Record<string, unknown>;
  compliance?: Record<string, unknown>;
  // Required for the NGN rail specifically.
  bvn?: string;
}

export interface KycReadinessResponse {
  ready: boolean;
  missing?: string[];
  [key: string]: unknown;
}

export interface KycActivateRequest {
  // Pass for USD/EUR (Global KYC / Sumsub path). Omit the body entirely
  // for CAD/NGN — do not send `{}` vs. no body interchangeably without
  // checking which one BMONI actually expects; the brief says "omit
  // entirely".
  sumsubLevelName?: string;
}

export interface UsdReadinessResponse {
  ready: boolean;
  [key: string]: unknown;
}

/** Confirmed live (2026-09-04) against persona BVN 22222222222. */
export interface BvnLookupResponse {
  bvn: string;
  firstName: string;
  lastName: string;
  middleName?: string;
  dateOfBirth?: string;
  gender?: string;
  email?: string;
  phoneNumber?: string;
  residentialAddress?: string;
  stateOfResidence?: string;
  stateOfOrigin?: string;
  lgaOfResidence?: string;
  lgaOfOrigin?: string;
  nin?: string;
  /** data: URI, base64 PNG — large; avoid logging this in full. */
  photo?: string;
  [key: string]: unknown;
}
