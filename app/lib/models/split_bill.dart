/// Mirrors backend/prisma/schema.prisma's SplitBill/SplitBillContributor
/// (build brief section 4.3 — orchestration only, no BMONI equivalent).
class SplitBillContributor {
  final String id;
  final String appUserId;
  final String shareAmount;
  final String status;

  SplitBillContributor({
    required this.id,
    required this.appUserId,
    required this.shareAmount,
    required this.status,
  });

  factory SplitBillContributor.fromJson(Map<String, dynamic> json) => SplitBillContributor(
        id: json['id'] as String,
        appUserId: json['appUserId'] as String,
        shareAmount: json['shareAmount'] as String,
        status: json['status'] as String,
      );
}

class SplitBill {
  final String id;
  final String description;
  final String currency;
  final String totalAmount;
  final String status;
  final List<SplitBillContributor> contributors;

  SplitBill({
    required this.id,
    required this.description,
    required this.currency,
    required this.totalAmount,
    required this.status,
    required this.contributors,
  });

  factory SplitBill.fromJson(Map<String, dynamic> json) => SplitBill(
        id: json['id'] as String,
        description: json['description'] as String,
        currency: json['currency'] as String,
        totalAmount: json['totalAmount'] as String,
        status: json['status'] as String,
        contributors: (json['contributors'] as List? ?? [])
            .map((e) => SplitBillContributor.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
