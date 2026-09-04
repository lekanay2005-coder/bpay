import 'package:flutter/material.dart';
import '../theme/payflex_tokens.dart';

/// Primary CTA — the one place (besides the balance card, splash and
/// signature moments) the blue→emerald gradient is allowed. Flat fill,
/// tight realistic shadow, white pressed overlay — never a glow.
class PfPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final bool expanded;
  final double height;

  const PfPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    this.expanded = true,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;

    final content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy) ...[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: 19, color: Colors.white),
          const SizedBox(width: 9),
        ],
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );

    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: PfGradient.primary,
            borderRadius: BorderRadius.circular(PfRadius.md),
            boxShadow: enabled ? PfShadow.button : null,
          ),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(PfRadius.md),
            overlayColor: WidgetStatePropertyAll(
              Colors.white.withValues(alpha: 0.12),
            ),
            child: AnimatedOpacity(
              duration: PfMotion.fast,
              opacity: enabled ? 1 : 0.45,
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary action — quiet border + flat accent text. Reads flat and
/// grown-up on both navy and off-white surfaces.
class PfSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final double height;

  const PfSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onDark = theme.brightness == Brightness.dark;
    final fg = onDark ? PfColors.onNavy : PfColors.accentOnLight;
    final border = onDark ? PfColors.navyBorder : PfColors.lineStrong;

    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(PfRadius.md),
            border: Border.all(color: border, width: 1.3),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(PfRadius.md),
            overlayColor: WidgetStatePropertyAll(
              fg.withValues(alpha: 0.08),
            ),
            child: Center(
              child: Row(
                mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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

/// Small gradient chip/button used for inline actions (e.g. "Pay now" on
/// a due row) — gradient kept to CTAs only.
class PfGradientChip extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const PfGradientChip({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: PfGradient.primary,
          borderRadius: BorderRadius.circular(PfRadius.pill),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(PfRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Opacity(
              opacity: enabled ? 1 : 0.45,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
