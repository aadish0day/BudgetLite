import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';
import 'app.dart';

/// Global navigation function used by app shortcuts.
/// Set by _MainShellState when it's initialized.
void Function(int tabIndex)? _navigateToTab;

/// Register a callback that app shortcuts can use to navigate.
void registerTabNavigation(void Function(int tabIndex) callback) {
  _navigateToTab = callback;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  _setupQuickActions();

  runApp(
    const ProviderScope(
      child: BudgetLiteApp(),
    ),
  );
}

void _setupQuickActions() {
  const quickActions = QuickActions();
  quickActions.initialize((shortcutType) {
    switch (shortcutType) {
      case 'add_expense':
        _navigateToTab?.call(0);
        break;
      case 'view_transactions':
        _navigateToTab?.call(1);
        break;
    }
  });

  quickActions.setShortcutItems([
    const ShortcutItem(
      type: 'add_expense',
      localizedTitle: 'Add Expense',
      icon: 'ic_add',
    ),
    const ShortcutItem(
      type: 'view_transactions',
      localizedTitle: 'Transactions',
      icon: 'ic_list',
    ),
  ]);
}
