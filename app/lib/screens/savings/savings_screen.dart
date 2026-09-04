import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/microfinance.dart';
import '../../models/transfer.dart';
import '../../services/api_client.dart';
import '../../services/transfer_flow.dart';
import '../../theme/payflex_tokens.dart';
import '../../theme/payflex_theme.dart';
import '../../utils/money.dart';
import '../../widgets/pf_balance_card.dart';
import '../../widgets/pf_buttons.dart';
import '../../widgets/pf_flow.dart';
import '../../widgets/pf_motion.dart';
import '../../widgets/pf_states.dart';
import '../transfer/send_money_screen.dart' show humanTransferStatus, transferTone;

/// App-level savings ledger (build brief §3 — no BMONI savings product
/// exists). See backend/prisma/schema.prisma's SavingsGoal doc comment
/// for why contributions are only ever "due," never auto-executed: every
/// transfer needs the user's live on-device signature, so the app is
/// where a due contribution actually gets paid.
class SavingsScreen extends StatefulWidget {
  final AppUser user;
  const SavingsScreen({super.key, required this.user});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  final _api = ApiClient();
  List<SavingsGoal> _goals = [];
  List<SavingsContribution> _due = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final goals = await _api.listSavingsGoals(widget.user.id);
      final due = await _api.listDueContributions(widget.user.id);
      setState(() {
        _goals = goals;
        _due = due;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _payContribution(String contributionId, SavingsContribution c) async {
    try {
      final proposal = await _api.payContribution(widget.user.id, contributionId);
      if (!mounted) return;
      final signed = await signAndSubmitTransfer(context, _api, widget.user.id, proposal.id);
      if (signed != null) {
        await showPfConfirmation(
          context,
          outcome: _outcome(signed, 'Contribution made',
              caption: 'Saved into ${c.goal?.name ?? 'your goal'}'),
          receipt: null,
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  PfFlowOutcome _outcome(Proposal signed, String headline, {String? caption}) =>
      PfFlowOutcome(
        headline: headline,
        amount: signed.amount,
        currency: signed.currency,
        caption: caption,
        reference: signed.id,
        statusLabel: humanTransferStatus(signed.status),
        statusTone: transferTone(signed.status),
        methodLabel: 'Savings',
      );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: PayFlexTheme.light,
      child: Scaffold(
        backgroundColor: PfColors.offWhite,
        appBar: AppBar(
          title: const Text('Savings goals'),
          backgroundColor: PfColors.offWhite,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'New goal',
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => CreateSavingsGoalScreen(user: widget.user)))
                  .then((_) => _load()),
            ),
          ],
        ),
        body: _loading && _goals.isEmpty
            ? const Center(child: PfBrandedLoader(size: 52))
            : RefreshIndicator(
                onRefresh: _load,
                color: PfColors.royalBlue,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(PfSpace.xl, 8, PfSpace.xl, 48),
                  children: [
                    if (_error != null) ...[
                      PfInlineError(message: _error!, onRetry: _load),
                      const SizedBox(height: 14),
                    ],
                    if (_due.isNotEmpty) ...[
                      const PfSectionHeader(title: 'Due now'),
                      const SizedBox(height: 10),
                      ..._due.map(
                        (c) => PfPanel(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: PfColors.successWash,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.schedule_rounded,
                                  color: PfColors.success,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.goal?.name ?? 'Contribution',
                                      style: const TextStyle(
                                        color: PfColors.ink,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatMoney(c.amount, c.goal?.currency ?? ''),
                                      style: const TextStyle(
                                        color: PfColors.inkMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PfGradientChip(
                                label: 'Pay now',
                                onPressed: () => _payContribution(c.id, c),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    const PfSectionHeader(title: 'Your goals'),
                    const SizedBox(height: 10),
                    if (_goals.isEmpty && _error == null)
                      PfEmptyState(
                        compact: true,
                        icon: Icons.savings_outlined,
                        title: 'No goals yet',
                        message: 'Set a target and PayFlex moves a little aside '
                            'on your schedule — each move signed by you.',
                        actionLabel: 'Create your first goal',
                        onAction: () => Navigator.of(context)
                            .push(MaterialPageRoute(
                              builder: (_) => CreateSavingsGoalScreen(user: widget.user),
                            ))
                            .then((_) => _load()),
                      ),
                    ..._goals.map((g) => _goalCard(g)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _goalCard(SavingsGoal g) {
    final saved = parseAmount(g.totalContributed);
    final target = parseAmount(g.targetAmount);
    final ratio = target > 0 ? (saved / target).clamp(0.0, 1.0).toDouble() : 0.0;
    return PfPanel(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  g.name,
                  style: const TextStyle(
                    color: PfColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PfStatusChip(
                label: g.status.toLowerCase() == 'active' ? 'On track' : g.status,
                tone: PfTone.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(g.totalContributed, g.currency),
                style: PfMoneyType.medium.copyWith(color: PfColors.ink),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'of ${formatMoney(g.targetAmount, g.currency)}',
                  style: const TextStyle(color: PfColors.inkMuted, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          PfProgressBar(value: ratio),
          const SizedBox(height: 8),
          Text(
            '${(ratio * 100).round()}% · ${g.frequency.toLowerCase()} contribution · '
            '${formatMoney(g.contributionAmount, g.currency)}',
            style: const TextStyle(color: PfColors.inkFaint, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class CreateSavingsGoalScreen extends StatefulWidget {
  final AppUser user;
  const CreateSavingsGoalScreen({super.key, required this.user});

  @override
  State<CreateSavingsGoalScreen> createState() => _CreateSavingsGoalScreenState();
}

class _CreateSavingsGoalScreenState extends State<CreateSavingsGoalScreen> {
  final _api = ApiClient();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _contributionController = TextEditingController();
  String _currency = 'NGN';
  String _frequency = 'WEEKLY';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _contributionController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.createSavingsGoal(
        widget.user.id,
        name: _nameController.text,
        currency: _currency,
        targetAmount: _targetController.text,
        contributionAmount: _contributionController.text,
        frequency: _frequency,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: PayFlexTheme.light,
      child: Scaffold(
        backgroundColor: PfColors.offWhite,
        appBar: AppBar(
          title: const Text('New savings goal'),
          backgroundColor: PfColors.offWhite,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(PfSpace.xl, PfSpace.lg, PfSpace.xl, 40),
                children: [
                  Text(
                    'What are you saving for?',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Name it, set a target, and PayFlex reminds you to put '
                    'money aside on your schedule.',
                    style: TextStyle(color: PfColors.inkMuted, fontSize: 13.5, height: 1.45),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Goal name',
                      hintText: 'e.g. School fees',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _targetController,
                    decoration: const InputDecoration(labelText: 'Target amount'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _contributionController,
                    decoration: const InputDecoration(labelText: 'Contribution amount'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 14),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _frequency,
                          decoration: const InputDecoration(labelText: 'Frequency'),
                          items: const [
                            DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                            DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                            DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                          ],
                          onChanged: (v) => setState(() => _frequency = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      'Contributions are always signed by you — PayFlex marks '
                      'them due, it never moves money unattended.',
                      style: TextStyle(color: PfColors.inkFaint, fontSize: 12, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (_error != null) ...[
                    PfInlineError(message: _error!),
                    const SizedBox(height: 14),
                  ],
                  PfPrimaryButton(
                    label: 'Create goal',
                    busy: _busy,
                    onPressed: _busy ? null : _create,
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
