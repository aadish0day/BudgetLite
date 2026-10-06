import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quick_actions/quick_actions.dart';
import 'app.dart';

final quickActionCallbackProvider = StateProvider<void Function(int tabIndex)?>(
  (ref) => null,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Strict offline-first enforcement: disable remote font fetching
  GoogleFonts.config.allowRuntimeFetching = false;

  runApp(const ProviderScope(child: BudgetLiteApp()));
}

final _quickActionsInitialized = StateProvider<bool>((ref) => false);

void setupQuickActions(WidgetRef ref) {
  if (ref.read(_quickActionsInitialized)) return;
  ref.read(_quickActionsInitialized.notifier).state = true;

  const quickActions = QuickActions();
  quickActions.initialize((shortcutType) {
    final callback = ref.read(quickActionCallbackProvider);
    switch (shortcutType) {
      case 'add_expense':
        callback?.call(0);
        break;
      case 'view_transactions':
        callback?.call(1);
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
