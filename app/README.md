# PayFlex mobile app (Flutter)

Phase 1 scope: create a PayFlex account, provision an on-device EVM owner
wallet via `bmoni_embedded_sdk`, and provision a managed smart wallet —
mirroring backend/scripts/sandbox-lifecycle.ts but through the real UI and
real on-device signing instead of a simulated signer.

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

```bash
flutter pub get

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

## Flow implemented in Phase 1

1. `CreateUserScreen` — collects firstName/lastName/email/phoneNumber (E.164),
   posts to the backend's `POST /users`.
2. `PinAndWalletScreen` — sets a 6-digit PIN (`BmoniEmbeddedSdk.setPin`),
   provisions an on-device owner wallet (`BmoniEmbeddedSdk.initWallet`),
   registers the address with the backend, lets the user pick a supported
   stablecoin, requests an owner-proof challenge, signs it on-device
   (`BmoniEmbeddedSdk.signMessage`), and submits the signature to create
   the managed smart wallet.
3. `WalletHomeScreen` — stub showing the provisioned wallet and onboarding
   status. Balances, transaction history, and transfers land in Phases 2-3.

## Explicitly deferred (see docs/BUILD_PROMPT.md section 4)

NFC and audio-chirp transfer are out of scope for the first working build —
flagged as future work, not attempted here.
