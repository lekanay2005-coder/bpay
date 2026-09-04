import 'package:flutter/material.dart';

/// Build brief section 2.3 / Phase 5: CAD/EUR/MXN are "structurally wired
/// but not UI-polished" — the backend endpoints exist
/// (OnboardingController's start-canada/start-monerium/latam-mx routes)
/// but there's deliberately no real onboarding flow here yet, matching
/// the brief's own reduced ambition for these three rails.
class StubRailsScreen extends StatelessWidget {
  const StubRailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More currencies')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: const [
            Text(
              'CAD, EUR, and MXN are wired on the backend but not yet built '
              'out here — the same way NGN and USD are, once there\'s a '
              'reason to prioritize them.',
            ),
            SizedBox(height: 16),
            ListTile(leading: Icon(Icons.hourglass_empty), title: Text('Canada (CAD) — coming soon')),
            ListTile(leading: Icon(Icons.hourglass_empty), title: Text('Europe (EUR / Monerium) — coming soon')),
            ListTile(leading: Icon(Icons.hourglass_empty), title: Text('Mexico (MXN) — coming soon')),
          ],
        ),
      ),
    );
  }
}
