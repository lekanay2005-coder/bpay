import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import bmoniConfig from './config/bmoni.config';
import { PrismaModule } from './prisma/prisma.module';
import { BmoniModule } from './bmoni/bmoni.module';
import { UsersModule } from './users/users.module';
import { OnboardingModule } from './onboarding/onboarding.module';
import { WebhooksModule } from './webhooks/webhooks.module';
import { KycModule } from './kyc/kyc.module';
import { WalletModule } from './wallet/wallet.module';
import { TransferModule } from './transfer/transfer.module';
import { PaymentsModule } from './payments/payments.module';
import { TreasuryModule } from './treasury/treasury.module';
import { SavingsModule } from './savings/savings.module';
import { LoansModule } from './loans/loans.module';
import { AgentModule } from './agent/agent.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, load: [bmoniConfig] }),
    ScheduleModule.forRoot(),
    PrismaModule,
    BmoniModule,
    UsersModule,
    OnboardingModule,
    WebhooksModule,
    KycModule,
    WalletModule,
    TransferModule,
    PaymentsModule,
    TreasuryModule,
    SavingsModule,
    LoansModule,
    AgentModule,
  ],
})
export class AppModule {}
