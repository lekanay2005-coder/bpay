import { ConflictException } from '@nestjs/common';
import { UsersService } from './users.service';
import { PrismaService } from '../prisma/prisma.service';
import { BmoniClientService } from '../bmoni/bmoni-client.service';
import { BmoniApiError } from '../bmoni/bmoni.errors';

describe('UsersService.getOrCreate', () => {
  const dto = {
    firstName: 'Samson',
    lastName: 'Jabo',
    email: 'samson@payflex.test',
    phoneNumber: '+2348000000001',
  };

  function buildService(overrides?: {
    findUnique?: jest.Mock;
    create?: jest.Mock;
    createUser?: jest.Mock;
  }) {
    const prisma = {
      appUser: {
        findUnique: overrides?.findUnique ?? jest.fn().mockResolvedValue(null),
        create: overrides?.create ?? jest.fn(),
      },
    } as unknown as PrismaService;
    const bmoni = {
      createUser: overrides?.createUser ?? jest.fn(),
    } as unknown as BmoniClientService;
    return { service: new UsersService(prisma, bmoni), prisma, bmoni };
  }

  it('never calls BMONI when a local user already exists for the phone number', async () => {
    const existing = { id: 'local-1', bmoniUserId: 'bmoni-1', ...dto };
    const findUnique = jest.fn().mockResolvedValue(existing);
    const createUser = jest.fn();
    const { service } = buildService({ findUnique, createUser });

    const result = await service.getOrCreate(dto);

    expect(result).toBe(existing);
    expect(createUser).not.toHaveBeenCalled();
  });

  it('creates a BMONI user and persists it locally on first sight of a phone number', async () => {
    const bmoniUser = {
      id: 'row-1',
      partnerName: 'BMONI Hackathon',
      employeeId: null,
      identityId: 'identity-1',
      bmoniUserId: 'bmoni-42',
      firstName: dto.firstName,
      lastName: dto.lastName,
      middleName: '',
      email: dto.email,
      phoneNumber: dto.phoneNumber,
      employerName: '',
      occupation: '',
      monthlySalary: '',
      linkedAt: null,
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
    };
    const createUser = jest.fn().mockResolvedValue(bmoniUser);
    const create = jest.fn().mockImplementation(({ data }) => ({ id: 'local-2', ...data }));
    const { service } = buildService({ createUser, create });

    const result = await service.getOrCreate(dto);

    expect(createUser).toHaveBeenCalledWith(dto);
    expect(create).toHaveBeenCalledWith({
      data: {
        bmoniUserId: 'bmoni-42',
        firstName: dto.firstName,
        lastName: dto.lastName,
        email: dto.email,
        phoneNumber: dto.phoneNumber,
      },
    });
    expect(result).toMatchObject({ bmoniUserId: 'bmoni-42' });
  });

  it('translates a BMONI 409 (phone already registered) into a ConflictException', async () => {
    const createUser = jest
      .fn()
      .mockRejectedValue(
        new BmoniApiError(409, 'Conflict', 'User already exists with this phoneNumber', '/v1/users'),
      );
    const { service } = buildService({ createUser });

    await expect(service.getOrCreate(dto)).rejects.toBeInstanceOf(ConflictException);
  });

  it('does not swallow non-conflict BMONI errors', async () => {
    const createUser = jest
      .fn()
      .mockRejectedValue(new BmoniApiError(400, 'Bad Request', ['email must be an email'], '/v1/users'));
    const { service } = buildService({ createUser });

    await expect(service.getOrCreate(dto)).rejects.toBeInstanceOf(BmoniApiError);
  });
});
