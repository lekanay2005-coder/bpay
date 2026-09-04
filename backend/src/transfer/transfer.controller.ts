import { BadRequestException, Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { TransferService } from './transfer.service';
import { PayTagService } from './paytag.service';
import { CreateTransferDto } from './dto/create-transfer.dto';
import { SubmitSignatureDto } from './dto/submit-signature.dto';
import { RejectProposalDto } from './dto/reject-proposal.dto';
import { RegisterPayTagDto } from './dto/register-paytag.dto';

@Controller()
export class TransferController {
  constructor(
    private readonly transfers: TransferService,
    private readonly payTags: PayTagService,
  ) {}

  @Post('users/:id/paytag')
  registerPayTag(@Param('id') id: string, @Body() dto: RegisterPayTagDto) {
    return this.payTags.register(id, dto.tag);
  }

  @Get('users/:id/paytag')
  getPayTag(@Param('id') id: string) {
    return this.payTags.getForUser(id);
  }

  @Get('paytag/:tag')
  async resolvePayTag(@Param('tag') tag: string) {
    const user = await this.payTags.resolve(tag);
    // Deliberately narrow: enough to show "sending to <name>" and target a
    // transfer, nothing else about the recipient.
    return {
      appUserId: user.id,
      bmoniUserId: user.bmoniUserId,
      firstName: user.firstName,
      lastName: user.lastName,
    };
  }

  @Post('users/:id/transfers')
  async createTransfer(@Param('id') id: string, @Body() dto: CreateTransferDto) {
    const targets = [dto.toBmoniUserId, dto.toAddress, dto.toPayTag].filter(Boolean);
    if (targets.length !== 1) {
      throw new BadRequestException(
        'Exactly one of toBmoniUserId, toAddress, or toPayTag is required.',
      );
    }

    let toBmoniUserId = dto.toBmoniUserId;
    if (dto.toPayTag) {
      const recipient = await this.payTags.resolve(dto.toPayTag);
      toBmoniUserId = recipient.bmoniUserId;
    }

    return this.transfers.createTransfer(id, {
      toBmoniUserId,
      toAddress: dto.toAddress,
      amount: dto.amount,
      currency: dto.currency,
      description: dto.description,
    });
  }

  @Get('users/:id/transfers')
  listTransfers(@Param('id') id: string, @Query('currency') currency: string) {
    if (!currency) throw new BadRequestException('?currency= query param is required.');
    return this.transfers.listProposals(id, currency);
  }

  @Get('users/:id/transfers/:proposalId')
  getTransfer(@Param('id') id: string, @Param('proposalId') proposalId: string) {
    return this.transfers.getProposal(id, proposalId);
  }

  @Get('users/:id/transfers/:proposalId/sign-payload')
  getSignPayload(@Param('id') id: string, @Param('proposalId') proposalId: string) {
    return this.transfers.getSignPayload(id, proposalId);
  }

  @Post('users/:id/transfers/:proposalId/sign')
  sign(
    @Param('id') id: string,
    @Param('proposalId') proposalId: string,
    @Body() dto: SubmitSignatureDto,
  ) {
    return this.transfers.submitSignature(id, proposalId, dto.signature);
  }

  @Post('users/:id/transfers/:proposalId/reject')
  reject(
    @Param('id') id: string,
    @Param('proposalId') proposalId: string,
    @Body() dto: RejectProposalDto,
  ) {
    return this.transfers.reject(id, proposalId, dto.reason);
  }
}
