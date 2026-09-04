import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/api_client.dart';
import '../services/local_user_store.dart';
import '../services/retry.dart';
import '../theme/payflex_tokens.dart';
import '../theme/payflex_theme.dart';
import '../widgets/pf_buttons.dart';
import '../widgets/pf_states.dart';
import 'onboarding/create_user_screen.dart';

/// Profile & settings (design brief §3): account tier and verification
/// status read from live onboarding state, appearance toggle (both
/// themes fully designed), security posture, support access, sign out.
class SettingsScreen extends StatefulWidget {
  final AppUser user;
  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

enum _RailState { active, pending, none }

class _SettingsScreenState extends State<SettingsScreen> {
  final _api = ApiClient();
  final _store = LocalUserStore();
  Map<String, dynamic>? _onboarding;
  String? _statusError;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loaded = false;
      _statusError = null;
    });
    try {
      final status = await withRetry(
        () => _api.getOnboardingStatus(widget.user.id),
      );
      if (mounted) {
        setState(() {
          _onboarding = status;
          _loaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusError = e.toString();
          _loaded = true;
        });
      }
    }
  }

  _RailState _railState(String key) {
    final value = (_onboarding?[key] as String?) ?? 'not_started';
    if (value == 'active') return _RailState.active;
    if (value == 'not_started') return _RailState.none;
    return _RailState.pending;
  }

  String get _tierLabel {
    if (!_loaded) return 'Checking…';
    const rails = ['anchorStatus', 'bridgeStatus', 'moneriumStatus', 'paytrieStatus', 'etherfuseStatus'];
    final anyActive = rails.any((r) => _railState(r) == _RailState.active);
    final anyPending = rails.any((r) => _railState(r) == _RailState.pending);
    if (anyActive) return 'Verified';
    if (anyPending) return 'Verification in progress';
    return 'Setup not started';
  }

  PfTone get _tierTone {
    if (!_loaded) return PfTone.muted;
    const rails = ['anchorStatus', 'bridgeStatus', 'moneriumStatus', 'paytrieStatus', 'etherfuseStatus'];
    final anyActive = rails.any((r) => _railState(r) == _RailState.active);
    final anyPending = rails.any((r) => _railState(r) == _RailState.pending);
    if (anyActive) return PfTone.success;
    if (anyPending) return PfTone.warn;
    return PfTone.muted;
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: PayFlexTheme.dark,
        child: Dialog(
          backgroundColor: PfColors.navyRaised,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PfRadius.lg),
            side: const BorderSide(color: PfColors.navyBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sign out of PayFlex?',
                  style: TextStyle(
                    color: PfColors.onNavy,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your on-device wallet key stays on this device — you can '
                  'sign back in and reuse it. Balances are safe on the network.',
                  style: TextStyle(color: PfColors.onNavyMuted, fontSize: 13.5, height: 1.45),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: PfSecondaryButton(
                        label: 'Keep me in',
                        onPressed: () => Navigator.of(context).pop(false),
                        height: 46,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PfPrimaryButton(
                        label: 'Sign out',
                        onPressed: () => Navigator.of(context).pop(true),
                        height: 46,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _store.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CreateUserScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final initials =
        '${u.firstName.isEmpty ? '' : u.firstName[0]}${u.lastName.isEmpty ? '' : u.lastName[0]}'
            .toUpperCase();

    return Theme(
      data: PayFlexTheme.dark,
      child: Scaffold(
        backgroundColor: PfColors.navy,
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: PfColors.navy,
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(PfSpace.xl, 8, PfSpace.xl, 48),
              children: [
                // ── Profile ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: PfColors.navyRaised,
                    borderRadius: BorderRadius.circular(PfRadius.md),
                    border: Border.all(color: PfColors.navyBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: PfColors.navyRaised2,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: PfColors.onNavy,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${u.firstName} ${u.lastName}',
                              style: const TextStyle(
                                color: PfColors.onNavy,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              u.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: PfColors.onNavyMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              u.phoneNumber,
                              style: const TextStyle(
                                color: PfColors.onNavyFaint,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PfStatusChip(label: _tierLabel, tone: _tierTone),
                    ],
                  ),
                ),
                if (_statusError != null) ...[
                  const SizedBox(height: 12),
                  PfInlineError(message: _statusError!, onRetry: _load),
                ],

                const SizedBox(height: 28),
                const PfSectionHeader(title: 'Verification'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: PfColors.navyRaised,
                    borderRadius: BorderRadius.circular(PfRadius.md),
                    border: Border.all(color: PfColors.navyBorder),
                  ),
                  child: Column(
                    children: [
                      _settingsRow(
                        icon: Icons.verified_outlined,
                        label: 'Account tier',
                        value: _tierLabel,
                        tone: _tierTone,
                      ),
                      const Divider(color: PfColors.navyBorder),
                      _settingsRow(
                        icon: Icons.language_outlined,
                        label: 'NGN rail',
                        value: _railLabel('anchorStatus'),
                        tone: _railTone('anchorStatus'),
                      ),
                      _settingsRow(
                        icon: Icons.public_outlined,
                        label: 'USD rail',
                        value: _railLabel('bridgeStatus'),
                        tone: _railTone('bridgeStatus'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Text(
                    'Tiers and rail status come from your live onboarding state — '
                    'complete KYC per currency to unlock more.',
                    style: TextStyle(
                      color: PfColors.onNavyFaint,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 28),
                const PfSectionHeader(title: 'Appearance'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: PfColors.navyRaised,
                    borderRadius: BorderRadius.circular(PfRadius.md),
                    border: Border.all(color: PfColors.navyBorder),
                  ),
                  child: ValueListenableBuilder<ThemeMode>(
                    valueListenable: PfAppearance.mode,
                    builder: (context, mode, _) {
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        leading: const Icon(
                          Icons.dark_mode_outlined,
                          color: PfColors.onNavyMuted,
                        ),
                        title: const Text(
                          'Dark mode',
                          style: TextStyle(
                            color: PfColors.onNavy,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          'Designed navy wallet surfaces stay navy either way.',
                          style: TextStyle(color: PfColors.onNavyFaint, fontSize: 11.5),
                        ),
                        trailing: Switch(
                          value: mode == ThemeMode.dark,
                          onChanged: (dark) => PfAppearance.set(
                            dark ? ThemeMode.dark : ThemeMode.light,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 28),
                const PfSectionHeader(title: 'Security'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: PfColors.navyRaised,
                    borderRadius: BorderRadius.circular(PfRadius.md),
                    border: Border.all(color: PfColors.navyBorder),
                  ),
                  child: Column(
                    children: const [
                      ListTile(
                        dense: true,
                        leading: Icon(Icons.key_outlined, color: PfColors.onNavyMuted, size: 22),
                        title: Text(
                          'PIN-gated on-device signing',
                          style: TextStyle(color: PfColors.onNavy, fontSize: 14.5),
                        ),
                        subtitle: Text(
                          'Every payment is signed on this device with your 6-digit PIN.',
                          style: TextStyle(color: PfColors.onNavyFaint, fontSize: 12),
                        ),
                      ),
                      Divider(color: PfColors.navyBorder),
                      ListTile(
                        dense: true,
                        leading: Icon(Icons.lock_outline_rounded, color: PfColors.onNavyMuted, size: 22),
                        title: Text(
                          'Your key never leaves this device',
                          style: TextStyle(color: PfColors.onNavy, fontSize: 14.5),
                        ),
                        subtitle: Text(
                          'PayFlex never holds your signing key — only your signatures.',
                          style: TextStyle(color: PfColors.onNavyFaint, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),
                const PfSectionHeader(title: 'Support'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: PfColors.navyRaised,
                    borderRadius: BorderRadius.circular(PfRadius.md),
                    border: Border.all(color: PfColors.navyBorder),
                  ),
                  child: Column(
                    children: [
                      _supportTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Help centre',
                        subtitle: 'Common questions about money movement',
                        onTap: _showHelp,
                      ),
                      const Divider(color: PfColors.navyBorder),
                      _supportTile(
                        icon: Icons.info_outline_rounded,
                        title: 'About PayFlex',
                        subtitle: 'v0.1.0 · BMONI smart-wallet rails',
                        onTap: _showAbout,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),
                PfSecondaryButton(
                  label: 'Sign out',
                  icon: Icons.logout_rounded,
                  onPressed: _signOut,
                  height: 48,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _railLabel(String key) => switch (_railState(key)) {
        _RailState.active => 'Active',
        _RailState.pending => 'Pending',
        _RailState.none => 'Not started',
      };

  PfTone _railTone(String key) => switch (_railState(key)) {
        _RailState.active => PfTone.success,
        _RailState.pending => PfTone.warn,
        _RailState.none => PfTone.muted,
      };

  Widget _settingsRow({
    required IconData icon,
    required String label,
    required String value,
    required PfTone tone,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: PfColors.onNavyMuted, size: 21),
      title: Text(
        label,
        style: const TextStyle(color: PfColors.onNavy, fontSize: 14.5),
      ),
      trailing: PfStatusChip(label: value, tone: tone),
    );
  }

  Widget _supportTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: PfColors.onNavyMuted, size: 21),
      title: Text(
        title,
        style: const TextStyle(color: PfColors.onNavy, fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: PfColors.onNavyFaint, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: PfColors.onNavyFaint),
      onTap: onTap,
    );
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => Theme(
        data: PayFlexTheme.dark,
        child: Dialog(
          backgroundColor: PfColors.navyRaised,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PfRadius.lg),
            side: const BorderSide(color: PfColors.navyBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Help centre',
                  style: TextStyle(color: PfColors.onNavy, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text('Where is my money?', style: TextStyle(color: PfColors.onNavy, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                const Text(
                  'Every transfer is signed on your device and settles on your '
                  'BMONI smart wallet. Check the receipt — reference numbers match '
                  'your activity history.',
                  style: TextStyle(color: PfColors.onNavyMuted, fontSize: 13, height: 1.45),
                ),
                const SizedBox(height: 12),
                const Text('Why is my verification pending?', style: TextStyle(color: PfColors.onNavy, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                const Text(
                  'Rail status comes from live onboarding state. NGN needs your '
                  'BVN; USD runs a real Sumsub identity check with camera captures.',
                  style: TextStyle(color: PfColors.onNavyMuted, fontSize: 13, height: 1.45),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Still stuck? Your nearest PayFlex agent can cash you in and out, '
                  'and raise issues on your behalf.',
                  style: TextStyle(color: PfColors.onNavyFaint, fontSize: 12.5, height: 1.45),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: PfPrimaryButton(
                    label: 'Got it',
                    onPressed: () => Navigator.of(context).pop(),
                    height: 46,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (context) => Theme(
        data: PayFlexTheme.dark,
        child: Dialog(
          backgroundColor: PfColors.navyRaised,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PfRadius.lg),
            side: const BorderSide(color: PfColors.navyBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About PayFlex',
                  style: TextStyle(color: PfColors.onNavy, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text(
                  'PayFlex 0.1.0 — mobile-first microfinance on BMONI smart-wallet '
                  'rails. Savings, loans and agent services are PayFlex layers on '
                  'top; money always settles through your own wallet.',
                  style: TextStyle(color: PfColors.onNavyMuted, fontSize: 13.5, height: 1.5),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: PfPrimaryButton(
                    label: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    height: 46,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
