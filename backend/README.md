# PayFlex backend (NestJS)

Orchestration service between the Flutter app and the BMONI Embedded API.
See `../docs/BUILD_PROMPT.md` for the full spec and `../README.md` for the
project-wide BMONI-vs-PayFlex boundary.

## Setup

```bash
npm install
cp .env.example .env          # sandbox key is already filled in
docker-compose up -d          # Postgres + Redis for local dev
npx prisma migrate dev        # creates the schema (first run only)
npm run start:dev             # http://localhost:3000
```

## Verifying Phase 1 against the live sandbox

```bash
npm run sandbox:lifecycle
```

This runs `scripts/sandbox-lifecycle.ts`, which boots the real
`UsersService` / `OnboardingService` / `BmoniClientService` (the exact
classes the HTTP API uses) as a Nest application context and walks the
full core lifecycle from build brief section 2.1 against
`https://embedded-dev.bmoni.com`:

1. create-or-reuse the persona user (`POST /v1/users`)
2. a safe, read-only BVN lookup preview (`GET /kyc/bvn-lookup/{bvn}`)
3. simulate on-device owner-wallet generation (see note below)
4. list supported stablecoins (`GET /smart-wallets/supported-currencies`)
5. request an owner-proof challenge
6. simulate on-device EIP-191 signing of that challenge
7. create the managed smart wallet
8. read onboarding status

This has been run against the live sandbox and succeeds end-to-end; the
last run produced a real `bmoniUserId` and a real, active NGN smart
wallet. Unit tests (`npm test`) additionally cover the "never recreate a
user" and BMONI-409-conflict-handling logic without hitting the network.

**The only deviation from the real app**: step 3/6 use a plain
`ethers.Wallet` to generate a keypair and produce the EIP-191 signature,
because there's no mobile device/emulator in a backend-only environment to
run `bmoni_embedded_sdk`. `ethers.Wallet.signMessage` performs the exact
same `personal_sign` EIP-191 construction the SDK does, so this proves the
BMONI API sequence works — it does **not** stand in for the Flutter app,
which must always go through `bmoni_embedded_sdk` for real key material.
See the header comment in `scripts/sandbox-lifecycle.ts`.

## Things discovered empirically that the brief didn't fully spell out

BMONI's request/response shapes for a few endpoints turned out to differ
in small but breaking ways from a literal reading of the brief. Fixed
during Phase 1 verification, and called out here (and in the DTO files
under `src/bmoni/dto/`) so nobody "fixes" them back:

- `POST /v1/users` requires `firstName`, `lastName`, `email`,
  `phoneNumber` (not `phone`). The response wraps the created user as
  `{ user: {...} }`, not a bare object.
- **The sandbox is multi-tenant.** The "BMONI Hackathon" partner key used
  for sandbox testing is shared across many developers, and BMONI
  enforces `phoneNumber` uniqueness *globally*, not per partner key. The
  build brief's canonical persona phone number
  (`+2348000000001`, Samson Jabo) was already registered by someone else
  under this key by the time this was built — a `409 Conflict` for that
  exact number is expected, not a bug. `UsersService.getOrCreate` maps
  that into a distinct `ConflictException` rather than a generic 500.
  `scripts/sandbox-lifecycle.ts` uses the persona's real name with a
  freshly-generated phone number instead, since name matching (not the
  phone number) is what actually matters for the KYC identity checks in
  Phase 2.
  - `GET /v1/users` is paginated (`page`/`limit`, max `limit=100`) and
    lists **every** user under the shared partner key, including other
    teams' real names/emails — treat it as sensitive and avoid bulk
    dumping it (we didn't, and deleted what little we'd pulled during
    debugging).
- The owner-proof-challenge response includes a `groupId` field
  alongside `challengeId` that the brief didn't mention.
- The managed-smart-wallet response labels `currency` by its **fiat**
  rail name (`"NGN"`) even though the request's `currency` field takes
  the **stablecoin** code (`"CNGN"`) — and uses `walletAddress` /
  `isActive`, not `address` / `status`. Send the stablecoin code in;
  expect the fiat label and the fields above back out.
- `GET /v1/users/{userId}/onboarding/status` for a brand-new user (smart
  wallet created, no rail onboarding started) returns a fixed set of
  per-provider fields — `anchorStatus`, `bridgeStatus`, `moneriumStatus`,
  `paytrieStatus`, `etherfuseStatus` — all `"not_started"`. How these
  evolve mid-flow hasn't been observed yet (Phase 2 work).

Everything else under `src/bmoni/dto/` that hasn't been exercised against
a live response yet is commented as such — treat those shapes as
best-effort from the brief, not confirmed.

## Testing

```bash
npm test                # unit tests (no network)
npm run sandbox:lifecycle  # live integration against the BMONI sandbox
```
