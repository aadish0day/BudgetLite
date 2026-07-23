import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';
import '../utils/constants.dart';

class AppTheme {
  AppTheme._();

  // ── Reusable style helpers for screens ──

  /// Use for all financial figures (amounts, balances, percentages).
  /// JetBrains Mono with tabular figures for zero-width numbers.
  static TextStyle financialStyle({
    double size = 16,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double letterSpacing = -0.5,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Use for display / heading text — DM Sans, tight tracking.
  static TextStyle displayStyle({
    double size = 18,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double height = 1.2,
    double letterSpacing = -0.3,
  }) {
    return GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Use for body / label text — Inter, comfortable reading.
  static TextStyle bodyStyle({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.5,
    double letterSpacing = 0.0,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // ── Theme factory ──

  static ThemeData get light => _lightTheme();
  static ThemeData get dark => _darkTheme();

  static ThemeData _lightTheme() {
    final colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryLight.withValues(alpha: 0.15),
      onPrimaryContainer: AppColors.primary,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryLight.withValues(alpha: 0.15),
      onSecondaryContainer: AppColors.secondary,
      tertiary: AppColors.tertiary,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.onSurfaceLight,
      onSurfaceVariant: AppColors.onSurfaceVariantLight,
      outline: AppColors.outlineLight,
      surfaceContainerHighest: AppColors.raisedLight,
    );

    return _buildTheme(colorScheme, isDark: false);
  }

  static ThemeData _darkTheme() {
    final colorScheme = ColorScheme.dark(
      primary: AppColors.primaryDark,
      onPrimary: const Color(0xFF003738),
      primaryContainer: AppColors.primaryDark.withValues(alpha: 0.15),
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.secondaryLight,
      onSecondary: const Color(0xFF1C0F00),
      secondaryContainer: AppColors.secondaryDark.withValues(alpha: 0.3),
      onSecondaryContainer: AppColors.secondaryLight,
      tertiary: AppColors.tertiaryLight,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.onSurfaceDark,
      onSurfaceVariant: AppColors.onSurfaceVariantDark,
      outline: AppColors.outlineDark,
      surfaceContainerHighest: AppColors.raisedDark,
    );

    return _buildTheme(colorScheme, isDark: true);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, {required bool isDark}) {
    final bodyFont = GoogleFonts.inter();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: bodyFont.fontFamily,

      // ── Text theme — deliberate DM Sans scale ──
      textTheme: TextTheme(
        displayLarge: GoogleFonts.dmSans(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          height: 1.1,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.dmSans(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          height: 1.15,
          letterSpacing: -0.4,
        ),
        displaySmall: GoogleFonts.dmSans(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        headlineLarge: GoogleFonts.dmSans(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        headlineMedium: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          height: 1.25,
          letterSpacing: -0.3,
        ),
        headlineSmall: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          height: 1.3,
          letterSpacing: -0.2,
        ),
        titleLarge: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          height: 1.2,
          letterSpacing: -0.2,
        ),
        titleMedium: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
          height: 1.3,
          letterSpacing: -0.1,
        ),
        titleSmall: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
          height: 1.3,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
          height: 1.6,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
          height: 1.3,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurfaceVariant,
          height: 1.3,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurfaceVariant,
          height: 1.3,
        ),
      ),

      // ── Card theme — shadow-as-border, layered depth ──
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        ),
        clipBehavior: Clip.antiAlias,
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),

      // ── AppBar — transparent, inset title ──
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.3,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          letterSpacing: -0.3,
        ),
      ),

      // ── Bottom navigation ──
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
        selectedItemColor: isDark ? AppColors.primaryDark : AppColors.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),

      // ── FAB — matte, no floating effect ──
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: isDark ? AppColors.primaryDark : AppColors.primary,
        foregroundColor: isDark ? const Color(0xFF003738) : Colors.white,
        elevation: isDark ? 0 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // ── Input decoration — clean, crisp ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.raisedDark.withValues(alpha: 0.6)
            : AppColors.raisedLight.withValues(alpha: 0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppColors.primaryDark : AppColors.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // ── Elevated button — scale on press via FilledButton ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // ── Filled button — primary action ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Chip theme ──
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // ── Dialog ──
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
      ),

      // ── Bottom sheet — elevated, rounded top ──
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        modalElevation: 0,
        backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
      ),

      // ── Slider ──
      sliderTheme: SliderThemeData(
        activeTrackColor: isDark ? AppColors.primaryDark : AppColors.primary,
        inactiveTrackColor: colorScheme.primaryContainer,
        thumbColor: isDark ? AppColors.primaryDark : AppColors.primary,
        overlayColor: (isDark ? AppColors.primaryDark : AppColors.primary).withValues(alpha: 0.12),
        activeTickMarkColor: isDark ? AppColors.primaryDark : AppColors.primary,
      ),

      // ── Snackbar — floating, rounded ──
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: isDark ? AppColors.elevatedDark : AppColors.onSurfaceLight,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.onSurfaceDark : Colors.white,
        ),
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withValues(alpha: 0.3),
        thickness: 0.5,
        space: 0,
      ),

      // ── Progress indicator ──
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? AppColors.primaryDark : AppColors.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
        circularTrackColor: colorScheme.surfaceContainerHighest,
      ),
    );
  }
}
