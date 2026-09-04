import 'package:flutter/material.dart';
import '../theme/payflex_tokens.dart';
import '../theme/payflex_theme.dart';

/// Every signing operation needs the user's PIN, and this app never
/// persists it in plaintext between screens (only the SDK's secure
/// storage holds a verifiable digest) — so anything that signs prompts
/// for it fresh. Returns null if the user cancels.
///
/// Flat navy surface, one field, one action — consistent with the wallet
/// surfaces the money moments live on.
Future<String?> promptForPin(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
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
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter your PIN',
                style: TextStyle(
                  color: PfColors.onNavy,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Signs this payment on your device. Nothing is sent without it.',
                style: TextStyle(color: PfColors.onNavyMuted, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: PfColors.onNavy,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: PfColors.navyRaised2,
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: PfColors.navyBorder),
                    borderRadius: BorderRadius.all(Radius.circular(PfRadius.sm)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Material(
                      color: Colors.transparent,
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: PfGradient.primary,
                          borderRadius: BorderRadius.circular(PfRadius.md),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(PfRadius.md),
                          onTap: () {
                            final text = controller.text;
                            Navigator.of(context).pop(text);
                          },
                          child: const SizedBox(
                            height: 46,
                            child: Center(
                              child: Text(
                                'Sign',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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
}
