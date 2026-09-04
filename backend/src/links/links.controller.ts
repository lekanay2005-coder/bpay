import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { LinksService } from './links.service';
import { SendViaLinkDto } from './dto/send-via-link.dto';

@Controller()
export class LinksController {
  constructor(private readonly links: LinksService) {}

  @Post('users/:id/send-via-link')
  sendViaLink(@Param('id') id: string, @Body() dto: SendViaLinkDto) {
    return this.links.sendViaLink(id, dto);
  }

  /** Public claim-landing preview — no auth, matches PayTag resolution's posture in this build. */
  @Get('claim/:token')
  previewClaim(@Param('token') token: string) {
    return this.links.previewClaim(token);
  }

  @Post('users/:id/claim/:token')
  claim(@Param('id') id: string, @Param('token') token: string) {
    return this.links.claim(id, token);
  }
}
