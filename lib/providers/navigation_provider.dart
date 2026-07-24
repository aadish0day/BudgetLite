import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the current bottom navigation tab index.
/// Allows any widget to switch tabs by writing to this provider.
final currentTabProvider = StateProvider<int>((ref) => 0);

/// Provider for pre-selecting a category filter on the transactions tab.
final transactionFilterProvider = StateProvider<String?>((ref) => null);

/// Provider for highlighting a budget category when navigated from an insight.
/// Value is a categoryId, or 'income' for the income summary card, or null for no highlight.
final budgetHighlightProvider = StateProvider<String?>((ref) => null);
