import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/claimable_link.dart';
import '../../services/api_client.dart';
import '../../services/transfer_flow.dart';

/// Build brief section 4.4 / section 3 — send-via-link. If the recipient
/// already has a bmoniUserId this degrades to a normal transfer; if not,
/// funds route through PayFlex's own treasury as an escrow holder.
///
/// *** This is a real liability/compliance surface, not just a feature —
/// see backend/README.md and the ClaimableLink model's doc comment in
/// backend/prisma/schema.prisma before assuming "it's just like QR Pay."
/// While a link sits unclaimed, PayFlex is holding a real customer's
/// funds in its own custodial account. ***
class SendViaLinkScreen extends StatefulWidget {
  final AppUser user;
  const SendViaLinkScreen({super.key, required this.user});

  @override
  State<SendViaLinkScreen> createState() => _SendViaLinkScreenState();
}

class _SendViaLinkScreenState extends State<SendViaLinkScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send via link'),
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Send'), Tab(text: 'Claim')]),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_SendTab(user: widget.user), _ClaimTab(user: widget.user)],
      ),
    );
  }
}

class _SendTab extends StatefulWidget {
  final AppUser user;
  const _SendTab({required this.user});

  @override
  State<_SendTab> createState() => _SendTabState();
}

class _SendTabState extends State<_SendTab> {
  final _api = ApiClient();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  String _currency = 'NGN';
  bool _busy = false;
  String? _error;
  String? _claimToken;
  String? _status;

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
      _claimToken = null;
      _status = null;
    });
    try {
      final result = await _api.sendViaLink(
        widget.user.id,
        toBmoniUserId: _recipientController.text.isEmpty ? null : _recipientController.text,
        amount: _amountController.text,
        currency: _currency,
      );
      if (!mounted) return;
      if (result.type == 'DIRECT_TRANSFER') {
        final signed = await signAndSubmitTransfer(
          context,
          _api,
          widget.user.id,
          result.proposal!.id,
        );
        setState(() => _status = signed == null ? 'Cancelled.' : 'Sent directly — recipient already has an account.');
      } else {
        final signed = await signAndSubmitTransfer(
          context,
          _api,
          widget.user.id,
          result.escrowProposal!.id,
        );
        setState(() {
          _claimToken = result.claimToken;
          _status = signed == null
              ? 'Cancelled.'
              : 'Escrowed with PayFlex. Share the claim link below — the recipient '
                  'needs a PayFlex account with a matching-currency wallet to claim it.';
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                "If the recipient doesn't have a PayFlex account yet, PayFlex holds your "
                'funds in its own account until they sign up and claim it — not a personal '
                'escrow just for you.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _recipientController,
            decoration: const InputDecoration(
              labelText: 'Recipient BMONI user ID (leave blank if they have no account)',
            ),
          ),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(labelText: 'Amount'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          DropdownButtonFormField<String>(
            value: _currency,
            decoration: const InputDecoration(labelText: 'Currency'),
            items: const [
              DropdownMenuItem(value: 'NGN', child: Text('NGN')),
              DropdownMenuItem(value: 'USD', child: Text('USD')),
            ],
            onChanged: (v) => setState(() => _currency = v!),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _send, child: const Text('Send')),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_status != null)
            Padding(padding: const EdgeInsets.only(top: 16), child: Text(_status!)),
          if (_claimToken != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SelectableText('Claim token: $_claimToken'),
            ),
        ],
      ),
    );
  }
}

class _ClaimTab extends StatefulWidget {
  final AppUser user;
  const _ClaimTab({required this.user});

  @override
  State<_ClaimTab> createState() => _ClaimTabState();
}

class _ClaimTabState extends State<_ClaimTab> {
  final _api = ApiClient();
  final _tokenController = TextEditingController();
  ClaimPreview? _preview;
  bool _busy = false;
  String? _error;
  String? _status;

  Future<void> _loadPreview() async {
    setState(() {
      _busy = true;
      _error = null;
      _preview = null;
    });
    try {
      _preview = await _api.previewClaim(_tokenController.text);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claim() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.claimLink(widget.user.id, _tokenController.text);
      setState(() => _status = 'Claimed! Funds released from PayFlex escrow to your wallet.');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          TextField(
            controller: _tokenController,
            decoration: const InputDecoration(labelText: 'Claim token'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _busy ? null : _loadPreview, child: const Text('Preview')),
          if (_preview != null) ...[
            const SizedBox(height: 16),
            Text('${_preview!.amount} ${_preview!.currency} from ${_preview!.senderName}'),
            Text('Status: ${_preview!.status}'),
            const SizedBox(height: 8),
            if (_preview!.status == 'ESCROWED')
              FilledButton(onPressed: _busy ? null : _claim, child: const Text('Claim')),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_status!, style: const TextStyle(color: Colors.green)),
            ),
        ],
      ),
    );
  }
}
