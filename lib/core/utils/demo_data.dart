import 'dart:math';
import 'package:drift/drift.dart';
import '../database/database.dart';

class DemoDataSeeder {
  static Future<void> seed(AppDatabase db) async {
    final random = Random(42);
    final now = DateTime.now();

    // Sample categories with realistic data
    final categoryIds = ['food', 'transport', 'rent', 'shopping', 'bills'];
    final merchants = {
      'food': ['Swiggy', 'Zomato', 'Starbucks', 'Domino\'s', 'Dhaba', 'Pizza Hut', 'McDonald\'s', 'Subway'],
      'transport': ['Uber', 'Ola', 'Petrol Pump', 'Metro Card', 'Bus Pass', 'Parking'],
      'rent': ['Housing Society', 'Landlord', 'Maintenance', 'Electricity Board'],
      'shopping': ['Amazon', 'Myntra', 'Flipkart', 'Zara', 'H&M', 'Ajio', 'Nykaa'],
      'bills': ['Netflix', 'Jio', 'Airtel', 'Electricity Bill', 'Water Bill', 'Internet', 'Spotify'],
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
        final amount = catId == 'rent'
            ? 12000 + (random.nextDouble() * 500)
            : _randomAmount(random, catId);

        batch.add(TransactionsCompanion.insert(
          id: 'demo_${daysAgo}_$i',
          amount: amount,
          categoryId: catId,
          accountId: 'default',
          note: Value(merchant),
          date: DateTime(date.year, date.month, date.day, random.nextInt(12) + 8, random.nextInt(60)),
          paymentMethod: Value(['Cash', 'UPI', 'Debit Card', 'Credit Card', 'Net Banking', 'Wallet'][random.nextInt(6)]),
          isRecurring: Value(catId == 'rent' || catId == 'bills'),
          recurringInterval: Value(catId == 'rent' ? 'monthly' : null),
        ));
      }
    }

    // Add some income entries (salary)
    for (int monthOffset = 0; monthOffset < 3; monthOffset++) {
      final salaryDate = DateTime(now.year, now.month - monthOffset, 1);
      batch.add(TransactionsCompanion.insert(
        id: 'demo_income_$monthOffset',
        amount: -45000.0, // negative = income
        categoryId: 'income',
        accountId: 'default',
        note: const Value('Monthly Salary'),
        date: salaryDate,
        paymentMethod: const Value('Net Banking'),
      ));
    }

    // Set monthly income for current month
    final existingIncome = await (db.select(db.monthlyIncome)
          ..where((t) => t.month.equals('${now.year}-${now.month.toString().padLeft(2, '0')}')))
        .get();

    if (existingIncome.isEmpty) {
      await db.into(db.monthlyIncome).insert(MonthlyIncomeCompanion.insert(
        id: 'demo_income_setting',
        month: '${now.year}-${now.month.toString().padLeft(2, '0')}',
        amount: 45000.0,
      ));
    }

    // Set budgets for categories
    final budgetAmounts = <String, double>{'food': 8000, 'transport': 3000, 'rent': 13000, 'shopping': 4000, 'bills': 3000};
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
        return (random.nextDouble() * 600 + 50); // ₹50-650
      case 'transport':
        return (random.nextDouble() * 300 + 20); // ₹20-320
      case 'shopping':
        return (random.nextDouble() * 2000 + 200); // ₹200-2200
      case 'bills':
        return (random.nextDouble() * 1000 + 100); // ₹100-1100
      default:
        return (random.nextDouble() * 500 + 100);
    }
  }
}
