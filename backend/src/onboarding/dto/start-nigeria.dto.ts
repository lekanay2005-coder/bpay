import { IsInt, IsNotEmpty, IsString, Min } from 'class-validator';

export class StartNigeriaDto {
  @IsString()
  @IsNotEmpty()
  bvn!: string;

  @IsInt()
  @Min(0)
  ngnWalletIndex!: number;
}
