import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosInstance, AxiosRequestConfig } from 'axios';
import { BmoniConfig } from '../config/bmoni.config';
import { BmoniPaths } from './bmoni.paths';
import { BmoniApiError, BmoniNetworkError } from './bmoni.errors';
import {
  BmoniUser,
  CreateBmoniUserRequest,
  CreateBmoniUserResponse,
  ListBmoniUsersResponse,
} from './dto/users.dto';
import {
  CreateManagedSmartWalletRequest,
  OnboardingStatusResponse,
  OwnerProofChallengeRequest,
  OwnerProofChallengeResponse,
  SmartWallet,
  SupportedCurrenciesResponse,
} from './dto/smart-wallets.dto';
import {
  BiometricType,
  BvnLookupResponse,
  IdentificationDocumentRequest,
  KycActivateRequest,
  KycActivateResponse,
  KycDocumentResponse,
  KycOccupation,
  KycOptionsResponse,
  KycPatchRequest,
  KycPatchResponse,
  KycReadinessResponse,
  ProofOfAddressType,
  UsdReadinessResponse,
} from './dto/kyc.dto';
import {
  LatamMxAgreementsResponse,
  LatamMxKycStatusResponse,
  StartNigeriaRequest,
  StartNigeriaResponse,
  StartUsaRequest,
  StartUsaResponse,
  VbaUsdStatusResponse,
} from './dto/onboarding.dto';
import {
  Balance,
  CreateProposalRequest,
  DepositWalletAddressResponse,
  ExchangeConvertRequest,
  ExchangeRateResponse,
  ListBalancesResponse,
  ListWalletsResponse,
  OfframpNigeriaRequest,
  PayoutsRequest,
  PayoutsValidateAccountRequest,
  Proposal,
  ProposalSignPayloadResponse,
  SignProposalRequest,
  SignatureRequest,
  TransactionsResponse,
  VbaAccountResponse,
  VerifyNigerianAccountRequest,
  VerifyNigerianAccountResponse,
  WithdrawalAccountNigeriaRequest,
  WithdrawalAccountNigeriaResponse,
} from './dto/wallet-home.dto';

/**
 * The single gateway to the BMONI Embedded API. Nothing else in this
 * codebase should call BMONI directly — every feature module (users,
 * onboarding, KYC, transfers, ...) depends on this service instead of
 * axios/fetch directly. This keeps the "/v1 gotcha", auth header, and
 * error-shape handling in exactly one place.
 */
@Injectable()
export class BmoniClientService {
  private readonly logger = new Logger(BmoniClientService.name);
  private readonly http: AxiosInstance;
  private readonly cfg: BmoniConfig;

  constructor(configService: ConfigService) {
    this.cfg = configService.getOrThrow<BmoniConfig>('bmoni');
    this.http = axios.create({
      // Origin only — see the block comment in src/config/bmoni.config.ts.
      baseURL: this.cfg.baseUrl,
      headers: { 'x-api-key': this.cfg.apiKey },
      timeout: 30_000,
    });
  }

  private async request<T>(config: AxiosRequestConfig): Promise<T> {
    try {
      const res = await this.http.request<T>(config);
      return res.data;
    } catch (err) {
      if (axios.isAxiosError(err)) {
        if (err.response) {
          const body = err.response.data as
            | { error?: string; message?: string | string[] }
            | undefined;
          this.logger.warn(
            `BMONI ${err.response.status} ${config.method?.toUpperCase()} ${config.url}: ${JSON.stringify(body)}`,
          );
          throw new BmoniApiError(
            err.response.status,
            body?.error,
            body?.message,
            config.url ?? '',
            err.response.data,
          );
        }
        throw new BmoniNetworkError(config.url ?? '', err);
      }
      throw err;
    }
  }

  // --- Core lifecycle (section 2.1) -----------------------------------------

  async createUser(body: CreateBmoniUserRequest): Promise<BmoniUser> {
    const res = await this.request<CreateBmoniUserResponse>({
      method: 'POST',
      url: BmoniPaths.createUser(),
      data: body,
    });
    return res.user;
  }

  listUsers(params?: { page?: number; limit?: number }): Promise<ListBmoniUsersResponse> {
    return this.request({ method: 'GET', url: BmoniPaths.listUsers(), params });
  }

  requestOwnerProofChallenge(
    userId: string,
    body: OwnerProofChallengeRequest,
  ): Promise<OwnerProofChallengeResponse> {
    return this.request({
      method: 'POST',
      url: BmoniPaths.ownerProofChallenge(userId),
      data: body,
    });
  }

  createManagedSmartWallet(
    userId: string,
    body: CreateManagedSmartWalletRequest,
  ): Promise<SmartWallet> {
    return this.request({
      method: 'POST',
      url: BmoniPaths.createManagedSmartWallet(userId),
      data: body,
    });
  }

  getSupportedCurrencies(): Promise<SupportedCurrenciesResponse> {
    return this.request({ method: 'GET', url: BmoniPaths.supportedCurrencies() });
  }

  getOnboardingStatus(userId: string): Promise<OnboardingStatusResponse> {
    return this.request({ method: 'GET', url: BmoniPaths.onboardingStatus(userId) });
  }

  // --- KYC wizard (section 2.2) ----------------------------------------------

  getKycOptions(userId: string): Promise<KycOptionsResponse> {
    return this.request({ method: 'GET', url: BmoniPaths.kycOptions(userId) });
  }

  getKycOccupations(userId: string, search = ''): Promise<KycOccupation[]> {
    return this.request({
      method: 'GET',
      url: BmoniPaths.kycOccupations(userId),
      params: { search },
    });
  }

  submitIdentificationDocument(
    userId: string,
    fields: IdentificationDocumentRequest,
    file: { buffer: Buffer; filename: string; contentType: string },
  ): Promise<KycDocumentResponse> {
    // Confirmed live: the file field is named `files`, and BMONI rejects
    // anything under ~2KB with a distinct "file too small" error — don't
    // wire this up to a 1x1 placeholder image in tests.
    return this.postMultipart(BmoniPaths.kycDocIdentification(userId), fields, file, 'files');
  }

  submitProofOfAddress(
    userId: string,
    type: ProofOfAddressType,
    file: { buffer: Buffer; filename: string; contentType: string },
  ): Promise<KycDocumentResponse> {
    return this.postMultipart(BmoniPaths.kycDocProofOfAddress(userId), { type }, file, 'files');
  }

  submitBiometric(
    userId: string,
    type: BiometricType,
    file: { buffer: Buffer; filename: string; contentType: string },
  ): Promise<KycDocumentResponse> {
    // Confirmed live: this endpoint's file field is named `selfie`, unlike
    // the other two document endpoints (`files`) — don't unify them.
    return this.postMultipart(BmoniPaths.kycDocBiometric(userId), { type }, file, 'selfie');
  }

  patchKyc(userId: string, body: KycPatchRequest): Promise<KycPatchResponse> {
    return this.request({ method: 'PATCH', url: BmoniPaths.kycPatch(userId), data: body });
  }

  getKycReadiness(userId: string): Promise<KycReadinessResponse> {
    return this.request({ method: 'GET', url: BmoniPaths.kycReadiness(userId) });
  }

  activateKyc(userId: string, body: KycActivateRequest): Promise<KycActivateResponse> {
    // Confirmed live: sumsubLevelName is required — BMONI does NOT accept
    // an omitted body here despite what the brief says for CAD/NGN. See
    // the KycActivateRequest doc comment.
    return this.request({ method: 'POST', url: BmoniPaths.kycActivate(userId), data: body });
  }

  getUsdReadiness(userId: string): Promise<UsdReadinessResponse> {
    return this.request({ method: 'GET', url: BmoniPaths.kycUsdReadiness(userId) });
  }

  /**
   * Fetch-only preview — writes nothing, does not require the submitted
   * name to already match. Safe to call repeatedly and the recommended
   * first call to sanity-check API key + persona plumbing before running
   * anything that performs an actual identity match.
   */
  bvnLookup(userId: string, bvn: string): Promise<BvnLookupResponse> {
    return this.request({ method: 'GET', url: BmoniPaths.kycBvnLookup(userId, bvn) });
  }

  private async postMultipart<T>(
    url: string,
    fields: object,
    file: { buffer: Buffer; filename: string; contentType: string },
    fileFieldName: string,
  ): Promise<T> {
    const FormData = (await import('form-data')).default;
    const form = new FormData();
    for (const [key, value] of Object.entries(fields as Record<string, unknown>)) {
      if (value !== undefined) form.append(key, String(value));
    }
    form.append(fileFieldName, file.buffer, {
      filename: file.filename,
      contentType: file.contentType,
    });
    return this.request<T>({
      method: 'POST',
      url,
      data: form,
      headers: form.getHeaders(),
    });
  }

  // --- Rail-specific onboarding (section 2.3) --------------------------------

  startNigeria(userId: string, body: StartNigeriaRequest): Promise<StartNigeriaResponse> {
    return this.request({ method: 'POST', url: BmoniPaths.startNigeria(userId), data: body });
  }

  startUsa(userId: string, body: StartUsaRequest): Promise<StartUsaResponse> {
    return this.request({ method: 'POST', url: BmoniPaths.startUsa(userId), data: body });
  }

  getVbaUsdStatus(userId: string): Promise<VbaUsdStatusResponse> {
    return this.request({ method: 'GET', url: BmoniPaths.vbaUsd(userId) });
  }

  startCanada(userId: string): Promise<unknown> {
    return this.request({ method: 'POST', url: BmoniPaths.startCanada(userId) });
  }

  startMonerium(userId: string): Promise<unknown> {
    return this.request({ method: 'POST', url: BmoniPaths.startMonerium(userId) });
  }

  activateLatamMxKyc(userId: string): Promise<unknown> {
    return this.request({ method: 'POST', url: BmoniPaths.latamMxKycActivate(userId) });
  }

  getLatamMxAgreements(userId: string): Promise<LatamMxAgreementsResponse> {
    return this.request({ method: 'GET', url: BmoniPaths.latamMxAgreements(userId) });
  }

  getLatamMxKycStatus(userId: string): Promise<LatamMxKycStatusResponse> {
    return this.request({ method: 'GET', url: BmoniPaths.latamMxKycStatus(userId) });
  }

  // --- Wallet home (section 2.4) ----------------------------------------------

  listWallets(userId: string): Promise<ListWalletsResponse> {
    return this.request({ method: 'GET', url: BmoniPaths.listWallets(userId) });
  }

  listBalances(userId: string): Promise<ListBalancesResponse> {
    return this.request({ method: 'GET', url: BmoniPaths.listBalances(userId) });
  }

  getWalletDetail(userId: string, smartWalletId: string): Promise<SmartWallet> {
    return this.request({ method: 'GET', url: BmoniPaths.walletDetail(userId, smartWalletId) });
  }

  createDepositWalletAddress(userId: string): Promise<DepositWalletAddressResponse> {
    return this.request({ method: 'POST', url: BmoniPaths.depositWalletAddress(userId) });
  }

  createVbaNgn(userId: string): Promise<VbaAccountResponse> {
    return this.request({ method: 'POST', url: BmoniPaths.vbaNgn(userId) });
  }

  createVbaEu(userId: string): Promise<VbaAccountResponse> {
    return this.request({ method: 'POST', url: BmoniPaths.vbaEu(userId) });
  }

  verifyNigerianAccount(
    body: VerifyNigerianAccountRequest,
  ): Promise<VerifyNigerianAccountResponse> {
    return this.request({ method: 'POST', url: BmoniPaths.verifyNigerianAccount(), data: body });
  }

  createNigerianWithdrawalAccount(
    body: WithdrawalAccountNigeriaRequest,
  ): Promise<WithdrawalAccountNigeriaResponse> {
    return this.request({
      method: 'POST',
      url: BmoniPaths.withdrawalAccountsNigeria(),
      data: body,
    });
  }

  offrampNigeria(smartWalletId: string, body: OfframpNigeriaRequest): Promise<unknown> {
    return this.request({
      method: 'POST',
      url: BmoniPaths.offrampNigeria(smartWalletId),
      data: body,
    });
  }

  validatePayoutAccount(
    userId: string,
    body: PayoutsValidateAccountRequest,
  ): Promise<unknown> {
    return this.request({
      method: 'POST',
      url: BmoniPaths.payoutsValidateAccount(userId),
      data: body,
    });
  }

  createPayout(userId: string, body: PayoutsRequest): Promise<SignatureRequest> {
    return this.request({ method: 'POST', url: BmoniPaths.payouts(userId), data: body });
  }

  getExchangeRate(from: string, to: string): Promise<ExchangeRateResponse> {
    return this.request({ method: 'GET', url: BmoniPaths.exchangeRate(from, to) });
  }

  convertExchange(userId: string, body: ExchangeConvertRequest): Promise<unknown> {
    return this.request({ method: 'POST', url: BmoniPaths.exchangeConvert(userId), data: body });
  }

  createProposal(smartWalletId: string, body: CreateProposalRequest): Promise<Proposal> {
    return this.request({ method: 'POST', url: BmoniPaths.createProposal(smartWalletId), data: body });
  }

  rejectProposal(proposalId: string): Promise<unknown> {
    return this.request({ method: 'POST', url: BmoniPaths.rejectProposal(proposalId) });
  }

  approveProposal(proposalId: string): Promise<unknown> {
    return this.request({ method: 'POST', url: BmoniPaths.approveProposal(proposalId) });
  }

  getProposalSignPayload(proposalId: string): Promise<ProposalSignPayloadResponse> {
    return this.request({ method: 'GET', url: BmoniPaths.proposalSignPayload(proposalId) });
  }

  signProposal(proposalId: string, body: SignProposalRequest): Promise<unknown> {
    return this.request({ method: 'POST', url: BmoniPaths.signProposal(proposalId), data: body });
  }

  getTransactions(
    userId: string,
    smartWalletId: string,
    params?: { page?: number; perPage?: number },
  ): Promise<TransactionsResponse> {
    return this.request({
      method: 'GET',
      url: BmoniPaths.transactions(userId, smartWalletId),
      params,
    });
  }
}

export type { Balance };
