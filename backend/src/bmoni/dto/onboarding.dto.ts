export interface StartNigeriaRequest {
  bvn: string;
  ngnWalletAddress: string;
  ngnWalletIndex: number;
}

export interface StartUsaRequest {
  smartWalletId: string;
}

export interface StartUsaResponse {
  workflowId: string;
}

export interface VbaUsdStatusResponse {
  status: string;
  [key: string]: unknown;
}

export interface LatamMxAgreementsResponse {
  [key: string]: unknown;
}

export interface LatamMxKycStatusResponse {
  status: string;
  [key: string]: unknown;
}
