/// Tiny shared formatting helpers (timestamps, truncation) — see
/// money.dart for amounts, which live in their own file per the build
/// brief's single-money-utility rule.
library;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// ISO-8601 (or epoch-millis) → "12 Aug · 14:05". Falls back to the raw
/// string when the backend sends something unparseable rather than
/// crashing a list.
String formatTimestamp(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final local = parsed.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_months[local.month - 1]} · $hh:$mm';
}

/// Long ISO timestamp → "12 Aug 2026, 14:05" for receipt footers.
String formatTimestampLong(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final local = parsed.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_months[local.month - 1]} ${local.year}, $hh:$mm';
}

/// Short, human label for a transaction reference / id — first and last
/// four characters with an ellipsis for long ids.
String shortRef(String id, {int keep = 4}) {
  if (id.length <= keep * 2 + 1) return id;
  return '${id.substring(0, keep)}…${id.substring(id.length - keep)}';
}
