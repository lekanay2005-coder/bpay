/// Single shared money-formatting utility for the whole Flutter app —
/// mirrors the backend's money.util.ts role on this side of the wire.
///
/// Every amount in this codebase crosses the wire as a plain decimal
/// string (BMONI balances are decimal strings; proposals carry decimal
/// strings too), so all display formatting lives here: currency symbol,
/// thousands separators, and a consistent 2-decimal rule app-wide. Never
/// format an amount inline in a screen — it is exactly the kind of drift
/// the build brief's §7 rule exists to prevent.
library;

String _prefixFor(String currencyCode) {
  switch (currencyCode.toUpperCase()) {
    case 'NGN':
      return '\u20A6'; // ₦
    case 'USD':
      return '\$';
    case 'CAD':
      return 'CA\$';
    case 'EUR':
      return '\u20AC'; // €
    case 'MXN':
      return 'MX\$';
    case 'GBP':
      return '\u00A3'; // £
    default:
      return '$currencyCode '; // unknown code: show it as a prefix label
  }
}

String _groupThousands(String fixed) {
  final parts = fixed.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  return parts.length > 1 ? '$buf.${parts[1]}' : buf.toString();
}

/// Renders a decimal-string amount with symbol prefix, thousands
/// separators, and exactly two decimals: `₦12,500.00`, `$1,200.00`.
/// Non-numeric input degrades to a safe `—`, never an exception.
String formatMoney(String amount, String currencyCode) {
  final grouped = _grouped(amount);
  return grouped == null ? '—' : '${_prefixFor(currencyCode)}$grouped';
}

/// Same as [formatMoney] but without the symbol — used where the
/// currency code sits in a chip beside the number (balance card anchor).
String formatAmountOnly(String amount) => _grouped(amount) ?? '—';

String? _grouped(String amount) {
  final value = double.tryParse(amount.trim().replaceAll(',', ''));
  if (value == null || !value.isFinite) return null;
  return _groupThousands(value.toStringAsFixed(2));
}

/// Safe numeric parse for progress math (savings-goal fill ratio, split
/// progress). Returns 0 for anything unparseable — never throws.
double parseAmount(String amount) {
  final value = double.tryParse(amount.trim().replaceAll(',', ''));
  return (value == null || !value.isFinite) ? 0 : value;
}

/// Formats an already-parsed numeric value (used by animated count-ups,
/// which must re-format every frame). Same rules as [formatMoney].
String formatMoneyValue(double value, String currencyCode) {
  if (!value.isFinite) return '—';
  return '${_prefixFor(currencyCode)}${_groupThousands(value.toStringAsFixed(2))}';
}

/// Numeric-only variant for animated balances shown beside a currency
/// chip. Same grouping as [formatAmountOnly].
String formatValueOnly(double value) {
  if (!value.isFinite) return '—';
  return _groupThousands(value.toStringAsFixed(2));
}
