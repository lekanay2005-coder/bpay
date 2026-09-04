import { IsNotEmpty, IsString } from 'class-validator';

export class SubmitSignatureDto {
  @IsString()
  @IsNotEmpty()
  signature!: string;
}
