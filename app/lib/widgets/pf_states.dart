import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/payflex_tokens.dart';

/// Designed empty state — flat line icon in a quiet circle, real copy, an
/// optional action. Never a bare "No data".
class PfEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  const PfEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onDark = theme.brightness == Brightness.dark;
    final muted = onDark ? PfColors.onNavyMuted : PfColors.inkMuted;
    final wash = onDark ? PfColors.navyRaised2 : PfColors.surfaceAlt;

    final circle = Container(
      width: compact ? 44 : 56,
      height: compact ? 44 : 56,
      decoration: BoxDecoration(color: wash, shape: BoxShape.circle),
      child: Icon(icon, color: muted, size: compact ? 20 : 24),
    );

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        circle,
        SizedBox(height: compact ? 12 : 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );

    if (compact) return body;
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: body));
  }
}

/// Designed inline error — soft wash, flat icon, human copy. Never a raw
/// red `Text(_error)` box.
class PfInlineError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  const PfInlineError({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onDark = theme.brightness == Brightness.dark;
    final wash = onDark
        ? PfColors.danger.withValues(alpha: 0.14)
        : PfColors.dangerWash;
    final fg = onDark ? const Color(0xFFFF8E82) : PfColors.danger;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(PfRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(retryLabel),
            ),
        ],
      ),
    );
  }
}

enum PfTone { success, info, warn, muted }

/// Flat status chip with a quiet dot — receipts, transaction rows, KYC
/// status. Colours are the flat semantic set, never glowing.
class PfStatusChip extends StatelessWidget {
  final String label;
  final PfTone tone;
  const PfStatusChip({super.key, required this.label, this.tone = PfTone.muted});

  @override
  Widget build(BuildContext context) {
    final onDark = Theme.of(context).brightness == Brightness.dark;
    final (fg, wash) = switch (tone) {
      PfTone.success => onDark
          ? (const Color(0xFF62E39A), PfColors.emerald.withValues(alpha: 0.16))
          : (PfColors.success, PfColors.successWash),
      PfTone.warn => onDark
          ? (const Color(0xFFFFD28A), PfColors.warn.withValues(alpha: 0.2))
          : (PfColors.warn, PfColors.warnWash),
      PfTone.info => onDark
          ? (PfColors.accentOnDark, PfColors.accentOnDark.withValues(alpha: 0.16))
          : (PfColors.royalBluePressed, PfColors.royalBlue.withValues(alpha: 0.08)),
      PfTone.muted => onDark
          ? (PfColors.onNavyMuted, PfColors.navyRaised2)
          : (PfColors.inkMuted, PfColors.surfaceAlt),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(PfRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header with the motif's thin gradient accent line.
class PfSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const PfSectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 15,
          decoration: BoxDecoration(
            gradient: PfGradient.tickDark,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Flat gradient progress bar (savings goals etc.).
class PfProgressBar extends StatelessWidget {
  final double value; // 0..1
  final double height;
  const PfProgressBar({super.key, required this.value, this.height = 8});

  @override
  Widget build(BuildContext context) {
    final onDark = Theme.of(context).brightness == Brightness.dark;
    final track = onDark ? PfColors.navyBorder : PfColors.surfaceAlt;
    return ClipRRect(
      borderRadius: BorderRadius.circular(PfRadius.pill),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: track),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0).toDouble(),
              child: Container(
                decoration: const BoxDecoration(gradient: PfGradient.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular progress ring in flat gradient (split-bill contributors,
/// savings) — fills clockwise from the top, no glow pulse.
class PfSplitRing extends StatelessWidget {
  final double progress; // 0..1
  final double size;
  final double strokeWidth;
  final Widget? center;

  const PfSplitRing({
    super.key,
    required this.progress,
    this.size = 64,
    this.strokeWidth = 6,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _RingPainter(
              progress: progress.clamp(0.0, 1.0).toDouble(),
              strokeWidth: strokeWidth,
            ),
          ),
          if (center != null) Center(child: center!),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  _RingPainter({required this.progress, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = const Color(0xFFE7E9F0),
    );
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth
          ..shader = PfGradient.primary.createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.strokeWidth != strokeWidth;
}

/// "Step 2 of 5 · Identity" — designed onboarding progress: quiet caps
/// label on the left, a row of thin segment pills on the right (design
/// brief §3: KYC never feels like paperwork).
class PfStepHeader extends StatelessWidget {
  final int step; // 1-based
  final int total;
  final String title;

  const PfStepHeader({
    super.key,
    required this.step,
    required this.total,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? PfColors.onNavyMuted
        : PfColors.inkMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Step $step of $total · $title',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: muted,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            Row(
              children: List.generate(total, (i) {
                final isDone = i + 1 < step;
                final isCurrent = i + 1 == step;
                return Container(
                  width: 18,
                  height: 4,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: (isDone || isCurrent)
                        ? PfGradient.tickDark
                        : null,
                    color: (isDone || isCurrent) ? null : muted.withValues(alpha: 0.25),
                  ),
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(title, style: theme.textTheme.headlineSmall),
      ],
    );
  }
}
