import { IsIn, IsNotEmpty, IsString } from 'class-validator';

export class WithdrawNigeriaDto {
  @IsIn(['NGN', 'USD'])
  sourceCurrency!: 'NGN' | 'USD';

  @IsString()
  @IsNotEmpty()
  bankAccountId!: string;

  /** Decimal string, e.g. "100.00". */
  @IsString()
  @IsNotEmpty()
  fromAmount!: string;
}
