import { IsIn } from 'class-validator';
import { BiometricType } from '../../bmoni/dto/kyc.dto';

const BIOMETRIC_TYPES: BiometricType[] = [
  'selfie',
  'liveness_check',
  'video_verification',
  'enrollment',
  'recovery_enrollment',
  'recovery_blocked_attempt',
];

export class BiometricDto {
  @IsIn(BIOMETRIC_TYPES)
  type!: BiometricType;
}
