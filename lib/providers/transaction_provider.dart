import 'dart:convert';
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
import 'settings_provider.dart';

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

/// Total spending this month.
final totalSpentThisMonthProvider = FutureProvider<double>((ref) async {
  final transactions = await ref.read(thisMonthTransactionsProvider.future);
  return transactions
      .where((t) => t.amount > 0)
      .fold<double>(0, (sum, t) => sum + t.amount);
});

/// Total income this month.
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
    bool isRecurring = false,
    String? recurringInterval,
    String? receiptImagePath,
    bool? isIncome,
    DateTime? recurringEndDate,
  }) async {
    final db = ref.read(databaseProvider);
    final uuid = const Uuid().v4();

    double finalAmount = amount;
    if (isIncome == true) {
      finalAmount = -amount.abs();
    } else {
      final cat = await (db.select(db.categories)..where((c) => c.id.equals(categoryId))).getSingleOrNull();
      if (cat != null && cat.type == 'income') {
        finalAmount = -amount.abs();
      } else {
        finalAmount = amount.abs();
      }
    }

    await db.into(db.transactions).insert(TransactionsCompanion.insert(
      id: uuid,
      amount: finalAmount,
      categoryId: categoryId,
      accountId: 'default',
      note: Value(note),
      date: date,
      paymentMethod: Value(paymentMethod),
      isRecurring: Value(isRecurring),
      isRecurringInstance: const Value(false),
      recurringInterval: Value(recurringInterval),
      recurringEndDate: Value(recurringEndDate),
      receiptImagePath: Value(receiptImagePath),
    ));

    ref.invalidate(transactionsProvider);
    ref.invalidate(thisMonthTransactionsProvider);
    ref.invalidate(totalSpentThisMonthProvider);
    ref.invalidate(totalIncomeThisMonthProvider);
  }

  Future<void> updateTransaction(Transaction transaction) async {
    final db = ref.read(databaseProvider);
    await db.update(db.transactions).replace(transaction);
    ref.invalidate(transactionsProvider);
    ref.invalidate(thisMonthTransactionsProvider);
  }



  Future<void> deleteTransaction(String id) async {
    final db = ref.read(databaseProvider);

    final transaction = await (db.select(db.transactions)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
    if (transaction != null && transaction.receiptImagePath != null) {
      try {
        final file = File(transaction.receiptImagePath!);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    await (db.delete(db.transactions)..where((t) => t.id.equals(id))).go();
    ref.invalidate(transactionsProvider);
    ref.invalidate(thisMonthTransactionsProvider);
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

  /// Post due recurring transactions as instances since the last check.
  /// Uses `last_recurring_check` in AppSettings to avoid duplicates.
  /// Each posted instance is flagged with `isRecurringInstance = true`.
  /// ⚠️ Income-type recurring templates are intentionally skipped — income
  /// is never auto-posted; it must be added manually or confirmed from SMS.
  Future<int> postDueRecurringTransactions() async {
    final settings = ref.read(settingsNotifierProvider.notifier);
    final lastCheckStr = await settings.getSetting('last_recurring_check');
    final lastCheck = lastCheckStr != null ? DateTime.tryParse(lastCheckStr) : null;
    final now = DateTime.now();

    final db = ref.read(databaseProvider);

    // Load categories to skip income-type recurring templates
    final categories = await db.select(db.categories).get();
    final incomeCategoryIds = categories
        .where((c) => c.type == 'income')
        .map((c) => c.id)
        .toSet();

    final templates = await (db.select(db.transactions)
      ..where((t) => t.isRecurring.equals(true))
      ..where((t) => t.isRecurringInstance.equals(false)))
      .get();

    const uuid = Uuid();
    int postedCount = 0;
    const int maxInstancesPerTemplate = 31;

    // Wrap all writes + check update in a single transaction for batch atomicity
    await db.transaction(() async {
      for (final template in templates) {
        // Skip income-category recurring templates — never auto-post income
        if (incomeCategoryIds.contains(template.categoryId)) continue;

        final interval = template.recurringInterval;
        if (interval == null) continue;

        // Respect end date — skip templates past their end date
        if (template.recurringEndDate != null && template.recurringEndDate!.isBefore(now)) {
          continue;
        }

        // Start enumerating from the later of template.date and lastCheck
        final startFrom = lastCheck != null && lastCheck.isAfter(template.date)
            ? lastCheck
            : template.date;

        // Determine end boundary: now or endDate, whichever is earlier
        final upTo = template.recurringEndDate != null && template.recurringEndDate!.isBefore(now)
            ? template.recurringEndDate!
            : now;

        // Enumerate all due dates from startFrom up to the boundary (cap at 31)
        final dueDates = _enumerateDueDates(
          from: startFrom,
          interval: interval,
          upTo: upTo,
        );

        // Safety cap: at most 31 instances per template
        for (final dueDate in dueDates.take(maxInstancesPerTemplate)) {
          await db.into(db.transactions).insert(TransactionsCompanion.insert(
            id: uuid.v4(),
            amount: template.amount,
            categoryId: template.categoryId,
            accountId: 'default',
            note: template.note != null
                ? Value('${template.note} (auto)')
                : const Value.absent(),
            date: dueDate,
            paymentMethod: const Value('cash'),
            isRecurring: const Value(false),
            isRecurringInstance: const Value(true),
            recurringInterval: const Value.absent(),
            receiptImagePath: const Value.absent(),
          ));

          postedCount++;
        }
      }
    });

    // Update last check time outside the transaction so it's only written
    // if the DB batch succeeded
    await settings.setSetting('last_recurring_check', now.toIso8601String());

    if (postedCount > 0) {
      ref.invalidate(transactionsProvider);
      ref.invalidate(thisMonthTransactionsProvider);
      ref.invalidate(totalIncomeThisMonthProvider);
      ref.invalidate(totalSpentThisMonthProvider);
    }

    return postedCount;
  }

  /// Enumerate all due dates for a recurring interval from [from] (exclusive)
  /// up to [upTo] (inclusive). Starts from the template date and advances
  /// one period at a time until all due dates in the range are found.
  List<DateTime> _enumerateDueDates({
    required DateTime from,
    required String interval,
    required DateTime upTo,
  }) {
    final results = <DateTime>[];

    // Find the first due date strictly after [from]
    DateTime current = _advanceDate(from, interval);
    if (current == from) return results; // unrecognized interval

    while (!current.isAfter(upTo)) {
      results.add(current);
      final next = _advanceDate(current, interval);
      if (next == current) break;
      current = next;
    }

    return results;
  }

  /// Advance a date by one period of the given interval.
  /// Returns the same date if the interval is unrecognized.
  DateTime _advanceDate(DateTime date, String interval) {
    switch (interval) {
      case 'daily':
        return date.add(const Duration(days: 1));
      case 'weekly':
        return date.add(const Duration(days: 7));
      case 'biweekly':
        return date.add(const Duration(days: 14));
      case 'monthly':
        return _addMonths(date, 1);
      case 'quarterly':
        return _addMonths(date, 3);
      case 'yearly':
        return _addMonths(date, 12);
      default:
        return date;
    }
  }

  DateTime _addMonths(DateTime date, int monthsToAdd) {
    final newMonth = date.month + monthsToAdd;
    final yearOffset = (newMonth - 1) ~/ 12;
    final targetYear = date.year + yearOffset;
    final targetMonth = ((newMonth - 1) % 12) + 1;
    // Get last day of target month
    final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final targetDay = date.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : date.day;
    return DateTime(targetYear, targetMonth, targetDay, date.hour, date.minute, date.second);
  }
}

final transactionNotifierProvider =
    StateNotifierProvider<TransactionNotifier, AsyncValue<void>>((ref) {
  return TransactionNotifier(ref);
});

final pendingSmsTransactionProvider = StateProvider<ParsedSmsTxn?>((ref) => null);

/// Provider for the persistent SMS review queue, stored in AppSettings as JSON.
final smsReviewQueueProvider =
    StateNotifierProvider<SmsReviewQueueNotifier, List<ParsedSmsTxn>>((ref) {
  return SmsReviewQueueNotifier(ref);
});

class SmsReviewQueueNotifier extends StateNotifier<List<ParsedSmsTxn>> {
  SmsReviewQueueNotifier(this.ref) : super([]) {
    _loadQueue();
  }

  final Ref ref;

  Future<void> _loadQueue() async {
    final settings = ref.read(settingsNotifierProvider.notifier);
    final stored = await settings.getSetting('pending_sms_queue');
    if (stored != null && stored.isNotEmpty) {
      try {
        final list = stored.split('|||').map((json) {
          try {
            return ParsedSmsTxn.fromJson(
              Map<String, dynamic>.from(
                const JsonDecoder().convert(json) as Map,
              ),
            );
          } catch (_) {
            return null;
          }
        }).whereType<ParsedSmsTxn>().toList();
        if (list.isNotEmpty) {
          state = list;
        }
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    final settings = ref.read(settingsNotifierProvider.notifier);
    final jsonStr = state.map((t) => const JsonEncoder().convert(t.toJson())).join('|||');
    await settings.setSetting('pending_sms_queue', jsonStr);
  }

  /// Add a parsed SMS to the review queue
  Future<void> addToQueue(ParsedSmsTxn txn) async {
    state = [...state, txn];
    await _persist();
  }

  /// Confirm (add as transaction) a single item and remove from queue
  Future<void> confirmItem(String id, {String? overrideCategory, String? overrideNote}) async {
    final txn = state.where((t) => t.id == id).firstOrNull;
    if (txn == null) return;

    final notifier = ref.read(transactionNotifierProvider.notifier);
    await notifier.addTransaction(
      amount: txn.amount,
      categoryId: overrideCategory ?? txn.categoryId,
      note: overrideNote ?? txn.note,
      date: txn.date,
      paymentMethod: 'UPI',
      isIncome: txn.isIncome,
    );

    state = state.where((t) => t.id != id).toList();
    await _persist();
  }

  /// Discard (remove without adding) a single item
  Future<void> discardItem(String id) async {
    state = state.where((t) => t.id != id).toList();
    await _persist();
  }

  /// Confirm all pending items
  Future<void> confirmAll() async {
    for (final txn in state.toList()) {
      await confirmItem(txn.id);
    }
  }

  /// Discard all pending items
  Future<void> discardAll() async {
    state = [];
    await _persist();
  }

  int get pendingCount => state.length;
}


/// Provider for all recurring transactions with computed next due dates
final recurringTransactionsProvider =
    FutureProvider<List<RecurringPaymentInfo>>((ref) async {
  final transactions = await ref.read(transactionsProvider.future);
  final categories = await ref.read(categoriesProvider.future);
  final settingsNotifier = ref.read(settingsNotifierProvider.notifier);

  final recurring = <RecurringPaymentInfo>[];
  final now = DateTime.now();

  for (final t in transactions.where((t) => t.isRecurring)) {
    final nextDate = NotificationService.calculateNextDueDate(
      lastDate: t.date,
      interval: t.recurringInterval,
    );
    if (nextDate != null) {
      final category = categories.where((c) => c.id == t.categoryId).firstOrNull;

      // "Possibly unused" is an opt-in signal based on whether the user
      // has manually marked this subscription as reviewed/used.
      // A subscription that has NOT been reviewed yet is flagged.
      // This is persisted in AppSettings (not SMS-based or time-based).
      // All subscriptions start as "potentially unused" until the user
      // explicitly marks them as reviewed.
      final isReviewed = await settingsNotifier.isSubscriptionReviewed(t.id);
      final possiblyUnused = !isReviewed;

      recurring.add(RecurringPaymentInfo(
        transaction: t,
        category: category,
        nextDate: nextDate,
        daysUntil: nextDate.difference(now).inDays,
        isPossiblyUnused: possiblyUnused,
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
  final bool isPossiblyUnused;

  const RecurringPaymentInfo({
    required this.transaction,
    this.category,
    required this.nextDate,
    required this.daysUntil,
    this.isPossiblyUnused = false,
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

