import 'package:flutter/material.dart';

/// LocKify palette: neutral blacks, hairline borders, and one signature
/// colour. The brand green is also the "secure" colour, so the brand and a
/// locked door read as the same thing.
class AppColors {
  static const Color brand = Color(0xFF3DDC97);
  static const Color primary = Color(0xFFF2F2F3); // primary buttons are white on black
  static const Color primaryLight = Color(0xFFF2F2F3);
  static const Color primaryDark = Color(0xFFD7D7DB);
  static const Color accent = brand;

  static const Color background = Color(0xFF09090B);
  static const Color backgroundRaised = Color(0xFF0F0F12);
  static const Color surface = Color(0xFF131316);
  static const Color surfaceLight = Color(0xFF1B1B1F);
  static const Color card = surface;
  static const Color hairline = Color(0xFF242428);

  static const Color secure = brand;
  static const Color open = Color(0xFFFFB020);
  static const Color warning = Color(0xFFFFB020);
  static const Color alarm = Color(0xFFFF453A);
  static const Color offline = Color(0xFF8E8E93);
  static const Color locked = secure;
  static const Color unlocked = open;

  static const Color textPrimary = Color(0xFFF2F2F3);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF6E6E76);
  static const Color border = hairline;
  static const Color divider = Color(0xFF1C1C20);
}
