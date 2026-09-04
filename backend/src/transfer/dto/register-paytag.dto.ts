import { Matches } from 'class-validator';

export class RegisterPayTagDto {
  // Lowercase alnum/underscore, 3-20 chars — deliberately conservative
  // for a first pass; loosen later if product wants unicode handles etc.
  @Matches(/^[a-z0-9_]{3,20}$/, {
    message: 'tag must be 3-20 characters: lowercase letters, digits, underscore',
  })
  tag!: string;
}
