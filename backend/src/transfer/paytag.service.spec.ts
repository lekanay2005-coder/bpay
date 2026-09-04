import { ConflictException, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PayTagService } from './paytag.service';
import { PrismaService } from '../prisma/prisma.service';

describe('PayTagService', () => {
  function buildService(overrides?: { upsert?: jest.Mock; findUnique?: jest.Mock }) {
    const prisma = {
      payTag: {
        upsert: overrides?.upsert ?? jest.fn(),
        findUnique: overrides?.findUnique ?? jest.fn(),
      },
    } as unknown as PrismaService;
    return { service: new PayTagService(prisma), prisma };
  }

  it('registers a tag for a user', async () => {
    const upsert = jest.fn().mockResolvedValue({ id: 't1', appUserId: 'u1', tag: 'samson' });
    const { service } = buildService({ upsert });

    const result = await service.register('u1', 'samson');

    expect(upsert).toHaveBeenCalledWith({
      where: { appUserId: 'u1' },
      create: { appUserId: 'u1', tag: 'samson' },
      update: { tag: 'samson' },
    });
    expect(result).toMatchObject({ tag: 'samson' });
  });

  it('translates a unique-constraint violation into a ConflictException', async () => {
    const upsert = jest.fn().mockRejectedValue(
      new Prisma.PrismaClientKnownRequestError('Unique constraint failed on the fields: (`tag`)', {
        code: 'P2002',
        clientVersion: '5.22.0',
      }),
    );
    const { service } = buildService({ upsert });

    await expect(service.register('u1', 'taken')).rejects.toBeInstanceOf(ConflictException);
  });

  it('does not swallow other database errors', async () => {
    const upsert = jest.fn().mockRejectedValue(new Error('connection lost'));
    const { service } = buildService({ upsert });

    await expect(service.register('u1', 'samson')).rejects.toThrow('connection lost');
  });

  it('resolves a tag to its owning user', async () => {
    const appUser = { id: 'u1', bmoniUserId: 'bm-1', firstName: 'Samson', lastName: 'Jabo' };
    const findUnique = jest.fn().mockResolvedValue({ tag: 'samson', appUser });
    const { service } = buildService({ findUnique });

    const result = await service.resolve('samson');

    expect(findUnique).toHaveBeenCalledWith({
      where: { tag: 'samson' },
      include: { appUser: true },
    });
    expect(result).toBe(appUser);
  });

  it('throws NotFoundException for an unregistered tag', async () => {
    const findUnique = jest.fn().mockResolvedValue(null);
    const { service } = buildService({ findUnique });

    await expect(service.resolve('nobody')).rejects.toBeInstanceOf(NotFoundException);
  });
});
