import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { AgentService } from './agent.service';
import { SetAgentStatusDto } from './dto/set-agent-status.dto';
import { CashInDto } from './dto/cash-in.dto';
import { CashOutDto } from './dto/cash-out.dto';

@Controller('users/:id/agent')
export class AgentController {
  constructor(private readonly agent: AgentService) {}

  @Post('status')
  setStatus(@Param('id') id: string, @Body() dto: SetAgentStatusDto) {
    return this.agent.setAgentStatus(id, dto.isAgent);
  }

  @Post('cash-in')
  cashIn(@Param('id') id: string, @Body() dto: CashInDto) {
    return this.agent.cashIn(id, dto);
  }

  @Post('cash-out')
  cashOut(@Param('id') id: string, @Body() dto: CashOutDto) {
    return this.agent.cashOut(id, dto);
  }

  @Get('transactions')
  transactions(@Param('id') id: string) {
    return this.agent.listTransactions(id);
  }
}
