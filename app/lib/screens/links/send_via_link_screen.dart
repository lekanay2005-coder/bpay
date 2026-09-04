import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/claimable_link.dart';
import '../../models/transfer.dart';
import '../../services/api_client.dart';
import '../../services/transfer_flow.dart';
import '../../theme/payflex_tokens.dart';
import '../../theme/payflex_theme.dart';
import '../../utils/money.dart';
import '../../widgets/pf_balance_card.dart';
import '../../widgets/pf_buttons.dart';
import '../../widgets/pf_flow.dart';
import '../../widgets/pf_states.dart';
import '../transfer/send_money_screen.dart' show humanTransferStatus, transferTone;

/// Build brief §4.4 / §3 — send-via-link. If the recipient already has a
/// bmoniUserId this degrades to a normal transfer; if not, funds route
/// through PayFlex's own treasury as an escrow holder.
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

class _SendViaLinkScreenState extends State<SendViaLinkScreen>
    with SingleTickerProviderStateMixin {
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
    return Theme(
      data: PayFlexTheme.light,
      child: Scaffold(
        backgroundColor: PfColors.offWhite,
        appBar: AppBar(
          title: const Text('Send via link'),
          backgroundColor: PfColors.offWhite,
          bottom: TabBar(
            indicatorColor: PfColors.royalBlue,
            labelColor: PfColors.ink,
            unselectedLabelColor: PfColors.inkMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: const [Tab(text: 'Send'), Tab(text: 'Claim')],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [_SendTab(user: widget.user), _ClaimTab(user: widget.user)],
        ),
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

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

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
        if (signed == null) {
          setState(() => _status = 'Cancelled — nothing was submitted.');
          return;
        }
        await _celebrateSend(
          signed,
          headline: 'Sent',
          caption: 'Sent directly — the recipient already has an account',
        );
      } else {
        final signed = await signAndSubmitTransfer(
          context,
          _api,
          widget.user.id,
          result.escrowProposal!.id,
        );
        if (signed == null) {
          setState(() => _status = 'Cancelled — nothing was submitted.');
          return;
        }
        setState(() => _claimToken = result.claimToken);
        await _celebrateSend(
          signed,
          headline: 'Escrowed',
          caption: 'Held safely by PayFlex until the recipient claims it',
          method: 'Payment link · escrow',
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _celebrateSend(
    Proposal signed, {
    required String headline,
    String? caption,
    String? method,
  }) {
    return showPfConfirmation(
      context,
      outcome: PfFlowOutcome(
        headline: headline,
        amount: signed.amount,
        currency: signed.currency,
        caption: caption,
        reference: signed.id,
        statusLabel: humanTransferStatus(signed.status),
        statusTone: transferTone(signed.status),
        methodLabel: method ?? 'Send via link',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(PfSpace.xl, PfSpace.xl, PfSpace.xl, 48),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: PfColors.navy,
                borderRadius: BorderRadius.circular(PfRadius.md),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: PfColors.onNavyMuted, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'If the recipient doesn\u2019t have a PayFlex account yet, '
                      'PayFlex holds your funds in its own account until they sign '
                      'up and claim them — not a personal escrow just for you.',
                      style: TextStyle(
                        color: PfColors.onNavyMuted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _recipientController,
              decoration: const InputDecoration(
                labelText: 'Recipient user ID',
                hintText: 'Leave blank if they have no account yet',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 116,
                  child: DropdownButtonFormField<String>(
                    value: _currency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: const [
                      DropdownMenuItem(value: 'NGN', child: Text('NGN')),
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                    ],
                    onChanged: (v) => setState(() => _currency = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              PfInlineError(message: _error!),
              const SizedBox(height: 14),
            ],
            if (_status != null) ...[
              PfPanel(
                padding: const EdgeInsets.all(12),
                color: PfColors.surfaceAlt,
                showShadow: false,
                child: Text(
                  _status!,
                  style: const TextStyle(color: PfColors.inkMuted, fontSize: 13, height: 1.45),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (_claimToken != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: PfColors.successWash,
                  borderRadius: BorderRadius.circular(PfRadius.sm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.link_rounded, color: PfColors.success, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Share this claim token',
                          style: TextStyle(
                            color: PfColors.success,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _claimToken!,
                      style: const TextStyle(
                        color: PfColors.ink,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            PfPrimaryButton(
              label: 'Send',
              icon: Icons.link_rounded,
              busy: _busy,
              onPressed: _busy ? null : _send,
            ),
          ],
        ),
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
  bool _claiming = false;
  String? _error;
  String? _status;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

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
      _claiming = true;
      _error = null;
    });
    try {
      await _api.claimLink(widget.user.id, _tokenController.text);
      if (!mounted) return;
      await showPfSimpleSuccess(
        context,
        title: 'Claimed',
        message: 'Funds released from PayFlex escrow to your wallet.',
        actionLabel: 'Done',
      );
      if (mounted) {
        setState(() {
          _preview = null;
          _status = null;
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(PfSpace.xl, PfSpace.xl, PfSpace.xl, 48),
          children: [
            Text(
              'Have a claim token?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Paste the token you received — preview what\u2019s waiting, then '
              'claim it into a matching-currency wallet.',
              style: TextStyle(color: PfColors.inkMuted, fontSize: 13.5, height: 1.45),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Claim token',
                prefixIcon: Icon(Icons.link_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            PfSecondaryButton(
              label: 'Preview',
              onPressed: _busy ? null : _loadPreview,
            ),
            if (p != null) ...[
              const SizedBox(height: 18),
              PfPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatMoney(p.amount, p.currency),
                            style: PfMoneyType.large.copyWith(color: PfColors.ink),
                          ),
                        ),
                        PfStatusChip(
                          label: p.status == 'ESCROWED' ? 'Waiting for you' : p.status,
                          tone: p.status == 'ESCROWED' ? PfTone.info : PfTone.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'from ${p.senderName}',
                      style: const TextStyle(color: PfColors.inkMuted, fontSize: 13.5),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'Expires',
                          style: TextStyle(color: PfColors.inkMuted, fontSize: 12.5),
                        ),
                        const Spacer(),
                        Text(
                          p.expiresAt,
                          style: const TextStyle(
                            color: PfColors.ink,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (p.status == 'ESCROWED')
                      PfPrimaryButton(
                        label: 'Claim into my wallet',
                        busy: _claiming,
                        onPressed: _claiming ? null : _claim,
                      )
                    else
                      const Text(
                        'This link has already been claimed or expired.',
                        style: TextStyle(color: PfColors.inkMuted, fontSize: 13),
                      ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              PfInlineError(message: _error!),
            ],
            if (_status != null) ...[
              const SizedBox(height: 14),
              PfInlineError(message: _status!, onRetry: null),
            ],
          ],
        ),
      ),
    );
  }
}
