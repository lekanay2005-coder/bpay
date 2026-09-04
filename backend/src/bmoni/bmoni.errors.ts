/**
 * Typed wrapper around BMONI's error responses so callers can branch on
 * `.status` / `.bmoniMessage` instead of poking at raw axios errors.
 * Observed shape from the live sandbox: { statusCode, error, message }
 * where `message` is either a string or a string[] (class-validator style).
 */
export class BmoniApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly bmoniError: string | undefined,
    public readonly bmoniMessage: string | string[] | undefined,
    public readonly path: string,
  ) {
    super(
      `BMONI ${status} on ${path}: ${
        Array.isArray(bmoniMessage) ? bmoniMessage.join('; ') : bmoniMessage ?? bmoniError ?? 'unknown error'
      }`,
    );
    this.name = 'BmoniApiError';
  }

  get isBadRequest() {
    return this.status === 400;
  }
  get isUnauthorized() {
    return this.status === 401;
  }
  get isForbidden() {
    return this.status === 403;
  }
  get isNotFound() {
    return this.status === 404;
  }
  get isConflict() {
    return this.status === 409;
  }
  get isServerError() {
    return this.status >= 500;
  }
}

export class BmoniNetworkError extends Error {
  constructor(
    public readonly path: string,
    public readonly cause: unknown,
  ) {
    super(`Network error calling BMONI at ${path}: ${String(cause)}`);
    this.name = 'BmoniNetworkError';
  }
}
