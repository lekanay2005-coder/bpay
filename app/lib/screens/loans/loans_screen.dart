import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/microfinance.dart';
import '../../services/api_client.dart';
import '../../services/transfer_flow.dart';

/// Build brief section 3 — BMONI has no loan product; scoring runs
/// entirely off BMONI transaction history via a pluggable
/// CreditScoringStrategy on the backend. Approval decides synchronously;
/// disbursement (if approved) is signed by PayFlex's treasury
/// server-side, so nothing to sign here for that part — only a
/// subsequent repayment needs the borrower's signature.
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
  String? _lastResult;

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
      setState(() {
        _lastResult = loan.status == 'REJECTED'
            ? 'Not approved this time (score ${loan.creditScore}).'
            : 'Approved and disbursed ${loan.approvedAmount} ${loan.currency} '
                '(score ${loan.creditScore}).';
      });
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
      if (signed != null) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loans')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('Apply for a loan', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    decoration: const InputDecoration(labelText: 'Amount requested'),
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
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _applying ? null : _apply,
                    child: const Text('Apply'),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  if (_lastResult != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(_lastResult!),
                    ),
                  const Divider(height: 32),
                  Text('Your loans', style: Theme.of(context).textTheme.titleMedium),
                  if (_loans.isEmpty) const Text('No loan applications yet.'),
                  ..._loans.map((loan) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${loan.requestedAmount} ${loan.currency} — ${loan.status}'),
                              if (loan.creditScore != null) Text('Score: ${loan.creditScore}'),
                              ...(_repaymentsByLoan[loan.id] ?? []).map(
                                (r) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('Repayment: ${r.amount} ${loan.currency}'),
                                  subtitle: Text('${r.status} · due ${r.dueAt}'),
                                  trailing: r.status == 'DUE'
                                      ? OutlinedButton(
                                          onPressed: () => _payRepayment(r.id),
                                          child: const Text('Pay'),
                                        )
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ),
    );
  }
}
