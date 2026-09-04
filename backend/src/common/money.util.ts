/**
 * Single shared place for converting between BMONI's minor-unit string
 * amounts (e.g. payouts in USDB minor units) and human decimal amounts.
 * Per the build brief: confirm the unit each endpoint expects and always
 * go through this utility rather than converting inline per call site.
 *
 * Decimals below are stablecoin conventions (18 decimals is the ERC-20
 * default most of these regional stablecoins follow) — reconcile against
 * BMONI's docs per currency if any of them turn out non-standard before
 * relying on this for a real money-moving call.
 */
const DECIMALS: Record<string, number> = {
  USDB: 18,
  CNGN: 18,
  CADC: 18,
  EURe: 18,
  GBPe: 18,
  MEXe: 18,
};

function decimalsFor(currency: string): number {
  const d = DECIMALS[currency.toUpperCase()];
  if (d === undefined) {
    throw new Error(
      `Unknown currency "${currency}" — add it to DECIMALS in money.util.ts once ` +
        `confirmed against BMONI's docs rather than guessing.`,
    );
  }
  return d;
}

/** Human decimal string (e.g. "12.50") -> minor-unit string BMONI expects. */
export function toMinorUnits(amount: string, currency: string): string {
  const decimals = decimalsFor(currency);
  const [whole, frac = ''] = amount.split('.');
  const paddedFrac = (frac + '0'.repeat(decimals)).slice(0, decimals);
  const combined = `${whole}${paddedFrac}`.replace(/^0+(?=\d)/, '');
  return combined;
}

/** Minor-unit string from BMONI -> human decimal string (e.g. "12.50"). */
export function fromMinorUnits(minorUnits: string, currency: string): string {
  const decimals = decimalsFor(currency);
  const padded = minorUnits.padStart(decimals + 1, '0');
  const whole = padded.slice(0, -decimals);
  const frac = padded.slice(-decimals).replace(/0+$/, '') || '0';
  return `${whole}.${frac}`;
}
