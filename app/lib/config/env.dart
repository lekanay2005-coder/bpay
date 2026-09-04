/// Base URL of the PayFlex orchestration backend (NestJS) — NOT BMONI's
/// API. The app never talks to BMONI directly; every call goes through
/// our own backend, which owns the single BmoniClient. See
/// backend/src/bmoni/bmoni-client.service.ts.
///
/// Override at build/run time with:
///   flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:3000
/// (10.0.2.2 is the Android emulator's alias for the host machine's
/// localhost; use http://localhost:3000 for iOS simulator.)
class Env {
  static const backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
}
