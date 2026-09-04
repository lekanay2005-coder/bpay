import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

/**
 * Exactly one of toBmoniUserId / toAddress / toPayTag must be set — the
 * controller validates that (a class-validator XOR-of-three constraint
 * would be more machinery than it's worth here) and resolves toPayTag to
 * a bmoniUserId before ever reaching TransferService, which stays
 * PayTag-agnostic per the "each mode only resolves who/how much" rule.
 */
export class CreateTransferDto {
  @IsOptional()
  @IsString()
  toBmoniUserId?: string;

  @IsOptional()
  @IsString()
  toAddress?: string;

  @IsOptional()
  @IsString()
  toPayTag?: string;

  /** Decimal string, e.g. "5.00" — NOT minor units. */
  @IsString()
  @IsNotEmpty()
  amount!: string;

  @IsString()
  @IsNotEmpty()
  currency!: string;

  @IsOptional()
  @IsString()
  description?: string;
}
