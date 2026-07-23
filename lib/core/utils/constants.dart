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
