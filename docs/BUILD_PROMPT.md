# PayFlex — Build Prompt for Claude Code

> Saved verbatim from the original project brief on 2026-09-04. This is the
> source of truth for architecture decisions in this repo. If behavior here
> and this document ever disagree, treat this document as authoritative and
> flag the discrepancy rather than silently picking one.

## 0. What you're building

**PayFlex** is a mobile-first microfinance app (in the spirit of Moniepoint / OPay) built on top of the **BMONI Embedded API** for identity, wallets, KYC, and money movement. The app adds a savings/micro-loan layer, an agent cash-in/cash-out network, and a fast, futuristic QR-first transfer experience on top of BMONI's smart-wallet rails.

**Important architectural truth, do not deviate from this:** BMONI Embedded is **not** built on Stellar. It uses EVM-based managed smart wallets (owner-proof challenge + EIP-191 signing) with regional stablecoins (`USDB` for USD, `CNGN` for NGN, `CADC` for CAD, `EURe` for EUR, `MEXe` for MXN). Do not attempt to route payments through Stellar, Horizon, or Soroban anywhere in this build — there is no integration point for that in BMONI's API. If a future task asks to add a Stellar-based rail, treat it as a fully separate parallel system (its own ledger, its own KYC bridge) and do not merge it into the BMONI wallet model. For this build: **BMONI is the only settlement rail.**

Build in phases. Do not try to build everything in one pass — scaffold the project, implement Phase 1 fully and get it working end-to-end against the sandbox before moving to Phase 2, etc. After each phase, run the app/tests and confirm it works before continuing.

---

## 1. Tech stack (fixed — do not substitute)

- **Mobile app:** Flutter (Dart), targeting iOS + Android
- **Wallet SDK:** `bmoni_embedded_sdk` — handles on-device EVM keypair generation, secure storage, and EIP-191 message signing gated by a PIN. Never implement your own key generation or signing logic; always go through this SDK.
- **Backend orchestration service:** Node.js + NestJS + TypeScript
- **App database:** PostgreSQL (via Prisma or TypeORM — pick one and be consistent)
- **Cache/session:** Redis
- **Auth to BMONI:** every request carries header `x-api-key: <partner key>`

### Environment config
```
BMONI_BASE_URL_SANDBOX=https://embedded-dev.bmoni.com
BMONI_BASE_URL_PRODUCTION=https://embedded.bmoni.com
BMONI_API_KEY_SANDBOX=pk_a025cacbf33a_76fb864113f3540909de5b1da39cc146906e35b1c6d4d1e4
```
Use the sandbox key and sandbox base URL for all local development and testing. Never hardcode the production key (there isn't one yet — a real partner key must be requested from developers@bkey.me before production launch; leave a `.env.example` placeholder for it).

**Critical gotcha:** the base URL is origin-only. Do NOT append `/v1` to it — all BMONI path constants already start with `/v1/`. `https://embedded-dev.bmoni.com/v1` as a base will produce `/v1/v1/...` 404s. Build the base URL config with this comment inline so nobody "fixes" it later.

---

## 2. What BMONI actually provides (build against this, not assumptions)

### 2.1 Core lifecycle (do this in order, every time, for every user)
1. `POST /v1/users` → create the user, returns `bmoniUserId`. Persist this locally immediately (e.g. secure storage / shared_preferences equivalent) — never recreate a user on relaunch, it forks wallet history.
2. On-device: SDK generates or loads an EVM owner wallet → `userOwnerAddress`. Private key never leaves the device.
3. `POST /v1/users/{userId}/smart-wallets/owner-proof-challenges` with `{ currency, userOwnerAddress }` → returns an EIP-191 message + `challengeId`.
4. SDK signs that message with the PIN → `ownerProofSignature`.
5. `POST /v1/users/{userId}/smart-wallets/create-managed` with `{ currency, userOwnerAddress, ownerProofChallengeId, ownerProofSignature }` → returns the `SmartWallet`.
   - Note: smart-wallet endpoints take the **stablecoin** code, not the fiat code: `USDB`, `CNGN`, `CADC`, `EURe`, `GBPe`, `MEXe`. Fetch the live list from `GET /v1/smart-wallets/supported-currencies` rather than hardcoding.
6. `GET /v1/users/{userId}/onboarding/status` → if the target currency is already active, skip to wallet home. Otherwise run KYC.

### 2.2 KYC wizard — fixed call order, do not reorder
1. `GET /v1/users/{userId}/kyc/options`
2. `GET /v1/users/{userId}/kyc/occupations?search=`
3. `POST /v1/users/{userId}/kyc/documents/identification` (multipart: ID image + `type`, `documentNumber`, `issuingCountry`, optional `expirationDate`/`issueDate`)
4. `POST /v1/users/{userId}/kyc/documents/proof-of-address` (multipart)
5. `POST /v1/users/{userId}/kyc/documents/biometric` (multipart selfie — required for Global KYC path: USD/EUR/MXN; not required for CAD/NGN)
6. `PATCH /v1/users/{userId}/kyc` (personal + address + employment + compliance; for NGN include `bvn`)
7. `GET /v1/users/{userId}/kyc/readiness` (gate — must pass before activation)
8. `POST /v1/users/{userId}/kyc/activate` — pass `sumsubLevelName` (e.g. `id-and-liveness`) for USD/EUR; omit body entirely for CAD/NGN

Build this as a single `KycService` in the backend with one method per step, and a Flutter wizard UI that mirrors the same sequence — do not let the frontend skip ahead.

**Per-currency, not per-profile:** KYC data submitted once is reused, but activation is per rail. Adding a second currency wallet to an already-onboarded user requires calling `POST /kyc/activate` again before that currency's `start-*` call — the document wizard is not repeated.

### 2.3 Rail-specific onboarding (one call per currency)
| Currency | Endpoint |
|---|---|
| NGN | `POST /v1/users/{userId}/onboarding/start-nigeria` (body includes `bvn`, `ngnWalletAddress`, `ngnWalletIndex`) |
| USD | Gate on `GET /v1/users/{userId}/kyc/usd-readiness` first, then `POST /v1/users/{userId}/onboarding/start-usa` with `{ smartWalletId }` → returns `{ workflowId }`; poll `GET /v1/users/{userId}/vba/usd` until `status: active` |
| CAD | `POST /v1/users/{userId}/onboarding/start-canada` |
| EUR | `POST /v1/users/{userId}/onboarding/start-monerium` |
| MXN | `POST /v1/users/{userId}/latam/mx/kyc/activate` → then `GET /latam/mx/kyc/launch/agreements` (user signs) → poll `GET /latam/mx/kyc/status` until approved |

For this build, **prioritize NGN and USD** — those are the primary target markets for a microfinance product. Implement CAD/EUR/MXN as stubs that are structurally wired but not UI-polished, so they're easy to finish later.

### 2.4 Wallet home operations
| Action | Endpoint |
|---|---|
| List wallets | `GET /v1/users/{userId}/smart-wallets/account/wallets` |
| List balances | `GET /v1/users/{userId}/smart-wallets/account/balances` |
| Wallet detail | `GET /v1/users/{userId}/smart-wallets/{smartWalletId}` |
| Crypto top-up address | `POST /v1/users/{userId}/deposit/wallet` |
| NGN/EUR virtual accounts | `POST /v1/users/{userId}/vba/ngn`, `POST /v1/users/{userId}/vba/eu` |
| NGN bank withdrawal | `POST /bank-accounts/verify-nigerian-account` → `POST /bank-accounts/withdrawal-accounts/nigeria` → `POST /smart-wallets/{smartWalletId}/offramp/nigeria` |
| Bank payout (general) | `POST /v1/users/{userId}/payouts/validate-account` → `POST /v1/users/{userId}/payouts` → returns a `signatureRequest`; sign via SDK and submit via the proposal/signature flow |
| Swap/convert | `POST /v1/users/{userId}/exchange/convert` (get a rate first via `GET /exchange/rate/{from}/{to}`) |
| Send to another user | `POST /smart-wallets/{smartWalletId}/proposals` (type `TRANSFER`) → `POST /proposals/{proposalId}/reject` or approve → `GET /proposals/{proposalId}/sign-payload` → SDK signs → `POST /proposals/{proposalId}/sign` |
| Transaction history | `GET /v1/users/{userId}/transactions/{smartWalletId}` |

All money movement — including your "futuristic" transfer modes — must ultimately resolve to this proposal → sign-payload → sign flow. There is no shortcut endpoint; build a single `TransferService` wrapper around it and have every transfer mode (QR, PayTag, link, split-bill) call into that one wrapper with different ways of resolving the recipient/amount.

---

## 3. What BMONI does NOT provide — build these yourself

Be explicit in code comments and README that these are app-layer features with no BMONI equivalent:
- **Lending/loans and credit scoring** — no BMONI endpoint. Build your own `LoanService` using `GET /transactions/{smartWalletId}` history as scoring input. Keep the actual scoring model simple and pluggable (a `CreditScoringStrategy` interface) rather than hardcoding a formula — you'll want to iterate on it.
- **Savings products / interest-bearing goals** — build as an app-level ledger that periodically moves funds via the transfer flow above; do not assume any on-chain escrow or smart-contract feature exists in BMONI.
- **Bill payments (airtime, electricity, etc.)** — not in BMONI's API. Stub an `IBillPaymentProvider` interface so a real aggregator (e.g. VTPass, Baxi for Nigeria) can be plugged in later without touching the rest of the app.
- **Claimable payment links for non-users** — BMONI has no claimable-balance primitive. If you build "send via link" for someone without an account, hold the funds in an internal PayFlex-controlled escrow smart wallet and release via the normal transfer flow once the recipient completes onboarding. Document this clearly as a liability/compliance consideration in the README, don't just quietly implement it.
- **Username/PayTag directory** (`@handle` → `bmoniUserId`) — your own Postgres table + API, resolved client-side before constructing a transfer.

---

## 4. The transfer UX (the product's differentiator)

Build all of these as thin wrappers around the single `TransferService` proposal flow described in 2.4. Each mode's job is only to resolve "who, how much" and then hand off.

1. **QR Pay** — generate a short-lived signed QR payload `{ recipientBmoniUserId | payTag, amount, currency, expiresAt }`. Scanning opens a pre-filled confirm screen, then runs the proposal flow. Show a success animation once `sign` returns.
2. **PayTag transfers** — `@handle` resolved against your own directory table to a `bmoniUserId`, then normal transfer flow.
3. **Split-bill** — one QR encodes a total + list of contributors; each contributor scans and submits their own independent proposal for their share. Track completion in your own `split_bills` table; this is orchestration only, BMONI has no group-payment primitive.
4. **Send via link** — generate a claim link/deep link. If the recipient already has a `bmoniUserId`, it's a normal transfer. If not, route through the escrow pattern in section 3 and prompt the recipient to onboard before releasing funds.
5. **Transaction visualization** — a simple animated confirmation (not a fake "blockchain network map" — don't overstate what's happening on-chain; BMONI's smart wallets are real EVM contracts, so keep any visualization honest about that, e.g. show wallet-to-wallet movement, not a fictional multi-node network).

Do not build NFC or audio-chirp transfer in the first pass — flag them as Phase 4/future work in the README; they add native-platform complexity that isn't worth the risk in a first working build.

---

## 5. Build phases — implement and verify in this order

**Phase 1 — Foundation**
- NestJS backend scaffold with a `BmoniClient` service wrapping every endpoint in section 2 (typed request/response DTOs, error handling for BMONI's `400/401/403/500` shapes)
- Flutter app scaffold with `bmoni_embedded_sdk` wired in
- User creation → owner wallet → smart wallet creation, working end-to-end against sandbox
- Verify with the sandbox test personas in section 6 before moving on

**Phase 2 — KYC + onboarding**
- Full KYC wizard (NGN + USD only for this phase)
- Rail onboarding for NGN and USD
- Wallet home: balances, transaction history

**Phase 3 — Transfers**
- `TransferService` proposal/sign wrapper
- QR Pay end-to-end
- PayTag directory + transfers
- Deposits and NGN bank withdrawals

**Phase 4 — Microfinance layer**
- Savings goals (app-level ledger + scheduled transfer jobs)
- Loan application + simple pluggable credit scoring off transaction history
- Agent mode (cash-in/cash-out screens using existing deposit/withdrawal endpoints, tagged to an agent account)

**Phase 5 — Polish**
- Split-bill, send-via-link/escrow
- CAD/EUR/MXN stubs
- Error states, retry logic, offline handling for QR scan

After each phase: run the app against the sandbox, walk through the relevant flow manually or with an integration test, and fix anything broken before starting the next phase. Do not proceed to Phase 2 with a broken Phase 1.

---

## 6. Sandbox test data — use these exact values, nothing else will resolve

**Persona: Samson Jabo** (use this as your default test user)
- BVN: `22222222222`
- NIN: `18482561982` (note: this NIN actually resolves to "Guion Audi", not Samson Jabo — don't use it if you need a NIN test)
- Phone: `08000000001` → convert to E.164: `+2348000000001`
- firstName: `Samson`, lastName: `Jabo`

**Persona: Bunch Dillon** (alternate persona)
- BVN: `95888168924`
- NIN: `63184876213`
- Phone: `08000000000` → `+2348000000000`
- firstName: `Bunch`, lastName: `Dillon`
- Driver's licence uses the same number as the NIN (`63184876213`) but the persona's name order is reversed for that specific check: `Dillon` first, `Bunch` last.

**Critical rule — match the persona exactly:** a valid BVN/NIN number is not sufficient. Verification checks the number AND the submitted name. Create the test user with the persona's exact `firstName`/`lastName`/phone — do not use a placeholder name like "Test User" with a persona's BVN, it will fail and that failure is correct sandbox behavior, not a bug. Keep one persona per test user; don't mix Bunch Dillon's BVN with Samson Jabo's phone.

Use `GET /v1/users/{userId}/kyc/bvn-lookup/{bvn}` first when populating a profile — it's a fetch-only preview (writes nothing, doesn't require the name to already match) and is the cheapest way to confirm your API key/plumbing works before running anything that actually performs identity matching.

Write at least one automated test for the deliberate-mismatch case (valid persona BVN + wrong name) since it's the failure real users will hit most often in production and it's fully deterministic in sandbox.

---

## 7. Non-negotiable engineering rules

- Every BMONI call goes through the single `BmoniClient` service — no ad-hoc `fetch`/`axios` calls scattered through feature code.
- Never implement wallet key generation, storage, or signing outside `bmoni_embedded_sdk`.
- Persist `bmoniUserId` on first creation; treat "did we already create this user" as a check against local storage before ever calling `POST /v1/users` again.
- Treat KYC submit order and activation-per-currency rules as hard constraints, not suggestions — violating them returns validation errors from BMONI, not from your code, and will be confusing to debug later if skipped now.
- All monetary amounts: confirm the unit BMONI expects per endpoint (some are minor units as strings, e.g. payouts use USDB minor units) and write a single shared money-formatting utility rather than converting inline in multiple places.
- Add a webhook receiver (NestJS route) for BMONI's async events even if not all are used yet in Phase 1–3: `employee.linked`, `onboarding.completed`, `onboarding.failed`, `kyc.action_required`. Log and store them; wire up handling as features need them.
- Write a README section explicitly listing what's real BMONI functionality vs. what PayFlex built on top (section 3 of this doc) — future developers need to know where the API boundary actually is.

---

## 8. First message to send in Claude Code

Once this file is in the repo, kick off with:

> Read the full build prompt in this file. Scaffold the project per section 1 (NestJS backend + Flutter app), then implement Phase 1 from section 5 completely, using the sandbox credentials and test persona from section 6 to verify user creation and smart wallet provisioning actually work end-to-end before you tell me it's done.

---

## 9. UI/UX & Motion Design Brief (v2 — matched to logo, no glow)

> Saved verbatim from the product owner on 2026-09-04, alongside the approved
> logo asset (`f93df9c4-e917-4a0b-aa26-53f3423a837e.png`, bundled for the app
> at `app/assets/brand/payflex_logo.png`). **This version replaces the
> earlier design brief** — it is built directly off the approved logo
> (QR-corners + flowing arrow mark, blue-to-emerald gradient) and removes
> all glow/neon effects. Where earlier sections of this document and §9
> disagree on anything visual, §9 wins.

### 1. Design direction

**Feel:** premium private-bank meets modern fintech — closer to Wise, Revolut, or Cash App than to a typical microfinance app. Confident, quiet, uncluttered. The business should feel bigger and more trustworthy than it is, without lying about what it does.

**Not this:** default Material Design blue, bootstrap-looking buttons, cluttered dashboards with too many colored cards, comic/cartoon iconography, and — explicitly — **no glow, no neon bloom, no soft-glow drop shadows on icons/buttons/text anywhere in the app.** The logo's gradient is vivid but flat and clean, not glowing; the app must match that, not drift toward a "gamer app" or neon-cyberpunk look. Any shadow used must be a soft, low-opacity, close, realistic elevation shadow — never a colored glow radiating outward from an element.

#### Core visual identity (pulled directly from the logo)
- **Primary gradient:** deep royal blue (`#0B2FBE`-ish, matching the logo's top-left blue) transitioning to emerald/spring green (`#1FD65F`-ish, matching the logo's bottom-right green). Use this gradient sparingly and intentionally — the splash screen, the primary CTA button, the balance card background — not smeared across every surface.
- **Base background:** a deep navy (`#0A1330`-ish, sampled from the logo's dark QR-code background) for dark-mode key screens (wallet home, splash, onboarding). This is a flat dark navy, not black, and not glowing.
- **Light mode base:** off-white (`#F7F7F5`), same blue→green gradient reserved for accents and CTAs only.
- **Accent usage:** the blue→green gradient is the *only* strong color move in the app. Everything else — text, icons, dividers, secondary surfaces — stays white, off-white, or muted grey/navy. This restraint is what makes the gradient feel premium instead of loud.
- **Typography:** one confident geometric display face for balances/headers (Inter, General Sans, or Satoshi at heavier weights), clean readable body face. Large, generous type for money amounts — the balance number is the visual anchor of wallet home.
- **Iconography:** custom-drawn line icons in flat white or navy, consistent stroke weight, no mixed icon packs, no glow or neon outlines on icons.
- **Cards/surfaces:** rounded corners (match the logo's rounded-square container radius proportionally — pick one radius scale, e.g. 12/16/24px, and stick to it). Elevation via soft, tight, realistic shadow only — flat design, no glow, no glassmorphism blur-glow combo.

#### The signature motif (from the logo)
The logo's core shape — the flowing arrow/ribbon cutting through the QR corners — is the app's recurring visual signature. Reuse it deliberately:
- As a subtle, low-opacity watermark shape in the corner of the wallet home background (flat, not glowing).
- As the shape the loading indicator draws itself from (see motion section).
- As the "success" mark shape during transfer confirmation — the ribbon/arrow completing its path, not a generic checkmark.
- As a thin accent line on receipts and section headers.

Do not scatter QR-corner brackets or the arrow shape decoratively everywhere — use it in these specific, meaningful places so it stays a signature rather than becoming visual noise.

### 2. Motion & animation requirements

Motion communicates money moving with weight and confidence — never bouncy/cartoonish, never instant/jarring, and **never accompanied by glow/bloom effects** (no pulsing light auras, no neon trails). Aim for physically-plausible, restrained motion (200–400ms, ease-out curves), the way Apple Pay or Wise transitions feel — clean and flat, not gamer-app or sci-fi.

Build these as first-class, reusable animation components (Flutter: `Hero`, `AnimatedContainer`/`AnimatedSwitcher`, `Rive` or `Lottie` for the more complex sequences) — not one-off animations bolted onto individual screens.

**Required signature animations:**
1. **Balance reveal** — on wallet home load, the balance number counts up/settles into place (subtle, ~400ms, once per session).
2. **Transfer confirmation** — the single most important animation in the app. The logo's ribbon/arrow motif draws itself along its path and settles, in flat gradient color, no glow or particle burst. This is the emotional payoff moment — get it right before anything else.
3. **QR scan → confirm transition** — the scanner view morphs into the confirm-payment sheet via a shared-element/Hero transition on the QR frame, not a hard page cut.
4. **Card/screen transitions** — consistent shared-axis or fade-through transitions between major sections, no default platform slide-in used inconsistently.
5. **Loading states** — a custom branded loader built from the arrow/ribbon motif tracing itself in a loop, flat gradient stroke, no glow — never the default spinner.
6. **Split-bill progress** — a ring or bar filling in flat gradient color as each contributor's share lands, no glow pulse.

**Explicitly avoid:** glow/bloom/neon effects of any kind, excessive bounce/spring easing, confetti/emoji bursts, more than one attention-grabbing animation on screen at once, animations that block the user from proceeding (always allow skip/tap-through).

### 3. "Business touch" — details that read as trustworthy and grown-up

- **Empty states and errors are designed, not default.** Real copy plus a simple flat icon in the brand style — never a bare "No data" or an unstyled red error box.
- **Receipts feel official.** Clear amount hierarchy, reference number, timestamp, status badge, logo mark small and flat at the top — never a wall of raw JSON-looking fields, never glowing text.
- **Numbers are formatted with care.** Currency symbol/code, thousands separators, and consistent decimal handling app-wide via a single shared money-formatting utility.
- **Onboarding/KYC doesn't feel like paperwork.** Clear step progress ("Step 2 of 5"), one action per screen, encouraging micro-copy — this is the part of a microfinance app users trust least, so it needs the most design care.
- **Dark mode and light mode both fully designed**, not auto-inverted — dark-default for wallet home/splash, light-default for forms, per section 1.
- **A real settings/profile screen** with account tier, verification status badge, and support access clearly visible.

### 4. Implementation notes

- Set up a single `AppTheme`/design-tokens file (exact hex values sampled from the logo, spacing scale, radius scale, type scale, motion durations/curves) referenced everywhere — no inline hex codes or magic numbers in widget code. Flutter implementation: `app/lib/theme/payflex_tokens.dart` + `payflex_theme.dart`.
- Add a lint/review checklist item: **no `BoxShadow` with spread/blur used to fake a glow, no colored shadows, no `Container` decorations simulating neon.** If a shadow is used, it must be a small, low-opacity, neutral-dark elevation shadow only.
- Build a small internal component library first (`BalanceCard`, `PrimaryButton`, `TransferConfirmationAnimation`, `BrandedLoader`, `ReceiptView`) before wiring up full screens, so the look is consistent by construction rather than retrofitted later. Flutter implementation: `app/lib/widgets/` (`pf_balance_card.dart`, `pf_buttons.dart`, `pf_flow.dart`, `pf_motion.dart`, `pf_states.dart`, `pf_mark.dart`).
- If using Rive/Lottie for the signature animations, keep source files in `/design/animations` in the repo and document how to swap them.
- After each phase, check screens against §1–§3 here — specifically confirm no glow effects have crept in — before calling that phase done.
