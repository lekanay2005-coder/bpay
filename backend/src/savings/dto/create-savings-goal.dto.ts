import { IsIn, IsNotEmpty, IsString } from 'class-validator';

export class CreateSavingsGoalDto {
  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsString()
  @IsNotEmpty()
  currency!: string;

  @IsString()
  @IsNotEmpty()
  targetAmount!: string;

  @IsString()
  @IsNotEmpty()
  contributionAmount!: string;

  @IsIn(['DAILY', 'WEEKLY', 'MONTHLY'])
  frequency!: 'DAILY' | 'WEEKLY' | 'MONTHLY';
}
