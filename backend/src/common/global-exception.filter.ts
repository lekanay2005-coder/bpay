import { ArgumentsHost, Catch, ExceptionFilter, HttpException, Logger } from '@nestjs/common';
import { Response } from 'express';
import { BmoniApiError, BmoniNetworkError } from '../bmoni/bmoni.errors';

/**
 * Consolidated error handling (Phase 5 polish — build brief's "error
 * states" bullet). Without this, anything that isn't a Nest
 * HttpException (a raw BmoniApiError, a BmoniNetworkError, a plain
 * Error thrown from a service) falls through to Nest's default handler,
 * which returns a bare 500 with no useful body and logs nothing
 * consistent server-side. Three cases, in order:
 *
 *  1. BmoniApiError — forward BMONI's real status/message/body verbatim
 *     (this used to be its own BmoniExceptionFilter; merged here once a
 *     second case needed the same "one filter, several exception types"
 *     shape rather than fighting Nest's multi-filter precedence rules).
 *  2. BmoniNetworkError — BMONI was unreachable; a 502 to the client, not
 *     a 500, since this app's own code didn't fail.
 *  3. Nest HttpException (ValidationPipe errors, NotFoundException, etc.)
 *     — pass its status/body through unchanged, this filter adds nothing.
 *  4. Anything else — a generic 500 with no internal detail leaked to the
 *     client, but the full error logged server-side so it's not silently
 *     swallowed.
 */
@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(GlobalExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const res = host.switchToHttp().getResponse<Response>();

    if (exception instanceof BmoniApiError) {
      const rawBody =
        exception.rawBody && typeof exception.rawBody === 'object'
          ? (exception.rawBody as Record<string, unknown>)
          : {};
      res.status(exception.status).json({
        ...rawBody,
        statusCode: exception.status,
        error: exception.bmoniError ?? rawBody.error ?? 'BmoniApiError',
        message: exception.bmoniMessage ?? exception.message,
        source: 'bmoni',
      });
      return;
    }

    if (exception instanceof BmoniNetworkError) {
      this.logger.warn(exception.message);
      res.status(502).json({
        statusCode: 502,
        error: 'Bad Gateway',
        message: 'Could not reach BMONI — try again shortly.',
        source: 'bmoni',
      });
      return;
    }

    if (exception instanceof HttpException) {
      res.status(exception.getStatus()).json(exception.getResponse());
      return;
    }

    this.logger.error('Unhandled exception', exception instanceof Error ? exception.stack : exception);
    res.status(500).json({
      statusCode: 500,
      error: 'Internal Server Error',
      message: 'Something went wrong. Try again, and if it keeps happening, contact support.',
    });
  }
}
