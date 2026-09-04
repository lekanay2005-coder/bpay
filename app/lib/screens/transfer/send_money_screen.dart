import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/transfer.dart';
import '../../services/api_client.dart';
import '../../services/transfer_flow.dart';
import '../../theme/payflex_tokens.dart';
import '../../theme/payflex_theme.dart';
import '../../utils/format.dart';
import '../../utils/money.dart';
import '../../widgets/pf_balance_card.dart';
import '../../widgets/pf_buttons.dart';
import '../../widgets/pf_flow.dart';
import '../../widgets/pf_states.dart';

enum _RecipientMode { payTag, bmoniUserId, address }

/// Direct transfer entry point (build brief §4.2 PayTag mode, plus a raw
/// bmoniUserId/address fallback). QR Pay is a separate screen that
/// ultimately calls the same TransferService flow — see qr_pay_screen.dart
/// and ApiClient.createTransfer/payQr.
class SendMoneyScreen extends StatefulWidget {
  final AppUser user;
  const SendMoneyScreen({super.key, required this.user});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final _api = ApiClient();
  _RecipientMode _mode = _RecipientMode.payTag;
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  String _currency = 'NGN';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String get _recipientLabel => switch (_mode) {
        _RecipientMode.payTag => '@${_recipientController.text}',
        _RecipientMode.bmoniUserId => _recipientController.text,
        _RecipientMode.address => shortRef(_recipientController.text),
      };

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final proposal = await _api.createTransfer(
        widget.user.id,
        toPayTag: _mode == _RecipientMode.payTag ? _recipientController.text : null,
        toBmoniUserId: _mode == _RecipientMode.bmoniUserId ? _recipientController.text : null,
        toAddress: _mode == _RecipientMode.address ? _recipientController.text : null,
        amount: _amountController.text,
        currency: _currency,
      );

      if (!mounted) return;
      final signed = await signAndSubmitTransfer(context, _api, widget.user.id, proposal.id);
      if (signed == null) {
        setState(() => _error = 'Cancelled — no signature was submitted, so nothing moved.');
        return;
      }
      if (!mounted) return;
      final outcome = _outcomeFor(signed);
      await showPfConfirmation(context, outcome: outcome, receipt: outcome);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  PfFlowOutcome _outcomeFor(Proposal signed) {
    return PfFlowOutcome(
      headline: 'Sent',
      amount: signed.amount,
      currency: signed.currency,
      caption: 'to ${_recipientLabel}',
      reference: signed.id,
      statusLabel: humanTransferStatus(signed.status),
      statusTone: transferTone(signed.status),
      methodLabel: 'Direct transfer',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: PayFlexTheme.light,
      child: Scaffold(
        backgroundColor: PfColors.offWhite,
        appBar: AppBar(
          title: const Text('Send money'),
          backgroundColor: PfColors.offWhite,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  PfSpace.xl, PfSpace.lg, PfSpace.xl, 40,
                ),
                children: [
                  Text(
                    'Where is it going?',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Send to another PayFlex account by PayTag, user ID or '
                    'wallet address.',
                    style: const TextStyle(
                      color: PfColors.inkMuted,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SegmentedButton<_RecipientMode>(
                    segments: const [
                      ButtonSegment(value: _RecipientMode.payTag, label: Text('PayTag')),
                      ButtonSegment(value: _RecipientMode.bmoniUserId, label: Text('User ID')),
                      ButtonSegment(value: _RecipientMode.address, label: Text('Address')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() => _mode = s.first),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _recipientController,
                    decoration: InputDecoration(
                      labelText: switch (_mode) {
                        _RecipientMode.payTag => '@PayTag',
                        _RecipientMode.bmoniUserId => 'Recipient BMONI user ID',
                        _RecipientMode.address => 'Recipient wallet address (0x…)',
                      },
                      prefixIcon: const Icon(Icons.alternate_email_outlined, size: 20),
                    ),
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    switch (_mode) {
                      _RecipientMode.payTag => 'Their @handle — resolved against the PayFlex directory.',
                      _RecipientMode.bmoniUserId => 'The 36-char id from their profile.',
                      _RecipientMode.address => 'Their BMONI smart-wallet address.',
                    },
                    style: const TextStyle(color: PfColors.inkFaint, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Amount',
                    style: const TextStyle(
                      color: PfColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PfPanel(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: PfColors.surface,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            decoration: const InputDecoration(
                              hintText: '0.00',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: PfMoneyType.large.copyWith(
                              color: PfColors.ink,
                            ),
                          ),
                        ),
                        DropdownButton<String>(
                          value: _currency,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: 'NGN', child: Text('NGN')),
                            DropdownMenuItem(value: 'USD', child: Text('USD')),
                          ],
                          onChanged: (v) => setState(() => _currency = v!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      parseAmount(_amountController.text) > 0
                          ? 'You\u2019re sending ${formatMoney(_amountController.text, _currency)}'
                          : 'Sign the payment with your 6-digit PIN when it\u2019s ready.',
                      style: const TextStyle(
                        color: PfColors.inkMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (_error != null) ...[
                    PfInlineError(message: _error!),
                    const SizedBox(height: 14),
                  ],
                  PfPrimaryButton(
                    label: 'Review & send',
                    icon: Icons.north_east_rounded,
                    busy: _busy,
                    onPressed: _busy ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared status label used across every transfer payoff: raw backend
/// status ("PENDING_SETTLEMENT") → "Pending settlement".
String humanTransferStatus(String status) {
  final words = status.toLowerCase().split('_');
  if (words.isEmpty) return status;
  return words.map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}

PfTone transferTone(String status) {
  final s = status.toUpperCase();
  if (s.contains('FAIL') || s.contains('REJECT')) return PfTone.warn;
  if (s.contains('COMPLETE') || s.contains('SUCCESS') || s.contains('SETTLED') ||
      s.contains('EXECUT')) {
    return PfTone.success;
  }
  return PfTone.info;
}
