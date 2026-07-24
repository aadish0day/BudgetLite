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
      'food': ['Swiggy', 'Zomato', 'Starbucks', 'Domino\'s', 'Dhaba', 'Pizza Hut', 'McDonald\'s', 'Subway'],
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
          isRecurring: Value(catId == 'bills'),
          recurringInterval: Value(catId == 'bills' ? 'monthly' : null),
        ));
      }
    }

    // Add past weekly pocket money entries for history (last 12 weeks)
    for (int weekOffset = 1; weekOffset < 12; weekOffset++) {
      final pocketDate = now.subtract(Duration(days: 7 * weekOffset));
      batch.add(TransactionsCompanion.insert(
        id: 'demo_income_weekly_$weekOffset',
        amount: -8000.0,
        categoryId: 'income',
        accountId: 'default',
        note: const Value('Weekly Pocket Money'),
        date: pocketDate,
        paymentMethod: const Value('UPI'),
      ));
    }

    // Create a recurring weekly pocket money template (auto-posts each week going forward)
    batch.add(TransactionsCompanion.insert(
      id: 'demo_income_recurring',
      amount: -8000.0,
      categoryId: 'income',
      accountId: 'default',
      note: const Value('Weekly Pocket Money'),
      date: now,
      paymentMethod: const Value('UPI'),
      isRecurring: const Value(true),
      recurringInterval: const Value('weekly'),
      isRecurringInstance: const Value(false),
    ));

    // Set monthly income to 32000 (8000 × 4 weeks)
    final existingIncome = await (db.select(db.monthlyIncome)
          ..where((t) => t.month.equals('${now.year}-${now.month.toString().padLeft(2, '0')}')))
        .get();

    if (existingIncome.isEmpty) {
      await db.into(db.monthlyIncome).insert(MonthlyIncomeCompanion.insert(
        id: 'demo_income_setting',
        month: '${now.year}-${now.month.toString().padLeft(2, '0')}',
        amount: 32000.0,
      ));
    }

    // Set budgets for categories
    final budgetAmounts = <String, double>{'food': 3000, 'transport': 1000, 'shopping': 2000, 'bills': 1000, 'entertainment': 1000};
    for (final entry in budgetAmounts.entries) {
      final existing = await (db.select(db.budgets)
            ..where((t) => t.categoryId.equals(entry.key))
            ..where((t) => t.month.equals('${now.year}-${now.month.toString().padLeft(2, '0')}')))
          .get();
      if (existing.isEmpty) {
        await db.into(db.budgets).insert(BudgetsCompanion.insert(
          id: 'demo_budget_${entry.key}',
          categoryId: entry.key,
          month: '${now.year}-${now.month.toString().padLeft(2, '0')}',
          allocatedAmount: entry.value,
        ));
      }
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
