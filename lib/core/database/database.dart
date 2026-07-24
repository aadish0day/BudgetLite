import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Accounts,
  Categories,
  Transactions,
  Budgets,
  Goals,
  MonthlyIncome,
  AppSettings,
  Tags,
  TransactionTags,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

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
        await m.createTable(tags);
        await m.createTable(transactionTags);
      }
    },
  );

  Future<void> _seedCategories() async {
    await batch((b) {
      b.insertAll(categories, [
        CategoriesCompanion.insert(
          id: 'food',
          name: 'Food',
          icon: const Value('restaurant'),
          color: const Value(0xFFEF4444),
          type: const Value('expense'),
        ),
        CategoriesCompanion.insert(
          id: 'transport',
          name: 'Transport',
          icon: const Value('directions_car'),
          color: const Value(0xFFF59E0B),
          type: const Value('expense'),
        ),
        CategoriesCompanion.insert(
          id: 'rent',
          name: 'Rent',
          icon: const Value('home'),
          color: const Value(0xFF8B5CF6),
          type: const Value('expense'),
        ),
        CategoriesCompanion.insert(
          id: 'shopping',
          name: 'Shopping',
          icon: const Value('shopping_bag'),
          color: const Value(0xFFEC4899),
          type: const Value('expense'),
        ),
        CategoriesCompanion.insert(
          id: 'bills',
          name: 'Bills',
          icon: const Value('receipt'),
          color: const Value(0xFF0D7377),
          type: const Value('expense'),
        ),
        CategoriesCompanion.insert(
          id: 'entertainment',
          name: 'Entertainment',
          icon: const Value('gamepad_2'),
          color: const Value(0xFF8B5CF6),
          type: const Value('expense'),
        ),
        CategoriesCompanion.insert(
          id: 'other',
          name: 'Other',
          icon: const Value('more_horiz'),
          color: const Value(0xFF6B7280),
          type: const Value('expense'),
        ),
        CategoriesCompanion.insert(
          id: 'income',
          name: 'Income',
          icon: const Value('account_balance'),
          color: const Value(0xFF10B981),
          type: const Value('income'),
        ),
      ]);
    });

    await into(accounts).insert(AccountsCompanion.insert(
      id: 'default',
      name: 'Main Account',
      balance: const Value(0),
      currency: const Value('INR'),
    ));
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'budget_lite.db'));
    return NativeDatabase(file);
  });
}
