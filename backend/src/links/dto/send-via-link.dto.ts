import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class SendViaLinkDto {
  /** If given and it resolves to an existing PayFlex user, this degrades to a normal transfer. */
  @IsOptional()
  @IsString()
  toBmoniUserId?: string;

  @IsString()
  @IsNotEmpty()
  amount!: string;

  @IsString()
  @IsNotEmpty()
  currency!: string;
}
