import { IsIn } from 'class-validator';
import { ProofOfAddressType } from '../../bmoni/dto/kyc.dto';

const PROOF_OF_ADDRESS_TYPES: ProofOfAddressType[] = [
  'utility_bill',
  'bank_statement',
  'rental_agreement',
  'tax_document',
  'other',
];

export class ProofOfAddressDto {
  @IsIn(PROOF_OF_ADDRESS_TYPES)
  type!: ProofOfAddressType;
}
