import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'BudgetLite';
  static const String appTagline = 'Smart budgeting, simplified.';

  static const double cardRadius = 18;
  static const double cardRadiusSmall = 14;
  static const double cardRadiusIcon = 10;
  static const double cardRadiusLarge = 22;

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 16,
  );

  static const EdgeInsets cardPadding = EdgeInsets.all(20);
  static const EdgeInsets cardPaddingCompact = EdgeInsets.all(16);

  // ── 8pt grid spacing scale ──
  static const double spaceXxs = 2;
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 20;
  static const double space2xl = 24;
  static const double space3xl = 32;
  static const double space4xl = 40;

  // ── Border radius scale (replaces scattered raw values) ──
  static const double radiusXs = 6; // badges, chips, small pills
  static const double radiusSm = 10; // icon containers
  static const double radiusMd = 14; // inner cards, inputs
  static const double radiusLg = 18; // outer cards (same as cardRadius)
  static const double radiusXl = 22; // modals, sheets
  static const double radiusFull = 999; // pills, circular

  // ── Animation durations ──
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 500);
  static const Duration staggerDelay = Duration(milliseconds: 60);

  static List<String> paymentMethods = [
    'Cash',
    'UPI',
    'Debit Card',
    'Credit Card',
    'Net Banking',
    'Wallet',
  ];

  static List<String> recurringIntervals = [
    'daily',
    'weekly',
    'biweekly',
    'monthly',
    'quarterly',
    'yearly',
  ];

  static const List<Color> progressGradientColors = [
    Color(0xFF0D7377),
    Color(0xFF14B8A6),
  ];
}
