import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/app_user.dart';
import '../../services/api_client.dart';
import '../../services/transfer_flow.dart';

/// Build brief section 4.1 — QR Pay. The QR payload is a short-lived,
/// HMAC-signed token minted by the backend (QrPayService); this screen
/// only generates/displays or scans/decodes it and hands off to the same
/// TransferService sign flow every other transfer mode uses.
class QrPayScreen extends StatefulWidget {
  final AppUser user;
  const QrPayScreen({super.key, required this.user});

  @override
  State<QrPayScreen> createState() => _QrPayScreenState();
}

class _QrPayScreenState extends State<QrPayScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Pay'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'My QR'), Tab(text: 'Scan to pay')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MyQrTab(user: widget.user),
          _ScanToPayTab(user: widget.user),
        ],
      ),
    );
  }
}

class _MyQrTab extends StatefulWidget {
  final AppUser user;
  const _MyQrTab({required this.user});

  @override
  State<_MyQrTab> createState() => _MyQrTabState();
}

class _MyQrTabState extends State<_MyQrTab> {
  final _api = ApiClient();
  final _amountController = TextEditingController();
  String _currency = 'NGN';
  String? _token;
  String? _error;
  bool _busy = false;

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await _api.generateQr(
        widget.user.id,
        amount: _amountController.text,
        currency: _currency,
      );
      setState(() => _token = token);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(labelText: 'Amount to request'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          DropdownButtonFormField<String>(
            value: _currency,
            decoration: const InputDecoration(labelText: 'Currency'),
            items: const [
              DropdownMenuItem(value: 'NGN', child: Text('NGN')),
              DropdownMenuItem(value: 'USD', child: Text('USD')),
            ],
            onChanged: (v) => setState(() => _currency = v!),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _generate, child: const Text('Generate QR')),
          const SizedBox(height: 24),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_token != null)
            Center(child: QrImageView(data: _token!, size: 240)),
        ],
      ),
    );
  }
}

class _ScanToPayTab extends StatefulWidget {
  final AppUser user;
  const _ScanToPayTab({required this.user});

  @override
  State<_ScanToPayTab> createState() => _ScanToPayTabState();
}

class _ScanToPayTabState extends State<_ScanToPayTab> {
  final _api = ApiClient();
  bool _handled = false;
  String? _error;
  String? _resultMessage;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    if (capture.barcodes.isEmpty) return;
    final token = capture.barcodes.first.rawValue;
    if (token == null) return;
    setState(() => _handled = true);

    try {
      final proposal = await _api.payQr(widget.user.id, token);
      if (!mounted) return;
      final signed = await signAndSubmitTransfer(context, _api, widget.user.id, proposal.id);
      setState(() {
        _resultMessage = signed == null
            ? 'Cancelled — proposal was created but not signed.'
            : 'Paid ${signed.amount} ${signed.currency}. Status: ${signed.status}.';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resultMessage != null || _error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _resultMessage ?? _error!,
                style: TextStyle(color: _error != null ? Colors.red : Colors.green),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => setState(() {
                  _handled = false;
                  _error = null;
                  _resultMessage = null;
                }),
                child: const Text('Scan another'),
              ),
            ],
          ),
        ),
      );
    }
    return MobileScanner(onDetect: _onDetect);
  }
}
