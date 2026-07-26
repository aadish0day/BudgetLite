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
import 'insights_provider.dart';
import 'budget_provider.dart';
import 'settings_provider.dart';

final transactionsProvider = StreamProvider.autoDispose<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.transactions)
        ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
      .watch();
});

final transactionsByMonthProvider =
    StreamProvider.family<List<Transaction>, String>((ref, monthKey) {
  final db = ref.watch(databaseProvider);
  final parts = monthKey.split('-');
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  return (db.select(db.transactions)
        ..where((t) => t.date.year.equals(year))
        ..where((t) => t.date.month.equals(month))
        ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
      .watch();
});

final thisMonthTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final asyncTxns = ref.watch(transactionsByMonthProvider(Formatters.monthKey));
  return asyncTxns.when(
    data: (txns) => Stream.value(txns),
    error: (err, stack) => Stream.error(err, stack),
    loading: () => const Stream.empty(),
  );
});

/// Total spending this month.
final totalSpentThisMonthProvider = StreamProvider<double>((ref) {
  final asyncTxns = ref.watch(thisMonthTransactionsProvider);
  return asyncTxns.when(
    data: (txns) {
      final spent = txns.where((t) => t.amount > 0).fold<double>(0, (sum, t) => sum + t.amount);
      return Stream.value(spent);
    },
    error: (err, stack) => Stream.error(err, stack),
    loading: () => const Stream.empty(),
  );
});

/// Total income this month.
final totalIncomeThisMonthProvider = StreamProvider<double>((ref) {
  final asyncTxns = ref.watch(thisMonthTransactionsProvider);
  return asyncTxns.when(
    data: (txns) {
      final income = txns.where((t) => t.amount < 0).fold<double>(0, (sum, t) => sum + t.amount.abs());
      return Stream.value(income);
    },
    error: (err, stack) => Stream.error(err, stack),
    loading: () => const Stream.empty(),
  );
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
    String? payee,
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
      payee: Value(payee),
    ));

    ref.invalidate(transactionsProvider);
    ref.invalidate(thisMonthTransactionsProvider);
    ref.invalidate(totalSpentThisMonthProvider);
    ref.invalidate(totalIncomeThisMonthProvider);
    ref.invalidate(budgetHealthProvider);
    ref.invalidate(spendingVelocityProvider);
    ref.invalidate(spendingInsightsProvider);
    ref.invalidate(effectiveCategoryBudgetProvider(categoryId));

    _checkBudgetAlerts(categoryId, date);
  }

  Future<void> updateTransaction(Transaction transaction) async {
    final db = ref.read(databaseProvider);
    await db.update(db.transactions).replace(transaction);
    ref.invalidate(transactionsProvider);
    ref.invalidate(thisMonthTransactionsProvider);
    ref.invalidate(totalSpentThisMonthProvider);
    ref.invalidate(totalIncomeThisMonthProvider);
    ref.invalidate(budgetHealthProvider);
    ref.invalidate(spendingVelocityProvider);
    ref.invalidate(spendingInsightsProvider);
    ref.invalidate(effectiveCategoryBudgetProvider(transaction.categoryId));

    _checkBudgetAlerts(transaction.categoryId, transaction.date);
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

    if (transaction != null) {
      await (db.delete(db.transactions)..where((t) => t.id.equals(id))).go();
      ref.invalidate(transactionsProvider);
      ref.invalidate(thisMonthTransactionsProvider);
      ref.invalidate(totalSpentThisMonthProvider);
      ref.invalidate(totalIncomeThisMonthProvider);
      ref.invalidate(budgetHealthProvider);
      ref.invalidate(spendingVelocityProvider);
      ref.invalidate(spendingInsightsProvider);
      ref.invalidate(effectiveCategoryBudgetProvider(transaction.categoryId));

      _checkBudgetAlerts(transaction.categoryId, transaction.date);
    }
  }

  Future<void> _checkBudgetAlerts(String categoryId, DateTime date) async {
    try {
      final db = ref.read(databaseProvider);
      final monthStr = Formatters.formatMonthKey(date);

      final budget = await (db.select(db.budgets)
            ..where((b) => b.categoryId.equals(categoryId))
            ..where((b) => b.month.equals(monthStr)))
          .getSingleOrNull();

      if (budget == null || budget.allocatedAmount <= 0) return;

      final category = await (db.select(db.categories)
            ..where((c) => c.id.equals(categoryId)))
          .getSingleOrNull();
      if (category == null || category.type == 'income') return;

      final txns = await (db.select(db.transactions)
            ..where((t) => t.categoryId.equals(categoryId))
            ..where((t) => t.date.year.equals(date.year))
            ..where((t) => t.date.month.equals(date.month)))
          .get();

      final spent = txns.where((t) => t.amount > 0).fold<double>(0, (sum, t) => sum + t.amount);

      await NotificationService.instance.checkBudgetThreshold(
        categoryId: categoryId,
        categoryName: category.name,
        month: monthStr,
        spent: spent,
        allocatedAmount: budget.allocatedAmount,
      );
    } catch (_) {}
  }

  /// Check for duplicate transactions before adding.
  /// Returns matching duplicates if found.
  Future<List<Transaction>> checkForDuplicates({
    required double amount,
    required String categoryId,
    required DateTime date,
    String? note,
    bool? isIncome,
  }) async {
    final existingTxns = await ref.read(transactionsProvider.future);
    return DuplicateDetector.findDuplicates(
      existingTransactions: existingTxns,
      amount: amount,
      categoryId: categoryId,
      date: date,
      note: note,
      isIncome: isIncome,
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

        // Enumerate all due dates from the template's original schedule date,
        // starting from the first due date strictly after [startFrom].
        final dueDates = _enumerateDueDates(
          from: startFrom,
          interval: interval,
          upTo: upTo,
          originalDate: template.date,
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

  /// Enumerate all due dates for a recurring interval.
  /// Enumerates from [originalDate] forward, including only dates strictly
  /// after [from] and at or before [upTo]. If [originalDate] is not provided,
  /// falls back to [from] for backward compatibility.
  List<DateTime> _enumerateDueDates({
    required DateTime from,
    required String interval,
    required DateTime upTo,
    DateTime? originalDate,
  }) {
    final results = <DateTime>[];
    final startSeed = originalDate ?? from;

    // Find the first due date after [startSeed], then skip those ≤ [from]
    DateTime current = _advanceDate(startSeed, interval);
    if (current == startSeed) return results;

    while (!current.isAfter(upTo)) {
      if (current.isAfter(from)) {
        results.add(current);
      }
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
    final totalMonths = date.year * 12 + (date.month - 1) + monthsToAdd;
    final targetYear = totalMonths ~/ 12;
    final targetMonth = (totalMonths % 12) + 1;
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
  final Set<String> _processedIds = {};

  Future<void> _loadQueue() async {
    final settings = ref.read(settingsNotifierProvider.notifier);
    
    // Load persisted set of processed/discarded/confirmed SMS IDs
    final storedProcessed = await settings.getSetting('processed_sms_ids');
    if (storedProcessed != null && storedProcessed.isNotEmpty) {
      _processedIds.addAll(storedProcessed.split('|||'));
    }

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
          // Filter out any items that were already processed in past sessions
          state = list.where((t) => !_processedIds.contains(t.id)).toList();
        }
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    final settings = ref.read(settingsNotifierProvider.notifier);
    final jsonStr = state.map((t) => const JsonEncoder().convert(t.toJson())).join('|||');
    await settings.setSetting('pending_sms_queue', jsonStr);
    await settings.setSetting('processed_sms_ids', _processedIds.join('|||'));
  }

  /// Check if an SMS ID was already processed, confirmed, or discarded
  bool isProcessed(String id) {
    return _processedIds.contains(id);
  }

  /// Check if an SMS ID is currently in the pending queue
  bool isAlreadyInQueue(String id) {
    return state.any((t) => t.id == id);
  }

  /// Clear all items from the queue and mark them as processed
  Future<void> clear() async {
    for (final txn in state) {
      _processedIds.add(txn.id);
    }
    state = [];
    await _persist();
  }

  /// Add a parsed SMS to the review queue if not already processed or queued
  Future<void> addToQueue(ParsedSmsTxn txn) async {
    if (isProcessed(txn.id) || isAlreadyInQueue(txn.id)) return;
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
      note: overrideNote ?? (txn.note.isNotEmpty ? txn.note : null),
      date: txn.date,
      paymentMethod: 'UPI',
      isIncome: txn.isIncome,
      payee: txn.payee,
    );

    _processedIds.add(id);
    state = state.where((t) => t.id != id).toList();
    await _persist();
  }

  /// Discard (remove without adding) a single item
  Future<void> discardItem(String id) async {
    _processedIds.add(id);
    state = state.where((t) => t.id != id).toList();
    await _persist();
  }

  /// Confirm all pending items in batch
  Future<void> confirmAll() async {
    final list = state.toList();
    if (list.isEmpty) return;

    final notifier = ref.read(transactionNotifierProvider.notifier);
    for (final txn in list) {
      await notifier.addTransaction(
        amount: txn.amount,
        categoryId: txn.categoryId,
        note: txn.note.isNotEmpty ? txn.note : null,
        date: txn.date,
        paymentMethod: 'UPI',
        isIncome: txn.isIncome,
        payee: txn.payee,
      );
      _processedIds.add(txn.id);
    }
    state = [];
    await _persist();
  }

  /// Discard all pending items
  Future<void> discardAll() async {
    for (final txn in state) {
      _processedIds.add(txn.id);
    }
    state = [];
    await _persist();
  }

  int get pendingCount => state.length;
}


/// Provider for all recurring transactions with computed next due dates
final recurringTransactionsProvider =
    FutureProvider<List<RecurringPaymentInfo>>((ref) async {
  final transactions = await ref.watch(transactionsProvider.future);
  final categories = await ref.watch(categoriesProvider.future);
  final settingsNotifier = ref.read(settingsNotifierProvider.notifier);

  final recurring = <RecurringPaymentInfo>[];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  for (final t in transactions.where((t) => t.isRecurring)) {
    final nextDate = NotificationService.calculateNextDueDate(
      lastDate: t.date,
      interval: t.recurringInterval,
    );
    if (nextDate != null) {
      final category = categories.where((c) => c.id == t.categoryId).firstOrNull;

      final isReviewed = await settingsNotifier.isSubscriptionReviewed(t.id);
      final nextDay = DateTime(nextDate.year, nextDate.month, nextDate.day);
      final daysUntil = nextDay.difference(today).inDays;

      recurring.add(RecurringPaymentInfo(
        transaction: t,
        category: category,
        nextDate: nextDate,
        daysUntil: daysUntil,
        isPossiblyUnused: !isReviewed,
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

/// Provider for pending reimbursements (transactions marked with [Owed by: ...] or #reimburse)
final pendingReimbursementsProvider = StreamProvider<List<Transaction>>((ref) {
  final asyncTxns = ref.watch(transactionsProvider);
  return asyncTxns.when(
    data: (txns) {
      final pending = txns.where((t) {
        final note = (t.note ?? '').toLowerCase();
        final payee = (t.payee ?? '').toLowerCase();
        return (note.contains('[owed by:') || note.contains('#reimburse') || payee.contains('[owed by:'));
      }).toList();
      return Stream.value(pending);
    },
    error: (err, stack) => Stream.error(err, stack),
    loading: () => const Stream.empty(),
  );
});

/// Total pending reimbursement amount owed to user
final totalPendingReimbursementProvider = StreamProvider<double>((ref) {
  final asyncPending = ref.watch(pendingReimbursementsProvider);
  return asyncPending.when(
    data: (txns) {
      final total = txns.fold<double>(0, (sum, t) => sum + t.amount.abs());
      return Stream.value(total);
    },
    error: (err, stack) => Stream.error(err, stack),
    loading: () => const Stream.empty(),
  );
});

