import 'package:flutter/material.dart';
import 'services/local_user_store.dart';
import 'services/api_client.dart';
import 'services/wallet_service.dart';
import 'theme/payflex_tokens.dart';
import 'theme/payflex_theme.dart';
import 'widgets/pf_mark.dart';
import 'widgets/pf_motion.dart';
import 'screens/onboarding/create_user_screen.dart';
import 'screens/wallet_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WalletService.initialize();
  await PfAppearance.init(); // persisted dark/light choice (default: dark)
  runApp(const PayFlexApp());
}

class PayFlexApp extends StatelessWidget {
  const PayFlexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: PfAppearance.mode,
      builder: (context, mode, _) => MaterialApp(
        title: 'PayFlex',
        debugShowCheckedModeBanner: false,
        theme: PayFlexTheme.light,
        darkTheme: PayFlexTheme.dark,
        themeMode: mode,
        // One consistent restrained transition for every route (design
        // brief §2, item 4) — configured per-theme in payflex_theme.dart.
        home: const _StartupGate(),
      ),
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
    return const _SplashView();
  }
}

/// Branded launch surface — flat deep navy, the approved logo mark, and
/// the ribbon loader tracing underneath while the startup decision runs.
/// Dark-default per the design brief (§1: splash lives on the logo's
/// navy, never a default spinner).
class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: PayFlexTheme.dark,
      child: Scaffold(
        backgroundColor: PfColors.navy,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 550),
                curve: PfMotion.easeOut,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, 14 * (1 - t)),
                    child: child,
                  ),
                ),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/brand/payflex_logo.png',
                      width: 128,
                      height: 128,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const PfMarkIcon(
                        size: 120,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'PayFlex',
                      style: TextStyle(
                        color: PfColors.onNavy,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Digital finance that moves with you',
                      style: TextStyle(
                        color: PfColors.onNavyMuted,
                        fontSize: 13.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
              const Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: PfBrandedLoader(size: 40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
