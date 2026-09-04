import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/api_client.dart';
import '../../services/wallet_service.dart';
import '../../theme/payflex_tokens.dart';
import '../../theme/payflex_theme.dart';
import '../../widgets/pf_balance_card.dart';
import '../../widgets/pf_buttons.dart';
import '../../widgets/pf_motion.dart';
import '../../widgets/pf_states.dart';
import '../kyc/kyc_wizard_screen.dart';

/// Runs steps 2-5 of the build brief's core lifecycle (section 2.1):
/// on-device owner wallet -> owner-proof challenge -> on-device signature
/// -> create-managed smart wallet. Everything that touches key material
/// goes through WalletService (bmoni_embedded_sdk); everything that
/// touches BMONI goes through ApiClient (the backend's BmoniClient).
///
/// Rendered as a navy "secure your wallet" moment (design brief §1) —
/// the part of the flow closest to the key material, so it gets the
/// wallet treatment rather than the paperwork treatment.
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
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

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
        // NGN/USD are this build's priority rails (build brief §2.3) —
        // default to the NGN stablecoin when available.
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
          builder: (_) => KycWizardScreen(
            user: widget.user,
            // `wallet.currency` is BMONI's fiat label (e.g. "NGN"), not
            // the stablecoin code that was sent in the create request —
            // see SmartWallet DTO doc comment on the backend.
            currency: wallet.currency,
            smartWalletId: wallet.id,
          ),
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
    return Theme(
      data: PayFlexTheme.dark,
      child: Scaffold(
        backgroundColor: PfColors.navy,
        appBar: AppBar(
          title: const Text('Secure your wallet'),
          backgroundColor: PfColors.navy,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(PfSpace.xl),
                child: _buildStep(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _stepTitle => switch (_step) {
        _Step.setPin => 'Secure your wallet',
        _Step.provisionWallet => 'Generating your key',
        _Step.chooseCurrency => 'Choose your first wallet',
        _Step.done => 'Done',
      };

  String get _stepSubtitle => switch (_step) {
        _Step.setPin =>
          'A 6-digit PIN gates every signature on this device. PayFlex never '
              'stores it — only a verifiable digest lives in secure storage.',
        _Step.provisionWallet =>
          'Creating an on-device EVM owner key. It never leaves this phone.',
        _Step.chooseCurrency => 'Your wallet settles on BMONI smart-wallet rails.',
        _Step.done => '',
      };

  Widget _buildStep() {
    if (_error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PfInlineError(message: _error!, onRetry: () => setState(() => _error = null)),
          const SizedBox(height: 16),
        ],
      );
    }
    if (_busy && _step == _Step.provisionWallet) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          PfBrandedLoader(size: 64),
          SizedBox(height: 22),
          Text(
            'Generating your on-device key…',
            style: TextStyle(color: PfColors.onNavyMuted, fontSize: 14),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _stepTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          _stepSubtitle,
          style: const TextStyle(
            color: PfColors.onNavyMuted,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 26),
        switch (_step) {
          _Step.setPin => _pinStep(),
          _Step.chooseCurrency => _currencyStep(),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }

  Widget _pinStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: PfColors.onNavy,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 10,
          ),
          decoration: InputDecoration(
            labelText: 'PIN',
            counterText: '',
            filled: true,
            fillColor: PfColors.navyRaised2,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.shield_outlined, size: 14, color: PfColors.onNavyFaint),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Used to sign every transfer — it never leaves this device.',
                style: TextStyle(
                  color: PfColors.onNavyFaint,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        PfPrimaryButton(
          label: 'Set PIN',
          icon: Icons.lock_outline_rounded,
          busy: _busy,
          onPressed: _busy ? null : _submitPin,
        ),
      ],
    );
  }

  Widget _currencyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_ownerAddress != null)
          PfPanel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            radius: PfRadius.sm,
            showShadow: false,
            child: Row(
              children: [
                const Text(
                  'Owner address',
                  style: TextStyle(color: PfColors.onNavyMuted, fontSize: 12.5),
                ),
                const Spacer(),
                Flexible(
                  child: SelectableText(
                    _ownerAddress!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PfColors.onNavy,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        if (_currencies.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: PfBrandedLoader(size: 40),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._currencies.map((c) {
                final selected = _selectedCurrency == c;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(PfRadius.md),
                    border: Border.all(
                      color: selected ? PfColors.emerald : PfColors.navyBorder,
                      width: selected ? 1.5 : 1,
                    ),
                    color: selected ? PfColors.emerald.withValues(alpha: 0.08) : PfColors.navyRaised,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(PfRadius.md),
                    onTap: () => setState(() => _selectedCurrency = c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected ? PfColors.emerald : PfColors.onNavyFaint,
                                width: 2,
                              ),
                            ),
                            child: selected
                                ? Center(
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: PfColors.emerald,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c,
                                  style: const TextStyle(
                                    color: PfColors.onNavy,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _friendlyCurrency(c),
                                  style: const TextStyle(
                                    color: PfColors.onNavyMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: PfColors.emerald,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 14),
              PfPrimaryButton(
                label: 'Create wallet',
                icon: Icons.arrow_forward_rounded,
                busy: _busy,
                onPressed: _currencies.isEmpty ? null : _createSmartWallet,
              ),
            ],
          ),
      ],
    );
  }

  String _friendlyCurrency(String stablecoin) {
    return switch (stablecoin) {
      'CNGN' => 'Nigerian naira · NGN',
      'USDB' => 'US dollar · USD',
      'CADC' => 'Canadian dollar · CAD',
      'EURe' => 'Euro · EUR',
      'MEXe' => 'Mexican peso · MXN',
      _ => stablecoin,
    };
  }
}
