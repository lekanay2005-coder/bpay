import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/microfinance.dart';
import '../../services/api_client.dart';
import '../../services/transfer_flow.dart';

/// App-level savings ledger (build brief section 3 — no BMONI savings
/// product exists). See backend/prisma/schema.prisma's SavingsGoal doc
/// comment for why contributions are only ever "due," never
/// auto-executed: every transfer needs the user's live on-device
/// signature, so the app is where a due contribution actually gets paid.
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

  Future<void> _payContribution(String contributionId) async {
    try {
      final proposal = await _api.payContribution(widget.user.id, contributionId);
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
        title: const Text('Savings goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => CreateSavingsGoalScreen(user: widget.user)))
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
                  if (_due.isNotEmpty) ...[
                    Text('Due now', style: Theme.of(context).textTheme.titleMedium),
                    ..._due.map((c) => Card(
                          child: ListTile(
                            title: Text('${c.amount} ${c.goal?.currency ?? ''}'),
                            subtitle: Text(c.goal?.name ?? ''),
                            trailing: FilledButton(
                              onPressed: () => _payContribution(c.id),
                              child: const Text('Pay now'),
                            ),
                          ),
                        )),
                    const Divider(height: 32),
                  ],
                  Text('Your goals', style: Theme.of(context).textTheme.titleMedium),
                  if (_goals.isEmpty) const Text('No savings goals yet.'),
                  ..._goals.map((g) => Card(
                        child: ListTile(
                          title: Text(g.name),
                          subtitle: Text(
                            '${g.totalContributed} / ${g.targetAmount} ${g.currency} '
                            '(${g.frequency.toLowerCase()}, ${g.status.toLowerCase()})',
                          ),
                        ),
                      )),
                ],
              ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('New savings goal')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Goal name'),
            ),
            TextField(
              controller: _targetController,
              decoration: const InputDecoration(labelText: 'Target amount'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: _contributionController,
              decoration: const InputDecoration(labelText: 'Contribution amount'),
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
            DropdownButtonFormField<String>(
              value: _frequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: const [
                DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
              ],
              onChanged: (v) => setState(() => _frequency = v!),
            ),
            const SizedBox(height: 24),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            FilledButton(
              onPressed: _busy ? null : _create,
              child: const Text('Create goal'),
            ),
          ],
        ),
      ),
    );
  }
}
