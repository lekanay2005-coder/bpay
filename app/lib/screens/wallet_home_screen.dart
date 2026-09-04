import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/kyc.dart';
import '../services/api_client.dart';
import '../services/retry.dart';
import '../theme/payflex_tokens.dart';
import '../theme/payflex_theme.dart';
import '../utils/format.dart';
import '../utils/money.dart';
import '../widgets/pf_balance_card.dart';
import '../widgets/pf_buttons.dart';
import '../widgets/pf_mark.dart';
import '../widgets/pf_motion.dart';
import '../widgets/pf_states.dart';
import 'settings_screen.dart';
import 'transfer/send_money_screen.dart';
import 'transfer/qr_pay_screen.dart';
import 'transfer/paytag_screen.dart';
import 'savings/savings_screen.dart';
import 'loans/loans_screen.dart';
import 'agent/agent_screen.dart';
import 'split_bill/split_bill_screen.dart';
import 'links/send_via_link_screen.dart';
import 'stub_rails_screen.dart';

/// Wallet home — the dark navy anchor of the app (design brief §1).
/// Layout, top to bottom: greeting header with the brand lockup and
/// quick icons, the flagship gradient balance card whose number counts
/// up once per session, secondary wallets, Send / QR Pay, and a recent
/// activity preview. Everything else hangs off the header menu.
class WalletHomeScreen extends StatefulWidget {
  final AppUser user;
  const WalletHomeScreen({super.key, required this.user});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

/// Priority order for deciding which wallet anchors the balance card.
const _walletPriority = ['NGN', 'USD', 'CAD', 'EUR', 'MXN'];

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  final _api = ApiClient();
  List<SmartWallet> _wallets = [];
  Map<String, Balance> _balancesByWalletId = {};
  List<Transaction> _recent = [];
  bool _loading = true;
  bool _offline = false;
  String? _error;

  // Balance count-up runs once per app session, not on every refresh.
  static bool _balanceRevealed = false;

  SmartWallet? get _primary {
    final sorted = [..._wallets]..sort((a, b) {
        final ia = _walletPriority.indexOf(a.currency);
        final ib = _walletPriority.indexOf(b.currency);
        final ra = ia == -1 ? 99 : ia;
        final rb = ib == -1 ? 99 : ib;
        return ra.compareTo(rb);
      });
    return sorted.isEmpty ? null : sorted.first;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _offline = false;
      _error = null;
    });
    try {
      // Offline handling: a stale wallet home from a lost connection reads
      // as "no wallets," which is misleading — retry transport failures
      // before surfacing an error (build brief §5 polish).
      final wallets = await withRetry(() => _api.listWallets(widget.user.id));
      final balances = await withRetry(() => _api.listBalances(widget.user.id));
      var recent = <Transaction>[];
      final balanceMap = {for (final b in balances) b.smartWalletId: b};
      final primaryId = balanceMap.keys.isEmpty
          ? (wallets.isEmpty ? null : wallets.first.id)
          : balanceMap.keys.first;
      if (primaryId != null) {
        try {
          recent = await _api.getTransactions(widget.user.id, primaryId);
        } catch (_) {
          // History is a preview — a failure here shouldn't sink the card.
          recent = [];
        }
      }
      setState(() {
        _wallets = wallets;
        _balancesByWalletId = balanceMap;
        _recent = recent;
      });
    } on OfflineException catch (e) {
      setState(() {
        _offline = true;
        _error = e.toString();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: PayFlexTheme.dark,
      child: Scaffold(
        backgroundColor: PfColors.navy,
        body: Stack(
          children: [
            // Flat watermark of the ribbon, low opacity, behind content.
            const Positioned(
              top: 120,
              right: -140,
              child: PfWatermark(size: 380),
            ),
            SafeArea(
              child: Column(
                children: [
                  _header(),
                  Expanded(child: _body()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final firstName = widget.user.firstName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(PfSpace.xl, PfSpace.lg, PfSpace.md, 4),
      child: Row(
        children: [
          Image.asset(
            'assets/brand/payflex_logo.png',
            width: 34,
            height: 34,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const PfMarkIcon(size: 30, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $firstName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PfColors.onNavy,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'Your wallet',
                  style: TextStyle(color: PfColors.onNavyMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          _HeaderIconButton(
            icon: Icons.alternate_email_outlined,
            tooltip: 'PayTag',
            onTap: () => _push(PayTagScreen(user: widget.user)),
          ),
          _HeaderIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Settings',
            onTap: () => _push(SettingsScreen(user: widget.user)),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: PfColors.onNavy,
              size: 24,
            ),
            tooltip: 'More',
            color: PfColors.navyRaised2,
            surfaceTintColor: Colors.transparent,
            onSelected: (value) {
              final screen = switch (value) {
                'savings' => SavingsScreen(user: widget.user),
                'loans' => LoansScreen(user: widget.user),
                'agent' => AgentScreen(user: widget.user),
                'split-bill' => SplitBillScreen(user: widget.user),
                'send-via-link' => SendViaLinkScreen(user: widget.user),
                'more-currencies' => const StubRailsScreen(),
                _ => null,
              };
              if (screen != null) _push(screen);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'savings', child: Text('Savings goals')),
              PopupMenuItem(value: 'loans', child: Text('Loans')),
              PopupMenuItem(value: 'agent', child: Text('Agent mode')),
              PopupMenuItem(value: 'split-bill', child: Text('Split bills')),
              PopupMenuItem(value: 'send-via-link', child: Text('Send via link')),
              PopupMenuItem(value: 'more-currencies', child: Text('More currencies')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _wallets.isEmpty) {
      return const Center(child: PfBrandedLoader(size: 56));
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: PfColors.emerald,
      backgroundColor: PfColors.navyRaised2,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(PfSpace.xl, 12, PfSpace.xl, 120),
        children: [
          if (_offline)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PfInlineError(
                message: _error ?? "You're offline — showing what we cached.",
                onRetry: _load,
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PfInlineError(message: _error!, onRetry: _load),
            ),
          if (_wallets.isEmpty && _error == null)
            PfEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No wallets yet',
              message: 'Finish onboarding and your first wallet will appear here.',
            ),
          ..._walletSection(),
          const SizedBox(height: 6),
          _actionsRow(),
          if (_recent.isNotEmpty) ...[
            const SizedBox(height: 28),
            _recentHeader(),
            const SizedBox(height: 8),
            ..._recent.take(5).map((t) => _RecentTxRow(transaction: t)),
            const SizedBox(height: 4),
            if (_primary != null)
              TextButton(
                onPressed: () => _push(TransactionHistoryScreen(
                  appUserId: widget.user.id,
                  smartWalletId: _primary!.id,
                  currency: _primary!.currency,
                )),
                child: const Text('View all activity'),
              ),
          ],
        ],
      ),
    );
  }

  List<Widget> _walletSection() {
    final primary = _primary;
    if (primary == null) return const [];
    final rest = _wallets.where((w) => w.id != primary.id).toList();
    return [
      PfBalanceCard(
        currency: primary.currency,
        amount: _balancesByWalletId[primary.id]?.balance ?? '0',
        countUp: !_balanceRevealed,
        statusLabel: 'Active',
        address: primary.walletAddress,
        onTap: () => _push(TransactionHistoryScreen(
          appUserId: widget.user.id,
          smartWalletId: primary.id,
          currency: primary.currency,
        )),
      ),
      const SizedBox(height: 6),
      if (!_balanceRevealed) _balanceRevealed = true,
      ...rest.map(
        (w) => PfWalletRow(
          currency: w.currency,
          amount: _balancesByWalletId[w.id]?.balance ?? '',
          address: w.walletAddress,
          active: w.isActive,
          onTap: () => _push(TransactionHistoryScreen(
            appUserId: widget.user.id,
            smartWalletId: w.id,
            currency: w.currency,
          )),
        ),
      ),
    ];
  }

  Widget _actionsRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 128,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PfRadius.md),
              boxShadow: PfShadow.button,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(PfRadius.md),
              child: Material(
                color: Colors.transparent,
                child: Ink(
                  decoration: const BoxDecoration(gradient: PfGradient.primary),
                  child: InkWell(
                    onTap: () => _push(SendMoneyScreen(user: widget.user)),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.north_east_rounded, color: Colors.white, size: 22),
                          Spacer(),
                          Text(
                            'Send money',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'PayTag · user ID · address',
                            style: TextStyle(
                              color: Color(0xB3FFFFFF),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 128,
            decoration: BoxDecoration(
              color: PfColors.navyRaised,
              borderRadius: BorderRadius.circular(PfRadius.md),
              border: Border.all(color: PfColors.navyBorder),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _push(QrPayScreen(user: widget.user)),
                borderRadius: BorderRadius.circular(PfRadius.md),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.qr_code_rounded, color: PfColors.onNavy, size: 22),
                      Spacer(),
                      Text(
                        'QR Pay',
                        style: TextStyle(
                          color: PfColors.onNavy,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Scan or share a request',
                        style: TextStyle(
                          color: PfColors.onNavyMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _recentHeader() {
    final primary = _primary;
    return Row(
      children: [
        const Expanded(child: PfSectionHeader(title: 'Recent activity')),
        if (primary != null)
          TextButton(
            onPressed: () => _push(TransactionHistoryScreen(
              appUserId: widget.user.id,
              smartWalletId: primary.id,
              currency: primary.currency,
            )),
            child: const Text('See all'),
          ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: PfColors.onNavy, size: 22),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}

/// A single recent-activity row: flat direction glyph in a quiet circle,
/// formatted amount, status + relative date.
class _RecentTxRow extends StatelessWidget {
  final Transaction transaction;
  const _RecentTxRow({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final isOut = t.direction.toUpperCase() == 'OUT';
    final tone = t.status.toUpperCase() == 'FAILED'
        ? PfTone.warn
        : t.status.toUpperCase() == 'SUCCESS' || t.status.toUpperCase() == 'COMPLETED'
            ? PfTone.success
            : PfTone.info;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isOut ? PfColors.navyRaised2 : PfColors.emerald.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOut ? Icons.north_east_rounded : Icons.south_west_rounded,
              size: 17,
              color: isOut ? PfColors.onNavyMuted : PfColors.emerald,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOut ? 'Sent' : 'Received',
                  style: const TextStyle(
                    color: PfColors.onNavy,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${t.status} · ${formatTimestamp(t.createdAt)}',
                  style: const TextStyle(color: PfColors.onNavyFaint, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Text(
            '${isOut ? '−' : '+'}${formatMoney(t.amount, t.currency)}',
            style: TextStyle(
              color: isOut ? PfColors.onNavyMuted : Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/// Full transaction history for one wallet — pushed from the balance
/// card / wallet rows. Designed empty + error states, never raw.
class TransactionHistoryScreen extends StatefulWidget {
  final String appUserId;
  final String smartWalletId;
  final String currency;

  const TransactionHistoryScreen({
    super.key,
    required this.appUserId,
    required this.smartWalletId,
    required this.currency,
  });

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final _api = ApiClient();
  List<Transaction> _transactions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final txns = await withRetry(
        () => _api.getTransactions(widget.appUserId, widget.smartWalletId),
      );
      if (mounted) {
        setState(() {
          _transactions = txns;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: PayFlexTheme.dark,
      child: Scaffold(
        backgroundColor: PfColors.navy,
        appBar: AppBar(
          title: Text('${widget.currency} · Activity'),
          backgroundColor: PfColors.navy,
        ),
        body: _loading
            ? const Center(child: PfBrandedLoader(size: 52))
            : _error != null
                ? PfEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load activity",
                    message: _error!,
                    actionLabel: 'Try again',
                    onAction: _load,
                  )
                : _transactions.isEmpty
                    ? PfEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No activity yet',
                        message:
                            'Payments in and out of your ${widget.currency} wallet '
                            'will appear here with their receipts.',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: PfColors.emerald,
                        backgroundColor: PfColors.navyRaised2,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                          itemCount: _transactions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (context, i) => _HistoryRow(
                            transaction: _transactions[i],
                            onTap: () => _showTxDialog(_transactions[i]),
                          ),
                        ),
                      ),
      ),
    );
  }

  void _showTxDialog(Transaction t) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final isOut = t.direction.toUpperCase() == 'OUT';
        return Theme(
          data: PayFlexTheme.dark,
          child: Dialog(
            backgroundColor: PfColors.navyRaised,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PfRadius.lg),
              side: const BorderSide(color: PfColors.navyBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isOut ? 'Money sent' : 'Money received',
                    style: const TextStyle(
                      color: PfColors.onNavy,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatMoney(t.amount, t.currency),
                    style: PfMoneyType.medium.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(color: PfColors.onNavyMuted, fontSize: 13),
                      ),
                      const Spacer(),
                      PfStatusChip(label: t.status, tone: PfTone.muted),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        'Time',
                        style: TextStyle(color: PfColors.onNavyMuted, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        formatTimestampLong(t.createdAt),
                        style: const TextStyle(
                          color: PfColors.onNavy,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        'Reference',
                        style: TextStyle(color: PfColors.onNavyMuted, fontSize: 13),
                      ),
                      const Spacer(),
                      Flexible(
                        child: SelectableText(
                          t.id,
                          style: const TextStyle(
                            color: PfColors.onNavy,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  PfPrimaryButton(
                    label: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onTap;
  const _HistoryRow({required this.transaction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final isOut = t.direction.toUpperCase() == 'OUT';
    return Container(
      decoration: BoxDecoration(
        color: PfColors.navyRaised,
        borderRadius: BorderRadius.circular(PfRadius.md),
        border: Border.all(color: PfColors.navyBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PfRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isOut ? PfColors.navyRaised2 : PfColors.emerald.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isOut ? Icons.north_east_rounded : Icons.south_west_rounded,
                    size: 16,
                    color: isOut ? PfColors.onNavyMuted : PfColors.emerald,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOut ? 'Sent' : 'Received',
                        style: const TextStyle(
                          color: PfColors.onNavy,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatTimestamp(t.createdAt),
                        style: const TextStyle(
                          color: PfColors.onNavyFaint,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isOut ? '−' : '+'}${formatMoney(t.amount, t.currency)}',
                      style: TextStyle(
                        color: isOut ? PfColors.onNavyMuted : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      t.status,
                      style: const TextStyle(
                        color: PfColors.onNavyFaint,
                        fontSize: 11,
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
}
