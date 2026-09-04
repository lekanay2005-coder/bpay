/// Mirrors backend/prisma/schema.prisma's Phase 4 models. See the schema
/// doc comments for why these are pure PayFlex ledger tables with no
/// BMONI equivalent, built on top of the TransferService proposal flow.

class SavingsGoal {
  final String id;
  final String name;
  final String currency;
  final String targetAmount;
  final String contributionAmount;
  final String frequency;
  final String status;
  final String totalContributed;

  SavingsGoal({
    required this.id,
    required this.name,
    required this.currency,
    required this.targetAmount,
    required this.contributionAmount,
    required this.frequency,
    required this.status,
    required this.totalContributed,
  });

  factory SavingsGoal.fromJson(Map<String, dynamic> json) => SavingsGoal(
        id: json['id'] as String,
        name: json['name'] as String,
        currency: json['currency'] as String,
        targetAmount: json['targetAmount'] as String,
        contributionAmount: json['contributionAmount'] as String,
        frequency: json['frequency'] as String,
        status: json['status'] as String,
        totalContributed: json['totalContributed'] as String,
      );
}

class SavingsContribution {
  final String id;
  final String amount;
  final String status;
  final SavingsGoal? goal;

  SavingsContribution({
    required this.id,
    required this.amount,
    required this.status,
    this.goal,
  });

  factory SavingsContribution.fromJson(Map<String, dynamic> json) => SavingsContribution(
        id: json['id'] as String,
        amount: json['amount'] as String,
        status: json['status'] as String,
        goal: json['savingsGoal'] != null
            ? SavingsGoal.fromJson(json['savingsGoal'] as Map<String, dynamic>)
            : null,
      );
}

class LoanApplication {
  final String id;
  final String requestedAmount;
  final String currency;
  final String status;
  final String? approvedAmount;
  final int? creditScore;
  final List<dynamic>? scoringReasoning;

  LoanApplication({
    required this.id,
    required this.requestedAmount,
    required this.currency,
    required this.status,
    this.approvedAmount,
    this.creditScore,
    this.scoringReasoning,
  });

  factory LoanApplication.fromJson(Map<String, dynamic> json) => LoanApplication(
        id: json['id'] as String,
        requestedAmount: json['requestedAmount'] as String,
        currency: json['currency'] as String,
        status: json['status'] as String,
        approvedAmount: json['approvedAmount'] as String?,
        creditScore: (json['creditScore'] as num?)?.toInt(),
        scoringReasoning: json['scoringReasoning'] as List<dynamic>?,
      );
}

class LoanRepayment {
  final String id;
  final String amount;
  final String status;
  final String dueAt;

  LoanRepayment({
    required this.id,
    required this.amount,
    required this.status,
    required this.dueAt,
  });

  factory LoanRepayment.fromJson(Map<String, dynamic> json) => LoanRepayment(
        id: json['id'] as String,
        amount: json['amount'] as String,
        status: json['status'] as String,
        dueAt: json['dueAt'] as String,
      );
}

class AgentTransaction {
  final String id;
  final String type;
  final String amount;
  final String currency;
  final String status;
  final String createdAt;

  AgentTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
  });

  factory AgentTransaction.fromJson(Map<String, dynamic> json) => AgentTransaction(
        id: json['id'] as String,
        type: json['type'] as String,
        amount: json['amount'] as String,
        currency: json['currency'] as String,
        status: json['status'] as String,
        createdAt: json['createdAt'] as String,
      );
}
