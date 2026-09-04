import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/api_client.dart';
import '../../services/wallet_service.dart';
import '../wallet_home_screen.dart';

/// Runs steps 2-5 of the build brief's core lifecycle (section 2.1):
/// on-device owner wallet -> owner-proof challenge -> on-device signature
/// -> create-managed smart wallet. Everything that touches key material
/// goes through WalletService (bmoni_embedded_sdk); everything that
/// touches BMONI goes through ApiClient (the backend's BmoniClient).
class PinAndWalletScreen extends StatefulWidget {
  final AppUser user;
  const PinAndWalletScreen({super.key, required this.user});

  @override
  State<PinAndWalletScreen> createState() => _PinAndWalletScreenState();
}

enum _Step { setPin, provisionWallet, chooseCurrency, done }

class _PinAndWalletScreenState extends State<PinAndWalletScreen> {
  final _api = ApiClient();
  final _pinController = TextEditingController();
  _Step _step = _Step.setPin;
  String? _error;
  bool _busy = false;
  List<String> _currencies = [];
  String? _selectedCurrency;
  String? _ownerAddress;
  String? _pin;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final hasPin = await WalletService.hasPin();
    final hasWallet = await WalletService.hasWallet();
    if (hasPin && hasWallet) {
      _ownerAddress = await WalletService.currentAddress();
      setState(() => _step = _Step.chooseCurrency);
      await _loadCurrencies();
    } else {
      setState(() => _step = _Step.setPin);
    }
  }

  Future<void> _submitPin() async {
    if (_pinController.text.length != 6) {
      setState(() => _error = 'PIN must be exactly 6 digits');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await WalletService.hasPin()) {
        await WalletService.setPin(_pinController.text);
      }
      _pin = _pinController.text;
      setState(() => _step = _Step.provisionWallet);
      await _provisionWallet();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _provisionWallet() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String address;
      if (await WalletService.hasWallet()) {
        address = (await WalletService.currentAddress())!;
      } else {
        address = await WalletService.provisionWallet();
      }
      _ownerAddress = address;
      await _api.setOwnerAddress(widget.user.id, address);
      setState(() => _step = _Step.chooseCurrency);
      await _loadCurrencies();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadCurrencies() async {
    try {
      final currencies = await _api.getSupportedCurrencies();
      setState(() {
        _currencies = currencies;
        // NGN/USD are this build's priority rails (see build brief section
        // 2.3) — default to the NGN stablecoin when available.
        _selectedCurrency = currencies.contains('CNGN') ? 'CNGN' : currencies.first;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _createSmartWallet() async {
    if (_selectedCurrency == null || _ownerAddress == null || _pin == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await _api.requestOwnerProofChallenge(
        widget.user.id,
        _selectedCurrency!,
      );
      final signature = await WalletService.signChallenge(challenge.message, _pin!);
      final wallet = await _api.createSmartWallet(
        widget.user.id,
        currency: _selectedCurrency!,
        ownerProofChallengeId: challenge.challengeId,
        ownerProofSignature: signature,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WalletHomeScreen(user: widget.user, initialWallet: wallet),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secure your wallet')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    if (_error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => setState(() => _error = null), child: const Text('Retry')),
        ],
      );
    }
    if (_busy) {
      return const Center(child: CircularProgressIndicator());
    }
    switch (_step) {
      case _Step.setPin:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Set a 6-digit PIN to protect your wallet on this device.'),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'PIN'),
            ),
            FilledButton(onPressed: _submitPin, child: const Text('Set PIN')),
          ],
        );
      case _Step.provisionWallet:
        return const Center(child: CircularProgressIndicator());
      case _Step.chooseCurrency:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Owner address: $_ownerAddress', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            const Text('Choose your first wallet currency:'),
            if (_currencies.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              DropdownButton<String>(
                value: _selectedCurrency,
                items: _currencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCurrency = v),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _currencies.isEmpty ? null : _createSmartWallet,
              child: const Text('Create smart wallet'),
            ),
          ],
        );
      case _Step.done:
        return const SizedBox.shrink();
    }
  }
}
