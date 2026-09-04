import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { SavingsService } from './savings.service';

/**
 * Runs SavingsService.runDueCheck on a schedule. This can only ever mark
 * contributions DUE, never execute one — see the doc comment on
 * SavingsGoal in schema.prisma for why (every transfer needs the user's
 * live on-device signature; there's no delegated-debit mechanism in
 * BMONI's API to build actual automatic execution on top of).
 */
@Injectable()
export class SavingsSchedulerService {
  private readonly logger = new Logger(SavingsSchedulerService.name);

  constructor(private readonly savings: SavingsService) {}

  @Cron(CronExpression.EVERY_HOUR)
  async handleDueCheck() {
    const result = await this.savings.runDueCheck();
    if (result.contributionsCreated > 0) {
      this.logger.log(
        `Savings due-check: ${result.contributionsCreated} contribution(s) now due ` +
          `across ${result.goalsChecked} goal(s).`,
      );
    }
  }
}
