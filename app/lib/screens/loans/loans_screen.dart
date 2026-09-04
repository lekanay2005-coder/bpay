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

/// Build brief §3 — BMONI has no loan product; scoring runs entirely off
/// BMONI transaction history via a pluggable CreditScoringStrategy on the
/// backend. Approval decides synchronously; disbursement (if approved)
/// is signed by PayFlex's treasury server-side, so nothing to sign here
/// for that part — only a subsequent repayment needs the borrower's
/// signature.
class LoansScreen extends StatefulWidget {
  final AppUser user;
  const LoansScreen({super.key, required this.user});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  final _api = ApiClient();
  final _amountController = TextEditingController();
  String _currency = 'NGN';
  List<LoanApplication> _loans = [];
  final Map<String, List<LoanRepayment>> _repaymentsByLoan = {};
  bool _loading = true;
  bool _applying = false;
  String? _error;
  LoanApplication? _lastResult;

  @override
  void dispose() {
    _amountController.dispose();
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
      final loans = await _api.listLoans(widget.user.id);
      for (final loan in loans) {
        if (loan.status == 'DISBURSED' || loan.status == 'REPAYING') {
          _repaymentsByLoan[loan.id] = await _api.listRepayments(widget.user.id, loan.id);
        }
      }
      setState(() => _loans = loans);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _apply() async {
    setState(() {
      _applying = true;
      _error = null;
      _lastResult = null;
    });
    try {
      final loan = await _api.applyForLoan(
        widget.user.id,
        requestedAmount: _amountController.text,
        currency: _currency,
      );
      setState(() => _lastResult = loan);
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _payRepayment(String repaymentId) async {
    try {
      final proposal = await _api.payRepayment(widget.user.id, repaymentId);
      if (!mounted) return;
      final signed = await signAndSubmitTransfer(context, _api, widget.user.id, proposal.id);
      if (signed != null) {
        await showPfConfirmation(
          context,
          outcome: PfFlowOutcome(
            headline: 'Repayment made',
            amount: signed.amount,
            currency: signed.currency,
            caption: 'Your balance drops by ${formatMoney(signed.amount, signed.currency)}',
            reference: signed.id,
            statusLabel: humanTransferStatus(signed.status),
            statusTone: transferTone(signed.status),
            methodLabel: 'Loan repayment',
          ),
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

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: PayFlexTheme.light,
      child: Scaffold(
        backgroundColor: PfColors.offWhite,
        appBar: AppBar(
          title: const Text('Loans'),
          backgroundColor: PfColors.offWhite,
        ),
        body: _loading && _loans.isEmpty
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
                    _applyPanel(),
                    if (_lastResult != null) ...[
                      const SizedBox(height: 14),
                      _decisionBanner(_lastResult!),
                    ],
                    const SizedBox(height: 24),
                    const PfSectionHeader(title: 'Your loans'),
                    const SizedBox(height: 10),
                    if (_loans.isEmpty && _error == null)
                      const PfEmptyState(
                        compact: true,
                        icon: Icons.account_balance_outlined,
                        title: 'No loan applications yet',
                        message: 'Credit is scored from your transaction history — '
                            'steady activity builds your score.',
                      ),
                    ..._loans.map(_loanCard),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _applyPanel() {
    return PfPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Borrow against your history',
            style: TextStyle(color: PfColors.ink, fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Instant decision, no paperwork. Approved loans disburse straight '
            'to your wallet — PayFlex signs that side.',
            style: TextStyle(color: PfColors.inkMuted, fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Amount requested'),
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
          const SizedBox(height: 14),
          PfPrimaryButton(
            label: 'Apply now',
            busy: _applying,
            onPressed: _applying ? null : _apply,
          ),
        ],
      ),
    );
  }

  Widget _decisionBanner(LoanApplication loan) {
    final approved = loan.status != 'REJECTED';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: approved ? PfColors.successWash : PfColors.surfaceAlt,
        borderRadius: BorderRadius.circular(PfRadius.md),
        border: Border.all(
          color: approved ? PfColors.success.withValues(alpha: 0.35) : PfColors.line,
        ),
      ),
      child: Row(
        children: [
          Icon(
            approved ? Icons.verified_outlined : Icons.info_outline_rounded,
            color: approved ? PfColors.success : PfColors.inkMuted,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  approved
                      ? 'Approved & disbursed'
                      : 'Not approved this time',
                  style: TextStyle(
                    color: approved ? PfColors.success : PfColors.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  approved
                      ? '${formatMoney(loan.approvedAmount ?? loan.requestedAmount, loan.currency)} '
                          'is on its way · score ${loan.creditScore}'
                      : 'Score ${loan.creditScore ?? '—'} — build transaction '
                          'history and try again soon.',
                  style: TextStyle(
                    color: approved ? PfColors.success : PfColors.inkMuted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loanCard(LoanApplication loan) {
    final repayments = _repaymentsByLoan[loan.id] ?? [];
    return PfPanel(
      margin: const EdgeInsets.only(bottom: 12),
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
                      formatMoney(loan.requestedAmount, loan.currency),
                      style: PfMoneyType.small.copyWith(
                        color: PfColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      loan.status == 'REJECTED'
                          ? 'Not approved'
                          : '${loan.status.toLowerCase().split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ')}',
                      style: const TextStyle(
                        color: PfColors.inkMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              PfStatusChip(
                label: loan.status == 'REJECTED'
                    ? 'Declined'
                    : loan.status == 'REPAYING'
                        ? 'Repaying'
                        : 'Live',
                tone: loan.status == 'REJECTED' ? PfTone.warn : PfTone.success,
              ),
            ],
          ),
          if (repayments.isNotEmpty) ...[
            const Divider(height: 26),
            ...repayments.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatMoney(r.amount, loan.currency),
                            style: const TextStyle(
                              color: PfColors.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Repayment · ${r.status.toLowerCase()} · due ${r.dueAt}',
                            style: const TextStyle(
                              color: PfColors.inkFaint,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (r.status == 'DUE')
                      PfGradientChip(
                        label: 'Pay',
                        onPressed: () => _payRepayment(r.id),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
