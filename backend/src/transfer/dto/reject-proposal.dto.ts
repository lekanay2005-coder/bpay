import { IsOptional, IsString } from 'class-validator';

export class RejectProposalDto {
  @IsOptional()
  @IsString()
  reason?: string;
}
