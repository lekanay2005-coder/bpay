import { Body, Controller, Get, Param, Patch, Post } from '@nestjs/common';
import { UsersService } from './users.service';
import { CreateUserDto } from './dto/create-user.dto';
import { SetOwnerAddressDto } from './dto/set-owner-address.dto';

@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Post()
  create(@Body() dto: CreateUserDto) {
    return this.users.getOrCreate(dto);
  }

  @Get(':id')
  findById(@Param('id') id: string) {
    return this.users.findById(id);
  }

  @Patch(':id/owner-address')
  setOwnerAddress(@Param('id') id: string, @Body() dto: SetOwnerAddressDto) {
    return this.users.setOwnerAddress(id, dto.ownerAddress);
  }
}
