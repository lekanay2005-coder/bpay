import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CashInDto {
  @IsOptional()
  @IsString()
  toBmoniUserId?: string;

  @IsOptional()
  @IsString()
  toPayTag?: string;

  @IsString()
  @IsNotEmpty()
  amount!: string;

  @IsString()
  @IsNotEmpty()
  currency!: string;
}
