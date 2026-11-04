import 'package:flutter/material.dart';

/// LocKify palette: neutral blacks/whites, hairline borders, and signature brand green.
class AppColors {
  // Shared brand & status accents
  static const Color brand = Color(0xFF3DDC97);
  static const Color accent = brand;
  static const Color secure = brand;
  static const Color open = Color(0xFFFFB020);
  static const Color warning = Color(0xFFFFB020);
  static const Color alarm = Color(0xFFFF453A);
  static const Color offline = Color(0xFF8E8E93);
  static const Color locked = secure;
  static const Color unlocked = open;

  // Dark Theme Palette
  static const Color darkBackground = Color(0xFF09090B);
  static const Color darkBackgroundRaised = Color(0xFF0F0F12);
  static const Color darkSurface = Color(0xFF131316);
  static const Color darkSurfaceLight = Color(0xFF1B1B1F);
  static const Color darkHairline = Color(0xFF242428);
  static const Color darkTextPrimary = Color(0xFFF2F2F3);
  static const Color darkTextSecondary = Color(0xFFA1A1AA);
  static const Color darkTextMuted = Color(0xFF6E6E76);
  static const Color darkDivider = Color(0xFF1C1C20);

  // Light Theme Palette
  static const Color lightBackground = Color(0xFFF5F5F7);
  static const Color lightBackgroundRaised = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLight = Color(0xFFECECEF);
  static const Color lightHairline = Color(0xFFD6D6DC);
  static const Color lightTextPrimary = Color(0xFF111114);
  static const Color lightTextSecondary = Color(0xFF55555E);
  static const Color lightTextMuted = Color(0xFF82828C);
  static const Color lightDivider = Color(0xFFE2E2E8);

  // Backward-compatible static constants (default to dark)
  static const Color primary = darkTextPrimary;
  static const Color primaryLight = darkTextPrimary;
  static const Color primaryDark = Color(0xFFD7D7DB);
  static const Color background = darkBackground;
  static const Color backgroundRaised = darkBackgroundRaised;
  static const Color surface = darkSurface;
  static const Color surfaceLight = darkSurfaceLight;
  static const Color card = darkSurface;
  static const Color hairline = darkHairline;
  static const Color border = darkHairline;
  static const Color divider = darkDivider;
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textMuted = darkTextMuted;

  // Context-aware getters (switch automatically with ThemeMode)
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  static Color backgroundOf(BuildContext context) =>
      isDark(context) ? darkBackground : lightBackground;

  static Color backgroundRaisedOf(BuildContext context) =>
      isDark(context) ? darkBackgroundRaised : lightBackgroundRaised;

  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? darkSurface : lightSurface;

  static Color surfaceLightOf(BuildContext context) =>
      isDark(context) ? darkSurfaceLight : lightSurfaceLight;

  static Color hairlineOf(BuildContext context) =>
      isDark(context) ? darkHairline : lightHairline;

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? darkTextPrimary : lightTextPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? darkTextSecondary : lightTextSecondary;

  static Color textMutedOf(BuildContext context) =>
      isDark(context) ? darkTextMuted : lightTextMuted;

  static Color dividerOf(BuildContext context) =>
      isDark(context) ? darkDivider : lightDivider;
}
