import { Module } from '@nestjs/common';
import { AgentService } from './agent.service';
import { AgentController } from './agent.controller';
import { UsersModule } from '../users/users.module';
import { TransferModule } from '../transfer/transfer.module';

@Module({
  imports: [UsersModule, TransferModule],
  providers: [AgentService],
  controllers: [AgentController],
})
export class AgentModule {}
