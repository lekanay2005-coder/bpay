import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from '../users/users.service';
import { TransferService } from '../transfer/transfer.service';
import { PayTagService } from '../transfer/paytag.service';
import { CashInDto } from './dto/cash-in.dto';
import { CashOutDto } from './dto/cash-out.dto';

/**
 * Agent cash-in/cash-out (build brief section 3/5 — no BMONI agent
 * primitive). Mechanically these are ordinary TransferService transfers;
 * this service only adds the "must actually be a registered agent" check
 * and a separate reconciliation ledger (AgentTransaction) so an agent can
 * see their own cash activity apart from a regular transaction list.
 */
@Injectable()
export class AgentService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly transfers: TransferService,
    private readonly payTags: PayTagService,
  ) {}

  async setAgentStatus(appUserId: string, isAgent: boolean) {
    await this.users.findById(appUserId);
    return this.prisma.appUser.update({ where: { id: appUserId }, data: { isAgent } });
  }

  /** Agent hands out digital funds after receiving physical cash from the customer. */
  async cashIn(agentAppUserId: string, dto: CashInDto) {
    const agent = await this.requireAgent(agentAppUserId);

    let toBmoniUserId = dto.toBmoniUserId;
    let customerAppUserId: string | null = null;
    if (dto.toPayTag) {
      const customer = await this.payTags.resolve(dto.toPayTag);
      toBmoniUserId = customer.bmoniUserId;
      customerAppUserId = customer.id;
    } else if (dto.toBmoniUserId) {
      const customer = await this.prisma.appUser.findUnique({
        where: { bmoniUserId: dto.toBmoniUserId },
      });
      customerAppUserId = customer?.id ?? null;
    }
    if (!toBmoniUserId) {
      throw new BadRequestException('Exactly one of toBmoniUserId or toPayTag is required.');
    }

    const proposal = await this.transfers.createTransfer(agentAppUserId, {
      toBmoniUserId,
      amount: dto.amount,
      currency: dto.currency,
      description: 'Agent cash-in',
    });

    await this.prisma.agentTransaction.create({
      data: {
        agentAppUserId: agent.id,
        customerAppUserId,
        customerBmoniUserId: toBmoniUserId,
        type: 'CASH_IN',
        amount: dto.amount,
        currency: dto.currency,
        bmoniProposalId: proposal.id,
        status: proposal.status,
      },
    });

    return proposal;
  }

  /** Customer sends digital funds to the agent in exchange for physical cash. */
  async cashOut(customerAppUserId: string, dto: CashOutDto) {
    const customer = await this.users.findById(customerAppUserId);

    let agent;
    if (dto.agentPayTag) {
      agent = await this.payTags.resolve(dto.agentPayTag);
    } else if (dto.agentBmoniUserId) {
      agent = await this.prisma.appUser.findUnique({
        where: { bmoniUserId: dto.agentBmoniUserId },
      });
    }
    if (!agent) {
      throw new BadRequestException(
        'Exactly one of agentBmoniUserId or agentPayTag is required and must resolve to a user.',
      );
    }
    if (!agent.isAgent) {
      throw new BadRequestException(`${agent.id} is not a registered agent.`);
    }

    const proposal = await this.transfers.createTransfer(customerAppUserId, {
      toBmoniUserId: agent.bmoniUserId,
      amount: dto.amount,
      currency: dto.currency,
      description: 'Agent cash-out',
    });

    await this.prisma.agentTransaction.create({
      data: {
        agentAppUserId: agent.id,
        customerAppUserId: customer.id,
        customerBmoniUserId: customer.bmoniUserId,
        type: 'CASH_OUT',
        amount: dto.amount,
        currency: dto.currency,
        bmoniProposalId: proposal.id,
        status: proposal.status,
      },
    });

    return proposal;
  }

  listTransactions(agentAppUserId: string) {
    return this.prisma.agentTransaction.findMany({
      where: { agentAppUserId },
      orderBy: { createdAt: 'desc' },
    });
  }

  private async requireAgent(appUserId: string) {
    const user = await this.users.findById(appUserId);
    if (!user.isAgent) {
      throw new NotFoundException(`${appUserId} is not a registered agent.`);
    }
    return user;
  }
}
