/**
 * Typed wrapper around BMONI's error responses so callers can branch on
 * `.status` / `.bmoniMessage` instead of poking at raw axios errors.
 * Most observed shapes are { statusCode, error, message } where `message`
 * is either a string or a string[] (class-validator style), but some
 * endpoints return richer bodies with no `error` key at all — e.g.
 * start-usa's 422 action-required response:
 *   { kycStatus, fieldsToAction: string[], code, message, statusCode }
 * `rawBody` preserves the full response so callers needing those extra
 * fields (like `fieldsToAction`) aren't stuck with just the message.
 */
export class BmoniApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly bmoniError: string | undefined,
    public readonly bmoniMessage: string | string[] | undefined,
    public readonly path: string,
    public readonly rawBody: unknown = undefined,
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
