import 'package:flutter/material.dart';
import '../models/transfer.dart';
import '../widgets/pin_prompt.dart';
import 'api_client.dart';
import 'wallet_service.dart';

/// Shared by every transfer entry point (direct send, QR Pay) once a
/// proposal exists: prompt for PIN, fetch the sign payload (already
/// retries past BMONI's async-not-ready-yet window — see ApiClient),
/// sign `signingPayloadHash` as a raw digest, submit. Returns the updated
/// Proposal, or null if the user cancelled at the PIN prompt.
Future<Proposal?> signAndSubmitTransfer(
  BuildContext context,
  ApiClient api,
  String appUserId,
  String proposalId,
) async {
  final pin = await promptForPin(context);
  if (pin == null || pin.isEmpty) return null;

  final signPayload = await api.getTransferSignPayload(appUserId, proposalId);
  final signature = await WalletService.signDigest(signPayload.signingPayloadHash, pin);
  return api.signTransfer(appUserId, proposalId, signature);
}
