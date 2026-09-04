import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/microfinance.dart';
import '../../services/api_client.dart';
import '../../services/transfer_flow.dart';

/// Agent cash-in/cash-out (build brief section 3/5 — no BMONI agent
/// primitive). Mechanically both are ordinary TransferService transfers
/// — cash-in has the agent as sender (agent received physical cash, sends
/// digital funds), cash-out has the customer as sender (customer sends
/// digital funds, agent hands over physical cash) — so whichever side of
/// the screen is "this device's user" is who signs.
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
  String? _status;

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
    setState(() {
      _error = null;
      _status = null;
    });
    try {
      final proposal = await _api.agentCashIn(
        widget.user.id,
        toPayTag: _cashInRecipientController.text,
        amount: _cashInAmountController.text,
        currency: _currency,
      );
      if (!mounted) return;
      final signed = await signAndSubmitTransfer(context, _api, widget.user.id, proposal.id);
      setState(() => _status = signed == null ? 'Cancelled.' : 'Cash-in signed and submitted.');
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _cashOut() async {
    setState(() {
      _error = null;
      _status = null;
    });
    try {
      final proposal = await _api.agentCashOut(
        widget.user.id,
        agentPayTag: _cashOutAgentController.text,
        amount: _cashOutAmountController.text,
        currency: _currency,
      );
      if (!mounted) return;
      final signed = await signAndSubmitTransfer(context, _api, widget.user.id, proposal.id);
      setState(() => _status = signed == null ? 'Cancelled.' : 'Cash-out signed and submitted.');
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agent mode')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                SwitchListTile(
                  title: const Text('I am a PayFlex agent'),
                  value: _isAgent,
                  onChanged: _toggleAgent,
                ),
                if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                if (_status != null) Text(_status!, style: const TextStyle(color: Colors.green)),
                const Divider(height: 32),
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
                Text('Cash-in (customer gives you cash)', style: Theme.of(context).textTheme.titleMedium),
                TextField(
                  controller: _cashInRecipientController,
                  decoration: const InputDecoration(labelText: 'Customer @PayTag'),
                ),
                TextField(
                  controller: _cashInAmountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                FilledButton(onPressed: _cashIn, child: const Text('Cash-in')),
                const Divider(height: 32),
                Text('Cash-out (you give the customer cash)', style: Theme.of(context).textTheme.titleMedium),
                TextField(
                  controller: _cashOutAgentController,
                  decoration: const InputDecoration(labelText: 'Agent @PayTag'),
                ),
                TextField(
                  controller: _cashOutAmountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                FilledButton(onPressed: _cashOut, child: const Text('Cash-out')),
                const Divider(height: 32),
                Text('Ledger', style: Theme.of(context).textTheme.titleMedium),
                ..._ledger.map((t) => ListTile(
                      leading: Icon(t.type == 'CASH_IN' ? Icons.arrow_downward : Icons.arrow_upward),
                      title: Text('${t.type} · ${t.amount} ${t.currency}'),
                      subtitle: Text('${t.status} · ${t.createdAt}'),
                    )),
              ],
            ),
    );
  }
}
