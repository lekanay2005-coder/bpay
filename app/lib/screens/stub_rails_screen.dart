import 'package:flutter/material.dart';
import '../theme/payflex_tokens.dart';
import '../theme/payflex_theme.dart';
import '../widgets/pf_states.dart';

/// Build brief §2.3 / Phase 5: CAD/EUR/MXN are "structurally wired but
/// not UI-polished" — the backend endpoints exist
/// (OnboardingController's start-canada/start-monerium/latam-mx routes)
/// but there's deliberately no real onboarding flow here yet, matching
/// the brief's own reduced ambition for these three rails.
class StubRailsScreen extends StatelessWidget {
  const StubRailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: PayFlexTheme.light,
      child: Scaffold(
        backgroundColor: PfColors.offWhite,
        appBar: AppBar(
          title: const Text('More currencies'),
          backgroundColor: PfColors.offWhite,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(PfSpace.xl),
                children: const [
                  PfEmptyState(
                    icon: Icons.language_outlined,
                    title: 'More rails are on the way',
                    message:
                        'CAD, EUR and MXN are wired on the backend but not yet '
                        'built out here — the same way NGN and USD are, once '
                        'there\u2019s a reason to prioritize them.',
                  ),
                  SizedBox(height: 28),
                  _RailRow(code: 'CAD', name: 'Canada', status: 'Wired · not shipped'),
                  _RailRow(code: 'EUR', name: 'Europe (Monerium)', status: 'Wired · not shipped'),
                  _RailRow(code: 'MXN', name: 'Mexico', status: 'Wired · not shipped'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailRow extends StatelessWidget {
  final String code;
  final String name;
  final String status;
  const _RailRow({required this.code, required this.name, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: PfColors.surface,
        borderRadius: BorderRadius.circular(PfRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PfColors.offWhite,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              code,
              style: const TextStyle(
                color: PfColors.ink,
                fontSize: 13,
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
                  name,
                  style: const TextStyle(
                    color: PfColors.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: const TextStyle(color: PfColors.inkFaint, fontSize: 12),
                ),
              ],
            ),
          ),
          PfStatusChip(label: 'Soon', tone: PfTone.muted),
        ],
      ),
    );
  }
}
