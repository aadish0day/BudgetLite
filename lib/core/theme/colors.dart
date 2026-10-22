import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Primary accent — signature teal (look.md) ──
  static const Color primary = Color(0xFF0D7377);
  static const Color primaryHover = Color(0xFF0B5E62);
  static const Color primaryLight = Color(0xFF14B8A6);
  static const Color primaryDark = Color(0xFF14B8A6);

  // ── Secondary — warm amber ──
  static const Color secondary = Color(0xFFD97706);
  static const Color secondaryLight = Color(0xFFF59E0B);
  static const Color secondaryDark = Color(0xFFB45309);
  static const Color accent = Color(0xFFF59E0B);

  // ── Tertiary — muted plum ──
  static const Color tertiary = Color(0xFF8B5CF6);
  static const Color tertiaryLight = Color(0xFFA78BFA);
  static const Color tertiaryDark = Color(0xFF7C3AED);

  // ── Semantic — muted (look.md) ──
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF0D7377);

  // ── Neutral ramp — tinted (look.md) ──
  static const Color nearWhite = Color(0xFFF8FAFA);
  static const Color surfaceLight = Color(0xFFF8FAFA);
  static const Color backgroundLight = Color(0xFFF0F4F4);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color raisedLight = Color(0xFFF1F5F5);
  static const Color onSurfaceLight = Color(0xFF1A1A2E);
  static const Color onSurfaceVariantLight = Color(0xFF62748E);
  static const Color outlineLight = Color(0xFFE2E8F0);
  static const Color outlineLightStrong = Color(0xFFCBD5E1);

  // ── Dark surfaces — elevated depth (look.md) ──
  static const Color surfaceDark = Color(0xFF0F171E);
  static const Color backgroundDark = Color(0xFF0B1117);
  static const Color cardDark = Color(0xFF1A2332);
  static const Color raisedDark = Color(0xFF1E2838);
  static const Color elevatedDark = Color(0xFF222D3D);
  static const Color onSurfaceDark = Color(0xFFE8EDF2);
  static const Color onSurfaceVariantDark = Color(0xFF8896A6);
  static const Color outlineDark = Color(0xFF2A3545);
  static const Color outlineDarkStrong = Color(0xFF374558);

  // ── Shadows as borders — light mode ──
  static List<BoxShadow> get borderShadowLight => [
    const BoxShadow(color: Color(0x0F000000), blurRadius: 1),
    const BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    const BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  // ── Shadows as borders — dark mode ──
  // Dark mode simplifies to a single white ring (layered depth not visible).
  static List<BoxShadow> get borderShadowDark => [
    const BoxShadow(color: Color(0x14FFFFFF), blurRadius: 1),
  ];

  // ── Legacy shadows (keep for backward compat) ──
  static List<BoxShadow> get cardShadowLight => borderShadowLight;
  static List<BoxShadow> get cardShadowDark => borderShadowDark;

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
}
