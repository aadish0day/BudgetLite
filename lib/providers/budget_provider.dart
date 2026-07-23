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

final budgetsProvider = FutureProvider<List<Budget>>((ref) async {
  final db = ref.read(databaseProvider);
  return db.select(db.budgets).get();
});

final budgetsByMonthProvider =
    FutureProvider.family<List<Budget>, String>((ref, monthKey) async {
  final db = ref.read(databaseProvider);
  return (db.select(db.budgets)..where((t) => t.month.equals(monthKey))).get();
});

final thisMonthBudgetsProvider = FutureProvider<List<Budget>>((ref) async {
  return ref.read(budgetsByMonthProvider(Formatters.monthKey).future);
});

final monthlyIncomeProvider = FutureProvider<double>((ref) async {
  final db = ref.read(databaseProvider);
  final incomes = await (db.select(db.monthlyIncome)
        ..where((t) => t.month.equals(Formatters.monthKey)))
      .get();
  return incomes.isNotEmpty ? incomes.first.amount : 0;
});

final totalBudgetThisMonthProvider = FutureProvider<double>((ref) async {
  final budgets = await ref.read(thisMonthBudgetsProvider.future);
  return budgets.fold<double>(0, (sum, b) => sum + b.allocatedAmount);
});

final remainingBudgetProvider = FutureProvider<double>((ref) async {
  final income = await ref.read(monthlyIncomeProvider.future);
  final spent = await ref.read(totalSpentThisMonthProvider.future);
  return income - spent;
});

// Import from transaction_provider
class BudgetNotifier extends StateNotifier<AsyncValue<void>> {
  BudgetNotifier(this.ref) : super(const AsyncData(null));
  final Ref ref;

  Future<void> setMonthlyIncome(double amount) async {
    final db = ref.read(databaseProvider);
    final existing = await (db.select(db.monthlyIncome)
          ..where((t) => t.month.equals(Formatters.monthKey)))
        .get();

    if (existing.isNotEmpty) {
      await (db.update(db.monthlyIncome)
            ..where((t) => t.month.equals(Formatters.monthKey)))
          .write(MonthlyIncomeCompanion(amount: Value(amount)));
    } else {
      await db.into(db.monthlyIncome).insert(MonthlyIncomeCompanion.insert(
        id: const Uuid().v4(),
        month: Formatters.monthKey,
        amount: amount,
      ));
    }
    ref.invalidate(monthlyIncomeProvider);
    ref.invalidate(remainingBudgetProvider);
  }

  Future<void> setBudget({
    required String categoryId,
    required double amount,
    bool rollover = false,
  }) async {
    final db = ref.read(databaseProvider);
    final existing = await (db.select(db.budgets)
          ..where((t) => t.categoryId.equals(categoryId))
          ..where((t) => t.month.equals(Formatters.monthKey)))
        .get();

    if (existing.isNotEmpty) {
      await (db.update(db.budgets)
            ..where((t) => t.id.equals(existing.first.id)))
          .write(BudgetsCompanion(
        allocatedAmount: Value(amount),
        rollover: Value(rollover),
      ));
    } else {
      await db.into(db.budgets).insert(BudgetsCompanion.insert(
        id: const Uuid().v4(),
        categoryId: categoryId,
        month: Formatters.monthKey,
        allocatedAmount: amount,
        rollover: Value(rollover),
      ));
    }
    ref.invalidate(budgetsProvider);
    ref.invalidate(thisMonthBudgetsProvider);
    ref.invalidate(totalBudgetThisMonthProvider);
  }

  /// Check budget thresholds after adding a transaction.
  /// Shows a snackbar if the category budget is at >= 80% or >= 100% usage.
  Future<void> checkBudgetThresholds({
    required BuildContext context,
    required String categoryId,
  }) async {
    final budgets = await ref.read(thisMonthBudgetsProvider.future);
    final budget = budgets.where((b) => b.categoryId == categoryId).firstOrNull;
    if (budget == null) return;

    final transactions = await ref.read(thisMonthTransactionsProvider.future);
    final spent = transactions
        .where((t) => t.categoryId == categoryId)
        .fold<double>(0, (sum, t) => sum + t.amount);

    if (budget.allocatedAmount <= 0) return;
    final ratio = spent / budget.allocatedAmount;

    if (ratio >= 1.0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(LucideIcons.alertTriangle, size: 18, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Over budget! ₹${(spent - budget.allocatedAmount).toStringAsFixed(0)} exceeded'),
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
    }
  }
}

final budgetNotifierProvider =
    StateNotifierProvider<BudgetNotifier, AsyncValue<void>>((ref) {
  return BudgetNotifier(ref);
});

/// Provider for the used budget ratio per category
final categoryBudgetUsageProvider =
    FutureProvider.family<double, String>((ref, categoryId) async {
  final budgets = await ref.read(thisMonthBudgetsProvider.future);
  final budget = budgets.where((b) => b.categoryId == categoryId).firstOrNull;
  if (budget == null) return 0.0;

  final transactions = await ref.read(thisMonthTransactionsProvider.future);
  final spent = transactions
      .where((t) => t.categoryId == categoryId)
      .fold<double>(0, (sum, t) => sum + t.amount);

  return budget.allocatedAmount > 0
      ? (spent / budget.allocatedAmount).clamp(0, 2).toDouble()
      : 0.0;
});
