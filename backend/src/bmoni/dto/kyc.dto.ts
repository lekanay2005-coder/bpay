/**
 * All shapes below confirmed live against the sandbox on 2026-09-04 using
 * a fresh test user carried through the full KYC wizard (options ->
 * occupations -> 3 documents -> PATCH -> readiness -> activate) and then
 * NGN + USD rail onboarding. Several field names differ from a literal
 * reading of the build brief — see backend/README.md "Phase 2 findings"
 * for the full list and why each one matters.
 */
export interface KycOptionsResponse {
  genders: string[];
  employmentStatuses: string[];
  fundsSources: string[];
  identificationTypes: string[];
  accountPurposes: string[];
  estimatedMonthlyVolumeRanges: Array<{ label: string; value: number }>;
}

export interface KycOccupation {
  id: string;
  socCode: string;
  displayName: string;
  category: string;
  aliases: string[];
  isActive: boolean;
}

/**
 * Confirmed `type` enum: passport | drivers_license | national_id |
 * government_id | nric | fin | other (NOT "driving_license" as the brief
 * spells it). `issuingCountry` is ISO 3166-1 alpha-3 (e.g. "NGA"), matching
 * `address.countryCode` in KycPatchRequest. The multipart file field is
 * named `files`, not `file`.
 */
export type IdentificationDocumentType =
  | 'passport'
  | 'drivers_license'
  | 'national_id'
  | 'government_id'
  | 'nric'
  | 'fin'
  | 'other';

export interface IdentificationDocumentRequest {
  type: IdentificationDocumentType;
  documentNumber: string;
  issuingCountry: string;
  expirationDate?: string;
  issueDate?: string;
}

export interface KycDocumentResponse {
  id: string;
  kycProfileId: string;
  type: string;
  documentNumber?: string;
  issuingCountryCode?: string;
  expirationDate?: string | null;
  issueDate?: string | null;
  status?: string;
  createdAt: string;
  updatedAt: string;
}

export type ProofOfAddressType =
  | 'utility_bill'
  | 'bank_statement'
  | 'rental_agreement'
  | 'tax_document'
  | 'other';

export type BiometricType =
  | 'selfie'
  | 'liveness_check'
  | 'video_verification'
  | 'enrollment'
  | 'recovery_enrollment'
  | 'recovery_blocked_attempt';

/**
 * Confirmed live shape for PATCH /v1/users/{userId}/kyc. Notably NOT what
 * a literal reading of the brief suggests:
 *   - the personal-info wrapper key is `personalInfo`, not `personal`
 *   - there is no `compliance` wrapper — `accountPurpose` and
 *     `estimatedMonthlyVolume` are top-level fields instead
 *   - address uses `streetLine1`/`streetLine2`, not `line1`/`line2`, and
 *     `countryCode` is ISO alpha-3 ("NGA"), not alpha-2 ("NG")
 *   - employment uses `employmentStatus` and `occupationCode` (the `id`
 *     from a KycOccupation), not `status`/`occupation`
 *   - `sourceOfFunds` is top-level, not nested under employment
 *   - there is no top-level `bvn` field here — BVN is submitted via
 *     POST /onboarding/start-nigeria instead, not this endpoint
 */
export interface KycPatchRequest {
  personalInfo?: {
    dateOfBirth?: string;
    gender?: string;
  };
  address?: {
    streetLine1?: string;
    streetLine2?: string;
    city?: string;
    state?: string;
    postalCode?: string;
    /** ISO 3166-1 alpha-3, e.g. "NGA". */
    countryCode?: string;
  };
  employment?: {
    employmentStatus?: string;
    /** id from GET /kyc/occupations, e.g. "132011". */
    occupationCode?: string;
    employerName?: string;
    monthlySalary?: number;
  };
  sourceOfFunds?: string;
  accountPurpose?: string;
  estimatedMonthlyVolume?: number;
}

export interface KycPatchResponse {
  success: boolean;
  saved: Record<string, boolean>;
  canActivate: boolean;
  missing: string[];
}

export interface KycReadinessResponse {
  ready: boolean;
  missing: string[];
}

/**
 * Confirmed live: sumsubLevelName is REQUIRED on every call observed so
 * far — omitting the body (as the brief instructs for CAD/NGN) returned a
 * validation error naming the field as missing, not a silent pass. The
 * set of *valid* values is dynamic based on the profile's current state
 * (documents submitted so far); "id-and-liveness" worked for an NGN-target
 * profile with all three document types submitted. Do not hardcode a
 * currency -> level mapping without re-confirming against a live
 * kyc/activate 400 response first (it echoes the currently valid set).
 */
export interface KycActivateRequest {
  sumsubLevelName: string;
}

export interface KycActivateResponse {
  activated: boolean;
  message: string;
}

export interface UsdReadinessResponse {
  ready: boolean;
  missing: string[];
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
