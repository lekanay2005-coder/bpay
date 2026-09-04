import { Body, Controller, Param, Post } from '@nestjs/common';
import { QrPayService } from './qr-pay.service';
import { GenerateQrDto } from './dto/generate-qr.dto';
import { PayQrDto } from './dto/pay-qr.dto';

@Controller('users/:id/qr')
export class QrPayController {
  constructor(private readonly qrPay: QrPayService) {}

  @Post('generate')
  generate(@Param('id') id: string, @Body() dto: GenerateQrDto) {
    return this.qrPay.generate(id, dto);
  }

  /** The payer's appUserId is :id — this is called after they scan and confirm. */
  @Post('pay')
  pay(@Param('id') id: string, @Body() dto: PayQrDto) {
    return this.qrPay.pay(id, dto.token);
  }
}
