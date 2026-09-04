import { IsNotEmpty, IsString } from 'class-validator';

/**
 * sumsubLevelName is required on every activate call BMONI has actually
 * accepted in testing — see the doc comment on KycActivateRequest in
 * src/bmoni/dto/kyc.dto.ts. The set of valid values is dynamic (depends
 * on which documents the profile already has), so this backend does not
 * try to guess one on the caller's behalf; the caller (Flutter wizard)
 * passes the level it wants and BMONI's 400 response — which echoes the
 * currently-valid set — is surfaced back verbatim on a bad guess.
 */
export class KycActivateDto {
  @IsString()
  @IsNotEmpty()
  sumsubLevelName!: string;
}
