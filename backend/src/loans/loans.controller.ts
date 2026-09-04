import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { LoansService } from './loans.service';
import { ApplyLoanDto } from './dto/apply-loan.dto';

@Controller('users/:id/loans')
export class LoansController {
  constructor(private readonly loans: LoansService) {}

  @Post('apply')
  apply(@Param('id') id: string, @Body() dto: ApplyLoanDto) {
    return this.loans.apply(id, dto);
  }

  @Get()
  list(@Param('id') id: string) {
    return this.loans.listForUser(id);
  }

  @Get(':loanId/repayments')
  listRepayments(@Param('loanId') loanId: string) {
    return this.loans.listRepayments(loanId);
  }

  @Post('repayments/:repaymentId/pay')
  payRepayment(@Param('id') id: string, @Param('repaymentId') repaymentId: string) {
    return this.loans.payRepayment(id, repaymentId);
  }
}
