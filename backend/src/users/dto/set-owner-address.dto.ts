import { IsString, Matches } from 'class-validator';

export class SetOwnerAddressDto {
  // Public EVM address generated on-device by bmoni_embedded_sdk. This
  // endpoint only ever receives the address, never a private key or
  // signature material.
  @IsString()
  @Matches(/^0x[a-fA-F0-9]{40}$/, { message: 'ownerAddress must be a 0x EVM address' })
  ownerAddress!: string;
}
