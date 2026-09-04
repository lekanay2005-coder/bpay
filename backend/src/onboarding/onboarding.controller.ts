import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { OnboardingService } from './onboarding.service';
import { RequestOwnerProofChallengeDto } from './dto/owner-proof-challenge.dto';
import { CreateSmartWalletDto } from './dto/create-smart-wallet.dto';
import { StartNigeriaDto } from './dto/start-nigeria.dto';

@Controller()
export class OnboardingController {
  constructor(private readonly onboarding: OnboardingService) {}

  @Get('onboarding/supported-currencies')
  supportedCurrencies() {
    return this.onboarding.getSupportedCurrencies();
  }

  @Post('users/:id/smart-wallets/owner-proof-challenges')
  requestChallenge(@Param('id') id: string, @Body() dto: RequestOwnerProofChallengeDto) {
    return this.onboarding.requestOwnerProofChallenge(id, dto.currency);
  }

  @Post('users/:id/smart-wallets')
  createSmartWallet(@Param('id') id: string, @Body() dto: CreateSmartWalletDto) {
    return this.onboarding.createSmartWallet(id, dto);
  }

  @Get('users/:id/onboarding/status')
  status(@Param('id') id: string) {
    return this.onboarding.getStatus(id);
  }

  @Post('users/:id/onboarding/start-nigeria')
  startNigeria(@Param('id') id: string, @Body() dto: StartNigeriaDto) {
    return this.onboarding.startNigeria(id, dto);
  }

  @Post('users/:id/onboarding/start-usa')
  startUsa(@Param('id') id: string) {
    return this.onboarding.startUsa(id);
  }

  @Get('users/:id/vba/usd')
  vbaUsdStatus(@Param('id') id: string) {
    return this.onboarding.getVbaUsdStatus(id);
  }

  // --- CAD/EUR/MXN stubs (Phase 5) — see OnboardingService's comment.
  // Deliberately no DTO class validation here (unlike every other
  // endpoint in this codebase) — these bodies aren't fully modeled since
  // there's no CAD/EUR/MXN UI driving them yet; the raw body is passed
  // straight through to BMONI, which will 400 with the real required
  // field list if it's wrong.

  @Post('users/:id/onboarding/start-canada')
  startCanada(
    @Param('id') id: string,
    @Body() body: { cadWalletAddress: string; cadWalletIndex: number },
  ) {
    return this.onboarding.startCanada(id, body);
  }

  @Post('users/:id/onboarding/start-monerium')
  startMonerium(
    @Param('id') id: string,
    @Body() body: { eurWalletAddress: string; eurWalletIndex: number },
  ) {
    return this.onboarding.startMonerium(id, body);
  }

  @Post('users/:id/latam/mx/kyc/activate')
  activateLatamMxKyc(@Param('id') id: string, @Body() body: Record<string, unknown>) {
    return this.onboarding.activateLatamMxKyc(id, body);
  }

  @Get('users/:id/latam/mx/kyc/agreements')
  latamMxAgreements(@Param('id') id: string) {
    return this.onboarding.getLatamMxAgreements(id);
  }

  @Get('users/:id/latam/mx/kyc/status')
  latamMxKycStatus(@Param('id') id: string) {
    return this.onboarding.getLatamMxKycStatus(id);
  }
}
