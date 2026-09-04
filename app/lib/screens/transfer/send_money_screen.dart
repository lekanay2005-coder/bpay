import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/api_client.dart';
import '../../services/transfer_flow.dart';

enum _RecipientMode { payTag, bmoniUserId, address }

/// Direct transfer entry point (build brief section 4.2's PayTag mode,
/// plus a raw bmoniUserId/address fallback). QR Pay is a separate screen
/// that ultimately calls the same TransferService flow — see
/// qr_pay_screen.dart and ApiClient.createTransfer/payQr.
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
  String? _resultMessage;

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
      _resultMessage = null;
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
        setState(() => _error = 'Cancelled — proposal was created but not signed.');
        return;
      }
      setState(() {
        _resultMessage =
            'Sent. Proposal ${signed.id} status: ${signed.status} '
            '(${signed.currentSignatures}/${signed.requiredSignatures} signatures).';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send money')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            SegmentedButton<_RecipientMode>(
              segments: const [
                ButtonSegment(value: _RecipientMode.payTag, label: Text('PayTag')),
                ButtonSegment(value: _RecipientMode.bmoniUserId, label: Text('User ID')),
                ButtonSegment(value: _RecipientMode.address, label: Text('Address')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _recipientController,
              decoration: InputDecoration(
                labelText: switch (_mode) {
                  _RecipientMode.payTag => '@PayTag',
                  _RecipientMode.bmoniUserId => 'Recipient BMONI user ID',
                  _RecipientMode.address => 'Recipient wallet address (0x...)',
                },
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _currency,
              decoration: const InputDecoration(labelText: 'Currency'),
              items: const [
                DropdownMenuItem(value: 'NGN', child: Text('NGN')),
                DropdownMenuItem(value: 'USD', child: Text('USD')),
              ],
              onChanged: (v) => setState(() => _currency = v!),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_resultMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_resultMessage!, style: const TextStyle(color: Colors.green)),
              ),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}
