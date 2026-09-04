import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/app_user.dart';
import '../../models/transfer.dart';
import '../../services/api_client.dart';
import '../../services/transfer_flow.dart';
import '../../services/retry.dart';
import '../../theme/payflex_tokens.dart';
import '../../theme/payflex_theme.dart';
import '../../utils/format.dart';
import '../../utils/money.dart';
import '../../widgets/pf_buttons.dart';
import '../../widgets/pf_flow.dart';
import '../../widgets/pf_mark.dart';
import '../../widgets/pf_motion.dart';
import '../../widgets/pf_states.dart';
import 'send_money_screen.dart' show humanTransferStatus, transferTone;

/// Build brief §4.1 — QR Pay. The QR payload is a short-lived, HMAC-signed
/// token minted by the backend (QrPayService); this screen only generates/
/// displays or scans/decodes it and hands off to the same TransferService
/// sign flow every other transfer mode uses.
///
/// Design (brief §2): navy scanner chrome; the scanner viewfinder frame
/// morphs into the confirm-payment card via a shared Hero on the QR frame
/// (tag `pf-qr-frame`) instead of a hard cut; the payoff is the ribbon
/// confirmation screen.
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
    return Theme(
      data: PayFlexTheme.dark,
      child: Scaffold(
        backgroundColor: PfColors.navy,
        appBar: AppBar(
          title: const Text('QR Pay'),
          backgroundColor: PfColors.navy,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: PfColors.emerald,
            labelColor: PfColors.onNavy,
            unselectedLabelColor: PfColors.onNavyMuted,
            dividerColor: PfColors.navyBorder,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
      _token = null;
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(PfSpace.xl, PfSpace.xl, PfSpace.xl, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Request money with a QR code',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text(
                'Set an amount and share the code — the payer scans and signs '
                'from their own device.',
                style: TextStyle(color: PfColors.onNavyMuted, fontSize: 13.5, height: 1.45),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Amount to request',
                        hintText: '0.00',
                        filled: true,
                        fillColor: PfColors.navyRaised2,
                        border: const OutlineInputBorder(
                          borderSide: BorderSide(color: PfColors.navyBorder),
                          borderRadius: BorderRadius.all(Radius.circular(PfRadius.sm)),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        color: PfColors.onNavy,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _currency,
                    dropdownColor: PfColors.navyRaised2,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(color: PfColors.onNavy),
                    items: const [
                      DropdownMenuItem(value: 'NGN', child: Text('NGN')),
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                    ],
                    onChanged: (v) => setState(() => _currency = v!),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PfPrimaryButton(
                label: _token == null ? 'Generate QR' : 'Regenerate QR',
                busy: _busy,
                onPressed: _busy ? null : _generate,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                PfInlineError(message: _error!),
              ],
              if (_token != null) ...[
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(PfRadius.lg),
                    boxShadow: PfShadow.onDark,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: QrImageView(
                          data: _token!,
                          size: 200,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF0A1330),
                          ),
                        ),
                      ),
                      // The flat QR-corner signature frame around the code.
                      const IgnorePointer(
                        child: SizedBox(
                          width: 248,
                          height: 248,
                          child: PfQrCorners(
                            color: Colors.white,
                            thickness: 3.5,
                            length: 0.14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: PfColors.navyRaised2,
                      borderRadius: BorderRadius.circular(PfRadius.pill),
                    ),
                    child: Text(
                      '${formatMoney(_amountController.text, _currency)} request',
                      style: const TextStyle(
                        color: PfColors.onNavy,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The code expires shortly and can only be paid once. '
                  'Keep it on screen or send it to the payer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: PfColors.onNavyFaint, fontSize: 12, height: 1.45),
                ),
              ],
            ],
          ),
        ),
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
  bool _offline = false;
  String? _error;
  String? _pendingToken;
  bool _opening = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    if (capture.barcodes.isEmpty) return;
    final token = capture.barcodes.first.rawValue;
    if (token == null) return;
    setState(() => _handled = true);
    await _pay(token);
  }

  Future<void> _pay(String token) async {
    setState(() {
      _offline = false;
      _error = null;
      _pendingToken = token;
      _opening = true;
    });
    try {
      // Offline handling: transport-level failures (no signal mid-scan,
      // e.g. inside a building) retry a few times before giving up, so a
      // brief connectivity blip doesn't force a full re-scan.
      final proposal = await withRetry(() => _api.payQr(widget.user.id, token));
      if (!mounted) return;
      setState(() => _opening = false);
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _ConfirmPaymentScreen(user: widget.user, proposal: proposal),
        ),
      );
    } on OfflineException catch (e) {
      setState(() {
        _opening = false;
        _offline = true;
        _error = e.toString();
      });
    } catch (e) {
      setState(() {
        _opening = false;
        _error = e.toString();
      });
    } finally {
      // Ready for the next scan either way.
      if (mounted) {
        setState(() {
          _handled = false;
          _pendingToken = null;
          _opening = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_offline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: PfEmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'You\u2019re offline',
            message: _error ?? 'Check your connection — the QR is still on screen.',
            actionLabel: 'Retry',
            onAction: () => _pay(_pendingToken!),
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: PfEmptyState(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Couldn\u2019t open that payment',
            message: _error!,
            actionLabel: 'Scan again',
            onAction: () => setState(() => _error = null),
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(onDetect: _onDetect),
        // The viewfinder frame — shares a Hero tag with the confirm
        // screen so the scan → confirm transition morphs the frame
        // instead of cutting hard (brief §2, item 3).
        Center(
          child: Hero(
            tag: 'pf-qr-frame',
            child: SizedBox(
              width: 264,
              height: 264,
              child: PfQrCorners(
                color: Colors.white,
                thickness: 4,
                length: 0.16,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 64,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: PfColors.navy.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(PfRadius.pill),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.center_focus_weak_rounded, color: PfColors.onNavyMuted, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Point at a PayFlex QR code',
                    style: TextStyle(color: PfColors.onNavy, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_opening)
          Container(
            color: PfColors.navy.withValues(alpha: 0.85),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PfBrandedLoader(size: 56),
                  SizedBox(height: 18),
                  Text(
                    'Opening payment…',
                    style: TextStyle(color: PfColors.onNavyMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Confirm-and-sign sheet reached from a successful scan. Its QR frame
/// (Hero, same tag as the viewfinder) morphs in from the scanner.
class _ConfirmPaymentScreen extends StatefulWidget {
  final AppUser user;
  final Proposal proposal;
  const _ConfirmPaymentScreen({required this.user, required this.proposal});

  @override
  State<_ConfirmPaymentScreen> createState() => _ConfirmPaymentScreenState();
}

class _ConfirmPaymentScreenState extends State<_ConfirmPaymentScreen> {
  final _api = ApiClient();
  bool _signing = false;
  String? _error;

  Future<void> _confirmAndPay() async {
    setState(() {
      _signing = true;
      _error = null;
    });
    try {
      final signed = await signAndSubmitTransfer(
        context,
        _api,
        widget.user.id,
        widget.proposal.id,
      );
      if (signed == null) {
        setState(() {
          _signing = false;
          _error = 'Signature cancelled — nothing was submitted.';
        });
        return;
      }
      if (!mounted) return;
      final outcome = PfFlowOutcome(
        headline: 'Paid',
        amount: signed.amount,
        currency: signed.currency,
        caption: 'QR payment · ${shortRef(widget.proposal.toUserId ?? widget.proposal.toAddress ?? 'wallet')}',
        reference: signed.id,
        statusLabel: humanTransferStatus(signed.status),
        statusTone: transferTone(signed.status),
        methodLabel: 'QR Pay',
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PfConfirmationScreen(outcome: outcome, receipt: outcome),
        ),
      );
    } catch (e) {
      setState(() {
        _signing = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.proposal;
    final recipient = shortRef(p.toUserId ?? p.toAddress ?? 'wallet');
    return Theme(
      data: PayFlexTheme.dark,
      child: Scaffold(
        backgroundColor: PfColors.navy,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: PfColors.onNavy),
            onPressed: _signing ? null : () => Navigator.of(context).pop(false),
          ),
          title: const Text('Confirm payment'),
          backgroundColor: PfColors.navy,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PfSpace.xl, vertical: PfSpace.lg),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Hero(
                          tag: 'pf-qr-frame',
                          child: SizedBox(
                            width: 168,
                            height: 168,
                            child: PfQrCorners(
                              color: Colors.white,
                              thickness: 3,
                              length: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'You\u2019re about to pay',
                          style: TextStyle(color: PfColors.onNavyMuted, fontSize: 13.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatMoney(p.amount, p.currency),
                          style: PfMoneyType.large.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'to $recipient',
                          style: const TextStyle(color: PfColors.onNavyMuted, fontSize: 13.5),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: PfColors.navyRaised,
                            borderRadius: BorderRadius.circular(PfRadius.md),
                            border: Border.all(color: PfColors.navyBorder),
                          ),
                          child: Column(
                            children: [
                              _ConfirmRow(label: 'Method', value: 'QR Pay'),
                              const SizedBox(height: 10),
                              _ConfirmRow(label: 'Amount', value: formatMoney(p.amount, p.currency)),
                              const SizedBox(height: 10),
                              _ConfirmRow(label: 'To', value: recipient),
                              const SizedBox(height: 10),
                              _ConfirmRow(label: 'Reference', value: shortRef(p.id)),
                            ],
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          PfInlineError(message: _error!),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_signing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PfBrandedLoader(size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Waiting for your signature…',
                          style: TextStyle(color: PfColors.onNavyMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                PfPrimaryButton(
                  label: 'Confirm & pay',
                  icon: Icons.north_east_rounded,
                  busy: _signing,
                  onPressed: _signing ? null : _confirmAndPay,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  const _ConfirmRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: PfColors.onNavyMuted, fontSize: 12.5),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: PfColors.onNavy,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
