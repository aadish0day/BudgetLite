import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final db = ref.read(databaseProvider);
  return db.select(db.categories).get();
});

final expenseCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final db = ref.read(databaseProvider);
  return (db.select(db.categories)..where((tbl) => tbl.type.equals('expense')))
      .get();
});

final accountProvider = FutureProvider<Account?>((ref) async {
  final db = ref.read(databaseProvider);
  final accounts = await db.select(db.accounts).get();
  return accounts.isNotEmpty ? accounts.first : null;
});

final accountsListProvider = FutureProvider<List<Account>>((ref) async {
  final db = ref.read(databaseProvider);
  return db.select(db.accounts).get();
});
