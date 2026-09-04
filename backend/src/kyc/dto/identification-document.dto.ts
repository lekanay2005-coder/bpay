import { IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { IdentificationDocumentType } from '../../bmoni/dto/kyc.dto';

const IDENTIFICATION_TYPES: IdentificationDocumentType[] = [
  'passport',
  'drivers_license',
  'national_id',
  'government_id',
  'nric',
  'fin',
  'other',
];

export class IdentificationDocumentDto {
  @IsIn(IDENTIFICATION_TYPES)
  type!: IdentificationDocumentType;

  @IsString()
  @IsNotEmpty()
  documentNumber!: string;

  /** ISO 3166-1 alpha-3, e.g. "NGA" — confirmed live, not alpha-2. */
  @IsString()
  @IsNotEmpty()
  issuingCountry!: string;

  @IsOptional() @IsString() expirationDate?: string;
  @IsOptional() @IsString() issueDate?: string;
}
