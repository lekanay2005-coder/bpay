import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/kyc.dart';
import '../services/api_client.dart';
import 'transfer/send_money_screen.dart';
import 'transfer/qr_pay_screen.dart';
import 'transfer/paytag_screen.dart';
import 'savings/savings_screen.dart';
import 'loans/loans_screen.dart';
import 'agent/agent_screen.dart';

/// Phase 2: real balances + transaction history, fetched fresh from the
/// backend rather than relying on a wallet object passed in at creation
/// time. Phase 3 adds send/QR Pay/PayTag entry points. Phase 4 adds
/// savings/loans/agent mode via the overflow menu.
class WalletHomeScreen extends StatefulWidget {
  final AppUser user;
  const WalletHomeScreen({super.key, required this.user});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  final _api = ApiClient();
  List<SmartWallet> _wallets = [];
  Map<String, Balance> _balancesByWalletId = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final wallets = await _api.listWallets(widget.user.id);
      final balances = await _api.listBalances(widget.user.id);
      setState(() {
        _wallets = wallets;
        _balancesByWalletId = {for (final b in balances) b.smartWalletId: b};
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${widget.user.firstName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.alternate_email),
            tooltip: 'PayTag',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PayTagScreen(user: widget.user)),
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          PopupMenuButton<String>(
            onSelected: (value) {
              final screen = switch (value) {
                'savings' => SavingsScreen(user: widget.user),
                'loans' => LoansScreen(user: widget.user),
                'agent' => AgentScreen(user: widget.user),
                _ => null,
              };
              if (screen != null) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'savings', child: Text('Savings goals')),
              PopupMenuItem(value: 'loans', child: Text('Loans')),
              PopupMenuItem(value: 'agent', child: Text('Agent mode')),
            ],
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton.extended(
            heroTag: 'send',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SendMoneyScreen(user: widget.user)),
            ),
            icon: const Icon(Icons.send),
            label: const Text('Send'),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'qr',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => QrPayScreen(user: widget.user)),
            ),
            icon: const Icon(Icons.qr_code),
            label: const Text('QR Pay'),
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
                  Text('BMONI user: ${widget.user.bmoniUserId}',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  if (_wallets.isEmpty && _error == null)
                    const Text('No smart wallets yet.'),
                  ..._wallets.map((w) => _WalletCard(
                        wallet: w,
                        balance: _balancesByWalletId[w.id],
                        appUserId: widget.user.id,
                      )),
                ],
              ),
            ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final SmartWallet wallet;
  final Balance? balance;
  final String appUserId;

  const _WalletCard({required this.wallet, required this.balance, required this.appUserId});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(wallet.currency, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(wallet.walletAddress, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              balance != null ? '${balance!.balance} ${balance!.currency}' : '—',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(wallet.isActive ? 'Active' : 'Inactive'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TransactionHistoryScreen(
                    appUserId: appUserId,
                    smartWalletId: wallet.id,
                    currency: wallet.currency,
                  ),
                ),
              ),
              child: const Text('View transactions'),
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionHistoryScreen extends StatefulWidget {
  final String appUserId;
  final String smartWalletId;
  final String currency;

  const TransactionHistoryScreen({
    super.key,
    required this.appUserId,
    required this.smartWalletId,
    required this.currency,
  });

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final _api = ApiClient();
  List<Transaction> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final txns = await _api.getTransactions(widget.appUserId, widget.smartWalletId);
    if (mounted) setState(() {
      _transactions = txns;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.currency} transactions')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? const Center(child: Text('No transactions yet.'))
              : ListView.builder(
                  itemCount: _transactions.length,
                  itemBuilder: (context, i) {
                    final t = _transactions[i];
                    return ListTile(
                      leading: Icon(t.direction == 'IN' ? Icons.arrow_downward : Icons.arrow_upward),
                      title: Text('${t.amount} ${t.currency}'),
                      subtitle: Text('${t.status} · ${t.createdAt}'),
                    );
                  },
                ),
    );
  }
}
