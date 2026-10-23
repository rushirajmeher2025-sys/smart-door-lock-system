import 'package:flutter/material.dart';

/// Design tokens and curated color palette for the Smart Door Lock System.
class AppColors {
  // Primary brand & accents
  static const Color primary = Color(0xFF0077B6);
  static const Color primaryLight = Color(0xFF48CAE4);
  static const Color primaryDark = Color(0xFF023E8A);
  static const Color accent = Color(0xFF00B4D8);

  // Backgrounds & Surfaces (Cyber-security dark theme)
  static const Color background = Color(0xFF0A0F1D);
  static const Color surface = Color(0xFF141C2E);
  static const Color surfaceLight = Color(0xFF1F2B45);
  static const Color card = Color(0xFF182238);

  // Status Colors
  static const Color locked = Color(0xFFEF476F);       // Alert Red
  static const Color lockedGlow = Color(0x33EF476F);
  static const Color unlocked = Color(0xFF06D6A0);     // Secure Green
  static const Color unlockedGlow = Color(0x3306D6A0);
  static const Color warning = Color(0xFFFFD166);      // Caution Amber
  static const Color alarm = Color(0xFFFF0055);        // Critical Siren Red

  // Typography & Neutrals
  static const Color textPrimary = Color(0xFFF8F9FA);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFF2E3D5B);
  static const Color divider = Color(0xFF1E293B);
}
