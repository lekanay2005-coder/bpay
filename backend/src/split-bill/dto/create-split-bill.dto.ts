import { ArrayMinSize, IsArray, IsNotEmpty, IsOptional, IsString, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

class SplitBillContributorDto {
  @IsOptional()
  @IsString()
  payTag?: string;

  @IsOptional()
  @IsString()
  bmoniUserId?: string;

  @IsString()
  @IsNotEmpty()
  shareAmount!: string;
}

export class CreateSplitBillDto {
  @IsString()
  @IsNotEmpty()
  description!: string;

  @IsString()
  @IsNotEmpty()
  currency!: string;

  @IsString()
  @IsNotEmpty()
  totalAmount!: string;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => SplitBillContributorDto)
  contributors!: SplitBillContributorDto[];
}
