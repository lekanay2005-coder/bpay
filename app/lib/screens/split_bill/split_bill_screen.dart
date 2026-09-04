import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/split_bill.dart';
import '../../services/api_client.dart';
import '../../services/transfer_flow.dart';

/// Build brief section 4.3 — split-bill. Orchestration only: BMONI has no
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

  Future<void> _payShare(String splitBillId) async {
    try {
      final proposal = await _api.paySplitBillShare(widget.user.id, splitBillId);
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
      appBar: AppBar(
        title: const Text('Split bills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => CreateSplitBillScreen(user: widget.user)))
                .then((_) => _load()),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                  if (_bills.isEmpty) const Text('No split bills yet.'),
                  ..._bills.map((bill) {
                    final myShare = bill.contributors
                        .where((c) => c.appUserId == widget.user.id)
                        .cast<SplitBillContributor?>()
                        .firstWhere((c) => true, orElse: () => null);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${bill.description} — ${bill.totalAmount} ${bill.currency}'),
                            Text('Status: ${bill.status}'),
                            ...bill.contributors.map(
                              (c) => Text('  ${c.shareAmount} ${bill.currency} — ${c.status}'),
                            ),
                            if (myShare != null && myShare.status == 'PENDING')
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: FilledButton(
                                  onPressed: () => _payShare(bill.id),
                                  child: Text('Pay my share (${myShare.shareAmount})'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
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
            .map((c) => (payTag: c.payTagController.text, bmoniUserId: null, shareAmount: c.shareController.text))
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
    return Scaffold(
      appBar: AppBar(title: const Text('New split bill')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'What is this for?'),
            ),
            TextField(
              controller: _totalController,
              decoration: const InputDecoration(labelText: 'Total amount'),
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
            const Divider(height: 32),
            Text('Contributors', style: Theme.of(context).textTheme.titleMedium),
            ..._contributors.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: row.payTagController,
                          decoration: const InputDecoration(labelText: '@PayTag'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: row.shareController,
                          decoration: const InputDecoration(labelText: 'Share'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                )),
            OutlinedButton(
              onPressed: () => setState(() => _contributors.add(_ContributorRow())),
              child: const Text('Add contributor'),
            ),
            const SizedBox(height: 24),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            FilledButton(onPressed: _busy ? null : _create, child: const Text('Create split bill')),
          ],
        ),
      ),
    );
  }
}
