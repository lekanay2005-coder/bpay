import { Type } from 'class-transformer';
import { IsInt, IsNumber, IsObject, IsOptional, IsString, ValidateNested } from 'class-validator';

/**
 * Mirrors the confirmed-live PATCH /v1/users/{userId}/kyc shape — see
 * backend/src/bmoni/dto/kyc.dto.ts for the full writeup of how this
 * differs from a literal reading of the build brief (personalInfo not
 * personal, no compliance wrapper, streetLine1 not line1, alpha-3 country
 * codes, employmentStatus/occupationCode not status/occupation).
 */
class PersonalInfoDto {
  @IsOptional() @IsString() dateOfBirth?: string;
  @IsOptional() @IsString() gender?: string;
}

class AddressDto {
  @IsOptional() @IsString() streetLine1?: string;
  @IsOptional() @IsString() streetLine2?: string;
  @IsOptional() @IsString() city?: string;
  @IsOptional() @IsString() state?: string;
  @IsOptional() @IsString() postalCode?: string;
  @IsOptional() @IsString() countryCode?: string;
}

class EmploymentDto {
  @IsOptional() @IsString() employmentStatus?: string;
  @IsOptional() @IsString() occupationCode?: string;
  @IsOptional() @IsString() employerName?: string;
  @IsOptional() @IsNumber() monthlySalary?: number;
}

export class KycPatchDto {
  @IsOptional()
  @IsObject()
  @ValidateNested()
  @Type(() => PersonalInfoDto)
  personalInfo?: PersonalInfoDto;

  @IsOptional()
  @IsObject()
  @ValidateNested()
  @Type(() => AddressDto)
  address?: AddressDto;

  @IsOptional()
  @IsObject()
  @ValidateNested()
  @Type(() => EmploymentDto)
  employment?: EmploymentDto;

  @IsOptional() @IsString() sourceOfFunds?: string;
  @IsOptional() @IsString() accountPurpose?: string;
  @IsOptional() @IsInt() estimatedMonthlyVolume?: number;
}
