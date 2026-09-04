import { Body, Controller, Logger, Post } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Receiver for BMONI's async webhook events. Phase 1 just logs and
 * persists every event so nothing is lost; per-event handling (e.g.
 * flipping onboarding state, notifying the app) gets wired up as the
 * features that need it land — see build brief section 7.
 *
 * Known event types so far: employee.linked, onboarding.completed,
 * onboarding.failed, kyc.action_required. BMONI's signing scheme for
 * these payloads is not yet confirmed; BMONI_WEBHOOK_SECRET is a
 * placeholder for whenever that's documented — do not assume HMAC
 * verification is happening until that's wired up for real.
 */
@Controller('webhooks')
export class WebhooksController {
  private readonly logger = new Logger(WebhooksController.name);

  constructor(private readonly prisma: PrismaService) {}

  @Post('bmoni')
  async receive(@Body() body: { type?: string; [key: string]: unknown }) {
    const type = body.type ?? 'unknown';
    this.logger.log(`Received BMONI webhook: ${type}`);
    await this.prisma.webhookEvent.create({
      data: { type, payload: body as object },
    });
    return { received: true };
  }
}
