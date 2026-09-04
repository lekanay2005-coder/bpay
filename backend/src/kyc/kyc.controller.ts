import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { KycService } from './kyc.service';
import { KycPatchDto } from './dto/kyc-patch.dto';
import { KycActivateDto } from './dto/kyc-activate.dto';
import { IdentificationDocumentDto } from './dto/identification-document.dto';
import { ProofOfAddressDto } from './dto/proof-of-address.dto';
import { BiometricDto } from './dto/biometric.dto';

/**
 * Our own multipart contract always uses a field named `file`, regardless
 * of what BMONI itself expects on the other side (`files` for
 * identification/proof-of-address, `selfie` for biometric — see
 * BmoniClientService). Decoupling our API shape from BMONI's per-endpoint
 * quirks means the Flutter app only has to remember one convention.
 */
@Controller('users/:id/kyc')
export class KycController {
  constructor(private readonly kyc: KycService) {}

  @Get('options')
  getOptions(@Param('id') id: string) {
    return this.kyc.getOptions(id);
  }

  @Get('occupations')
  getOccupations(@Param('id') id: string, @Query('search') search = '') {
    return this.kyc.getOccupations(id, search);
  }

  @Post('documents/identification')
  @UseInterceptors(FileInterceptor('file'))
  submitIdentification(
    @Param('id') id: string,
    @Body() dto: IdentificationDocumentDto,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('file is required');
    return this.kyc.submitIdentification(id, dto, {
      buffer: file.buffer,
      filename: file.originalname,
      contentType: file.mimetype,
    });
  }

  @Post('documents/proof-of-address')
  @UseInterceptors(FileInterceptor('file'))
  submitProofOfAddress(
    @Param('id') id: string,
    @Body() dto: ProofOfAddressDto,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('file is required');
    return this.kyc.submitProofOfAddress(id, dto, {
      buffer: file.buffer,
      filename: file.originalname,
      contentType: file.mimetype,
    });
  }

  @Post('documents/biometric')
  @UseInterceptors(FileInterceptor('file'))
  submitBiometric(
    @Param('id') id: string,
    @Body() dto: BiometricDto,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('file is required');
    return this.kyc.submitBiometric(id, dto, {
      buffer: file.buffer,
      filename: file.originalname,
      contentType: file.mimetype,
    });
  }

  @Patch()
  patch(@Param('id') id: string, @Body() dto: KycPatchDto) {
    return this.kyc.patch(id, dto);
  }

  @Get('readiness')
  readiness(@Param('id') id: string) {
    return this.kyc.getReadiness(id);
  }

  @Get('usd-readiness')
  usdReadiness(@Param('id') id: string) {
    return this.kyc.getUsdReadiness(id);
  }

  @Post('activate')
  activate(@Param('id') id: string, @Body() dto: KycActivateDto, @Query('currency') currency: string) {
    if (!currency) {
      throw new BadRequestException('?currency= query param is required (which rail this activates)');
    }
    return this.kyc.activate(id, currency, dto.sumsubLevelName);
  }

  @Get('bvn-lookup/:bvn')
  bvnLookup(@Param('id') id: string, @Param('bvn') bvn: string) {
    return this.kyc.bvnLookup(id, bvn);
  }
}
