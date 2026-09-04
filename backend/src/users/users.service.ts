import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BmoniClientService } from '../bmoni/bmoni-client.service';
import { BmoniApiError } from '../bmoni/bmoni.errors';
import { CreateUserDto } from './dto/create-user.dto';
import { AppUser } from '@prisma/client';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly bmoni: BmoniClientService,
  ) {}

  /**
   * The one and only place a BMONI user is created from this app. Always
   * checks local storage first — per the brief, recreating a BMONI user
   * on relaunch forks wallet history, so an existing local row always
   * wins over calling POST /v1/users again.
   */
  async getOrCreate(dto: CreateUserDto): Promise<AppUser> {
    const existing = await this.prisma.appUser.findUnique({
      where: { phoneNumber: dto.phoneNumber },
    });
    if (existing) return existing;

    try {
      const bmoniUser = await this.bmoni.createUser(dto);
      return await this.prisma.appUser.create({
        data: {
          bmoniUserId: bmoniUser.bmoniUserId,
          firstName: bmoniUser.firstName,
          lastName: bmoniUser.lastName,
          email: bmoniUser.email,
          phoneNumber: bmoniUser.phoneNumber,
        },
      });
    } catch (err) {
      if (err instanceof BmoniApiError && err.isConflict) {
        // BMONI enforces phoneNumber uniqueness across the whole sandbox
        // partner key, not just our own users — this can legitimately
        // fire even for a phone number we've never created locally (e.g.
        // in a shared sandbox where another team already registered it).
        // Surface a distinct, actionable error rather than a generic 500.
        throw new ConflictException(
          `A BMONI user already exists for ${dto.phoneNumber}. This phone cannot be ` +
            `re-registered under a different app account; if this is unexpected, ` +
            `confirm you're not reusing a persona phone number someone else already ` +
            `claimed in a shared sandbox.`,
        );
      }
      throw err;
    }
  }

  async findById(id: string): Promise<AppUser> {
    const user = await this.prisma.appUser.findUnique({ where: { id } });
    if (!user) throw new NotFoundException(`No local user with id ${id}`);
    return user;
  }

  async setOwnerAddress(id: string, ownerAddress: string): Promise<AppUser> {
    await this.findById(id);
    return this.prisma.appUser.update({ where: { id }, data: { ownerAddress } });
  }
}
