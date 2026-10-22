import 'package:budget_lite/core/database/database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  const uuid = Uuid();
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase Offline Operations', () {
    test('database seeds default categories on creation', () async {
      final categories = await db.select(db.categories).get();
      expect(categories, isNotEmpty);
      expect(categories.any((c) => c.name == 'Food'), isTrue);
      expect(categories.any((c) => c.name == 'Income'), isTrue);
    });

    test('can create accounts and insert transactions', () async {
      final accountId = uuid.v4();
      await db.into(db.accounts).insert(
            AccountsCompanion.insert(
              id: accountId,
              name: 'Cash Wallet',
              balance: const drift.Value(5000),
            ),
          );

      final categories = await db.select(db.categories).get();
      final foodCategory = categories.firstWhere((c) => c.type == 'expense');

      final txnId = uuid.v4();
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: txnId,
              accountId: accountId,
              categoryId: foodCategory.id,
              amount: 250,
              date: DateTime.now(),
              payee: const drift.Value('Local Cafe'),
            ),
          );

      final txns = await (db.select(db.transactions)
            ..where((t) => t.id.equals(txnId)))
          .get();
      expect(txns.length, 1);
      expect(txns.first.amount, 250.0);
      expect(txns.first.payee, 'Local Cafe');

      // Test count query
      final count = await db.getTransactionCountForCategory(foodCategory.id);
      expect(count, 1);
    });

    test('reassigns transactions when a category is deleted', () async {
      final accountId = uuid.v4();
      await db.into(db.accounts).insert(
            AccountsCompanion.insert(
              id: accountId,
              name: 'Bank Account',
            ),
          );

      final catAId = uuid.v4();
      final catBId = uuid.v4();

      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              id: catAId,
              name: 'Old Category',
              icon: const drift.Value('folder'),
              color: const drift.Value(0xFF123456),
              type: const drift.Value('expense'),
            ),
          );

      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              id: catBId,
              name: 'New Category',
              icon: const drift.Value('tag'),
              color: const drift.Value(0xFF654321),
              type: const drift.Value('expense'),
            ),
          );

      final txnId = uuid.v4();
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: txnId,
              accountId: accountId,
              categoryId: catAId,
              amount: 100,
              date: DateTime.now(),
            ),
          );

      expect(await db.getTransactionCountForCategory(catAId), 1);
      expect(await db.getTransactionCountForCategory(catBId), 0);

      // Reassign transactions from catA to catB
      await (db.update(db.transactions)..where((t) => t.categoryId.equals(catAId)))
          .write(TransactionsCompanion(categoryId: drift.Value(catBId)));

      // Delete catA
      await (db.delete(db.categories)..where((c) => c.id.equals(catAId))).go();

      expect(await db.getTransactionCountForCategory(catAId), 0);
      expect(await db.getTransactionCountForCategory(catBId), 1);

      final catList = await (db.select(db.categories)..where((c) => c.id.equals(catAId))).get();
      expect(catList, isEmpty);
    });

    test('stores and updates monthly budget allocations', () async {
      final categories = await db.select(db.categories).get();
      final cat = categories.first;
      final now = DateTime.now();
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final budgetId = uuid.v4();

      await db.into(db.budgets).insert(
            BudgetsCompanion.insert(
              id: budgetId,
              categoryId: cat.id,
              allocatedAmount: 15000,
              month: month,
              rollover: const drift.Value(true),
            ),
          );

      final budgets = await (db.select(db.budgets)
            ..where((b) => b.categoryId.equals(cat.id) & b.month.equals(month)))
          .get();

      expect(budgets.length, 1);
      expect(budgets.first.allocatedAmount, 15000.0);
      expect(budgets.first.rollover, isTrue);
    });

    test('watchRecentTransactions limits results correctly', () async {
      final accountId = uuid.v4();
      await db.into(db.accounts).insert(
            AccountsCompanion.insert(
              id: accountId,
              name: 'Test Account',
            ),
          );
      final categories = await db.select(db.categories).get();
      final cat = categories.first;

      for (int i = 0; i < 10; i++) {
        await db.into(db.transactions).insert(
              TransactionsCompanion.insert(
                id: uuid.v4(),
                accountId: accountId,
                categoryId: cat.id,
                amount: 10.0 * (i + 1),
                date: DateTime.now().subtract(Duration(minutes: 10 - i)),
              ),
            );
      }

      final recent = await db.watchRecentTransactions().first;
      expect(recent.length, 5);
      // Verify ordering: newest first
      expect(recent.first.amount, 100);
    });

    test('watchRecurringTransactions returns only active recurring rules', () async {
      final accountId = uuid.v4();
      await db.into(db.accounts).insert(
            AccountsCompanion.insert(
              id: accountId,
              name: 'Test Account',
            ),
          );
      final categories = await db.select(db.categories).get();
      final cat = categories.first;

      // Regular transaction
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: uuid.v4(),
              accountId: accountId,
              categoryId: cat.id,
              amount: 50,
              date: DateTime.now(),
            ),
          );

      // Recurring rule template
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: uuid.v4(),
              accountId: accountId,
              categoryId: cat.id,
              amount: 99,
              date: DateTime.now(),
              isRecurring: const drift.Value(true),
              recurringInterval: const drift.Value('monthly'),
              isRecurringInstance: const drift.Value(false),
            ),
          );

      // Recurring instance (not the template)
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: uuid.v4(),
              accountId: accountId,
              categoryId: cat.id,
              amount: 99,
              date: DateTime.now(),
              isRecurring: const drift.Value(true),
              recurringInterval: const drift.Value('monthly'),
              isRecurringInstance: const drift.Value(true),
            ),
          );

      final recurring = await db.watchRecurringTransactions().first;
      expect(recurring.length, 1);
      expect(recurring.first.amount, 99.0);
      expect(recurring.first.isRecurringInstance, isFalse);
    });

    test('checkpointWal executes SQLite wal_checkpoint without error', () async {
      await expectLater(db.checkpointWal(), completes);
    });

    test('categories are seeded with valid sortOrder and default categories', () async {
      final categories = await (db.select(db.categories)
            ..orderBy([(c) => drift.OrderingTerm(expression: c.sortOrder)]))
          .get();
      expect(categories.length, greaterThanOrEqualTo(8));
      for (int i = 0; i < categories.length - 1; i++) {
        expect(categories[i].sortOrder <= categories[i + 1].sortOrder, isTrue);
      }
    });

    test('clearAllData wipes all tables and reseeds default account and categories', () async {
      final defaultAccount = await db.getDefaultAccount();
      final cat = (await db.select(db.categories).get()).first;

      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: uuid.v4(),
              accountId: defaultAccount.id,
              categoryId: cat.id,
              amount: 500,
              date: DateTime.now(),
            ),
          );

      await db.into(db.goals).insert(
            GoalsCompanion.insert(
              id: uuid.v4(),
              name: 'Emergency Fund',
              targetAmount: 50000,
              targetDate: DateTime.now().add(const Duration(days: 365)),
            ),
          );

      await db.into(db.monthlyIncome).insert(
            MonthlyIncomeCompanion.insert(
              id: uuid.v4(),
              month: '2026-07',
              amount: 60000,
            ),
          );

      await db.into(db.appSettings).insert(
            AppSettingsCompanion.insert(
              key: 'test_key',
              value: 'test_val',
            ),
          );

      // Verify records exist
      expect((await db.select(db.transactions).get()).length, 1);
      expect((await db.select(db.goals).get()).length, 1);
      expect((await db.select(db.monthlyIncome).get()).length, 1);
      expect((await db.select(db.appSettings).get()).length, 1);

      // Clear all
      await db.clearAllData();

      // Verify all tables emptied except seeded defaults
      expect(await db.select(db.transactions).get(), isEmpty);
      expect(await db.select(db.goals).get(), isEmpty);
      expect(await db.select(db.monthlyIncome).get(), isEmpty);
      expect(await db.select(db.appSettings).get(), isEmpty);
      expect(await db.select(db.budgets).get(), isEmpty);

      // Accounts and categories reseeded
      final accounts = await db.select(db.accounts).get();
      expect(accounts.length, 1);
      expect(accounts.first.id, 'default');
      final newCats = await db.select(db.categories).get();
      expect(newCats.length, 8);
    });
  });
}
