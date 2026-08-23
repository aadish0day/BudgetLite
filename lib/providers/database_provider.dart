import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  db.migrateLegacyPayees();
  ref.onDispose(() => db.close());
  return db;
});

final categoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.select(db.categories).get();
});

final accountsProvider = FutureProvider.autoDispose<List<Account>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.select(db.accounts).get();
});

final expenseCategoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.categories)..where((tbl) => tbl.type.equals('expense')))
      .get();
});

/// Stream-based provider for the default account's initial/starting balance.
/// Updates live whenever the balance is changed via the edit dialog.
final initialBalanceProvider = StreamProvider.autoDispose<double>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchDefaultAccount().map((account) => account.balance);
});

/// Update the initial balance stored in the default account.
Future<void> updateInitialBalance(AppDatabase db, double newBalance) async {
  await db.updateAccountBalance('default', newBalance);
}
