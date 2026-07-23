import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../core/database/database.dart';
import '../core/utils/formatters.dart';
import '../core/utils/sms_parser.dart';
import '../core/utils/duplicate_detector.dart';
import '../core/utils/notification_service.dart';
import 'database_provider.dart';

final transactionsProvider = FutureProvider.autoDispose<List<Transaction>>((ref) async {
  final db = ref.read(databaseProvider);
  return (db.select(db.transactions)
        ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
      .get();
});

final transactionsByMonthProvider =
    FutureProvider.family<List<Transaction>, String>((ref, monthKey) async {
  final db = ref.read(databaseProvider);
  return (db.select(db.transactions)
        ..where((t) => t.date.year.equals(int.parse(monthKey.split('-')[0])))
        ..where((t) => t.date.month.equals(int.parse(monthKey.split('-')[1])))
        ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
      .get();
});

final thisMonthTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  return ref.read(transactionsByMonthProvider(Formatters.monthKey).future);
});

final totalSpentThisMonthProvider = FutureProvider<double>((ref) async {
  final transactions = await ref.read(thisMonthTransactionsProvider.future);
  return transactions
      .where((t) => t.amount > 0)
      .fold<double>(0, (sum, t) => sum + t.amount);
});

final totalIncomeThisMonthProvider = FutureProvider<double>((ref) async {
  final transactions = await ref.read(thisMonthTransactionsProvider.future);
  return transactions
      .where((t) => t.amount < 0)
      .fold<double>(0, (sum, t) => sum + t.amount.abs());
});

class TransactionNotifier extends StateNotifier<AsyncValue<void>> {
  TransactionNotifier(this.ref) : super(const AsyncData(null));
  final Ref ref;

  Future<void> addTransaction({
    required double amount,
    required String categoryId,
    String? note,
    required DateTime date,
    String paymentMethod = 'cash',
    String accountId = 'default',
    bool isRecurring = false,
    String? recurringInterval,
    String? receiptImagePath,
  }) async {
    final db = ref.read(databaseProvider);
    final uuid = const Uuid().v4();

    double finalAmount = amount;
    final cat = await (db.select(db.categories)..where((c) => c.id.equals(categoryId))).getSingleOrNull();
    if (cat != null && cat.type == 'income') {
      finalAmount = -amount.abs();
    } else {
      finalAmount = amount.abs();
    }

    await db.into(db.transactions).insert(TransactionsCompanion.insert(
      id: uuid,
      amount: finalAmount,
      categoryId: categoryId,
      accountId: accountId,
      note: Value(note),
      date: date,
      paymentMethod: Value(paymentMethod),
      isRecurring: Value(isRecurring),
      recurringInterval: Value(recurringInterval),
      receiptImagePath: Value(receiptImagePath),
    ));

    // Update account balance
    final account = await (db.select(db.accounts)..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (account != null) {
      await (db.update(db.accounts)..where((a) => a.id.equals(accountId)))
          .write(AccountsCompanion(balance: Value(account.balance - finalAmount)));
    }
    ref.invalidate(accountsListProvider);

    ref.invalidate(transactionsProvider);
    ref.invalidate(thisMonthTransactionsProvider);
    ref.invalidate(totalSpentThisMonthProvider);
    ref.invalidate(totalIncomeThisMonthProvider);
  }

  Future<void> updateTransaction(Transaction transaction, {Transaction? originalTransaction}) async {
    final db = ref.read(databaseProvider);      // Reverse original transaction's effect then reapply with new amount
    if (originalTransaction != null) {
      final account = await (db.select(db.accounts)
        ..where((a) => a.id.equals(originalTransaction.accountId))).getSingleOrNull();
      if (account != null) {
        // Single write: reverse original (+original.amount) and apply new (-transaction.amount)
        await (db.update(db.accounts)..where((a) => a.id.equals(originalTransaction.accountId)))
            .write(AccountsCompanion(
              balance: Value(account.balance + originalTransaction.amount - transaction.amount),
            ));
      }
    }

    await db.update(db.transactions).replace(transaction);
    ref.invalidate(transactionsProvider);
    ref.invalidate(thisMonthTransactionsProvider);
    ref.invalidate(accountsListProvider);
  }

  /// Transfer funds between two accounts
  Future<void> transferFunds({
    required double amount,
    required String fromAccountId,
    required String toAccountId,
    String? note,
    required DateTime date,
  }) async {
    final db = ref.read(databaseProvider);
    final fromUuid = const Uuid().v4();
    final toUuid = const Uuid().v4();

    // Outgoing transaction from source account
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
      id: fromUuid,
      amount: amount,
      categoryId: 'transfer',
      accountId: fromAccountId,
      note: Value(note ?? 'Transfer'),
      date: date,
    ));

    // Incoming transaction to destination account
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
      id: toUuid,
      amount: -amount,
      categoryId: 'transfer',
      accountId: toAccountId,
      note: Value(note ?? 'Transfer'),
      date: date,
    ));

    // Update balances: subtract from source, add to destination
    final fromAccount = await (db.select(db.accounts)..where((a) => a.id.equals(fromAccountId))).getSingleOrNull();
    final toAccount = await (db.select(db.accounts)..where((a) => a.id.equals(toAccountId))).getSingleOrNull();
    if (fromAccount != null) {
      await (db.update(db.accounts)..where((a) => a.id.equals(fromAccountId)))
          .write(AccountsCompanion(balance: Value(fromAccount.balance - amount)));
    }
    if (toAccount != null) {
      await (db.update(db.accounts)..where((a) => a.id.equals(toAccountId)))
          .write(AccountsCompanion(balance: Value(toAccount.balance + amount)));
    }

    ref.invalidate(transactionsProvider);
    ref.invalidate(thisMonthTransactionsProvider);
    ref.invalidate(accountsListProvider);
  }

  Future<void> deleteTransaction(String id) async {
    final db = ref.read(databaseProvider);

    // Reverse the transaction's effect on account balance
    final transaction = await (db.select(db.transactions)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
    if (transaction != null) {
      final account = await (db.select(db.accounts)
        ..where((a) => a.id.equals(transaction.accountId))).getSingleOrNull();
      if (account != null) {
        await (db.update(db.accounts)..where((a) => a.id.equals(transaction.accountId)))
            .write(AccountsCompanion(
              balance: Value(account.balance + transaction.amount),
            ));
      }

      // Delete orphaned receipt photo
      if (transaction.receiptImagePath != null) {
        try {
          final file = File(transaction.receiptImagePath!);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }

    await (db.delete(db.transactions)..where((t) => t.id.equals(id))).go();
    ref.invalidate(transactionsProvider);
    ref.invalidate(thisMonthTransactionsProvider);
    ref.invalidate(accountsListProvider);
  }

  /// Check for duplicate transactions before adding.
  /// Returns matching duplicates if found, or null if none.
  Future<DuplicateCheckResult?> checkForDuplicates({
    required double amount,
    required String categoryId,
    required DateTime date,
    String? note,
  }) async {
    final existingTxns = await ref.read(transactionsProvider.future);
    return DuplicateDetector.findDuplicates(
      existingTransactions: existingTxns,
      amount: amount,
      categoryId: categoryId,
      date: date,
      note: note,
    );
  }
}

final transactionNotifierProvider =
    StateNotifierProvider<TransactionNotifier, AsyncValue<void>>((ref) {
  return TransactionNotifier(ref);
});

final pendingSmsTransactionProvider = StateProvider<ParsedSmsTxn?>((ref) => null);

/// Provider for all recurring transactions with computed next due dates
final recurringTransactionsProvider =
    FutureProvider<List<RecurringPaymentInfo>>((ref) async {
  final transactions = await ref.read(transactionsProvider.future);
  final categories = await ref.read(categoriesProvider.future);

  final recurring = <RecurringPaymentInfo>[];
  final now = DateTime.now();

  for (final t in transactions.where((t) => t.isRecurring)) {
    final nextDate = NotificationService.calculateNextDueDate(
      lastDate: t.date,
      interval: t.recurringInterval,
    );
    if (nextDate != null) {
      final category = categories.where((c) => c.id == t.categoryId).firstOrNull;
      recurring.add(RecurringPaymentInfo(
        transaction: t,
        category: category,
        nextDate: nextDate,
        daysUntil: nextDate.difference(now).inDays,
      ));
    }
  }

  // Sort by next due date (closest first)
  recurring.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
  return recurring;
});

/// Structured info about a recurring payment with computed next due date
class RecurringPaymentInfo {
  final Transaction transaction;
  final Category? category;
  final DateTime nextDate;
  final int daysUntil;

  const RecurringPaymentInfo({
    required this.transaction,
    this.category,
    required this.nextDate,
    required this.daysUntil,
  });

  bool get isOverdue => daysUntil < 0;
  bool get isDueToday => daysUntil == 0;
  bool get isDueSoon => daysUntil > 0 && daysUntil <= 3;
  String get intervalLabel {
    switch (transaction.recurringInterval) {
      case 'daily': return 'Daily';
      case 'weekly': return 'Weekly';
      case 'biweekly': return 'Biweekly';
      case 'monthly': return 'Monthly';
      case 'quarterly': return 'Quarterly';
      case 'yearly': return 'Yearly';
      default: return transaction.recurringInterval ?? 'Recurring';
    }
  }

  /// Monthly equivalent cost for comparison
  double get monthlyCost {
    switch (transaction.recurringInterval) {
      case 'daily': return transaction.amount.abs() * 30;
      case 'weekly': return transaction.amount.abs() * 4.33;
      case 'biweekly': return transaction.amount.abs() * 2.17;
      case 'monthly': return transaction.amount.abs();
      case 'quarterly': return transaction.amount.abs() / 3;
      case 'yearly': return transaction.amount.abs() / 12;
      default: return transaction.amount.abs();
    }
  }

  /// Annual cost for comparison
  double get annualCost => monthlyCost * 12;
}

