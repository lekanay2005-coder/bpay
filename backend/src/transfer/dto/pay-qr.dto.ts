import { IsNotEmpty, IsString } from 'class-validator';

export class PayQrDto {
  @IsString()
  @IsNotEmpty()
  token!: string;
}
