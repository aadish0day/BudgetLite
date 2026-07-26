import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/database/database.dart';
import '../core/utils/formatters.dart';
import '../core/theme/colors.dart';
import 'transaction_provider.dart';
import 'database_provider.dart';
import 'settings_provider.dart';

final budgetsProvider = StreamProvider<List<Budget>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.budgets).watch();
});

final budgetsByMonthProvider =
    StreamProvider.family<List<Budget>, String>((ref, monthKey) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.budgets)..where((t) => t.month.equals(monthKey))).watch();
});

final thisMonthBudgetsProvider = StreamProvider<List<Budget>>((ref) {
  final asyncBudgets = ref.watch(budgetsByMonthProvider(Formatters.monthKey));
  return asyncBudgets.when(
    data: (budgets) => Stream.value(budgets),
    error: (err, stack) => Stream.error(err, stack),
    loading: () => const Stream.empty(),
  );
});

final monthlyIncomeProvider = StreamProvider<double>((ref) {
  final asyncIncome = ref.watch(totalIncomeThisMonthProvider);
  return asyncIncome.when(
    data: (income) => Stream.value(income),
    error: (err, stack) => Stream.error(err, stack),
    loading: () => const Stream.empty(),
  );
});

final totalBudgetThisMonthProvider = StreamProvider<double>((ref) {
  final asyncBudgets = ref.watch(thisMonthBudgetsProvider);
  return asyncBudgets.when(
    data: (budgets) {
      final total = budgets.fold<double>(0, (sum, b) => sum + b.allocatedAmount);
      return Stream.value(total);
    },
    error: (err, stack) => Stream.error(err, stack),
    loading: () => const Stream.empty(),
  );
});

final remainingBudgetProvider = StreamProvider<double>((ref) {
  final incomeAsync = ref.watch(monthlyIncomeProvider);
  final spentAsync = ref.watch(totalSpentThisMonthProvider);
  final income = incomeAsync.valueOrNull ?? 0.0;
  final spent = spentAsync.valueOrNull ?? 0.0;
  return Stream.value(income - spent);
});

class BudgetNotifier extends StateNotifier<AsyncValue<void>> {
  BudgetNotifier(this.ref) : super(const AsyncData(null));
  final Ref ref;

  Future<void> setBudget({
    required String categoryId,
    required double amount,
    bool rollover = false,
  }) async {
    // Allocated amount must be >= 0
    final validAmount = amount < 0 ? 0.0 : amount;
    final db = ref.read(databaseProvider);
    final existing = await (db.select(db.budgets)
          ..where((t) => t.categoryId.equals(categoryId))
          ..where((t) => t.month.equals(Formatters.monthKey)))
        .get();

    if (existing.isNotEmpty) {
      await (db.update(db.budgets)
            ..where((t) => t.id.equals(existing.first.id)))
          .write(BudgetsCompanion(
        allocatedAmount: Value(validAmount),
        rollover: Value(rollover),
      ));
    } else {
      await db.into(db.budgets).insert(BudgetsCompanion.insert(
        id: const Uuid().v4(),
        categoryId: categoryId,
        month: Formatters.monthKey,
        allocatedAmount: validAmount,
        rollover: Value(rollover),
      ));
    }
    ref.invalidate(budgetsProvider);
    ref.invalidate(thisMonthBudgetsProvider);
    ref.invalidate(totalBudgetThisMonthProvider);
    ref.invalidate(effectiveCategoryBudgetProvider(categoryId));
  }

  /// Check budget thresholds after adding a transaction.
  /// Fires notification only once per threshold crossing (not on every transaction after).
  Future<void> checkBudgetThresholds({
    required BuildContext context,
    required String categoryId,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final info = await ref.read(effectiveCategoryBudgetProvider(categoryId).future);
    if (info.effectiveAllocated <= 0) return;
    final ratio = info.spent / info.effectiveAllocated;
    final settings = ref.read(settingsNotifierProvider.notifier);

    if (ratio >= 1.0) {
      final alreadyNotified = await settings.wasBudgetNotified(categoryId, 'over');
      if (!alreadyNotified) {
        await settings.setBudgetNotified(categoryId, 'over');
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(LucideIcons.alertTriangle, size: 18, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Over budget! ₹${(info.spent - info.effectiveAllocated).toStringAsFixed(0)} exceeded'),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            backgroundColor: AppColors.error.withValues(alpha: 0.9),
          ),
        );
      }
    } else if (ratio >= 0.8) {
      final alreadyNotified = await settings.wasBudgetNotified(categoryId, 'approaching');
      if (!alreadyNotified) {
        await settings.setBudgetNotified(categoryId, 'approaching');
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(LucideIcons.bell, size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Approaching limit! ${(ratio * 100).toStringAsFixed(0)}% of budget used',
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            backgroundColor: AppColors.warning.withValues(alpha: 0.9),
          ),
        );
      }
    } else {
      await settings.resetBudgetNotified(categoryId);
    }
  }
}

final budgetNotifierProvider =
    StateNotifierProvider<BudgetNotifier, AsyncValue<void>>((ref) {
  return BudgetNotifier(ref);
});

/// Provider for effective budget of a category for this month, including rollover carryover if enabled.
/// If rollover is ON: effectiveAllocated = baseAllocated + max(0, previousAllocated - previousUsed). Overspend does NOT carry as negative.
/// If rollover is OFF: effectiveAllocated = baseAllocated.
final effectiveCategoryBudgetProvider =
    FutureProvider.family<({double baseAllocated, double effectiveAllocated, double spent, bool rollover}), String>(
        (ref, categoryId) async {
  final thisMonthBudgets = await ref.read(thisMonthBudgetsProvider.future);
  final budget = thisMonthBudgets.where((b) => b.categoryId == categoryId).firstOrNull;

  final baseAllocated = budget?.allocatedAmount ?? 0.0;
  final rollover = budget?.rollover ?? false;

  // Derive live used amount from this month's transactions
  final thisMonthTxns = await ref.read(thisMonthTransactionsProvider.future);
  final spent = thisMonthTxns
      .where((t) => t.categoryId == categoryId && t.amount > 0)
      .fold<double>(0, (sum, t) => sum + t.amount);

  double carryover = 0.0;
  if (rollover) {
    // Check previous month budget and usage
    final prevMonthBudgets = await ref.read(budgetsByMonthProvider(Formatters.previousMonthKey).future);
    final prevBudget = prevMonthBudgets.where((b) => b.categoryId == categoryId).firstOrNull;
    if (prevBudget != null) {
      final prevMonthTxns = await ref.read(transactionsByMonthProvider(Formatters.previousMonthKey).future);
      final prevSpent = prevMonthTxns
          .where((t) => t.categoryId == categoryId && t.amount > 0)
          .fold<double>(0, (sum, t) => sum + t.amount);
      final unspent = prevBudget.allocatedAmount - prevSpent;
      // Overspend does NOT carry as negative
      if (unspent > 0) {
        carryover = unspent;
      }
    }
  }

  final effectiveAllocated = baseAllocated + carryover;
  return (
    baseAllocated: baseAllocated,
    effectiveAllocated: effectiveAllocated,
    spent: spent,
    rollover: rollover,
  );
});

/// Provider for the used budget ratio per category (using effective budget with rollover)
final categoryBudgetUsageProvider =
    FutureProvider.family<double, String>((ref, categoryId) async {
  final info = await ref.read(effectiveCategoryBudgetProvider(categoryId).future);
  if (info.effectiveAllocated <= 0) return 0.0;
  return (info.spent / info.effectiveAllocated).clamp(0, 2).toDouble();
});
