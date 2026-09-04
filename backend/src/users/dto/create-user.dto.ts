import { IsEmail, IsNotEmpty, IsString, Matches } from 'class-validator';

export class CreateUserDto {
  @IsString()
  @IsNotEmpty()
  firstName!: string;

  @IsString()
  @IsNotEmpty()
  lastName!: string;

  @IsEmail()
  email!: string;

  // E.164, e.g. +2348000000001 — BMONI rejects a bare local-format number.
  @Matches(/^\+[1-9]\d{6,14}$/, {
    message: 'phoneNumber must be E.164, e.g. +2348000000001',
  })
  phoneNumber!: string;
}
