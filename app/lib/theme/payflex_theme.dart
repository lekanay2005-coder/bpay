import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'payflex_tokens.dart';

/// ──────────────────────────────────────────────────────────────────────────
/// PayFlex light + dark themes, both fully designed (design brief §1/§3 —
/// never auto-inverted). Light chrome is for forms/business screens; dark
/// navy chrome is for wallet home, splash, QR and confirmations. Screens
/// pick their own surface by wrapping content in the matching theme
/// (`Theme(data: PayFlexTheme.light, ...)`), because the two modes are
/// designed per-surface, not inverted from one switch.
///
/// Default launch mode is dark. Users can flip it in Settings — see
/// [PfAppearance]. Switches affect chrome (dialogs, sheets, inputs on
/// theme surfaces); the flagship navy surfaces stay navy by design.
/// ──────────────────────────────────────────────────────────────────────────
class PayFlexTheme {
  PayFlexTheme._();

  static final ThemeData light = _build(
    brightness: Brightness.light,
    background: PfColors.offWhite,
    surface: PfColors.surface,
    surfaceRaised: PfColors.surfaceAlt,
    border: PfColors.line,
    borderStrong: PfColors.lineStrong,
    textPrimary: PfColors.ink,
    textMuted: PfColors.inkMuted,
    textFaint: PfColors.inkFaint,
    accent: PfColors.accentOnLight,
    accentPressed: PfColors.accentOnLightPressed,
    inputFill: PfColors.surface,
    primary: PfColors.royalBlue,
    onPrimary: Colors.white,
  );

  static final ThemeData dark = _build(
    brightness: Brightness.dark,
    background: PfColors.navy,
    surface: PfColors.navyRaised,
    surfaceRaised: PfColors.navyRaised2,
    border: PfColors.navyBorder,
    borderStrong: PfColors.navyBorder,
    textPrimary: PfColors.onNavy,
    textMuted: PfColors.onNavyMuted,
    textFaint: PfColors.onNavyFaint,
    accent: PfColors.accentOnDark,
    accentPressed: PfColors.accentOnDark,
    inputFill: PfColors.navyRaised2,
    primary: PfColors.accentOnDark,
    onPrimary: PfColors.onNavy,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceRaised,
    required Color border,
    required Color borderStrong,
    required Color textPrimary,
    required Color textMuted,
    required Color textFaint,
    required Color accent,
    required Color accentPressed,
    required Color inputFill,
    required Color primary,
    required Color onPrimary,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: PfColors.royalBlue,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      secondary: PfColors.emeraldPressed,
      onSecondary: PfColors.offWhite,
      surface: background,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceRaised,
      outline: borderStrong,
      outlineVariant: border,
      error: PfColors.danger,
      onError: Colors.white,
    );

    // Inter/General Sans/Satoshi note: drop a brand font in
    // app/assets/fonts and set `fontFamily` here once licensed — every
    // screen picks it up from this one place.
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
    );

    final textTheme = base.textTheme.copyWith(
      displayLarge: TextStyle(
        fontSize: 40, fontWeight: FontWeight.w700, height: 1.08,
        letterSpacing: -0.8, color: textPrimary,
      ),
      displayMedium: TextStyle(
        fontSize: 34, fontWeight: FontWeight.w700, height: 1.1,
        letterSpacing: -0.5, color: textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 26, fontWeight: FontWeight.w700, height: 1.2,
        letterSpacing: -0.3, color: textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 21, fontWeight: FontWeight.w600, height: 1.25,
        color: textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 19, fontWeight: FontWeight.w600, height: 1.3,
        color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w600, height: 1.3,
        color: textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600, height: 1.3,
        color: textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w400, height: 1.45,
        color: textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w400, height: 1.45,
        color: textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w400, height: 1.4,
        color: textMuted,
      ),
      labelLarge: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600, height: 1.2,
        letterSpacing: 0.1, color: textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, height: 1.2,
        color: textMuted,
      ),
      labelSmall: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w600, height: 1.2,
        letterSpacing: 0.4, color: textFaint,
      ),
    );

    final inputDecoration = InputDecorationTheme(
      filled: true,
      fillColor: inputFill,
      labelStyle: TextStyle(color: textMuted, fontSize: 14),
      hintStyle: TextStyle(color: textFaint, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: PfSpace.lg,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PfRadius.sm),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PfRadius.sm),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PfRadius.sm),
        borderSide: BorderSide(color: accent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PfRadius.sm),
        borderSide: BorderSide(color: PfColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PfRadius.sm),
        borderSide: BorderSide(color: PfColors.danger, width: 1.6),
      ),
    );

    // One shared shape for the app's flat controls. Keep everything
    // 12/16/24 from the radius scale.
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(PfRadius.md),
    );
    final buttonStyle = ButtonStyle(
      shape: WidgetStatePropertyAll(buttonShape),
      textStyle: const WidgetStatePropertyAll(TextStyle(
        fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1,
      )),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary,
        ),
      ),
      inputDecorationTheme: inputDecoration,
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: PfColors.navy,
        contentTextStyle: const TextStyle(
          color: PfColors.onNavy, fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PfRadius.md),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(PfRadius.lg)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PfRadius.md),
        ),
        elevation: 6,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: buttonStyle.copyWith(
          backgroundColor: const WidgetStatePropertyAll(PfColors.royalBlue),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: buttonStyle.copyWith(
          foregroundColor: WidgetStatePropertyAll(accent),
          side: WidgetStatePropertyAll(BorderSide(color: borderStrong)),
          backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: buttonStyle.copyWith(
          foregroundColor: WidgetStatePropertyAll(accent),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PfRadius.sm),
          )),
          side: WidgetStatePropertyAll(BorderSide(color: borderStrong)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return brightness == Brightness.dark
                  ? PfColors.navyRaised2
                  : PfColors.offWhite;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return textPrimary;
            return textMuted;
          }),
          textStyle: const WidgetStatePropertyAll(TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
          )),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return PfColors.royalBlue;
          return border;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return PfColors.royalBlue;
          return textMuted;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return PfColors.royalBlue;
          return Colors.transparent;
        }),
        side: BorderSide(color: borderStrong, width: 1.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PfRadius.xs),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: PfColors.royalBlue,
        linearTrackColor: border,
        circularTrackColor: border,
      ),
      listTileTheme: ListTileThemeData(
        textColor: textPrimary,
        iconColor: textMuted,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        // One consistent, restrained transition for every route — no
        // platform-default slide-in used inconsistently (design brief §2).
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Persisted appearance preference. Defaults to dark (design brief §1:
/// dark-default for the key screens); flipping it in Settings restyles
/// the chrome while designed surfaces keep their own tokens.
class PfAppearance {
  PfAppearance._();

  static const _key = 'payflex.themeMode';
  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    mode.value = stored == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  static Future<void> set(ThemeMode next) async {
    mode.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, next == ThemeMode.light ? 'light' : 'dark');
  }
}
