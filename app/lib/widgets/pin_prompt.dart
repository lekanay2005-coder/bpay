import 'package:flutter/material.dart';

/// Every signing operation needs the user's PIN, and this app never
/// persists it in plaintext between screens (only the SDK's secure
/// storage holds a verifiable digest) — so anything that signs prompts
/// for it fresh. Returns null if the user cancels.
Future<String?> promptForPin(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Enter your PIN'),
      content: TextField(
        controller: controller,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}
