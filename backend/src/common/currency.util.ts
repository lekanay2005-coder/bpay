/**
 * Maps the fiat rail label BMONI's smart-wallet responses use
 * (SmartWallet.currency, e.g. "NGN") back to the stablecoin code BMONI's
 * request bodies expect elsewhere (e.g. proposal.currency, e.g. "CNGN").
 * See src/bmoni/dto/smart-wallets.dto.ts's SmartWallet doc comment for why
 * these differ: create-managed is requested with a stablecoin code but
 * responds with (and SmartWallet rows are stored under) the fiat label.
 */
const FIAT_TO_STABLECOIN: Record<string, string> = {
  NGN: 'CNGN',
  USD: 'USDB',
  CAD: 'CADC',
  EUR: 'EURe',
  GBP: 'GBPe',
  MXN: 'MEXe',
};

export function stablecoinForFiat(fiat: string): string {
  const code = FIAT_TO_STABLECOIN[fiat.toUpperCase()];
  if (!code) {
    throw new Error(
      `No known stablecoin mapping for fiat currency "${fiat}" — add it to ` +
        `FIAT_TO_STABLECOIN in currency.util.ts once confirmed against BMONI's docs.`,
    );
  }
  return code;
}
