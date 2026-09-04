import { ArgumentsHost, Catch, ExceptionFilter } from '@nestjs/common';
import { Response } from 'express';
import { BmoniApiError } from './bmoni.errors';

/**
 * Without this, a BmoniApiError thrown out of a controller (anything not
 * explicitly caught and re-mapped, like UsersService does for 409s) would
 * fall through to Nest's default handler, which treats an unrecognized
 * Error as a generic 500 — losing BMONI's actual status code and message.
 * That's fine for a simple happy path but not once KYC/onboarding surface
 * real validation errors (400), action-required states (422), etc. that
 * the app needs to branch on. This filter forwards BMONI's status and
 * message through verbatim instead.
 */
@Catch(BmoniApiError)
export class BmoniExceptionFilter implements ExceptionFilter {
  catch(exception: BmoniApiError, host: ArgumentsHost) {
    const res = host.switchToHttp().getResponse<Response>();
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
  }
}
