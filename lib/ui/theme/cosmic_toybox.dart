/// Cosmic Toybox design system (UX report §3). Centralized tokens + a
/// [ThemeData] the whole app derives from. Games use the raw tokens (Flame
/// paints its own canvas) and the shared widgets in `widgets.dart`.
library;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------- tokens

abstract final class Ct {
  // Brand palette.
  static const indigo = Color(0xFF1B1533);
  static const indigoDeep = Color(0xFF130E24);
  static const indigoLight = Color(0xFF241A45);
  static const coral = Color(0xFFFF5A5F); // primary action
  static const coralHot = Color(0xFFFF7A72);
  static const cyan = Color(0xFF29E0E0);
  static const gold = Color(0xFFFFC53D); // rewards
  static const mint = Color(0xFF3DDC97); // success
  static const ember = Color(0xFFFF4D6D); // danger / misses
  static const ink = Color(0xFF0B0817); // text on light surfaces
  static const white = Color(0xFFF6F3FF);

  // Surface translucency for glassy cards over the deep gradient.
  static const surface = Color(0x14FFFFFF);
  static const surfaceStrong = Color(0x24FFFFFF);
  static const surfaceStroke = Color(0x2EFFFFFF);

  // Motion (D7): springy overshoot for entrances, squash for presses.
  static const easeOutBack = Curves.easeOutBack;
  static const Duration popIn = Duration(milliseconds: 520); // big entrances
  static const Duration enter = Duration(milliseconds: 260); // small entrances
  static const Duration press = Duration(milliseconds: 120); // squash

  // Shape language: everything is softly rounded.
  static const radius = BorderRadius.all(Radius.circular(20));
  static const radiusSmall = BorderRadius.all(Radius.circular(12));

  static const shimmer = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3A2E66), Color(0xFF1E1737), Color(0xFF3A2E66)],
  );

  /// Deep space background with an aurora bloom behind the hub content.
  static const background = RadialGradient(
    center: Alignment(0, -0.55),
    radius: 1.35,
    colors: [Color(0xFF3A2C70), indigo, indigoDeep],
  );

  static const glowShadow = BoxShadow(
    color: Color(0x66FF5A5F),
    blurRadius: 24,
    offset: Offset(0, 6),
  );
}

// ---------------------------------------------------------------- theme

ThemeData cosmicTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Ct.indigoDeep,
    colorScheme: const ColorScheme.dark(
      primary: Ct.coral,
      secondary: Ct.cyan,
      tertiary: Ct.mint,
      error: Ct.ember,
      surface: Ct.indigo,
      onPrimary: Ct.white,
      onSurface: Ct.white,
    ),
    fontFamily: 'Inter',
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: _display(base, 44, w800),
      displayMedium: _display(base, 32, w800),
      headlineMedium: _display(base, 26, w800),
      titleLarge: _display(base, 20, w800),
      titleMedium: _display(base, 16, w700),
      titleSmall: _display(base, 14, w700),
      bodyLarge: _body(base, 16),
      bodyMedium: _body(base, 14),
      bodySmall: _body(base, 12, color: Ct.white.withValues(alpha: 0.7)),
      labelLarge: _display(base, 16, w800, color: Ct.white),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Ct.coral,
        foregroundColor: Ct.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: Ct.radius),
        textStyle: _display(base, 17, w800),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      ),
    ),
    iconTheme: const IconThemeData(color: Ct.white),
  );
}

const w700 = FontWeight.w700;
const w800 = FontWeight.w800;

TextStyle _display(ThemeData base, double size, FontWeight w, {Color? color}) =>
    base.textTheme.displayMedium!.copyWith(
      fontFamily: 'Nunito',
      fontSize: size,
      fontWeight: w,
      color: color,
      height: 1.1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

TextStyle _body(ThemeData base, double size, {Color? color}) =>
    base.textTheme.bodyLarge!.copyWith(
      fontSize: size,
      height: 1.35,
      color: color,
    );
