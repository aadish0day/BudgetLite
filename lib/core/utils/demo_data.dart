import 'dart:math';
import 'package:drift/drift.dart';
import '../database/database.dart';

class DemoDataSeeder {
  static Future<void> seed(AppDatabase db) async {
    final random = Random(42);
    final now = DateTime.now();

    // Sample categories with student-friendly data
    final categoryIds = ['food', 'transport', 'shopping', 'bills', 'entertainment'];
    final merchants = {
      'food': ['Swiggy', 'Zomato', 'Starbucks', "Domino's", 'Dhaba', 'Pizza Hut', "McDonald's", 'Subway'],
      'transport': ['Uber', 'Ola', 'Metro Card', 'Bus Pass', 'Auto'],
      'shopping': ['Amazon', 'Myntra', 'Flipkart', 'Zara', 'H&M', 'Ajio', 'Nykaa'],
      'bills': ['Netflix', 'Jio', 'Airtel', 'Electricity', 'Internet', 'Spotify'],
      'entertainment': ['PVR', 'BookMyShow', 'Steam', 'Spotify', 'Zomato'],
    };

    // Delete existing transactions to avoid duplicates
    await db.delete(db.transactions).go();

    // Generate transactions for the past 3 months
    final batch = <TransactionsCompanion>[];

    for (int daysAgo = 0; daysAgo < 90; daysAgo++) {
      final date = now.subtract(Duration(days: daysAgo));
      // 1-3 transactions per day
      final txnsToday = random.nextInt(3) + 1;

      for (int i = 0; i < txnsToday; i++) {
        final catId = categoryIds[random.nextInt(categoryIds.length)];
        final merchant = merchants[catId]![random.nextInt(merchants[catId]!.length)];
        final amount = _randomAmount(random, catId);

        batch.add(TransactionsCompanion.insert(
          id: 'demo_${daysAgo}_$i',
          amount: amount,
          categoryId: catId,
          accountId: 'default',
          note: Value(merchant),
          date: DateTime(date.year, date.month, date.day, random.nextInt(12) + 8, random.nextInt(60)),
          paymentMethod: Value(['Cash', 'UPI', 'Debit Card', 'Credit Card', 'Net Banking', 'Wallet'][random.nextInt(6)]),
          // Historical one-offs must NOT be flagged recurring — that would
          // turn dozens of past payments into templates whose due instances
          // flood the ledger with "(auto)" rows after seeding.
        ));
      }
    }

    // Add past income entries for history (last 12 weeks) — one-off transactions only
    for (int weekOffset = 1; weekOffset <= 12; weekOffset++) {
      final pocketDate = now.subtract(Duration(days: 7 * weekOffset));
      batch.add(TransactionsCompanion.insert(
        id: 'demo_income_weekly_$weekOffset',
        amount: -3000.0,
        categoryId: 'income',
        accountId: 'default',
        note: const Value('Pocket Money'),
        date: pocketDate,
        paymentMethod: const Value('UPI'),
      ));
    }

    // A few explicit subscription templates so the Subscriptions screen has
    // sensible demo content without mass-flagged historical transactions.
    final subTemplates = [
      ('demo_sub_netflix', 'Netflix', 'bills', 250.0, 6),
      ('demo_sub_spotify', 'Spotify', 'bills', 119.0, 11),
      ('demo_sub_jio', 'Jio Recharge', 'bills', 239.0, 21),
    ];
    for (final (id, name, catId, amount, daysAgo) in subTemplates) {
      final d = now.subtract(Duration(days: daysAgo));
      batch.add(TransactionsCompanion.insert(
        id: id,
        amount: amount,
        categoryId: catId,
        accountId: 'default',
        note: Value(name),
        date: DateTime(d.year, d.month, d.day, 10, 0),
        paymentMethod: const Value('UPI'),
        isRecurring: const Value(true),
        recurringInterval: const Value('monthly'),
      ));
    }

    // Set budgets for categories
    final budgetAmounts = <String, double>{'food': 3000, 'transport': 1000, 'shopping': 2000, 'bills': 1000, 'entertainment': 1000};
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    for (final entry in budgetAmounts.entries) {
      // Upsert on the primary key — a plain insert crashes when demo data was
      // seeded before a month boundary (same fixed id, existence check only
      // matched the current month).
      await db.into(db.budgets).insertOnConflictUpdate(BudgetsCompanion.insert(
        id: 'demo_budget_${entry.key}',
        categoryId: entry.key,
        month: monthKey,
        allocatedAmount: entry.value,
      ));
    }

    // Insert all transactions
    await db.batch((b) {
      for (final txn in batch) {
        b.insert(db.transactions, txn);
      }
    });
  }

  static double _randomAmount(Random random, String categoryId) {
    switch (categoryId) {
      case 'food':
        return (random.nextDouble() * 400 + 30); // ₹30-430
      case 'transport':
        return (random.nextDouble() * 200 + 10); // ₹10-210
      case 'shopping':
        return (random.nextDouble() * 1000 + 100); // ₹100-1100
      case 'bills':
        return (random.nextDouble() * 500 + 50); // ₹50-550
      case 'entertainment':
        return (random.nextDouble() * 300 + 50); // ₹50-350
      default:
        return (random.nextDouble() * 300 + 50);
    }
  }
}
