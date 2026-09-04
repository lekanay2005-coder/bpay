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
}
