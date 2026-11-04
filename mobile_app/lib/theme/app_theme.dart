import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  /// Headlines: Geist, tight tracking.
  static TextStyle display({
    BuildContext? context,
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double letterSpacing = -0.9,
    double? height,
  }) {
    Color? resolved = color;
    if (resolved == null && context != null) {
      resolved = AppColors.textPrimaryOf(context);
    }
    return GoogleFonts.geist(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: resolved,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Technical details (IDs, versions, timestamps): Geist Mono.
  static TextStyle mono({
    BuildContext? context,
    double fontSize = 12,
    Color? color,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    Color? resolved = color;
    if (resolved == null && context != null) {
      resolved = AppColors.textMutedOf(context);
    }
    return GoogleFonts.geistMono(
      fontSize: fontSize,
      color: resolved,
      fontWeight: fontWeight,
      letterSpacing: 0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Small upper-case section label.
  static TextStyle label({BuildContext? context, Color? color}) {
    Color? resolved = color;
    if (resolved == null && context != null) {
      resolved = AppColors.textMutedOf(context);
    }
    return GoogleFonts.geistMono(fontSize: 11, color: resolved, fontWeight: FontWeight.w500, letterSpacing: 1.1);
  }

  static ThemeData get lightTheme {
    // Light-mode color constants (inlined; AppColors stays dark-only)
    const Color lBackground = Color(0xFFF8F8FA);
    const Color lSurface = Color(0xFFFFFFFF);
    const Color lSurfaceLight = Color(0xFFF1F1F5);
    const Color lHairline = Color(0xFFE4E4E7);
    const Color lTextPrimary = Color(0xFF18181B);
    const Color lTextSecondary = Color(0xFF52525B);
    const Color lTextMuted = Color(0xFF8E8E93);
    const Color lDivider = Color(0xFFE4E4E7);

    final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
    final text = GoogleFonts.geistTextTheme(base.textTheme).apply(
      bodyColor: lTextPrimary,
      displayColor: lTextPrimary,
    );

    OutlineInputBorder field(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lBackground,
      textTheme: text,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.brand,
        surface: lSurface,
        error: AppColors.alarm,
        onPrimary: lBackground,
        onSurface: lTextPrimary,
      ),
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.black.withValues(alpha: 0.03),
      splashColor: Colors.black.withValues(alpha: 0.05),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      dividerTheme: const DividerThemeData(color: lDivider, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: lTextSecondary,
        textColor: lTextPrimary,
        minLeadingWidth: 22,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        titleTextStyle: GoogleFonts.geist(color: lTextPrimary, fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -0.2),
        subtitleTextStyle: GoogleFonts.geist(color: lTextMuted, fontSize: 13, height: 1.35),
      ),
      cardTheme: CardThemeData(
        color: lSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lHairline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lSurfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: lHairline),
        ),
        titleTextStyle: GoogleFonts.geist(fontSize: 19, fontWeight: FontWeight.w600, color: lTextPrimary, letterSpacing: -0.4),
        contentTextStyle: GoogleFonts.geist(color: lTextSecondary, fontSize: 14, height: 1.5),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lSurfaceLight,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: lTextMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: lHairline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lSurface,
        disabledColor: lSurfaceLight,
        selectedColor: AppColors.brand.withValues(alpha: 0.18),
        secondarySelectedColor: AppColors.brand.withValues(alpha: 0.18),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        labelStyle: GoogleFonts.geist(color: lTextPrimary, fontSize: 13),
        secondaryLabelStyle: GoogleFonts.geist(color: AppColors.brand, fontSize: 13, fontWeight: FontWeight.w600),
        side: const BorderSide(color: lHairline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: lSurfaceLight,
        contentTextStyle: GoogleFonts.geist(color: lTextPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lHairline),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: lSurfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lHairline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lTextPrimary,
          foregroundColor: lBackground,
          disabledBackgroundColor: lSurfaceLight,
          disabledForegroundColor: lTextMuted,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.geist(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lTextPrimary,
          foregroundColor: lBackground,
          disabledBackgroundColor: lSurfaceLight,
          disabledForegroundColor: lTextMuted,
          minimumSize: const Size(88, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.geist(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lTextPrimary,
          minimumSize: const Size(88, 46),
          side: const BorderSide(color: lHairline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.geist(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -0.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lTextSecondary,
          textStyle: GoogleFonts.geist(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lSurface,
        hintStyle: const TextStyle(color: lTextMuted, fontSize: 14),
        labelStyle: const TextStyle(color: lTextMuted, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: lTextSecondary),
        prefixIconColor: lTextMuted,
        suffixIconColor: lTextMuted,
        border: field(lHairline),
        enabledBorder: field(lHairline),
        focusedBorder: field(lTextSecondary),
        errorBorder: field(AppColors.alarm),
        focusedErrorBorder: field(AppColors.alarm),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? lBackground : lTextSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? AppColors.brand : lSurfaceLight;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: lTextPrimary),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final text = GoogleFonts.geistTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    OutlineInputBorder field(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: text,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.brand,
        surface: AppColors.surface,
        error: AppColors.alarm,
        onPrimary: AppColors.background,
        onSurface: AppColors.textPrimary,
      ),
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.white.withValues(alpha: 0.03),
      splashColor: Colors.white.withValues(alpha: 0.05),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        minLeadingWidth: 22,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        titleTextStyle: GoogleFonts.geist(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -0.2),
        subtitleTextStyle: GoogleFonts.geist(color: AppColors.textMuted, fontSize: 13, height: 1.35),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.backgroundRaised,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: AppColors.hairline),
        ),
        titleTextStyle: display(fontSize: 19, letterSpacing: -0.4),
        contentTextStyle: GoogleFonts.geist(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.backgroundRaised,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: AppColors.textMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: AppColors.hairline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceLight,
        contentTextStyle: GoogleFonts.geist(color: AppColors.textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.background,
          disabledBackgroundColor: AppColors.surfaceLight,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.geist(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.background,
          disabledBackgroundColor: AppColors.surfaceLight,
          disabledForegroundColor: AppColors.textMuted,
          minimumSize: const Size(88, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.geist(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(88, 46),
          side: const BorderSide(color: AppColors.hairline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.geist(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -0.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          textStyle: GoogleFonts.geist(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        border: field(AppColors.hairline),
        enabledBorder: field(AppColors.hairline),
        focusedBorder: field(AppColors.textSecondary),
        errorBorder: field(AppColors.alarm),
        focusedErrorBorder: field(AppColors.alarm),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? AppColors.background : AppColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? AppColors.brand : AppColors.surfaceLight;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        disabledColor: AppColors.surfaceLight,
        selectedColor: AppColors.brand.withValues(alpha: 0.18),
        secondarySelectedColor: AppColors.brand.withValues(alpha: 0.18),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        labelStyle: GoogleFonts.geist(color: AppColors.textPrimary, fontSize: 13),
        secondaryLabelStyle: GoogleFonts.geist(color: AppColors.brand, fontSize: 13, fontWeight: FontWeight.w600),
        side: const BorderSide(color: AppColors.hairline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.textPrimary),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
