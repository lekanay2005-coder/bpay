import { IsBoolean } from 'class-validator';

export class SetAgentStatusDto {
  @IsBoolean()
  isAgent!: boolean;
}
