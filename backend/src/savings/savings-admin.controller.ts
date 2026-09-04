import { Controller, Post } from '@nestjs/common';
import { SavingsService } from './savings.service';

/**
 * Manual trigger for the due-contribution check, so this can be verified
 * (and demoed) without waiting for the hourly cron in
 * SavingsSchedulerService. In production this should be behind
 * admin/internal auth — it's unauthenticated here like every other route
 * in this sandbox build.
 */
@Controller('savings')
export class SavingsAdminController {
  constructor(private readonly savings: SavingsService) {}

  @Post('run-due-check')
  runDueCheck() {
    return this.savings.runDueCheck();
  }
}
