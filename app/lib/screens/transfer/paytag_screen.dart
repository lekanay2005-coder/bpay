import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../../models/app_user.dart';
import '../../services/api_client.dart';
import '../../theme/payflex_tokens.dart';
import '../../theme/payflex_theme.dart';
import '../../widgets/pf_buttons.dart';
import '../../widgets/pf_motion.dart';
import '../../widgets/pf_states.dart';

/// PayFlex's own @handle directory (build brief §3 — no BMONI
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
  bool _saving = false;
  bool _saved = false;

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _currentTag = await _api.getMyPayTag(widget.user.id);
      if (_currentTag != null) _tagController.text = _currentTag!;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register() async {
    setState(() {
      _saving = true;
      _error = null;
      _saved = false;
    });
    try {
      await _api.registerPayTag(widget.user.id, _tagController.text);
      setState(() {
        _currentTag = _tagController.text;
        _saved = true;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: PayFlexTheme.light,
      child: Scaffold(
        backgroundColor: PfColors.offWhite,
        appBar: AppBar(
          title: const Text('PayTag'),
          backgroundColor: PfColors.offWhite,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _busy
                  ? const Center(child: PfBrandedLoader(size: 48))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        PfSpace.xl, PfSpace.lg, PfSpace.xl, 48,
                      ),
                      children: [
                        Text(
                          _currentTag == null
                              ? 'Pick your PayTag'
                              : 'Your PayTag',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'The @handle others use to send you money — no long '
                          'addresses, no typos.',
                          style: TextStyle(
                            color: PfColors.inkMuted,
                            fontSize: 13.5,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_currentTag != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 18),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: PfColors.navy,
                              borderRadius: BorderRadius.circular(PfRadius.md),
                              boxShadow: PfShadow.soft,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'PAYTAG · LIVE',
                                        style: TextStyle(
                                          color: PfColors.onNavyMuted,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '@$_currentTag',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Copy',
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: '@$_currentTag'),
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('PayTag copied'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    color: PfColors.onNavy,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        TextField(
                          controller: _tagController,
                          decoration: const InputDecoration(
                            prefixText: '@',
                            labelText: 'PayTag',
                            hintText: 'e.g. adaeze_92',
                            helperText: 'lowercase · 3–20 chars · letters, digits, underscore',
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_error != null) ...[
                          PfInlineError(message: _error!),
                          const SizedBox(height: 14),
                        ],
                        if (_saved) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: PfColors.successWash,
                              borderRadius: BorderRadius.circular(PfRadius.sm),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_outline_rounded,
                                    color: PfColors.success, size: 18),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Saved — people can send to this PayTag now.',
                                    style: TextStyle(
                                      color: PfColors.success,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        PfPrimaryButton(
                          label: _currentTag == null ? 'Save my PayTag' : 'Update PayTag',
                          busy: _saving,
                          onPressed: _saving ? null : _register,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
