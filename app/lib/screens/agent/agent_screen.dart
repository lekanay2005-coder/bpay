import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/microfinance.dart';
import '../../models/transfer.dart';
import '../../services/api_client.dart';
import '../../services/transfer_flow.dart';
import '../../theme/payflex_tokens.dart';
import '../../utils/format.dart';
import '../../theme/payflex_theme.dart';
import '../../utils/money.dart';
import '../../widgets/pf_balance_card.dart';
import '../../widgets/pf_buttons.dart';
import '../../widgets/pf_flow.dart';
import '../../widgets/pf_motion.dart';
import '../../widgets/pf_states.dart';
import '../transfer/send_money_screen.dart' show humanTransferStatus, transferTone;

/// Agent cash-in/cash-out (build brief §3/5 — no BMONI agent primitive).
/// Mechanically both are ordinary TransferService transfers — cash-in has
/// the agent as sender (agent received physical cash, sends digital
/// funds), cash-out has the customer as sender (customer sends digital
/// funds, agent hands over physical cash) — so whichever side of the
/// screen is "this device's user" is who signs.
class AgentScreen extends StatefulWidget {
  final AppUser user;
  const AgentScreen({super.key, required this.user});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final _api = ApiClient();
  bool _isAgent = false;
  List<AgentTransaction> _ledger = [];
  bool _loading = true;

  final _cashInRecipientController = TextEditingController();
  final _cashInAmountController = TextEditingController();
  final _cashOutAgentController = TextEditingController();
  final _cashOutAmountController = TextEditingController();
  String _currency = 'NGN';
  String? _error;

  @override
  void dispose() {
    _cashInRecipientController.dispose();
    _cashInAmountController.dispose();
    _cashOutAgentController.dispose();
    _cashOutAmountController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _ledger = await _api.listAgentTransactions(widget.user.id);
    } catch (_) {
      // Non-agents will 404/empty here — fine, just means no ledger yet.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleAgent(bool value) async {
    try {
      await _api.setAgentStatus(widget.user.id, value);
      setState(() => _isAgent = value);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _cashIn() async {
    setState(() => _error = null);
    try {
      final proposal = await _api.agentCashIn(
        widget.user.id,
        toPayTag: _cashInRecipientController.text,
        amount: _cashInAmountController.text,
        currency: _currency,
      );
      if (!mounted) return;
      final signed = await signAndSubmitTransfer(context, _api, widget.user.id, proposal.id);
      if (signed == null) return;
      await _celebrate(
        signed,
        headline: 'Cash-in submitted',
        caption: 'Customer hands you cash · digital funds sent to @${_cashInRecipientController.text}',
      );
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _cashOut() async {
    setState(() => _error = null);
    try {
      final proposal = await _api.agentCashOut(
        widget.user.id,
        agentPayTag: _cashOutAgentController.text,
        amount: _cashOutAmountController.text,
        currency: _currency,
      );
      if (!mounted) return;
      final signed = await signAndSubmitTransfer(context, _api, widget.user.id, proposal.id);
      if (signed == null) return;
      await _celebrate(
        signed,
        headline: 'Cash-out submitted',
        caption: 'You hand cash to @${_cashOutAgentController.text} · digital funds moved',
      );
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _celebrate(Proposal signed, {required String headline, required String caption}) {
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
        methodLabel: 'Agent network',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: PayFlexTheme.light,
      child: Scaffold(
        backgroundColor: PfColors.offWhite,
        appBar: AppBar(
          title: const Text('Agent mode'),
          backgroundColor: PfColors.offWhite,
        ),
        body: _loading
            ? const Center(child: PfBrandedLoader(size: 52))
            : ListView(
                padding: const EdgeInsets.fromLTRB(PfSpace.xl, 8, PfSpace.xl, 48),
                children: [
                  if (_error != null) ...[
                    PfInlineError(message: _error!),
                    const SizedBox(height: 12),
                  ],
                  PfPanel(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'I am a PayFlex agent',
                        style: TextStyle(
                          color: PfColors.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Cash-in customers\u2019 money and cash them out — each '
                        'direction is a signed transfer.',
                        style: TextStyle(color: PfColors.inkMuted, fontSize: 12.5, height: 1.4),
                      ),
                      value: _isAgent,
                      onChanged: _toggleAgent,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
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
                  const SizedBox(height: 18),
                  _cashPanel(
                    icon: Icons.south_west_rounded,
                    title: 'Cash-in',
                    caption: 'Customer gives you cash — you send digital funds.',
                    tagController: _cashInRecipientController,
                    amountController: _cashInAmountController,
                    tagLabel: 'Customer @PayTag',
                    actionLabel: 'Confirm cash-in',
                    onAction: _cashIn,
                  ),
                  const SizedBox(height: 16),
                  _cashPanel(
                    icon: Icons.north_east_rounded,
                    title: 'Cash-out',
                    caption: 'Customer sends digital funds — you hand over cash.',
                    tagController: _cashOutAgentController,
                    amountController: _cashOutAmountController,
                    tagLabel: 'Agent @PayTag',
                    actionLabel: 'Confirm cash-out',
                    onAction: _cashOut,
                  ),
                  const SizedBox(height: 26),
                  const PfSectionHeader(title: 'Your ledger'),
                  const SizedBox(height: 10),
                  if (_ledger.isEmpty)
                    const PfEmptyState(
                      compact: true,
                      icon: Icons.receipt_long_outlined,
                      title: 'No agent transactions yet',
                      message: 'Cash-ins and cash-outs you complete land here.',
                    )
                  else
                    ..._ledger.map((t) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: PfColors.surface,
                            borderRadius: BorderRadius.circular(PfRadius.md),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: t.type == 'CASH_IN'
                                      ? PfColors.successWash
                                      : PfColors.offWhite,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  t.type == 'CASH_IN'
                                      ? Icons.south_west_rounded
                                      : Icons.north_east_rounded,
                                  size: 16,
                                  color: t.type == 'CASH_IN'
                                      ? PfColors.success
                                      : PfColors.inkMuted,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.type == 'CASH_IN' ? 'Cash-in' : 'Cash-out',
                                      style: const TextStyle(
                                        color: PfColors.ink,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${t.status.toLowerCase()} · ${formatTimestamp(t.createdAt)}',
                                      style: const TextStyle(
                                        color: PfColors.inkFaint,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formatMoney(t.amount, t.currency),
                                style: TextStyle(
                                  color: t.type == 'CASH_IN' ? PfColors.success : PfColors.ink,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
      ),
    );
  }

  Widget _cashPanel({
    required IconData icon,
    required String title,
    required String caption,
    required TextEditingController tagController,
    required TextEditingController amountController,
    required String tagLabel,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return PfPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: PfColors.royalBlue),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: PfColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: const TextStyle(color: PfColors.inkMuted, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: tagController,
            decoration: InputDecoration(labelText: tagLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountController,
            decoration: const InputDecoration(labelText: 'Amount'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 14),
          PfPrimaryButton(label: actionLabel, onPressed: onAction),
        ],
      ),
    );
  }
}
