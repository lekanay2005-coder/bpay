import 'package:flutter/material.dart';
import '../theme/payflex_tokens.dart';

/// ──────────────────────────────────────────────────────────────────────────
/// The PayFlex signature motif — a flowing arrow/ribbon sweeping from the
/// lower-left into a flat arrowhead at the upper-right, the direction
/// every money surface in the app points at. This is a code-drawn vector
/// stand-in for the approved logo's ribbon mark: it exists so the motif
/// can DRAW ITSELF (branded loader, transfer confirmation, watermark) the
/// way a static PNG cannot.
///
/// Geometry is authored in a 100×100 space and scaled by the painter, so
/// every consumer (a 16px icon to a full-screen confirmation) shares the
/// same path.
///
/// Swap note (design brief §4): if a Rive/Lottie version of the ribbon
/// ever replaces these painters, keep the source under `/design/animations`
/// in the repo and document the swap here.
/// ──────────────────────────────────────────────────────────────────────────

/// Ribbon centerline in 100-space: a single flowing cubic from the lower
/// centre-left, curling up, then sweeping to the upper-right where the
/// arrowhead sits. Its end tangent (end − C2) points NE; [pfArrowHead]
/// is authored to continue that line.
Path pfRibbonCenterline() => Path()
  ..moveTo(20, 86)
  ..cubicTo(10, 48, 36, 60, 63, 33);

/// Filled arrowhead in 100-space. Base centre sits just behind the
/// ribbon's round end-cap so the two read as one continuous shape.
Path pfArrowHead() {
  const apex = Offset(84, 20);
  const baseCenter = Offset(65.6, 38.4);
  const halfBase = 13.5;
  const perp = Offset(0.707, 0.707);
  final f1 = baseCenter + perp * halfBase;
  final f2 = baseCenter - perp * halfBase;
  return Path()
    ..moveTo(apex.dx, apex.dy)
    ..lineTo(f1.dx, f1.dy)
    ..lineTo(f2.dx, f2.dy)
    ..close();
}

/// Static mark drawn as ONE filled outline so callers that only need the
/// silhouette (watermarks, iconography) can stroke or fill it directly.
Path pfFullMarkOutline({double strokeWidth = 16}) {
  return Path.combine(
    PathOperation.union,
    pfRibbonCenterline(),
    pfArrowHead(),
  );
}

/// Draws the motif up to progress [t] (0..1): the ribbon strokes itself
/// in first (0 → 0.8), then the arrowhead settles in (0.78 → 1) with a
/// flat, tiny scale-settle — no glow, no particles.
///
/// With [solidColor] the whole mark is that colour (icons, watermarks);
/// otherwise it uses the blue→emerald gradient.
class PfMarkPainter extends CustomPainter {
  final double t; // 0..1
  final Color? solidColor;
  final bool loop; // true: fade the tail of the cycle so repeats are clean
  final double strokeWidth; // in 100-space units (16 ≈ logo proportion)

  PfMarkPainter({
    this.t = 1,
    this.solidColor,
    this.loop = false,
    this.strokeWidth = 16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100;
    canvas.save();
    canvas.scale(scale, scale);

    final t = this.t.clamp(0.0, 1.0).toDouble();
    // In loop mode, fade the final 8% so a restart isn't a visible cut.
    // Gradient shaders can't carry alpha, so when fading a gradient mark
    // we wrap the whole frame in an opacity layer instead.
    var opacity = 1.0;
    if (loop && t > 0.92) opacity = (1 - t) / 0.08;
    var layered = false;
    if (solidColor == null && opacity < 1) {
      canvas.saveLayer(
        const Rect.fromLTWH(0, 0, 100, 100),
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
      layered = true;
      opacity = 1.0;
    }
    if (opacity <= 0 && !layered) {
      canvas.restore();
      return;
    }

    // ── Ribbon phase: fully stroked by t = 0.8.
    final ribbonT = (t / 0.8).clamp(0.0, 1.0).toDouble();
    final ribbonPath = pfRibbonCenterline();
    final ribbonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = (solidColor ?? PfColors.onNavy).withValues(alpha: opacity);
    if (solidColor == null) {
      ribbonPaint.shader = PfGradient.primary.createShader(
        const Rect.fromLTWH(0, 0, 100, 100),
      );
    }

    if (ribbonT < 1) {
      final metric = ribbonPath.computeMetrics().first;
      final partial = metric.extractPath(
        0,
        metric.length * Curves.easeInOut.transform(ribbonT),
      );
      canvas.drawPath(partial, ribbonPaint);
    } else {
      canvas.drawPath(ribbonPath, ribbonPaint);
    }

    // ── Head phase: fades/settles in over 0.78 → 1.
    if (t >= 0.78) {
      final headT = ((t - 0.78) / 0.22).clamp(0.0, 1.0).toDouble();
      final eased = Curves.easeOutCubic.transform(headT);
      final alpha = opacity * eased;

      canvas.save();
      // Scale around the head centroid (68, 30) — 1.12 → 1.00 settle.
      canvas.translate(68, 30);
      canvas.scale(1.12 - 0.12 * eased);
      canvas.translate(-68, -30);

      if (solidColor != null) {
        canvas.drawPath(
          pfArrowHead(),
          Paint()
            ..style = PaintingStyle.fill
            ..color = solidColor!.withValues(alpha: alpha),
        );
      } else {
        // Gradient shaders can't carry alpha — draw the head inside an
        // opacity layer (flat fade, still no glow).
        canvas.saveLayer(
          const Rect.fromLTWH(0, 0, 100, 100),
          Paint()..color = Colors.white.withValues(alpha: alpha),
        );
        canvas.drawPath(
          pfArrowHead(),
          Paint()
            ..style = PaintingStyle.fill
            ..shader = PfGradient.primary.createShader(
              const Rect.fromLTWH(0, 0, 100, 100),
            ),
        );
        canvas.restore();
      }
      canvas.restore();
    }

    canvas.restore();
    if (layered) canvas.restore();
  }

  @override
  bool shouldRepaint(PfMarkPainter old) =>
      old.t != t || old.solidColor != solidColor || old.loop != loop;
}

/// Static flat mark in one colour — icons, empty states, headers,
/// receipts (gradient only where the brief names it).
class PfMarkIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidthFactor; // of size
  const PfMarkIcon({
    super.key,
    this.size = 24,
    this.color = PfColors.onNavy,
    this.strokeWidthFactor = 0.16,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: PfMarkPainter(
        t: 1,
        solidColor: color,
        strokeWidth: 100 * strokeWidthFactor,
      ),
    );
  }
}

/// QR-frame corner brackets — the flat "scan" affordance, used in the two
/// meaningful places: the scanner viewfinder and the QR frame on navy
/// (brief §1: a signature, not scattered decoration).
class PfQrCorners extends StatelessWidget {
  final Color color;
  final double thickness;
  final double length; // fraction of the box edge
  const PfQrCorners({
    super.key,
    this.color = PfColors.onNavy,
    this.thickness = 3,
    this.length = 0.22,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _QrCornersPainter(
        color: color,
        thickness: thickness,
        length: length,
      ),
    );
  }
}

class _QrCornersPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final double length;

  _QrCornersPainter({
    required this.color,
    required this.thickness,
    required this.length,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final l = size.shortestSide * length;
    final inset = thickness / 2;
    // Each corner draws an L along its two edges.
    for (final signX in const [-1.0, 1.0]) {
      for (final signY in const [-1.0, 1.0]) {
        final cx = signX == 1.0 ? size.width - inset : inset;
        final cy = signY == 1.0 ? size.height - inset : inset;
        final path = Path()
          ..moveTo(cx, cy - signY * l)
          ..lineTo(cx, cy)
          ..lineTo(cx - signX * l, cy);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_QrCornersPainter old) =>
      old.color != color || old.thickness != thickness || old.length != length;
}

/// Very low-opacity, flat watermark of the ribbon in a screen corner —
/// used behind the wallet-home content. Never glowing.
class PfWatermark extends StatelessWidget {
  final double size;
  final Color color;
  const PfWatermark({
    super.key,
    this.size = 280,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.05,
        child: Transform.rotate(
          angle: 0.35,
          child: PfMarkIcon(size: size, color: color),
        ),
      ),
    );
  }
}
