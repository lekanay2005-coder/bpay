import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/api_client.dart';

/// Phase 1 stub — proves the lifecycle end to end. Balances, transaction
/// history, and the transfer UX land in Phases 2-3.
class WalletHomeScreen extends StatefulWidget {
  final AppUser user;
  final SmartWallet? initialWallet;
  const WalletHomeScreen({super.key, required this.user, this.initialWallet});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _api.getOnboardingStatus(widget.user.id);
      setState(() => _status = status);
    } catch (_) {
      // Non-fatal for this stub screen.
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = widget.initialWallet;
    return Scaffold(
      appBar: AppBar(title: Text('Hi, ${widget.user.firstName}')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            Text('BMONI user: ${widget.user.bmoniUserId}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            if (wallet != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(wallet.currency, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(wallet.walletAddress),
                      const SizedBox(height: 8),
                      Text(wallet.isActive ? 'Active' : 'Inactive'),
                    ],
                  ),
                ),
              )
            else
              const Text('No smart wallet loaded for this session.'),
            const SizedBox(height: 24),
            Text('Onboarding status', style: Theme.of(context).textTheme.titleMedium),
            Text(_status?.toString() ?? 'Loading...'),
          ],
        ),
      ),
    );
  }
}
