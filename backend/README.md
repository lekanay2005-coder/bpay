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
npm run provision:treasury    # one-time: creates PayFlex's own treasury BMONI account
                               # (paste its output's two lines into .env — required for
                               # loan disbursement; everything else works without it)
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

## Verifying Phase 2 against the live sandbox

```bash
npm run sandbox:phase2        # full NGN KYC wizard + rail onboarding + wallet home
npm run sandbox:kyc-mismatch  # the deliberate BVN/name-mismatch check (see below)
```

`scripts/sandbox-lifecycle-phase2.ts` runs the real `KycService` /
`OnboardingService` / `WalletService` through the complete NGN flow:
KYC options/occupations, all three documents, the `PATCH kyc` profile
fields, readiness, activation, `start-nigeria`, polling onboarding status
to `active`, then wallets/balances/transactions. This has been run
against the live sandbox and passes end-to-end. The document images are
a real (but content-meaningless) PNG fixture at
`scripts/fixtures/test-document.png` — BMONI validates that uploads are
genuine image/PDF files, so random bytes are rejected outright.

The USD rail is wired the same way (`KycController`/`OnboardingService`
both handle it) but is **not** exercised by an automated script, because
BMONI's USD path runs a real Sumsub identity check that the synthetic
fixture image fails (see finding below) — completing it requires an
actual photorealistic ID/selfie capture, which only makes sense to test
from the real Flutter app on a device.

## Verifying Phase 3 against the live sandbox

```bash
npm run sandbox:phase3
```

`scripts/sandbox-lifecycle-phase3.ts` provisions two users with NGN smart
wallets, registers a PayTag for one of them, then exercises every
transfer path through the real `TransferService` / `PayTagService` /
`QrPayService`: a direct PayTag-resolved transfer, a QR-Pay-initiated
transfer (generate → decode → pay), signing both proposals, rejecting a
third, and listing proposals. This has been run against the live sandbox
and passes end-to-end — proposal creation and signing are both confirmed
working. What it can *not* verify: on-chain execution, because this
sandbox has no faucet and the one funding path that exists (crypto
deposit) 502'd on every attempt — see findings below. That's a sandbox
limitation, not a gap in this integration.

Before writing any Phase 3 code, this pass also discovered that BMONI's
own OpenAPI spec is served at `GET /docs/openapi.json` on the sandbox
host (linked from `/docs`, a Scalar API reference page) — this is *not*
mentioned anywhere in the build brief. It's far more reliable than
guessing paths by trial and error the way Phases 1-2 had to, though it is
**not** perfectly in sync with live behavior either (see the proposal
response-envelope mismatch below) — treat it as a strong hint to verify
live, not a substitute for testing.

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

### Phase 2 findings

The KYC/onboarding/wallet-home surface diverges from the brief more than
Phase 1's did. All confirmed live on 2026-09-04 against a fresh sandbox
user carried through the full wizard:

- **`PATCH /kyc`'s real shape is not what the brief describes.** The
  personal-info wrapper key is `personalInfo`, not `personal`; there is
  no `compliance` wrapper (`accountPurpose` and `estimatedMonthlyVolume`
  are top-level); address uses `streetLine1`/`streetLine2` and an ISO
  **alpha-3** `countryCode` (`"NGA"`, not `"NG"`); employment uses
  `employmentStatus`/`occupationCode` (not `status`/`occupation`);
  `sourceOfFunds` is top-level, not nested under employment. There is no
  `bvn` field on this endpoint at all — BVN is submitted via
  `POST /onboarding/start-nigeria` instead. Getting any of this wrong
  doesn't 400 loudly in every case — `PATCH /kyc` silently ignores/rejects
  unknown top-level keys (`"property X should not exist"`) but nested
  typos inside an accepted key can pass validation and just never show up
  in `saved`, so cross-check against `kyc/readiness`'s `missing` array
  after every patch, not just the `saved` map in the response.
- **The three document-upload endpoints each use a different file field
  name.** `documents/identification` and `documents/proof-of-address`
  both expect the file under `files`; `documents/biometric` expects it
  under `selfie`. All three reject non-image/PDF bytes outright ("not a
  valid JPEG, PNG, or PDF") and separately reject anything under ~2KB.
  `BmoniClientService`'s `postMultipart` takes the field name as a
  parameter specifically because of this — don't unify it.
- **`identificationTypes` from `GET /kyc/options` does not match what
  `documents/identification` actually accepts.** Options lists
  `["passport","national_id","driving_license","voter_id","tax_id"]`;
  the upload endpoint's real enum is `["passport","drivers_license",
  "national_id","government_id","nric","fin","other"]` (note
  `drivers_license` vs `driving_license`, and `voter_id`/`tax_id` aren't
  accepted at all). The Flutter KYC wizard hardcodes the upload-side enum
  for this reason rather than trusting `kyc/options`.
- **`kyc/activate`'s `sumsubLevelName` is always required** — BMONI
  rejects an omitted/empty body with a 400, contradicting the brief's
  instruction to omit it entirely for CAD/NGN. Its *valid* value set is
  also dynamic: an activate call before any documents were submitted
  listed 8 possible values including `"KYC via API"`; after all three
  documents were submitted for an NGN-target profile, the valid set
  narrowed to 4 values and `"KYC via API"` was no longer among them.
  `"id-and-liveness"` is the value confirmed working in that
  post-documents state. Don't hardcode a currency→level table without
  re-confirming against a live 400 response, which echoes the current
  valid set verbatim.
- **`onboarding/status` is asynchronous, not synchronous with the call
  that triggers it.** Immediately after `start-nigeria` returns 200,
  `anchorStatus` can still read `"not_started"` (or transiently
  `"pending"`) for a few seconds before settling to `"active"`. Both
  `scripts/sandbox-lifecycle-phase2.ts` and the Flutter wizard poll for
  this rather than checking once.
- **`start-usa` performs a real Sumsub identity check and will 422 on a
  synthetic image.** The response shape is also not the brief's bare
  `{ workflowId }` on failure — it's
  `{ kycStatus: "action_required", fieldsToAction: ["BAD_SELFIE",
  "DOCUMENT_PAGE_MISSING"], code, message, statusCode: 422 }`. This is
  the only endpoint in Phase 1-2 found so far where BMONI's error body has
  no `error` key at all, which is why `BmoniApiError` now carries the full
  `rawBody` alongside the parsed `error`/`message` — see
  `OnboardingService.startUsa`'s catch block, which records this as an
  `action_required` `RailOnboarding` row rather than losing the detail.
- **`GET /wallets` returns a bare array**, not `{ wallets: [...] }`.
  **`GET /balances`** returns `{ smartAccountAddress, balances: [{
  smartWalletId, currency, balance, error }] }` — `balance` is a plain
  decimal string (`"0"`), not a minor-unit string, so don't run it
  through `money.util.ts`. **`GET /transactions/{walletId}`** is
  paginated (`{ transactions, page, perPage, total, pageCount,
  hasNextPage, hasPreviousPage }`), not a bare `{ transactions }`.
- **A BVN/name mismatch was NOT rejected by `start-nigeria` in this
  sandbox**, contrary to the build brief's claim that "verification
  checks the number AND the submitted name." `npm run sandbox:kyc-mismatch`
  registers a user named "Deliberately Mismatched", confirms via
  `bvn-lookup` that BVN `22222222222` is on file for "Samson Jabo", then
  calls `start-nigeria` with that BVN anyway. Across three separate runs,
  the call returned 200 every time and `anchorStatus` settled to
  `"active"` within a few seconds, identical to the correctly-matched
  case — no rejection, no distinguishable "under review" hold, and no
  synchronous or fast-async error of any kind. This does **not** mean
  BMONI never enforces the match — it may happen later out-of-band (e.g.
  a `kyc.action_required` webhook, which this environment has no public
  URL to receive) — but it means **`start-nigeria` returning success is
  not, by itself, proof that identity was verified**, and this codebase
  should not treat it as a compliance control on its own. Flag this to
  BMONI/product before relying on it for anything KYC-sensitive; don't
  quietly assume the brief's description is what's actually enforced.

### Phase 3 findings

The proposal/transfer surface is where the build brief's literal
endpoints diverge from live behavior the most — every path below was
wrong or incomplete in the brief and had to be re-derived from BMONI's
OpenAPI spec (`GET /docs/openapi.json`) and then confirmed against a real
signed, submitted proposal:

- **Proposal creation/listing need the `/v1/users/{userId}` prefix the
  brief omits**: `POST/GET /v1/users/{userId}/smart-wallets/{smartWalletId}/proposals`,
  not `POST /smart-wallets/{smartWalletId}/proposals`. The body must be
  wrapped as `{ proposal: {...} }`, not the proposal fields at the top
  level.
- **There is no "approve" endpoint at all**, despite the brief — and even
  BMONI's own endpoint descriptions in its OpenAPI spec — describing an
  "approve → sign-payload → sign" sequence. Every plausible path
  (`/proposals/:id/approve` under half a dozen prefix variations) 404'd.
  Submitting a valid signature via `sign` **is** the approval action; plan
  around reject/sign-payload/sign/get as the complete set of proposal
  mutations, not four of five.
- **`reject`/`sign`/`sign-payload`/`get` are addressed by `proposalId`
  alone**, nested directly under `smart-wallets` — NOT under a specific
  `smartWalletId` the way creation is:
  `/v1/users/{userId}/smart-wallets/proposals/{proposalId}/sign` (etc.),
  not `/v1/proposals/{proposalId}/sign`.
- **The value to sign is `signingPayloadHash`, taken as a raw digest — not
  the EIP-712 hash of the accompanying `typedData` object.** `GET
  sign-payload` returns `{ signingPayloadHash, typedData, signatureExpiresAt,
  proposalStatus }`, where `typedData` is a full EIP-712 structure (domain
  `"Coinbase Smart Wallet"`, type `CoinbaseSmartWalletMessage`). The
  intuitive reading — compute the real EIP-712 digest from `typedData` and
  sign that — was tested directly against the live sandbox using
  `ethers.TypedDataEncoder.hash(domain, types, message)` and BMONI
  **rejected** the result: `"Signature does not match your registered
  owner address"`. Signing `signingPayloadHash` directly (raw ECDSA over
  that exact 32-byte value, no additional hashing) was **accepted**. This
  matches `bmoni_embedded_sdk`'s `signTransactionHash` exactly (its own
  docstring: "no prefix and no additional hashing is applied — the
  supplied hash is signed directly") — meaning the Flutter app needs
  **no EIP-712 encoder at all**, despite BMONI handing back a full typed-data
  structure that looks like it wants one. Get this backwards and every
  signature silently fails with a generic mismatch error that gives no
  hint the digest itself was wrong.
- **The sign payload is prepared asynchronously.** A `GET sign-payload`
  called immediately after proposal creation can 409 with `{code: "E201",
  message: "Signing payload is not ready yet. Wait until approvals
  complete and the transfer is prepared."}`. Both
  `scripts/sandbox-lifecycle-phase3.ts` and `TransferService` callers
  should poll (the script retries every 1.5s) rather than assume it's
  ready right away — this cost real debugging time before we realized it
  wasn't a one-off flake.
- **The live response envelope for proposal endpoints is `{ proposal }`
  everywhere** (create, get, sign, reject) — not the
  `{success,message,data:{proposal}}` shape BMONI's own OpenAPI spec
  documents for these same operations. This is the clearest example found
  so far of the spec and live behavior disagreeing; don't trust the spec's
  response shape without checking a live call.
- **BMONI's smart-wallet architecture is a Coinbase Smart Wallet /
  Safe-style multisig**, not the simple single-owner wallet the brief's
  description implies. A proposal's `signerSnapshot` lists two addresses
  (our registered `userOwnerAddress` plus a BMONI-side relay/KMS address),
  `executionModeSnapshot` is `"SAFE_TX_HASH_KMS_RELAY"`, and a proposal
  carries independent `currentSignatures`/`requiredSignatures` **and**
  `currentApprovals`/`requiredApprovals` counters. In every proposal we
  fully signed in this sandbox (`currentSignatures === requiredSignatures`),
  `currentApprovals` stayed at `0` and the proposal never left
  `PENDING_APPROVALS` even after ~30s of polling — plausibly because
  on-chain execution (and whatever grants the "approval") is gated on the
  wallet actually being able to fund the transfer, which a zero-balance
  sandbox wallet never can. Don't read a fully-signed, still-pending
  proposal as evidence of a bug in this integration.
- **A wallet's stored `currency` is the fiat label (`"NGN"`), but the
  proposal body's `currency` field wants the stablecoin code
  (`"CNGN"`)** — the same fiat/stablecoin split documented in the Phase 1
  findings above, now with a second consumer. `TransferService` and
  `PaymentsService` both take the fiat label (matching everywhere else in
  this app) and translate via `src/common/currency.util.ts`'s
  `stablecoinForFiat` before calling BMONI — don't pass a fiat label
  straight through to a proposal body a second time.
- **`account/send` (the documented "let the server pick the wallet"
  convenience endpoint) does not return what its own OpenAPI spec
  describes.** The spec says it returns `FundSmartWalletResponse` →
  `{ signatureRequest, quote }` (ready-to-sign, no separate sign-payload
  call needed); live, it returned a bare `{ proposal }` — the exact same
  shape as the raw proposals endpoint, requiring the normal
  sign-payload/sign follow-up. This backend uses the raw
  `.../smart-wallets/{smartWalletId}/proposals` endpoint directly instead
  of `account/send`/`fund`, since we already track `smartWalletId` locally
  and the "convenience" wrapper turned out not to save a round trip
  anyway.
- **Crypto deposit only bridges into a USDB wallet.** `POST deposit/wallet`
  against a CNGN wallet returned `400 "Group wallet must be for USDB
  currency, got CNGN"`. `GET deposit/supported-assets` listed only `USDC`
  as an enabled token per chain in this sandbox, despite `WalletDepositInput`'s
  documented enum including DAI/EURC/PYUSD/USDP/USDT. The deposit call
  itself returned a raw (non-JSON) `502` from BMONI's upstream bridge
  provider on every attempt — `PaymentsService.createDepositAddress` is
  wired and typed correctly against the confirmed request/response shapes,
  but could not be verified working end-to-end in this sandbox.
- **NGN bank account verification needs a real NUBAN** — unlike the BVN
  test values in build brief section 6, there's no documented sandbox
  test account number, so `verify-nigerian-account` /
  `withdrawal-accounts/nigeria` / `withdrawal/wallet/nigeria` are wired
  and typed against BMONI's OpenAPI spec but not exercised end-to-end here
  (a fabricated 10-digit number correctly 400s: `"We could not verify
  this account"`).
- One owner address maps to exactly one BMONI "group wallet" shared across
  all that user's currencies — adding a second currency wallet for a user
  requires reusing their **existing** `userOwnerAddress` in a fresh
  owner-proof-challenge for the new currency, not generating a new random
  owner. (This was already how `OnboardingService.createSmartWallet`
  worked, since it reads `AppUser.ownerAddress` — this surfaced only as a
  bug in a disposable verification script that generated a fresh random
  wallet per currency instead of reusing the app's own persisted one.)

## Verifying Phase 4 against the live sandbox

```bash
npm run provision:treasury    # one-time: creates PayFlex's own treasury BMONI account
npm run sandbox:phase4        # savings, loans (incl. auto-disbursement), agent mode
```

`scripts/sandbox-lifecycle-phase4.ts` runs the real `SavingsService` /
`LoansService` / `AgentService` / `TreasuryService`: creates a savings
goal, back-dates it and runs the due-check, signs the resulting
contribution; applies for a loan with a fresh account (correctly
rejected, score 0) and with a back-dated account (approved, and — this is
the interesting part — **disbursed with PayFlex's treasury account
signing server-side, no simulated end-user interaction at all**); signs a
loan repayment; then runs an agent cash-in and cash-out, each signed by
whichever side is the sender. This has been run against the live sandbox
and passes end-to-end, log line included:
`[TreasuryService] Treasury signing digest 0x...` — proof the server-side
signing path actually executed, not just the borrower-side ones every
other phase already covers.

### Phase 4 findings

Phase 4 needed no new BMONI endpoints — everything here is pure PayFlex
logic (build brief section 3) built on the same proposal primitive from
Phase 3 — but building it surfaced one structural point worth calling
out clearly, plus a scoring caveat:

- **BMONI's signing model has no delegated/pre-authorized debit
  mechanism**, which is why "scheduled transfer jobs" for savings
  (section 5's Phase 4 bullet) can only ever mean "the backend decides
  when a contribution is *due*," never "the backend executes it
  unattended." Every transfer — savings contribution, loan repayment,
  agent cash-out — is signed by the paying party's own on-device key, so
  `SavingsSchedulerService`'s hourly cron only flips a contribution to
  `DUE`; a human still has to open the app and sign it. This isn't a
  shortcut we took — it's a real constraint of an architecture where key
  custody never leaves the user's device, and it's worth stating
  explicitly so nobody "fixes" the scheduler to attempt silent execution
  later.
- **Loan disbursement is the one case in this entire app where PayFlex
  signs a transfer itself**, because PayFlex's own money is moving under
  PayFlex's own authority with no borrower action required. That needs a
  server-held signing key — `src/treasury/treasury.service.ts` holds it
  from a plain `.env` var in this sandbox build, which is explicitly
  flagged there as unacceptable for production (needs a real KMS/HSM).
  Provisioning the treasury account hit the same "config eagerly
  validated in a constructor" trap once already fixed in this codebase:
  `TreasuryService` originally threw at app-boot if its env vars weren't
  set, which would have made it impossible to ever run
  `provision:treasury` in the first place (it boots the same `AppModule`).
  Fixed by validating lazily, on first real use, instead.
- **Credit scoring can only ever be as good as the transaction history
  available**, and this sandbox's wallets are permanently at zero balance
  (see Phase 3's findings — there's no way to fund a test wallet here),
  so every real transaction-history signal `SimpleCreditScoringStrategy`
  looks at is always empty in this environment. `scripts/sandbox-
  lifecycle-phase4.ts` demonstrates both branches honestly: a fresh
  account is correctly rejected (score 0), and to also exercise the
  approval/disbursement path the script deliberately back-dates a test
  user's `createdAt` by 90 days (clearly commented as test-only) so the
  account-age component alone clears the threshold. A real deployment's
  scores will only become meaningful once real transaction volume exists
  to score against — that's inherent to the approach the brief asks for
  (score off transaction history), not a defect in this implementation.

## Verifying Phase 5 against the live sandbox

```bash
npm run sandbox:phase5        # split-bill and send-via-link/escrow
```

`scripts/sandbox-lifecycle-phase5.ts` creates a split bill between two
contributors (resolved by PayTag), signs both shares, and confirms the
bill flips to `COMPLETED`; then exercises send-via-link both ways — a
known recipient (degrades to a normal signed transfer) and an unknown one
(escrows into PayFlex's treasury, previews the claim, onboards a fresh
recipient with a wallet, and claims it — **with the treasury signing the
release server-side**, same pattern as loan disbursement). Run against
the live sandbox and passes end-to-end.

CAD/EUR/MXN and the error/retry/offline polish were **not** given the
same live-verification depth as the rest of this build — deliberately,
matching the brief's own reduced ambition for these ("stubs... not
UI-polished"). See findings below for what was and wasn't checked.

### Phase 5 findings

- **Split-bill and send-via-link needed no new BMONI endpoints** — both
  are pure orchestration on top of the Phase 3 transfer primitive
  (`SplitBillService`/`LinksService`), consistent with the build brief's
  own framing of them as PayFlex-built, no-BMONI-equivalent features.
- **`HmacTokenService` was extracted from `QrPayService`** once split-bill
  QR codes and claim-link tokens needed the exact same short-lived,
  HMAC-signed, expiry-checked opaque-token mechanics — see
  `src/common/hmac-token.service.ts`. `QR_SIGNING_SECRET` now signs every
  app-layer token in this build (QR Pay, split-bill QR, claim links), not
  just QR Pay ones; nothing to rotate or reconfigure, just a naming note.
- **Send-via-link's escrow reuses the Phase 4 treasury account** rather
  than standing up a second PayFlex-controlled BMONI persona — it's the
  same real-world entity (PayFlex's own custodial wallet) either way, and
  splitting it into two accounts would only add operational surface
  (two keys to protect, two balances to reconcile) with no corresponding
  benefit. `TreasuryService.getWalletId`/`getAppUserId`/`signDigest` are
  shared unchanged between `LoansService` and `LinksService`.
- **A claimant needs a wallet in the escrowed currency before they can
  claim** — confirmed live back in Phase 3 findings (BMONI: "the
  recipient must hold a wallet in this currency") and re-confirmed here:
  `scripts/sandbox-lifecycle-phase5.ts`'s recipient is provisioned with an
  NGN wallet *before* calling `claim()`. This maps directly onto the
  brief's own instruction to "prompt the recipient to onboard before
  releasing funds" — it's not just good UX advice, `claim()` will fail
  against BMONI without it.
- **CAD/EUR/MXN request bodies are non-empty and rail-specific** — a
  quick live probe (not full verification) found `start-canada` needs
  `{ cadWalletAddress, cadWalletIndex }`, `start-monerium` needs
  `{ eurWalletAddress, eurWalletIndex }` (both mirroring start-nigeria's
  shape), and `latam/mx/kyc/activate` needs LATAM-specific compound
  surname fields (`paternalLastName`, `maternalLastName`, ...) rather
  than the usual firstName/lastName. `BmoniClientService`'s stub methods
  now require these bodies instead of silently sending nothing (which
  would always 400) — but `OnboardingService` doesn't yet resolve
  wallet addresses/indices from local records the way NGN does, matching
  the brief's "structurally wired but not UI-polished" ask. Finish
  properly (local wallet resolution, a real Flutter flow, live
  verification through KYC/activation) if/when a phase actually targets
  one of these rails.
- **Error handling was consolidated into one `GlobalExceptionFilter`**
  (`src/common/global-exception.filter.ts`), replacing the narrower
  `BmoniExceptionFilter` from Phase 2. It's one `@Catch()` handling four
  cases explicitly (`BmoniApiError`, `BmoniNetworkError` → 502,
  `HttpException` pass-through, generic `Error` → opaque 500) rather than
  registering several `@Catch(SpecificType)` filters and relying on
  Nest's filter-precedence rules to sort them out correctly.
- **Flutter-side retry/offline handling** (`app/lib/services/retry.dart`)
  only retries transport-level failures (`SocketException`,
  `TimeoutException`, `HttpException` from `dart:io`) — never a real
  ApiException from the backend, since retrying a 400/404 changes
  nothing. Wired into the QR-scan-to-pay flow (the brief's explicit
  example) and the wallet home's initial load; not swept across every
  other screen's network calls — that would be straightforward
  copy-paste from here but wasn't judged worth the diff size this pass.

## Testing

```bash
npm test                      # unit tests (no network)
npm run sandbox:lifecycle     # Phase 1: user + owner wallet + smart wallet
npm run sandbox:phase2        # Phase 2: full NGN KYC wizard + onboarding + wallet home
npm run sandbox:kyc-mismatch  # Phase 2: the deliberate BVN/name-mismatch check
npm run sandbox:phase3        # Phase 3: transfers, QR Pay, PayTag
npm run sandbox:phase4        # Phase 4: savings, loans + disbursement, agent mode
npm run sandbox:phase5        # Phase 5: split-bill, send-via-link/escrow
```
