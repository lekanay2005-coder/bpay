import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';

/// ──────────────────────────────────────────────────────────────────────────
/// PayFlex design tokens — the ONLY place hex codes, radii, spacing,
/// motion durations/curves and shadows are defined (docs/BUILD_PROMPT.md
/// §9 / design brief v2 §4: "no inline hex codes or magic numbers in
/// widget code"). Exact values are sampled from the approved logo:
/// deep navy QR background (#0A1330), royal blue top-left (#0B2FBE),
/// emerald bottom-right (#1FD65F), off-white paper (#F7F7F5).
///
/// Restraint rules that fall out of these tokens, enforced by review:
///  • The blue→emerald gradient is the app's ONLY strong colour move.
///  • Every shadow is a small, low-opacity, neutral-dark elevation — no
///    coloured shadows, no blur used to fake a glow, no neon anywhere.
/// ──────────────────────────────────────────────────────────────────────────
class PfColors {
  PfColors._();

  // Dark navy system (wallet home, splash, QR, confirmations).
  static const navy = Color(0xFF0A1330); // logo QR-code background
  static const navyRaised = Color(0xFF0F1B3D); // cards on navy
  static const navyRaised2 = Color(0xFF16244B); // chips / inputs on navy
  static const navyBorder = Color(0xFF26345F); // hairline on navy
  static const onNavy = Color(0xFFFFFFFF);
  static const onNavyMuted = Color(0xFF97A2C7);
  static const onNavyFaint = Color(0xFF5E6A96);

  // The logo gradient anchors.
  static const royalBlue = Color(0xFF0B2FBE);
  static const royalBluePressed = Color(0xFF0A2796);
  static const emerald = Color(0xFF1FD65F);
  static const emeraldPressed = Color(0xFF13AF4F);

  // Flat accent (non-gradient) uses, kept desaturated so the gradient
  // stays the one loud move: links, selection states, toggles.
  static const accentOnDark = Color(0xFF7D93FF); // royal, lightened for dark bg
  static const accentOnLight = royalBlue;
  static const accentOnLightPressed = royalBluePressed;

  // Light system (forms, KYC, PayTag, business screens).
  static const offWhite = Color(0xFFF7F7F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFEFF0F5);
  static const line = Color(0xFFE3E5EE);
  static const lineStrong = Color(0xFFC9CFDF);
  static const ink = Color(0xFF0A1330);
  static const inkMuted = Color(0xFF5B6580);
  static const inkFaint = Color(0xFF8B93AA);

  // Semantic, flat — never glowing.
  static const success = Color(0xFF0E9F4B);
  static const successWash = Color(0xFFE2F6EA);
  static const danger = Color(0xFFB3372C);
  static const dangerWash = Color(0xFFFBE9E7);
  static const warn = Color(0xFF8A6110);
  static const warnWash = Color(0xFFFAF1DC);

  // Brand mark on light surfaces (deep navy works as a flat "ink" mark).
  static const markOnLight = ink;
}

/// The blue→emerald brand gradient (logo top-left → bottom-right).
class PfGradient {
  PfGradient._();

  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [PfColors.royalBlue, PfColors.emerald],
  );

  /// Pressed / active state of the same gradient — slightly deeper so a
  /// press reads without any glow trickery.
  static const primaryPressed = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [PfColors.royalBluePressed, PfColors.emeraldPressed],
  );

  /// Hairline accent for section ticks / divider accents. Flat, 3% white
  /// on dark; components pick the dark variant themselves via
  /// [accentTick].
  static const tickDark = LinearGradient(
    colors: [PfColors.royalBlue, PfColors.emerald],
  );
}

/// One radius scale — 12 / 16 / 24 — proportional to the logo's rounded
/// container. Pick from here; never invent intermediate values.
class PfRadius {
  PfRadius._();

  static const sm = 12.0; // inputs, chips, small surfaces
  static const md = 16.0; // buttons, sheets, list cards
  static const lg = 24.0; // hero surfaces: balance card, QR frame, dialogs
  static const pill = 999.0;
}

class PfSpace {
  PfSpace._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Motion vocabulary (design brief §2): 200–400ms UI motion, ease-out,
/// physically plausible — never bouncy springs, never instant. Signature
/// sequences (mark draw-ins) may run longer but still ease out flat.
class PfMotion {
  PfMotion._();

  static const fast = Duration(milliseconds: 200);
  static const base = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 400);

  /// Branded draw / settle sequences.
  static const signature = Duration(milliseconds: 900);
  static const signatureSettle = Duration(milliseconds: 260);

  static const easeOut = Curves.easeOutCubic;
  static const easeInOut = Curves.easeInOutCubic;

  /// The count-up easing — starts fast, lands softly, no overshoot.
  static const countUp = Curves.easeOutQuint;
}

/// Neutral, realistic elevation shadows only. Rule: a shadow must be
/// small, low-opacity and neutral-dark — never a coloured glow.
class PfShadow {
  PfShadow._();

  /// Light surfaces: barely-there card lift.
  static const soft = <BoxShadow>[
    BoxShadow(
      color: Color(0x140A1330), // ~8% navy, not black — keeps it neutral-cold
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  /// Dark navy surfaces need slightly deeper, tighter shadows to read.
  static const onDark = <BoxShadow>[
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// Buttons: tight, close, realistic.
  static const button = <BoxShadow>[
    BoxShadow(
      color: Color(0x240A1330),
      blurRadius: 10,
      offset: Offset(0, 3),
    ),
  ];
}

/// Balance/amount display styles — heavy, confident, tabular so digits
/// don't jitter while a balance counts up. Color is applied by the
/// component (depends on the surface it sits on).
class PfMoneyType {
  PfMoneyType._();

  static const hero = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w700,
    height: 1.05,
    letterSpacing: -0.6,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const large = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.4,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const medium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.15,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const small = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
