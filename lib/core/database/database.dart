import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    Budgets,
    Goals,
    MonthlyIncome,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _seedCategories();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.addColumn(transactions, transactions.isRecurringInstance);
      }
      if (from < 3) {
        await m.addColumn(transactions, transactions.recurringEndDate);
      }
      if (from < 4) {
        await m.addColumn(categories, categories.sortOrder);
      }
      if (from < 5) {
        await m.addColumn(transactions, transactions.payee);
        await customStatement(
          'UPDATE transactions SET payee = note, note = NULL WHERE payee IS NULL AND note IS NOT NULL AND note != ""',
        );
      }
    },
  );

  /// Migrate existing transaction data: copies legacy merchant names from 'note' into 'payee' and clears 'note'
  Future<void> migrateLegacyPayees() async {
    final list = await (select(
      transactions,
    )..where((t) => t.payee.isNull() & t.note.isNotNull())).get();
    for (final txn in list) {
      if (txn.note != null &&
          txn.note!.trim().isNotEmpty &&
          (txn.payee == null || txn.payee!.isEmpty)) {
        await (update(transactions)..where((t) => t.id.equals(txn.id))).write(
          TransactionsCompanion(
            payee: Value(txn.note),
            note: const Value(null),
          ),
        );
      }
    }
  }

  Future<void> _seedCategories() async {
    await batch((b) {
      b.insertAll(categories, [
        CategoriesCompanion.insert(
          id: 'food',
          name: 'Food',
          icon: const Value('restaurant'),
          color: const Value(0xFFEF4444),
          type: const Value('expense'),
          sortOrder: const Value(1),
        ),
        CategoriesCompanion.insert(
          id: 'transport',
          name: 'Transport',
          icon: const Value('directions_car'),
          color: const Value(0xFFF59E0B),
          type: const Value('expense'),
          sortOrder: const Value(2),
        ),
        CategoriesCompanion.insert(
          id: 'rent',
          name: 'Rent',
          icon: const Value('home'),
          color: const Value(0xFF8B5CF6),
          type: const Value('expense'),
          sortOrder: const Value(3),
        ),
        CategoriesCompanion.insert(
          id: 'shopping',
          name: 'Shopping',
          icon: const Value('shopping_bag'),
          color: const Value(0xFFEC4899),
          type: const Value('expense'),
          sortOrder: const Value(4),
        ),
        CategoriesCompanion.insert(
          id: 'bills',
          name: 'Bills',
          icon: const Value('receipt'),
          color: const Value(0xFF0D7377),
          type: const Value('expense'),
          sortOrder: const Value(5),
        ),
        CategoriesCompanion.insert(
          id: 'entertainment',
          name: 'Entertainment',
          icon: const Value('gamepad_2'),
          color: const Value(0xFF8B5CF6),
          type: const Value('expense'),
          sortOrder: const Value(6),
        ),
        CategoriesCompanion.insert(
          id: 'other',
          name: 'Other',
          icon: const Value('more_horiz'),
          color: const Value(0xFF6B7280),
          type: const Value('expense'),
          sortOrder: const Value(7),
        ),
        CategoriesCompanion.insert(
          id: 'income',
          name: 'Income',
          icon: const Value('account_balance'),
          color: const Value(0xFF10B981),
          type: const Value('income'),
          sortOrder: const Value(8),
        ),
      ]);
    });

    await into(accounts).insert(
      AccountsCompanion.insert(
        id: 'default',
        name: 'Main Account',
        balance: const Value(0),
        currency: const Value('INR'),
      ),
    );
  }

  /// Watch the default account as a stream (for live balance updates).
  Stream<Account> watchDefaultAccount() {
    return (select(
      accounts,
    )..where((a) => a.id.equals('default'))).watchSingle();
  }

  /// Get the default account.
  Future<Account> getDefaultAccount() {
    return (select(accounts)..where((a) => a.id.equals('default'))).getSingle();
  }

  /// Update the balance of an account.
  Future<void> updateAccountBalance(String accountId, double newBalance) async {
    await (update(accounts)..where((a) => a.id.equals(accountId))).write(
      AccountsCompanion(balance: Value(newBalance)),
    );
  }

  /// Get number of transactions tied to a category.
  Future<int> getTransactionCountForCategory(String categoryId) async {
    final query = select(transactions)
      ..where((t) => t.categoryId.equals(categoryId));
    final list = await query.get();
    return list.length;
  }

  /// Delete a category after reassigning existing transactions and budgets to targetCategoryId.
  Future<void> deleteCategoryWithReassignment(
    String categoryId,
    String targetCategoryId,
  ) async {
    await transaction(() async {
      await (update(transactions)
            ..where((t) => t.categoryId.equals(categoryId)))
          .write(TransactionsCompanion(categoryId: Value(targetCategoryId)));
      await (delete(
        budgets,
      )..where((b) => b.categoryId.equals(categoryId))).go();
      await (delete(categories)..where((c) => c.id.equals(categoryId))).go();
    });
  }

  /// Delete ALL stored data (transactions, budgets, goals, recurring definitions, settings, tags)
  /// and re-seed default account and categories.
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(transactions).go();
      await delete(budgets).go();
      await delete(goals).go();
      await delete(monthlyIncome).go();
      await delete(appSettings).go();
      await delete(categories).go();
      await delete(accounts).go();

      await _seedCategories();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'budget_lite.db'));
    return NativeDatabase(
      file,
      setup: (rawDb) {
        rawDb.execute('PRAGMA foreign_keys = ON;');
      },
    );
  });
}
