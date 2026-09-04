import { registerAs } from '@nestjs/config';

export interface BmoniConfig {
  env: 'sandbox' | 'production';
  baseUrl: string;
  apiKey: string;
}

/**
 * BMONI base URLs are ORIGIN ONLY — e.g. "https://embedded-dev.bmoni.com".
 * Every path constant in src/bmoni/bmoni.paths.ts already starts with
 * "/v1/". Do NOT append "/v1" to the base URL here or in any client call:
 * "https://embedded-dev.bmoni.com/v1" + "/v1/users" => "/v1/v1/users" 404s.
 * This has bitten past integrators of this API; leave this comment intact.
 */
export default registerAs('bmoni', (): BmoniConfig => {
  const env = (process.env.BMONI_ENV ?? 'sandbox') as 'sandbox' | 'production';

  const baseUrl =
    env === 'production'
      ? process.env.BMONI_BASE_URL_PRODUCTION
      : process.env.BMONI_BASE_URL_SANDBOX;

  const apiKey =
    env === 'production'
      ? process.env.BMONI_API_KEY_PRODUCTION
      : process.env.BMONI_API_KEY_SANDBOX;

  if (!baseUrl) {
    throw new Error(
      `Missing BMONI base URL for env "${env}". Set BMONI_BASE_URL_${env.toUpperCase()} in .env.`,
    );
  }
  if (!apiKey) {
    if (env === 'production') {
      throw new Error(
        'BMONI_API_KEY_PRODUCTION is not set. Request a production partner key ' +
          'from developers@bkey.me before running in production — there is no ' +
          'fallback and the sandbox key must never be used for real money movement.',
      );
    }
    throw new Error('Missing BMONI_API_KEY_SANDBOX in .env.');
  }

  return { env, baseUrl: baseUrl.replace(/\/+$/, ''), apiKey };
});
