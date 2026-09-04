import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { SplitBillService } from './split-bill.service';
import { CreateSplitBillDto } from './dto/create-split-bill.dto';

@Controller()
export class SplitBillController {
  constructor(private readonly splitBills: SplitBillService) {}

  @Post('users/:id/split-bills')
  create(@Param('id') id: string, @Body() dto: CreateSplitBillDto) {
    return this.splitBills.create(id, dto);
  }

  @Get('users/:id/split-bills')
  listForUser(@Param('id') id: string) {
    return this.splitBills.listForUser(id);
  }

  @Get('split-bills/qr/:token')
  getByToken(@Param('token') token: string) {
    return this.splitBills.getByToken(token);
  }

  @Get('split-bills/:splitBillId')
  getDetail(@Param('splitBillId') splitBillId: string) {
    return this.splitBills.getDetail(splitBillId);
  }

  @Post('users/:id/split-bills/:splitBillId/pay')
  pay(@Param('id') id: string, @Param('splitBillId') splitBillId: string) {
    return this.splitBills.pay(id, splitBillId);
  }
}
