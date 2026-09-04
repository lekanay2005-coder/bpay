# PayFlex

A mobile-first microfinance app (in the spirit of Moniepoint / OPay) built
on top of the **BMONI Embedded API** for identity, wallets, KYC, and money
movement. PayFlex adds a savings/micro-loan layer, an agent cash-in/cash-out
network, and a QR-first transfer UX on top of BMONI's smart-wallet rails.

Full spec: [`docs/BUILD_PROMPT.md`](docs/BUILD_PROMPT.md). This README
tracks what's actually been built against that spec.

## Architecture, in one paragraph

BMONI Embedded is **not** built on Stellar — it's EVM-based managed smart
wallets (owner-proof challenge + EIP-191 signing) backed by regional
stablecoins (`USDB`, `CNGN`, `CADC`, `EURe`, `MEXe`). BMONI is the only
settlement rail in this build; nothing here talks to Stellar/Horizon/Soroban.
The Flutter app never calls BMONI directly and never touches key material
itself — it goes through the NestJS backend's single `BmoniClientService`
for every API call, and through `bmoni_embedded_sdk` for every key
generation / signing operation.

```
app/       Flutter mobile app (iOS + Android)
backend/   NestJS orchestration service — the only thing that calls BMONI
docs/      The original build brief (source of truth for architecture)
```

## Where the BMONI API boundary actually is

Future contributors need to know what's a real BMONI capability vs. what
PayFlex built on top, because the two are easy to conflate once it's all
behind one app UI.

**Real BMONI functionality** (backend/src/bmoni/ wraps all of it):
user creation, on-device owner-wallet proof + managed smart wallets, the
KYC document/readiness/activation wizard, per-currency rail onboarding
(NGN/USD/CAD/EUR/MXN), wallet balances/detail, deposits, virtual bank
accounts, NGN bank withdrawal, general bank payouts, currency exchange,
the proposal → sign-payload → sign transfer primitive, and transaction
history.

**PayFlex-built, no BMONI equivalent** (all app-layer, on top of the
transfer primitive above):
- **Lending/credit scoring** — BMONI has no loan product; scoring is a
  pluggable `CreditScoringStrategy` reading BMONI transaction history.
  **Done** (Phase 4), including automatic disbursement — see below for
  why that's the one place PayFlex signs a transfer itself.
- **Savings goals** — an app-level ledger with scheduled transfers; there
  is no on-chain escrow or smart-contract savings feature in BMONI.
  **Done** (Phase 4) — "scheduled" means the backend marks a contribution
  due, not that it executes unattended; see below for why.
- **Agent cash-in/cash-out** — BMONI has no agent-network concept; both
  directions are ordinary transfers with a separate reconciliation
  ledger. **Done** (Phase 4).
- **Bill payments** (airtime, electricity, ...) — stubbed behind an
  `IBillPaymentProvider` interface for a real aggregator later.
- **Claimable payment links for non-users** — BMONI has no
  claimable-balance primitive. Funds for a recipient without a BMONI
  account sit in a PayFlex-controlled escrow smart wallet until the
  recipient onboards. **This is a real liability/compliance surface**,
  not a shortcut — treat any escrow balance as PayFlex-held customer
  funds, not BMONI-custodied funds, when this ships (Phase 5).
- **PayTag directory** (`@handle` → `bmoniUserId`) — our own Postgres
  table, resolved before every transfer that uses it. **Done** (Phase 3).
- **QR Pay** — a short-lived, HMAC-signed QR payload naming a
  recipient/amount/currency; scanning hands off to the same transfer
  primitive below. **Done** (Phase 3).
- **Split-bill orchestration** — BMONI has no group-payment primitive;
  it's independent per-contributor proposals tracked in our own table.

## Build status

| Phase | Status |
|---|---|
| 1 — Foundation (user + owner wallet + managed smart wallet) | **Done, verified against the live sandbox** — see `backend/README.md` |
| 2 — KYC + onboarding (NGN, USD) | **Done for NGN, verified against the live sandbox; USD wired but blocked on a real device camera** — see below |
| 3 — Transfers (QR, PayTag, deposits, NGN withdrawal) | **Transfers/QR/PayTag done, verified against the live sandbox; deposits and NGN withdrawal wired but blocked on sandbox limitations** — see below |
| 4 — Microfinance layer (savings, loans, agent mode) | **Done, verified against the live sandbox — including a real server-side treasury signature for loan disbursement** — see below |
| 5 — Polish (split-bill, send-via-link/escrow, CAD/EUR/MXN stubs) | Not started |

Phase 1 was run end-to-end against `https://embedded-dev.bmoni.com` (not
mocked): user creation, on-device owner wallet, owner-proof challenge,
EIP-191 signing, and managed smart wallet creation all round-tripped
successfully, and the resulting rows are persisted correctly in Postgres.
Along the way we found and documented a handful of places where BMONI's
actual response shapes differ from a literal reading of the build brief —
see `backend/README.md` for the specifics (field names, response
envelopes, and the fact that the sandbox is a shared, multi-tenant
environment with global phone-number uniqueness).

Phase 2's NGN path was also run end-to-end against the live sandbox: the
full KYC wizard (options, occupations, all three documents, profile PATCH,
readiness, activation), `start-nigeria`, and wallet home (wallets,
balances, transaction history) all round-trip successfully. The USD path
is wired identically in the backend and Flutter wizard, but BMONI's USD
onboarding runs a real Sumsub identity check that rejects a synthetic test
image — completing it needs an actual photorealistic ID/selfie capture
from a real device, which this environment can't provide. Also worth
flagging: a deliberately mismatched name against a real BVN was **not**
rejected by `start-nigeria` in three separate live test runs, contradicting
the build brief's description of that check — see `backend/README.md`
"Phase 2 findings" before treating that endpoint as a compliance control.

Phase 3's transfer primitive (create proposal → sign-payload → sign),
QR Pay, and PayTag were all run end-to-end against the live sandbox: two
users provisioned, a PayTag registered and resolved, a direct
PayTag-addressed transfer signed, and a QR-Pay-generated transfer signed
by the scanning "payer." The single most important finding from this
phase: the value BMONI actually wants signed is a raw digest
(`signingPayloadHash`) it returns alongside a full EIP-712 `typedData`
structure — signing the *properly computed* EIP-712 hash of that
structure was tested against the live sandbox and **rejected**
("signature does not match your registered owner address"); signing
`signingPayloadHash` directly was accepted. Also found and fixed: several
proposal endpoint paths in the build brief don't exist at all (there is
no "approve" endpoint anywhere in BMONI's API — signing a proposal *is*
the approval), and BMONI's own OpenAPI spec (served at
`/docs/openapi.json` on the sandbox host, undocumented in the brief) is a
much better starting point than guessing but is itself not fully in sync
with live behavior. See `backend/README.md` "Phase 3 findings" for the
complete list. Deposits and NGN bank withdrawal are wired and typed
against confirmed request/response shapes but not verified end-to-end:
crypto deposit 502'd from BMONI's own upstream bridge provider on every
attempt, and NGN account verification needs a real NUBAN this sandbox has
no test value for.

Phase 4 (savings, loans, agent mode) needed no new BMONI endpoints — it's
all PayFlex's own logic on top of the Phase 3 transfer primitive — but
was run end-to-end against the live sandbox anyway: a savings goal
created and its first contribution signed; a loan application correctly
rejected for a fresh account (credit score 0) and, for a back-dated test
account, approved and **disbursed with PayFlex's own treasury account
signing the payout server-side** — the one place in this app where
PayFlex, not the end user, authorizes a transfer, because it's PayFlex's
own money moving under PayFlex's own authority. A key architectural
constraint worth stating plainly: BMONI's signing model has no delegated
or pre-authorized debit mechanism, so a "scheduled" savings contribution
can only ever be marked *due* by the backend — a human still has to open
the app and sign it, the same as any other transfer. See
`backend/README.md` "Phase 4 findings" for the details, including a
config-validation bug (treasury setup throwing at app-boot, which would
have made it impossible to ever provision the treasury) caught and fixed
during this phase.

The Flutter app is scaffolded and wired for all four phases, written
against the real `bmoni_embedded_sdk` v0.0.2 API (inspected from its
pub.dev package, not guessed) and the backend's confirmed-live HTTP
contract, but **has not been run** — this environment has no Flutter/Dart
SDK installed. See `app/README.md`.

## Quickstart

```bash
cd backend
npm install
cp .env.example .env
docker-compose up -d
npx prisma migrate dev
npm run start:dev            # backend on :3000
npm run sandbox:lifecycle    # re-verify Phase 1 against the live sandbox
npm run sandbox:phase2       # re-verify Phase 2 NGN KYC + onboarding
npm run sandbox:kyc-mismatch # the deliberate BVN/name-mismatch check
npm run sandbox:phase3       # re-verify Phase 3 transfers, QR Pay, PayTag
npm run provision:treasury   # one-time: create PayFlex's treasury BMONI account
npm run sandbox:phase4       # re-verify Phase 4 savings, loans, agent mode
```

```bash
cd app
flutter pub get
flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:3000
```

## Non-negotiable engineering rules (see docs/BUILD_PROMPT.md §7)

- Every BMONI call goes through `BmoniClientService` — no ad-hoc HTTP calls
  in feature code.
- No key generation, storage, or signing outside `bmoni_embedded_sdk`.
- `bmoniUserId` is persisted on first creation, both locally on-device
  (`SharedPreferences`) and in the backend's Postgres — a user is never
  recreated on relaunch.
- KYC submit order and per-currency activation are hard constraints, not
  suggestions (Phase 2).
- All monetary amounts go through one shared money-formatting utility
  (`backend/src/common/money.util.ts`) rather than inline conversions.
- A webhook receiver (`POST /webhooks/bmoni`) logs and persists every
  BMONI async event from Phase 1 onward, even before all event types are
  acted on.
