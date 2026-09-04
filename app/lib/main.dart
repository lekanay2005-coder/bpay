import 'package:flutter/material.dart';
import 'services/local_user_store.dart';
import 'services/api_client.dart';
import 'services/wallet_service.dart';
import 'screens/onboarding/create_user_screen.dart';
import 'screens/wallet_home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WalletService.initialize();
  runApp(const PayFlexApp());
}

class PayFlexApp extends StatelessWidget {
  const PayFlexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PayFlex',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const _StartupGate(),
    );
  }
}

/// Decides, once at launch, whether we already have a local PayFlex user
/// (skip straight to the wallet) or need to run creation from scratch.
/// This is the app-side half of "never recreate a user on relaunch" —
/// the backend enforces it too, but checking here avoids even attempting
/// the call.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  final _store = LocalUserStore();
  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final appUserId = await _store.getAppUserId();
    if (!mounted) return;
    if (appUserId == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CreateUserScreen()),
      );
      return;
    }
    try {
      final user = await _api.getUser(appUserId);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => WalletHomeScreen(user: user)),
      );
    } catch (_) {
      // Local id points at a user the backend doesn't know about (e.g.
      // pointed at a different backend/DB) — fall back to creation
      // rather than getting stuck on a blank screen.
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CreateUserScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
