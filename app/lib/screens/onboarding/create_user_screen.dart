import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/local_user_store.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Create your PayFlex account')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _firstName,
                decoration: const InputDecoration(labelText: 'First name'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _lastName,
                decoration: const InputDecoration(labelText: 'Last name'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (E.164, e.g. +2348000000001)',
                ),
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || !RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(v))
                    ? 'Enter E.164 format, e.g. +2348000000001'
                    : null,
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
