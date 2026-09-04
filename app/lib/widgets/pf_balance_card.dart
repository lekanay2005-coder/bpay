import 'package:flutter/material.dart';
import '../theme/payflex_tokens.dart';
import '../utils/format.dart';
import '../utils/money.dart';
import 'pf_mark.dart';
import 'pf_motion.dart';

/// The flagship balance card — one of the three places the gradient is
/// allowed (design brief §1). Deep gradient field, flat white hero number
/// that counts up once per session ([PfCountUpMoney]), the ribbon
/// watermark breathing faintly in the corner.
class PfBalanceCard extends StatelessWidget {
  final String currency;
  final String amount; // decimal string
  final bool countUp;
  final String? statusLabel;
  final String? address;
  final VoidCallback? onTap;

  const PfBalanceCard({
    super.key,
    required this.currency,
    required this.amount,
    this.countUp = true,
    this.statusLabel,
    this.address,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PfRadius.lg),
        boxShadow: PfShadow.onDark,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PfRadius.lg),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: const BoxDecoration(gradient: PfGradient.primary),
            child: InkWell(
              onTap: onTap,
              child: Stack(
                children: [
                  // Flat watermark — the ribbon, 5% white, no glow.
                  Positioned(
                    right: -70,
                    bottom: -110,
                    child: PfWatermark(size: 260, color: Colors.white),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Available balance',
                              style: TextStyle(
                                color: Color(0xB3FFFFFF),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(PfRadius.pill),
                              ),
                              child: Text(
                                currency,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 52,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: PfCountUpMoney(
                                    amount: amount,
                                    currency: currency,
                                    animate: countUp,
                                    style: PfMoneyType.hero.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            if (statusLabel != null) ...[
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF8DFFB6),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                statusLabel!,
                                style: const TextStyle(
                                  color: Color(0xD9FFFFFF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (address != null)
                              Flexible(
                                child: Text(
                                  shortRef(address!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0x99FFFFFF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
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

/// Secondary currency row — quiet navy-raised surface under the flagship
/// gradient card. Shows formatted balance and opens that wallet's
/// transactions.
class PfWalletRow extends StatelessWidget {
  final String currency;
  final String amount; // decimal string or empty for "no balance yet"
  final String? address;
  final bool active;
  final VoidCallback? onTap;

  const PfWalletRow({
    super.key,
    required this.currency,
    required this.amount,
    this.address,
    this.active = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: PfColors.navyRaised2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: PfMarkIcon(
                    size: 19,
                    color: PfColors.onNavyMuted,
                    strokeWidthFactor: 0.2,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$currency wallet',
                        style: const TextStyle(
                          color: PfColors.onNavy,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shortRef(address ?? ''),
                        style: const TextStyle(
                          color: PfColors.onNavyFaint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  amount.isEmpty ? '—' : formatAmountOnly(amount),
                  style: const TextStyle(
                    color: PfColors.onNavy,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: PfColors.onNavyFaint,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's one shared "surface" card: flat fill that follows the theme
/// (navy-raised on dark, white + soft elevation on light), 16px radius.
/// Everything that used to be a default M3 `Card` goes through this so
/// the surface language stays consistent.
class PfPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;
  final bool showShadow;

  const PfPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = PfRadius.md,
    this.onTap,
    this.color,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final onDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color ??
        (onDark ? PfColors.navyRaised : PfColors.surface);

    final content = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(radius),
        border: onDark && color == null
            ? Border.all(color: PfColors.navyBorder)
            : null,
        boxShadow: !onDark && showShadow ? PfShadow.soft : null,
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}
