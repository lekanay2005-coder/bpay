/// Mirrors backend/src/bmoni/dto/wallet-home.dto.ts's Proposal/
/// ProposalSignPayloadResponse — see that file for how these were
/// confirmed against the live sandbox (notably: sign `signingPayloadHash`
/// raw, never the EIP-712 hash of `typedData`).
class Proposal {
  final String id;
  final String status;
  final String? nextAction;
  final String amount;
  final String currency;
  final String? toUserId;
  final String? toAddress;
  final int currentSignatures;
  final int requiredSignatures;
  final int currentApprovals;
  final int requiredApprovals;

  Proposal({
    required this.id,
    required this.status,
    required this.nextAction,
    required this.amount,
    required this.currency,
    required this.toUserId,
    required this.toAddress,
    required this.currentSignatures,
    required this.requiredSignatures,
    required this.currentApprovals,
    required this.requiredApprovals,
  });

  factory Proposal.fromJson(Map<String, dynamic> json) {
    final proposal = (json['proposal'] as Map<String, dynamic>?) ?? json;
    return Proposal(
      id: proposal['id'] as String,
      status: proposal['status'] as String,
      nextAction: proposal['nextAction'] as String?,
      amount: proposal['amount'] as String,
      currency: proposal['currency'] as String,
      toUserId: proposal['toUserId'] as String?,
      toAddress: proposal['toAddress'] as String?,
      currentSignatures: (proposal['currentSignatures'] as num?)?.toInt() ?? 0,
      requiredSignatures: (proposal['requiredSignatures'] as num?)?.toInt() ?? 1,
      currentApprovals: (proposal['currentApprovals'] as num?)?.toInt() ?? 0,
      requiredApprovals: (proposal['requiredApprovals'] as num?)?.toInt() ?? 1,
    );
  }
}

class ProposalSignPayload {
  final String signingPayloadHash;
  final String proposalStatus;

  ProposalSignPayload({required this.signingPayloadHash, required this.proposalStatus});

  factory ProposalSignPayload.fromJson(Map<String, dynamic> json) => ProposalSignPayload(
        signingPayloadHash: json['signingPayloadHash'] as String,
        proposalStatus: json['proposalStatus'] as String,
      );
}

class PayTagUser {
  final String appUserId;
  final String bmoniUserId;
  final String firstName;
  final String lastName;

  PayTagUser({
    required this.appUserId,
    required this.bmoniUserId,
    required this.firstName,
    required this.lastName,
  });

  factory PayTagUser.fromJson(Map<String, dynamic> json) => PayTagUser(
        appUserId: json['appUserId'] as String,
        bmoniUserId: json['bmoniUserId'] as String,
        firstName: json['firstName'] as String,
        lastName: json['lastName'] as String,
      );
}
