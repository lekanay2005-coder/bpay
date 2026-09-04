import 'dart:async';
import 'dart:io';

/// Distinguishes "you're offline / BMONI-or-our-backend is unreachable"
/// from a real server-returned error (ApiException) — the two need very
/// different UI treatment (retry button vs. showing the actual message).
class OfflineException implements Exception {
  final String message;
  OfflineException([this.message = 'No internet connection. Check your connection and try again.']);

  @override
  String toString() => message;
}

/// Phase 5 polish (build brief: "retry logic ... for QR scan", generalized
/// to any network call worth retrying). Retries only transport-level
/// failures (no connection, DNS failure, timeout) — never a real HTTP
/// error response, since retrying a 400/404 changes nothing. After
/// [maxAttempts] transport failures, throws [OfflineException] instead of
/// the raw SocketException/TimeoutException so callers can show one
/// consistent "you're offline" message.
Future<T> withRetry<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  Duration delay = const Duration(seconds: 2),
}) async {
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await action();
    } on SocketException {
      if (attempt == maxAttempts) throw OfflineException();
    } on HttpException {
      if (attempt == maxAttempts) throw OfflineException();
    } on TimeoutException {
      if (attempt == maxAttempts) throw OfflineException();
    }
    await Future.delayed(delay);
  }
  throw OfflineException();
}
