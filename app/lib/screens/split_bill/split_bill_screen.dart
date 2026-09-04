import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/split_bill.dart';
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

/// Build brief §4.3 — split-bill. Orchestration only: BMONI has no
/// group-payment primitive, so each contributor's payment is an
/// independent TransferService proposal they sign themselves.
class SplitBillScreen extends StatefulWidget {
  final AppUser user;
  const SplitBillScreen({super.key, required this.user});

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> {
  final _api = ApiClient();
  List<SplitBill> _bills = [];
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
      _bills = await _api.listSplitBills(widget.user.id);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _payShare(SplitBill bill) async {
    try {
      final proposal = await _api.paySplitBillShare(widget.user.id, bill.id);
      if (!mounted) return;
      final signed = await signAndSubmitTransfer(context, _api, widget.user.id, proposal.id);
      if (signed != null) {
        await showPfConfirmation(
          context,
          outcome: _outcome(signed, 'Share paid',
              caption: '${bill.description} · split bill'),
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
        methodLabel: 'Split bill',
      );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: PayFlexTheme.light,
      child: Scaffold(
        backgroundColor: PfColors.offWhite,
        appBar: AppBar(
          title: const Text('Split bills'),
          backgroundColor: PfColors.offWhite,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'New split bill',
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => CreateSplitBillScreen(user: widget.user)))
                  .then((_) => _load()),
            ),
          ],
        ),
        body: _loading && _bills.isEmpty
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
                    if (_bills.isEmpty && _error == null)
                      PfEmptyState(
                        compact: true,
                        icon: Icons.groups_2_outlined,
                        title: 'No split bills yet',
                        message: 'Dinner with friends, group data, house bills — '
                            'one QR, each person signs their own share.',
                        actionLabel: 'Create a split bill',
                        onAction: () => Navigator.of(context)
                            .push(MaterialPageRoute(
                              builder: (_) => CreateSplitBillScreen(user: widget.user),
                            ))
                            .then((_) => _load()),
                      ),
                    ..._bills.map(_billCard),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _billCard(SplitBill bill) {
    final paidCount = bill.contributors
        .where((c) => c.status.toUpperCase() == 'PAID' || c.status.toUpperCase() == 'COMPLETED')
        .length;
    final total = bill.contributors.length;
    final fraction = total == 0 ? 0.0 : paidCount / total;
    final myShare = bill.contributors
        .where((c) => c.appUserId == widget.user.id)
        .cast<SplitBillContributor?>()
        .firstWhere((c) => true, orElse: () => null);
    final billComplete = bill.status.toUpperCase() == 'COMPLETED';

    return PfPanel(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.description,
                      style: const TextStyle(
                        color: PfColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatMoney(bill.totalAmount, bill.currency),
                      style: const TextStyle(color: PfColors.inkMuted, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              PfStatusChip(
                label: billComplete ? 'Paid up' : '${paidCount}/$total paid',
                tone: billComplete ? PfTone.success : PfTone.info,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              PfSplitRing(
                progress: fraction,
                size: 52,
                strokeWidth: 5,
                center: Text(
                  '${(fraction * 100).round()}%',
                  style: const TextStyle(
                    color: PfColors.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: bill.contributors.map((c) {
                    final isMe = c.appUserId == widget.user.id;
                    final paid = c.status.toUpperCase() == 'PAID' ||
                        c.status.toUpperCase() == 'COMPLETED';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isMe ? 'You' : 'Contributor',
                              style: TextStyle(
                                color: isMe ? PfColors.ink : PfColors.inkMuted,
                                fontSize: 12.5,
                                fontWeight: isMe ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                          Text(
                            formatMoney(c.shareAmount, bill.currency),
                            style: const TextStyle(
                              color: PfColors.ink,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            paid ? Icons.check_circle_rounded : Icons.circle_outlined,
                            size: 15,
                            color: paid ? PfColors.success : PfColors.inkFaint,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          if (myShare != null && !billComplete &&
              myShare.status.toUpperCase() == 'PENDING') ...[
            const SizedBox(height: 14),
            PfPrimaryButton(
              label: 'Pay my share',
              icon: Icons.north_east_rounded,
              onPressed: () => _payShare(bill),
              height: 48,
            ),
          ],
        ],
      ),
    );
  }
}

class CreateSplitBillScreen extends StatefulWidget {
  final AppUser user;
  const CreateSplitBillScreen({super.key, required this.user});

  @override
  State<CreateSplitBillScreen> createState() => _CreateSplitBillScreenState();
}

class _ContributorRow {
  final payTagController = TextEditingController();
  final shareController = TextEditingController();
}

class _CreateSplitBillScreenState extends State<CreateSplitBillScreen> {
  final _api = ApiClient();
  final _descriptionController = TextEditingController();
  final _totalController = TextEditingController();
  String _currency = 'NGN';
  final List<_ContributorRow> _contributors = [_ContributorRow()];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    _totalController.dispose();
    for (final c in _contributors) {
      c.payTagController.dispose();
      c.shareController.dispose();
    }
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.createSplitBill(
        widget.user.id,
        description: _descriptionController.text,
        currency: _currency,
        totalAmount: _totalController.text,
        contributors: _contributors
            .map((c) => (
                  payTag: c.payTagController.text,
                  bmoniUserId: null,
                  shareAmount: c.shareController.text,
                ))
            .toList(),
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
          title: const Text('New split bill'),
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
                    'Split it fairly',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Name the bill, add contributors by PayTag, and each person '
                    'signs their own share from their own wallet.',
                    style: TextStyle(color: PfColors.inkMuted, fontSize: 13.5, height: 1.45),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'What is this for?',
                      hintText: 'e.g. Saturday dinner',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _totalController,
                          decoration: const InputDecoration(labelText: 'Total amount'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
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
                  const SizedBox(height: 24),
                  const PfSectionHeader(title: 'Contributors'),
                  const SizedBox(height: 12),
                  ..._contributors.asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PfColors.surface,
                        borderRadius: BorderRadius.circular(PfRadius.md),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: PfColors.offWhite,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: PfColors.inkMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: row.payTagController,
                              decoration: const InputDecoration(
                                labelText: '@PayTag',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: row.shareController,
                              decoration: const InputDecoration(
                                labelText: 'Share',
                                isDense: true,
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          if (index > 0)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              color: PfColors.inkFaint,
                              onPressed: () {
                                setState(() {
                                  row.payTagController.dispose();
                                  row.shareController.dispose();
                                  _contributors.removeAt(index);
                                });
                              },
                            ),
                        ],
                      ),
                    );
                  }),
                  PfSecondaryButton(
                    label: 'Add contributor',
                    icon: Icons.add_rounded,
                    onPressed: () => setState(() => _contributors.add(_ContributorRow())),
                    height: 44,
                  ),
                  const SizedBox(height: 22),
                  if (_error != null) ...[
                    PfInlineError(message: _error!),
                    const SizedBox(height: 14),
                  ],
                  PfPrimaryButton(
                    label: 'Create split bill',
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
