/// Mirrors backend/src/bmoni/dto/kyc.dto.ts — see that file for how these
/// shapes were confirmed against the live sandbox (several differ from a
/// literal reading of the build brief: personalInfo not personal,
/// streetLine1 not line1, alpha-3 country codes, etc).
class EstimatedMonthlyVolumeRange {
  final String label;
  final int value;
  EstimatedMonthlyVolumeRange({required this.label, required this.value});

  factory EstimatedMonthlyVolumeRange.fromJson(Map<String, dynamic> json) =>
      EstimatedMonthlyVolumeRange(label: json['label'] as String, value: json['value'] as int);
}

class KycOptions {
  final List<String> genders;
  final List<String> employmentStatuses;
  final List<String> fundsSources;
  final List<String> identificationTypes;
  final List<String> accountPurposes;
  final List<EstimatedMonthlyVolumeRange> estimatedMonthlyVolumeRanges;

  KycOptions({
    required this.genders,
    required this.employmentStatuses,
    required this.fundsSources,
    required this.identificationTypes,
    required this.accountPurposes,
    required this.estimatedMonthlyVolumeRanges,
  });

  factory KycOptions.fromJson(Map<String, dynamic> json) => KycOptions(
        genders: List<String>.from(json['genders'] as List),
        employmentStatuses: List<String>.from(json['employmentStatuses'] as List),
        fundsSources: List<String>.from(json['fundsSources'] as List),
        identificationTypes: List<String>.from(json['identificationTypes'] as List),
        accountPurposes: List<String>.from(json['accountPurposes'] as List),
        estimatedMonthlyVolumeRanges: (json['estimatedMonthlyVolumeRanges'] as List)
            .map((e) => EstimatedMonthlyVolumeRange.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class KycOccupation {
  final String id;
  final String displayName;
  final String category;

  KycOccupation({required this.id, required this.displayName, required this.category});

  factory KycOccupation.fromJson(Map<String, dynamic> json) => KycOccupation(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        category: json['category'] as String,
      );
}

class KycReadiness {
  final bool ready;
  final List<String> missing;

  KycReadiness({required this.ready, required this.missing});

  factory KycReadiness.fromJson(Map<String, dynamic> json) => KycReadiness(
        ready: json['ready'] as bool,
        missing: List<String>.from(json['missing'] as List? ?? []),
      );
}

class Balance {
  final String smartWalletId;
  final String currency;
  final String balance;

  Balance({required this.smartWalletId, required this.currency, required this.balance});

  factory Balance.fromJson(Map<String, dynamic> json) => Balance(
        smartWalletId: json['smartWalletId'] as String,
        currency: json['currency'] as String,
        balance: json['balance'] as String,
      );
}

class Transaction {
  final String id;
  final String amount;
  final String currency;
  final String direction;
  final String status;
  final String createdAt;

  Transaction({
    required this.id,
    required this.amount,
    required this.currency,
    required this.direction,
    required this.status,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        amount: json['amount'] as String,
        currency: json['currency'] as String,
        direction: json['direction'] as String,
        status: json['status'] as String,
        createdAt: json['createdAt'] as String,
      );
}
