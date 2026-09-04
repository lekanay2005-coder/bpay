import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/api_client.dart';

/// PayFlex's own @handle directory (build brief section 3 — no BMONI
/// equivalent). Registering here is what makes SendMoneyScreen's PayTag
/// mode resolvable for other users.
class PayTagScreen extends StatefulWidget {
  final AppUser user;
  const PayTagScreen({super.key, required this.user});

  @override
  State<PayTagScreen> createState() => _PayTagScreenState();
}

class _PayTagScreenState extends State<PayTagScreen> {
  final _api = ApiClient();
  final _tagController = TextEditingController();
  String? _currentTag;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _currentTag = await _api.getMyPayTag(widget.user.id);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.registerPayTag(widget.user.id, _tagController.text);
      setState(() => _currentTag = _tagController.text);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PayTag')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _busy
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_currentTag != null) ...[
                    Text('Your PayTag', style: Theme.of(context).textTheme.titleMedium),
                    Text('@$_currentTag', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 24),
                    const Text('Change it:'),
                  ] else
                    const Text('Pick a PayTag so others can send you money by @handle.'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      prefixText: '@',
                      labelText: 'lowercase, 3-20 chars, letters/digits/underscore',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  FilledButton(onPressed: _register, child: const Text('Save PayTag')),
                ],
              ),
      ),
    );
  }
}
