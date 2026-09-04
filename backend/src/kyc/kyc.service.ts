import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { BmoniClientService } from '../bmoni/bmoni-client.service';
import { UsersService } from '../users/users.service';
import { KycPatchDto } from './dto/kyc-patch.dto';
import { IdentificationDocumentDto } from './dto/identification-document.dto';
import { ProofOfAddressDto } from './dto/proof-of-address.dto';
import { BiometricDto } from './dto/biometric.dto';

type UploadedFile = { buffer: Buffer; filename: string; contentType: string };

@Injectable()
export class KycService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly bmoni: BmoniClientService,
    private readonly users: UsersService,
  ) {}

  private async getOrCreateProfile(appUserId: string) {
    return this.prisma.kycProfile.upsert({
      where: { appUserId },
      create: { appUserId },
      update: {},
    });
  }

  async getOptions(appUserId: string) {
    const user = await this.users.findById(appUserId);
    return this.bmoni.getKycOptions(user.bmoniUserId);
  }

  async getOccupations(appUserId: string, search: string) {
    const user = await this.users.findById(appUserId);
    return this.bmoni.getKycOccupations(user.bmoniUserId, search);
  }

  async submitIdentification(appUserId: string, dto: IdentificationDocumentDto, file: UploadedFile) {
    const user = await this.users.findById(appUserId);
    const result = await this.bmoni.submitIdentificationDocument(user.bmoniUserId, dto, file);
    await this.getOrCreateProfile(appUserId);
    await this.prisma.kycProfile.update({
      where: { appUserId },
      data: { identificationSubmittedAt: new Date() },
    });
    return result;
  }

  async submitProofOfAddress(appUserId: string, dto: ProofOfAddressDto, file: UploadedFile) {
    const user = await this.users.findById(appUserId);
    const result = await this.bmoni.submitProofOfAddress(user.bmoniUserId, dto.type, file);
    await this.getOrCreateProfile(appUserId);
    await this.prisma.kycProfile.update({
      where: { appUserId },
      data: { proofOfAddressSubmittedAt: new Date() },
    });
    return result;
  }

  async submitBiometric(appUserId: string, dto: BiometricDto, file: UploadedFile) {
    const user = await this.users.findById(appUserId);
    const result = await this.bmoni.submitBiometric(user.bmoniUserId, dto.type, file);
    await this.getOrCreateProfile(appUserId);
    await this.prisma.kycProfile.update({
      where: { appUserId },
      data: { biometricSubmittedAt: new Date() },
    });
    return result;
  }

  async patch(appUserId: string, dto: KycPatchDto) {
    const user = await this.users.findById(appUserId);
    const result = await this.bmoni.patchKyc(user.bmoniUserId, dto);
    await this.getOrCreateProfile(appUserId);
    await this.prisma.kycProfile.update({
      where: { appUserId },
      data: {
        personalInfo: dto.personalInfo as unknown as Prisma.InputJsonValue | undefined,
        address: dto.address as unknown as Prisma.InputJsonValue | undefined,
        employment: dto.employment as unknown as Prisma.InputJsonValue | undefined,
        sourceOfFunds: dto.sourceOfFunds,
        accountPurpose: dto.accountPurpose,
        estimatedMonthlyVolume: dto.estimatedMonthlyVolume,
      },
    });
    return result;
  }

  async getReadiness(appUserId: string) {
    const user = await this.users.findById(appUserId);
    const readiness = await this.bmoni.getKycReadiness(user.bmoniUserId);
    if (readiness.ready) {
      await this.getOrCreateProfile(appUserId);
      await this.prisma.kycProfile.update({
        where: { appUserId },
        data: { readyAt: new Date() },
      });
    }
    return readiness;
  }

  async getUsdReadiness(appUserId: string) {
    const user = await this.users.findById(appUserId);
    return this.bmoni.getUsdReadiness(user.bmoniUserId);
  }

  async activate(appUserId: string, currency: string, sumsubLevelName: string) {
    const user = await this.users.findById(appUserId);
    const result = await this.bmoni.activateKyc(user.bmoniUserId, { sumsubLevelName });
    if (result.activated) {
      const profile = await this.getOrCreateProfile(appUserId);
      const activatedCurrencies = Array.from(
        new Set([...profile.activatedCurrencies, currency]),
      );
      await this.prisma.kycProfile.update({
        where: { appUserId },
        data: { activatedCurrencies },
      });
    }
    return result;
  }

  async bvnLookup(appUserId: string, bvn: string) {
    const user = await this.users.findById(appUserId);
    return this.bmoni.bvnLookup(user.bmoniUserId, bvn);
  }
}
