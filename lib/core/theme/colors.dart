import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Primary accent — signature teal ──
  static const Color primary = Color(0xFF0D9488);
  static const Color primaryLight = Color(0xFF14B8A6);
  static const Color primaryDark = Color(0xFF2DD4BF);
  static const Color primaryHover = Color(0xFF0F766E);

  // ── Secondary — warm amber (for contrast with cool palette) ──
  static const Color secondary = Color(0xFFD97706);
  static const Color secondaryLight = Color(0xFFF59E0B);
  static const Color secondaryDark = Color(0xFFB45309);
  static const Color accent = Color(0xFFF59E0B);

  // ── Tertiary — muted plum ──
  static const Color tertiary = Color(0xFF8B5CF6);
  static const Color tertiaryLight = Color(0xFFA78BFA);
  static const Color tertiaryDark = Color(0xFF7C3AED);

  // ── Semantic — muted, not fluorescent ──
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFE5484D);
  static const Color info = Color(0xFF3B82F6);

  // ── Neutral ramp — cool-tinted (teal undertone) ──
  // Surface colors are tinted slightly toward the primary hue
  // for a cohesive, premium feel (never pure gray).

  static const Color nearWhite = Color(0xFFF8FAFB);
  static const Color surfaceLight = Color(0xFFF4F7FA);
  static const Color backgroundLight = Color(0xFFEEF2F6);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color raisedLight = Color(0xFFF1F5F9);
  static const Color onSurfaceLight = Color(0xFF0F172A);
  static const Color onSurfaceVariantLight = Color(0xFF62748E);
  static const Color outlineLight = Color(0xFFE2E8F0);
  static const Color outlineLightStrong = Color(0xFFCBD5E1);

  // ── Dark surfaces — elevation-based brightness ──
  // Dark surfaces get lighter as elevation increases (instead of darker).
  static const Color surfaceDark = Color(0xFF0D1117);
  static const Color backgroundDark = Color(0xFF090D14);
  static const Color cardDark = Color(0xFF151B24);
  static const Color raisedDark = Color(0xFF1C2333);
  static const Color elevatedDark = Color(0xFF242B3D);
  static const Color onSurfaceDark = Color(0xFFF0F6FC);
  static const Color onSurfaceVariantDark = Color(0xFF8894A8);
  static const Color outlineDark = Color(0xFF21262D);
  static const Color outlineDarkStrong = Color(0xFF30363D);

  // ── Shadows as borders — light mode ──
  static List<BoxShadow> get borderShadowLight => [
    BoxShadow(
      color: const Color(0x0F000000),
      blurRadius: 1,
      offset: const Offset(0, 0),
    ),
    BoxShadow(
      color: const Color(0x0D000000),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: const Color(0x0A000000),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get borderShadowLightHover => [
    BoxShadow(
      color: const Color(0x14000000),
      blurRadius: 1,
      offset: const Offset(0, 0),
    ),
    BoxShadow(
      color: const Color(0x12000000),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: const Color(0x0E000000),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  // ── Shadows as borders — dark mode ──
  // Dark mode simplifies to a single white ring (layered depth not visible).
  static List<BoxShadow> get borderShadowDark => [
    BoxShadow(
      color: const Color(0x14FFFFFF),
      blurRadius: 1,
      offset: const Offset(0, 0),
    ),
  ];

  static List<BoxShadow> get borderShadowDarkHover => [
    BoxShadow(
      color: const Color(0x21FFFFFF),
      blurRadius: 1,
      offset: const Offset(0, 0),
    ),
  ];

  // ── Legacy shadows (keep for backward compat) ──
  static List<BoxShadow> get cardShadowLight => borderShadowLight;
  static List<BoxShadow> get cardShadowDark => borderShadowDark;
  static List<BoxShadow> get cardShadowDarkHover => borderShadowDarkHover;

  // ── Category colors (unchanged — they're good) ──
  static const List<Color> categoryColors = [
    Color(0xFFE5484D),
    Color(0xFFD97706),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF0D9488),
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF97316),
    Color(0xFF6366F1),
    Color(0xFF14B8A6),
  ];

  static const List<String> categoryIcons = [
    'restaurant',
    'directions_car',
    'home',
    'shopping_bag',
    'receipt',
    'local_hospital',
    'school',
    'flight',
    'entertainment',
    'more_horiz',
  ];

  // ── Glass surface (for signature moments) ──
  static BoxDecoration glassDecoration({
    required bool isDark,
    Color? tint,
  }) {
    final surface = isDark ? cardDark : cardLight;
    final borderColor = isDark
        ? const Color(0x14FFFFFF)
        : const Color(0x0F000000);
    return BoxDecoration(
      color: tint?.withValues(alpha: 0.03) ?? surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor),
      boxShadow: isDark ? borderShadowDark : borderShadowLight,
    );
  }
}
