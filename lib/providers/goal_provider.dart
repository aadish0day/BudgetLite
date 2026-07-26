import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../core/database/database.dart';
import 'database_provider.dart';
import 'transaction_provider.dart';

final goalsProvider = StreamProvider<List<Goal>>((ref) {
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
    final goal = await (db.select(db.goals)..where((t) => t.id.equals(id))).getSingle();
    final newAmount = (goal.currentAmount + amount).clamp(0.0, double.infinity);
    await (db.update(db.goals)..where((t) => t.id.equals(id))).write(
      GoalsCompanion(currentAmount: Value(newAmount)),
    );

    if (amount > 0) {
      final txnNotifier = ref.read(transactionNotifierProvider.notifier);
      await txnNotifier.addTransaction(
        amount: amount,
        categoryId: 'savings',
        note: 'Contribution to Goal: ${goal.name}',
        date: DateTime.now(),
      );
    }
    ref.invalidate(goalsProvider);
  }

  Future<void> deleteGoal(String id) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.goals)..where((t) => t.id.equals(id))).go();
    ref.invalidate(goalsProvider);
  }
}

final goalNotifierProvider =
    StateNotifierProvider<GoalNotifier, AsyncValue<void>>((ref) {
  return GoalNotifier(ref);
});
