import { IsString, IsNotEmpty } from 'class-validator';

export class CreateSmartWalletDto {
  @IsString()
  @IsNotEmpty()
  currency!: string;

  @IsString()
  @IsNotEmpty()
  ownerProofChallengeId!: string;

  // EIP-191 signature produced on-device by bmoni_embedded_sdk, gated by
  // the user's PIN. This backend never sees the private key — only this
  // signature crosses the wire.
  @IsString()
  @IsNotEmpty()
  ownerProofSignature!: string;
}
