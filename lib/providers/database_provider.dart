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
