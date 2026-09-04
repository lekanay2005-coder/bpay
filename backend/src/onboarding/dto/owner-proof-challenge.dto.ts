import { IsString, IsNotEmpty } from 'class-validator';

export class RequestOwnerProofChallengeDto {
  // Stablecoin code (USDB, CNGN, CADC, EURe, GBPe, MEXe) — fetch the live
  // list from GET /onboarding/supported-currencies rather than hardcoding.
  @IsString()
  @IsNotEmpty()
  currency!: string;
}
