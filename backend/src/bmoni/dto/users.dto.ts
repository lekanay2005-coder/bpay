/**
 * Confirmed against the live sandbox (2026-09-04):
 *   POST /v1/users requires firstName, lastName, email, phoneNumber
 *   (E.164). "phone" is rejected — the field is "phoneNumber".
 *   A duplicate phoneNumber returns 409 Conflict, "User already exists
 *   with this phoneNumber" — BMONI enforces phone uniqueness globally
 *   across the whole partner sandbox, not just within a caller's own
 *   users, in the shared "BMONI Hackathon" sandbox key. Treat 409 here
 *   as "this phone is already a BMONI user" and surface it distinctly
 *   from a generic validation failure — see UsersService.
 */
export interface CreateBmoniUserRequest {
  firstName: string;
  lastName: string;
  email: string;
  phoneNumber: string;
}

export interface BmoniUser {
  id: string;
  partnerName: string;
  employeeId: string | null;
  identityId: string;
  bmoniUserId: string;
  firstName: string;
  lastName: string;
  middleName: string;
  email: string;
  phoneNumber: string;
  employerName: string;
  occupation: string;
  monthlySalary: string;
  linkedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface ListBmoniUsersResponse {
  users: BmoniUser[];
  total: number;
  page: number;
  limit: number;
}

/** POST /v1/users wraps the created user under a `user` key — confirmed live. */
export interface CreateBmoniUserResponse {
  user: BmoniUser;
}
