import { IsNotEmpty, IsString, Length } from 'class-validator';

export class VerifyNigerianAccountDto {
  @IsString()
  @IsNotEmpty()
  bankCode!: string;

  @IsString()
  @Length(10, 10, { message: 'accountNumber must be exactly 10 digits (NUBAN)' })
  accountNumber!: string;
}
