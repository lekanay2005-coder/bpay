import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { SavingsService } from './savings.service';
import { CreateSavingsGoalDto } from './dto/create-savings-goal.dto';

@Controller('users/:id/savings')
export class SavingsController {
  constructor(private readonly savings: SavingsService) {}

  @Post('goals')
  createGoal(@Param('id') id: string, @Body() dto: CreateSavingsGoalDto) {
    return this.savings.createGoal(id, dto);
  }

  @Get('goals')
  listGoals(@Param('id') id: string) {
    return this.savings.listGoals(id);
  }

  @Get('due')
  listDue(@Param('id') id: string) {
    return this.savings.listDueContributions(id);
  }

  /**
   * Returns the same Proposal shape TransferController's endpoints do —
   * the app signs/submits it via the normal
   * /transfers/:proposalId/sign-payload and /sign routes.
   */
  @Post('contributions/:contributionId/pay')
  contribute(@Param('id') id: string, @Param('contributionId') contributionId: string) {
    return this.savings.contribute(id, contributionId);
  }
}
