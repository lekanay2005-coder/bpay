# PayFlex mobile app (Flutter)

Phase 1: create a PayFlex account, provision an on-device EVM owner
wallet via `bmoni_embedded_sdk`, and provision a managed smart wallet —
mirroring backend/scripts/sandbox-lifecycle.ts but through the real UI and
real on-device signing instead of a simulated signer.

Phase 2: a KYC wizard mirroring the backend's fixed call order (options ->
occupations -> 3 documents -> profile PATCH -> readiness -> activate),
then NGN or USD rail onboarding depending on which currency the Phase 1
wallet was created for, then a wallet home screen with real balances and
transaction history.

Phase 3: send money directly (by PayTag, BMONI user ID, or raw wallet
address), QR Pay (generate a QR to receive, or scan one to pay), and a
PayTag registration screen — all resolving to the same sign/submit flow
via `lib/services/transfer_flow.dart`.

Phase 4: savings goals (create a goal, pay a due contribution), loans
(apply, see the credit-scoring result, pay a repayment), and agent mode
(toggle agent status, cash-in/cash-out, view your ledger) — all built on
the same transfer sign/submit flow. Loan disbursement is the one
exception: it's signed by PayFlex's own treasury account server-side, so
there's nothing to sign on the borrower's side for that particular step.

> **Not run in this environment.** The sandbox this was built in has no
> Flutter/Dart SDK installed, so this code has not been through
> `flutter pub get` / `flutter analyze` / `flutter run`. It was written and
> reviewed against the *actual* `bmoni_embedded_sdk` v0.0.2 API (downloaded
> and inspected from pub.dev — not guessed from the package name), and the
> backend it talks to has been fully verified end-to-end against the live
> BMONI sandbox (see ../backend/README.md). Before trusting this as done,
> run it on a real Flutter toolchain and walk through the flow on a
> device/emulator.

## Run

This repo currently holds only the Dart application code (`lib/` +
`pubspec.yaml`) — there is no `flutter create` in this environment, so the
`android/`/`ios/` platform folders don't exist yet. One-time setup on a
machine with the Flutter SDK installed:

```bash
flutter create --org com.payflex --project-name payflex .   # adds android/ios/ without touching lib/ or pubspec.yaml
flutter pub get

# Camera permission is required for the Phase 2 KYC capture screens
# (image_picker) AND Phase 3's QR scanner (mobile_scanner reuses the same
# permission) — add to android/app/src/main/AndroidManifest.xml:
#   <uses-permission android:name="android.permission.CAMERA" />
# and to ios/Runner/Info.plist:
#   <key>NSCameraUsageDescription</key>
#   <string>PayFlex needs your camera to verify your identity documents and scan payment QR codes.</string>

# Point at your locally running backend (see ../backend/README.md).
# 10.0.2.2 is the Android emulator's alias for the host's localhost;
# use localhost for iOS simulator, or your LAN IP for a physical device.
flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:3000
```

## Architecture

- The app **never** calls BMONI directly. Every network call goes through
  `lib/services/api_client.dart`, which talks only to the PayFlex backend.
  The backend owns the single `BmoniClientService` — see
  `../backend/src/bmoni/`.
- The app **never** generates keys or signs anything itself outside
  `lib/services/wallet_service.dart`, which is a thin wrapper around
  `bmoni_embedded_sdk`. The private key never leaves the device; only the
  public owner address and EIP-191 signatures are sent to the backend.
- `lib/services/local_user_store.dart` persists the local PayFlex user id
  (`SharedPreferences`) so the app skips straight to the wallet home screen
  on relaunch instead of re-running account creation.

## Flow implemented

1. `CreateUserScreen` — collects firstName/lastName/email/phoneNumber (E.164),
   posts to the backend's `POST /users`.
2. `PinAndWalletScreen` — sets a 6-digit PIN (`BmoniEmbeddedSdk.setPin`),
   provisions an on-device owner wallet (`BmoniEmbeddedSdk.initWallet`),
   registers the address with the backend, lets the user pick a supported
   stablecoin, requests an owner-proof challenge, signs it on-device
   (`BmoniEmbeddedSdk.signMessage`), and submits the signature to create
   the managed smart wallet.
3. `KycWizardScreen` (Phase 2) — personal info + address + employment form,
   camera capture + upload for the identification document, proof of
   address, and a selfie, a readiness check, then KYC activation. Two
   confirmed-live quirks this screen deliberately works around (see
   `../backend/README.md` "Phase 2 findings" for the full detail):
   the identification-document type enum shown in the picker is the one
   the *upload* endpoint accepts, not `GET kyc/options`' `identificationTypes`
   (they don't match); and `sumsubLevelName` is hardcoded to
   `"id-and-liveness"` with a comment explaining that BMONI's valid-value
   set for that field is dynamic, and a 400 will surface the current set
   verbatim if this ever stops working.
4. Rail onboarding, branching on the wallet's currency: a BVN field for
   NGN (`POST start-nigeria`, then polling `onboarding/status` until
   `anchorStatus` is `"active"` — confirmed live to take a few seconds,
   not instant), or a single button for USD (`POST start-usa`) — **the USD
   path cannot be completed from an emulator with a placeholder image**;
   BMONI runs a real Sumsub check and returns 422
   `BAD_SELFIE`/`DOCUMENT_PAGE_MISSING` against anything that isn't an
   actual photo, so this needs a real device camera to verify.
5. `WalletHomeScreen` — real balances, a transaction history screen per
   wallet, and (Phase 3) Send / QR Pay / PayTag entry points.
6. `SendMoneyScreen` (Phase 3) — pick a recipient by PayTag, BMONI user
   ID, or raw address, then `ApiClient.createTransfer` +
   `transfer_flow.dart`'s shared sign/submit helper.
7. `QrPayScreen` (Phase 3) — "My QR" generates and displays a short-lived
   token as a QR code (`qr_flutter`); "Scan to pay" (`mobile_scanner`)
   decodes one and runs the same sign/submit flow. **Critical and
   non-obvious**: the value actually signed is `signingPayloadHash` from
   the backend's sign-payload response, taken as a **raw digest** via
   `WalletService.signDigest` (→ `BmoniEmbeddedSdk.signTransactionHash`)
   — NOT an EIP-712 hash computed from the accompanying `typedData`
   object, even though BMONI hands back a full EIP-712 structure that
   looks like it wants one. This was confirmed against the live sandbox:
   signing the properly-computed EIP-712 digest was tested and BMONI
   rejected it ("signature does not match your registered owner
   address"); signing `signingPayloadHash` directly was accepted. See
   `../backend/README.md` "Phase 3 findings" for the full story — getting
   this backwards produces a signature that fails with a generic mismatch
   error and no hint the digest itself was wrong.
8. `PayTagScreen` (Phase 3) — register/view the current user's `@handle`.
9. `SavingsScreen` (Phase 4) — create a goal, see due contributions, pay
   one via the shared sign/submit helper. A contribution only ever
   appears here because the backend's hourly scheduler marked it due —
   nothing executes without the user opening the app and signing it (see
   `../backend/README.md` "Phase 4 findings" for why that's a real
   constraint of BMONI's signing model, not a corner we cut).
10. `LoansScreen` (Phase 4) — apply for a loan and see the credit-scoring
    result immediately (approved+disbursed, or rejected, with the score);
    pay a repayment via the same sign/submit helper. Disbursement itself
    needs no action here — PayFlex's treasury signs that server-side.
11. `AgentScreen` (Phase 4) — toggle agent status, cash-in (you're the
    sender — you received physical cash) or cash-out (the current user is
    the sender — they're handing digital funds to an agent for cash), and
    view the agent's own transaction ledger.

## Explicitly deferred (see docs/BUILD_PROMPT.md section 4)

NFC and audio-chirp transfer are out of scope for the first working build —
flagged as future work, not attempted here.
