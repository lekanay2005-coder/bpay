import { IsNotEmpty, IsString, Length } from 'class-validator';

export class CreateWithdrawalAccountDto {
  @IsString()
  @Length(10, 10, { message: 'accountNumber must be exactly 10 digits (NUBAN)' })
  accountNumber!: string;

  @IsString()
  @IsNotEmpty()
  bankCode!: string;

  @IsString()
  @IsNotEmpty()
  bankName!: string;

  // Use the exact name verify-nigerian-account returned, not a user-typed one.
  @IsString()
  @IsNotEmpty()
  accountHolderName!: string;
}
