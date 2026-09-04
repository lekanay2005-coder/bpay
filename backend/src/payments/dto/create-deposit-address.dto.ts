import { IsIn } from 'class-validator';
import { DepositChain, DepositCurrency } from '../../bmoni/dto/wallet-home.dto';

const CHAINS: DepositChain[] = [
  'Arbitrum',
  'Avalanche',
  'Base',
  'Ethereum',
  'Optimism',
  'Polygon',
  'Solana',
  'Stellar',
  'Tron',
];
const CURRENCIES: DepositCurrency[] = ['DAI', 'EURC', 'PYUSD', 'USDB', 'USDC', 'USDP', 'USDT'];

export class CreateDepositAddressDto {
  @IsIn(CHAINS)
  chain!: DepositChain;

  @IsIn(CURRENCIES)
  currency!: DepositCurrency;
}
