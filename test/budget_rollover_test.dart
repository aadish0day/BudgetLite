import 'package:budget_lite/core/database/database.dart';
import 'package:budget_lite/core/utils/formatters.dart';
import 'package:budget_lite/providers/budget_provider.dart';
import 'package:budget_lite/providers/database_provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  const uuid = Uuid();
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Budget Rollover & Calculations', () {
    test('effective budget without rollover matches base allocated amount',
        () async {
      final categories = await db.select(db.categories).get();
      final cat = categories.first;

      await db.into(db.budgets).insert(
            BudgetsCompanion.insert(
              id: uuid.v4(),
              categoryId: cat.id,
              allocatedAmount: 5000,
              month: Formatters.monthKey,
              rollover: const drift.Value(false),
            ),
          );

      final result = await container.read(
        effectiveCategoryBudgetProvider(cat.id).future,
      );

      expect(result.baseAllocated, 5000);
      expect(result.effectiveAllocated, 5000);
      expect(result.rollover, isFalse);
      expect(result.spent, 0);
    });

    test('effective budget with rollover carries over positive unspent amount',
        () async {
      final categories = await db.select(db.categories).get();
      final cat = categories.first;

      final accountId = uuid.v4();
      await db.into(db.accounts).insert(
            AccountsCompanion.insert(
              id: accountId,
              name: 'Primary Account',
            ),
          );

      // Previous month budget: allocated 4000 with rollover true
      await db.into(db.budgets).insert(
            BudgetsCompanion.insert(
              id: uuid.v4(),
              categoryId: cat.id,
              allocatedAmount: 4000,
              month: Formatters.previousMonthKey,
              rollover: const drift.Value(true),
            ),
          );

      // Previous month transaction: spent 2500 (unspent 1500)
      final now = DateTime.now();
      final prevDate = DateTime(now.year, now.month - 1, 15);
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: uuid.v4(),
              accountId: accountId,
              categoryId: cat.id,
              amount: 2500,
              date: prevDate,
            ),
          );

      // This month budget: allocated 5000 with rollover true
      await db.into(db.budgets).insert(
            BudgetsCompanion.insert(
              id: uuid.v4(),
              categoryId: cat.id,
              allocatedAmount: 5000,
              month: Formatters.monthKey,
              rollover: const drift.Value(true),
            ),
          );

      // This month transaction: spent 800
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: uuid.v4(),
              accountId: accountId,
              categoryId: cat.id,
              amount: 800,
              date: now,
            ),
          );

      final result = await container.read(
        effectiveCategoryBudgetProvider(cat.id).future,
      );

      expect(result.baseAllocated, 5000);
      // 5000 base + 1500 carryover = 6500 effective
      expect(result.effectiveAllocated, 6500);
      expect(result.rollover, isTrue);
      expect(result.spent, 800);
    });

    test('overspending in previous month does not carry as negative carryover',
        () async {
      final categories = await db.select(db.categories).get();
      final cat = categories.first;

      final accountId = uuid.v4();
      await db.into(db.accounts).insert(
            AccountsCompanion.insert(
              id: accountId,
              name: 'Bank',
            ),
          );

      // Previous month budget: allocated 3000
      await db.into(db.budgets).insert(
            BudgetsCompanion.insert(
              id: uuid.v4(),
              categoryId: cat.id,
              allocatedAmount: 3000,
              month: Formatters.previousMonthKey,
              rollover: const drift.Value(true),
            ),
          );

      // Previous month spent 4500 (overspend 1500)
      final now = DateTime.now();
      final prevDate = DateTime(now.year, now.month - 1, 10);
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: uuid.v4(),
              accountId: accountId,
              categoryId: cat.id,
              amount: 4500,
              date: prevDate,
            ),
          );

      // This month budget: allocated 5000
      await db.into(db.budgets).insert(
            BudgetsCompanion.insert(
              id: uuid.v4(),
              categoryId: cat.id,
              allocatedAmount: 5000,
              month: Formatters.monthKey,
              rollover: const drift.Value(true),
            ),
          );

      final result = await container.read(
        effectiveCategoryBudgetProvider(cat.id).future,
      );

      // Overspend should not reduce base allocation
      expect(result.baseAllocated, 5000);
      expect(result.effectiveAllocated, 5000);
      expect(result.rollover, isTrue);
    });
  });
}
