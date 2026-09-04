import { IsNotEmpty, IsString } from 'class-validator';

export class ApplyLoanDto {
  @IsString()
  @IsNotEmpty()
  requestedAmount!: string;

  @IsString()
  @IsNotEmpty()
  currency!: string;
}
