/// Mirrors backend/prisma/schema.prisma's ClaimableLink (build brief
/// section 4.4 / section 3 — send-via-link escrow). See the schema's doc
/// comment there before assuming this is "just a feature" — while a link
/// is ESCROWED, PayFlex is holding a real customer's funds.
class ClaimPreview {
  final String amount;
  final String currency;
  final String senderName;
  final String status;
  final String expiresAt;

  ClaimPreview({
    required this.amount,
    required this.currency,
    required this.senderName,
    required this.status,
    required this.expiresAt,
  });

  factory ClaimPreview.fromJson(Map<String, dynamic> json) => ClaimPreview(
        amount: json['amount'] as String,
        currency: json['currency'] as String,
        senderName: json['senderName'] as String,
        status: json['status'] as String,
        expiresAt: json['expiresAt'] as String,
      );
}
