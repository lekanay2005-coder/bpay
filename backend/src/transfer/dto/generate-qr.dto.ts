import { IsInt, IsNotEmpty, IsOptional, IsString, Max, Min } from 'class-validator';

export class GenerateQrDto {
  @IsString()
  @IsNotEmpty()
  amount!: string;

  @IsString()
  @IsNotEmpty()
  currency!: string;

  @IsOptional()
  @IsInt()
  @Min(30)
  @Max(3600)
  expiresInSeconds?: number;
}
