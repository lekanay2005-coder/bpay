import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import bmoniConfig from './config/bmoni.config';
import { PrismaModule } from './prisma/prisma.module';
import { BmoniModule } from './bmoni/bmoni.module';
import { UsersModule } from './users/users.module';
import { OnboardingModule } from './onboarding/onboarding.module';
import { WebhooksModule } from './webhooks/webhooks.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, load: [bmoniConfig] }),
    PrismaModule,
    BmoniModule,
    UsersModule,
    OnboardingModule,
    WebhooksModule,
  ],
})
export class AppModule {}
