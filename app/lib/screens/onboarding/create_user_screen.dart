import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/local_user_store.dart';
import '../../theme/payflex_tokens.dart';
import '../../theme/payflex_theme.dart';
import '../../widgets/pf_buttons.dart';
import '../../widgets/pf_states.dart';
import 'pin_and_wallet_screen.dart';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _api = ApiClient();
  final _store = LocalUserStore();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final user = await _api.createUser(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        phoneNumber: _phone.text.trim(),
      );
      await _store.setAppUserId(user.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PinAndWalletScreen(user: user)),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: PayFlexTheme.light,
      child: Scaffold(
        backgroundColor: PfColors.offWhite,
        appBar: AppBar(
          title: const Text('Create your account'),
          backgroundColor: PfColors.offWhite,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    PfSpace.xl, PfSpace.lg, PfSpace.xl, 40,
                  ),
                  children: [
                    Text(
                      'Create your account',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your details open the wallet — KYC documents come '
                      'later, one step at a time.',
                      style: TextStyle(
                        color: PfColors.inkMuted,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _firstName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _lastName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Last name',
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Enter a valid email'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        hintText: '+2348000000001',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          (v == null || !RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(v))
                              ? 'Use E.164 format, e.g. +2348000000001'
                              : null,
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        'Phone numbers are E.164 (country code first) — used '
                        'for verification and recovery only.',
                        style: TextStyle(
                          color: PfColors.inkFaint,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (_error != null) ...[
                      PfInlineError(message: _error!),
                      const SizedBox(height: 14),
                    ],
                    PfPrimaryButton(
                      label: 'Continue',
                      icon: Icons.arrow_forward_rounded,
                      busy: _submitting,
                      onPressed: _submitting ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
