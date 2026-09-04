import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CashOutDto {
  @IsOptional()
  @IsString()
  agentBmoniUserId?: string;

  @IsOptional()
  @IsString()
  agentPayTag?: string;

  @IsString()
  @IsNotEmpty()
  amount!: string;

  @IsString()
  @IsNotEmpty()
  currency!: string;
}
