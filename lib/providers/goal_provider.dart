import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../core/database/database.dart';
import 'database_provider.dart';
import 'transaction_provider.dart';

final goalsProvider = StreamProvider.autoDispose<List<Goal>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.goals)
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
      .watch();
});

class GoalNotifier extends StateNotifier<AsyncValue<void>> {
  GoalNotifier(this.ref) : super(const AsyncData(null));
  final Ref ref;

  Future<void> addGoal({
    required String name,
    required double targetAmount,
    required DateTime targetDate,
    int color = 0xFF14B8A6,
    String icon = 'flag',
  }) async {
    final db = ref.read(databaseProvider);
    await db.into(db.goals).insert(GoalsCompanion.insert(
      id: const Uuid().v4(),
      name: name,
      targetAmount: targetAmount,
      currentAmount: const Value(0),
      targetDate: targetDate,
      color: Value(color),
      icon: Value(icon),
    ));
    ref.invalidate(goalsProvider);
  }

  Future<void> updateGoalProgress(String id, double amount) async {
    final db = ref.read(databaseProvider);
    final rows = await (db.select(db.goals)..where((t) => t.id.equals(id))).get();
    final goal = rows.isNotEmpty ? rows.first : null;
    if (goal == null) return;
    final newAmount = (goal.currentAmount + amount).clamp(0.0, double.infinity);

    if (amount > 0) {
      // Record the ledger entry first — if it fails, the goal balance stays
      // consistent with the transaction history.
      const savingsCategoryId = 'savings';
      final savingsCat = await (db.select(db.categories)
            ..where((c) => c.id.equals(savingsCategoryId)))
          .getSingleOrNull();
      if (savingsCat == null) {
        // Seed data has no 'savings' category; create it on first use so
        // contributions don't reference a dangling categoryId.
        await db.into(db.categories).insert(CategoriesCompanion.insert(
              id: savingsCategoryId,
              name: 'Savings',
              icon: const Value('savings'),
              color: const Value(0xFF14B8A6),
              type: const Value('expense'),
              sortOrder: const Value(90),
            ));
        ref.invalidate(categoriesProvider);
        ref.invalidate(expenseCategoriesProvider);
      }
      final txnNotifier = ref.read(transactionNotifierProvider.notifier);
      await txnNotifier.addTransaction(
        amount: amount,
        categoryId: savingsCategoryId,
        note: 'Contribution to Goal: ${goal.name}',
        date: DateTime.now(),
      );
    }

    await (db.update(db.goals)..where((t) => t.id.equals(id))).write(
      GoalsCompanion(currentAmount: Value(newAmount)),
    );
    ref.invalidate(goalsProvider);
  }

  Future<void> deleteGoal(String id) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.goals)..where((t) => t.id.equals(id))).go();
    ref.invalidate(goalsProvider);
  }
}

final goalNotifierProvider =
    StateNotifierProvider.autoDispose<GoalNotifier, AsyncValue<void>>((ref) {
  return GoalNotifier(ref);
});
