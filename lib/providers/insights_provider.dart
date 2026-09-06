import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database.dart';
import '../core/utils/formatters.dart';
import 'budget_provider.dart';
import 'database_provider.dart';
import 'transaction_provider.dart';

/// Monthly income totals (amount < 0)
final incomeByMonthProvider = FutureProvider.autoDispose.family<double, String>(
  (ref, monthKey) async {
    final db = ref.read(databaseProvider);
    final year = int.parse(monthKey.split('-')[0]);
    final month = int.parse(monthKey.split('-')[1]);
    // Compare against local month-boundary instants instead of extracting
    // year/month components — drift stores DateTimes as UTC instants and
    // component extraction reads UTC parts, which mis-buckets transactions
    // created between midnight and the UTC offset in timezones ahead of UTC.
    final transactions =
        await (db.select(db.transactions)
              ..where((t) => t.date.isBiggerOrEqualValue(DateTime(year, month)))
              ..where(
                (t) => t.date.isSmallerThanValue(DateTime(year, month + 1)),
              ))
            .get();
    return transactions
        .where((t) => t.amount < 0)
        .fold<double>(0, (sum, t) => sum + t.amount.abs());
  },
);

/// Monthly spending totals (amount > 0, excluding transfers)
final spendingByMonthProvider = FutureProvider.autoDispose
    .family<double, String>((ref, monthKey) async {
      final db = ref.read(databaseProvider);
      final year = int.parse(monthKey.split('-')[0]);
      final month = int.parse(monthKey.split('-')[1]);
      final transactions =
          await (db.select(db.transactions)
                ..where(
                  (t) => t.date.isBiggerOrEqualValue(DateTime(year, month)),
                )
                ..where(
                  (t) => t.date.isSmallerThanValue(DateTime(year, month + 1)),
                ))
              .get();
      return transactions
          .where((t) => t.amount > 0 && t.categoryId != 'transfer')
          .fold<double>(0, (sum, t) => sum + t.amount);
    });

/// Monthly net (income - spending)
final netByMonthProvider = FutureProvider.autoDispose.family<double, String>((
  ref,
  monthKey,
) async {
  final income = await ref.watch(incomeByMonthProvider(monthKey).future);
  final spending = await ref.watch(spendingByMonthProvider(monthKey).future);
  return income - spending;
});

/// Transactions within a date range, optionally filtered by categories
final transactionsByDateRangeProvider = FutureProvider.autoDispose
    .family<
      List<Transaction>,
      ({DateTime start, DateTime end, Set<String>? categoryIds})
    >((ref, params) async {
      final db = ref.read(databaseProvider);
      // Treat `end` as a calendar date and include the entire day (date pickers
      // return midnight, which would otherwise exclude that day's transactions).
      final endExclusive = DateTime(
        params.end.year,
        params.end.month,
        params.end.day + 1,
      );
      var query = db.select(db.transactions)
        ..where((t) => t.date.isBiggerOrEqualValue(params.start))
        ..where((t) => t.date.isSmallerThanValue(endExclusive))
        ..orderBy([
          (t) => drift.OrderingTerm(
            expression: t.date,
            mode: drift.OrderingMode.desc,
          ),
        ]);

      if (params.categoryIds != null && params.categoryIds!.isNotEmpty) {
        query = query..where((t) => t.categoryId.isIn(params.categoryIds!));
      }

      return query.get();
    });

/// Daily spending totals for a given year (for calendar/contribution graph)
/// Returns `Map<DateTime(day only), double>`
final dailySpendingProvider = FutureProvider.autoDispose
    .family<Map<DateTime, double>, ({int year, String? categoryId})>((
      ref,
      params,
    ) async {
      final db = ref.read(databaseProvider);
      var query = db.select(db.transactions)
        ..where((t) => t.date.isBiggerOrEqualValue(DateTime(params.year)))
        ..where((t) => t.date.isSmallerThanValue(DateTime(params.year + 1)));

      if (params.categoryId != null) {
        query = query..where((t) => t.categoryId.equals(params.categoryId!));
      }

      final transactions = await query.get();
      final daily = <DateTime, double>{};
      for (final t in transactions.where(
        (t) => t.amount > 0 && t.categoryId != 'transfer',
      )) {
        final dayKey = DateTime(t.date.year, t.date.month, t.date.day);
        daily[dayKey] = (daily[dayKey] ?? 0.0) + t.amount;
      }
      return daily;
    });

/// Daily income totals for a given year
final dailyIncomeProvider = FutureProvider.autoDispose
    .family<Map<DateTime, double>, int>((ref, year) async {
      final db = ref.read(databaseProvider);
      final transactions =
          await (db.select(db.transactions)
                ..where((t) => t.date.isBiggerOrEqualValue(DateTime(year)))
                ..where((t) => t.date.isSmallerThanValue(DateTime(year + 1))))
              .get();
      final daily = <DateTime, double>{};
      for (final t in transactions.where((t) => t.amount < 0)) {
        final dayKey = DateTime(t.date.year, t.date.month, t.date.day);
        daily[dayKey] = (daily[dayKey] ?? 0.0) + t.amount.abs();
      }
      return daily;
    });

/// Budget health for current month: utilization %, status, remaining
final budgetHealthProvider = FutureProvider.autoDispose<BudgetHealth>((
  ref,
) async {
  final budgets = await ref.watch(thisMonthBudgetsProvider.future);
  final transactions = await ref.watch(thisMonthTransactionsProvider.future);

  final categorySpending = <String, double>{};
  for (final t in transactions.where(
    (t) => t.amount > 0 && t.categoryId != 'transfer',
  )) {
    categorySpending[t.categoryId] =
        (categorySpending[t.categoryId] ?? 0.0) + t.amount;
  }

  double totalBudget = 0;
  double totalSpent = 0;
  final categoryHealth = <String, CategoryBudgetHealth>{};

  for (final budget in budgets) {
    final spent = categorySpending[budget.categoryId] ?? 0.0;
    final allocated = budget.allocatedAmount;
    totalBudget += allocated;
    totalSpent += spent;

    final pct = allocated > 0 ? (spent / allocated * 100) : 0.0;
    categoryHealth[budget.categoryId] = CategoryBudgetHealth(
      categoryId: budget.categoryId,
      allocated: allocated,
      spent: spent,
      percentUsed: pct,
      status: _budgetStatus(pct),
    );
  }

  final overallPct = totalBudget > 0 ? (totalSpent / totalBudget * 100) : 0.0;

  return BudgetHealth(
    totalBudget: totalBudget,
    totalSpent: totalSpent,
    percentUsed: overallPct,
    status: _budgetStatus(overallPct),
    remaining: totalBudget - totalSpent,
    categoryHealth: categoryHealth,
  );
});

BudgetStatus _budgetStatus(double percent) {
  if (percent >= 100) return BudgetStatus.critical;
  if (percent >= 70) return BudgetStatus.warning;
  return BudgetStatus.healthy;
}

/// Spending velocity & pacing insights
final spendingVelocityProvider = FutureProvider.autoDispose<SpendingVelocity>((
  ref,
) async {
  final now = DateTime.now();

  final thisMonthTxns = await ref.watch(thisMonthTransactionsProvider.future);
  final lastMonthKey = Formatters.formatMonthKey(
    DateTime(now.year, now.month - 1),
  );
  final lastMonthTxns = await ref.watch(
    transactionsByMonthProvider(lastMonthKey).future,
  );

  final thisMonthSpent = thisMonthTxns
      .where((t) => t.amount > 0 && t.categoryId != 'transfer')
      .fold<double>(0, (s, t) => s + t.amount);
  final lastMonthSpent = lastMonthTxns
      .where((t) => t.amount > 0 && t.categoryId != 'transfer')
      .fold<double>(0, (s, t) => s + t.amount);

  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  final daysElapsed = now.day;
  final dailyAvg = daysElapsed > 0 ? thisMonthSpent / daysElapsed : 0.0;
  final projectedMonthEnd = dailyAvg * daysInMonth;

  final budgets = await ref.watch(thisMonthBudgetsProvider.future);
  final totalBudget = budgets.fold<double>(0, (s, b) => s + b.allocatedAmount);
  final budgetDailyTarget = totalBudget > 0 ? totalBudget / daysInMonth : 0.0;
  final pacingVsBudgetPercent = budgetDailyTarget > 0
      ? (dailyAvg / budgetDailyTarget * 100)
      : 0.0;

  final lastMonthDailyAvg =
      lastMonthSpent / DateTime(now.year, now.month, 0).day;
  final velocityVsLastMonthPercent = lastMonthDailyAvg > 0
      ? ((dailyAvg - lastMonthDailyAvg) / lastMonthDailyAvg * 100)
      : 0.0;

  return SpendingVelocity(
    dailyAverage: dailyAvg,
    projectedMonthEnd: projectedMonthEnd,
    daysElapsed: daysElapsed,
    daysInMonth: daysInMonth,
    pacingVsBudgetPercent: pacingVsBudgetPercent,
    velocityVsLastMonthPercent: velocityVsLastMonthPercent,
    totalBudget: totalBudget,
  );
});

/// Smart insights computed from spending patterns
final spendingInsightsProvider = FutureProvider.autoDispose<List<SpendingInsight>>((
  ref,
) async {
  final insights = <SpendingInsight>[];
  final now = DateTime.now();

  // Get velocity data
  final velocity = await ref.watch(spendingVelocityProvider.future);
  final thisMonthTxns = await ref.watch(thisMonthTransactionsProvider.future);
  final thisMonthSpent = thisMonthTxns
      .where((t) => t.amount > 0 && t.categoryId != 'transfer')
      .fold<double>(0, (s, t) => s + t.amount);

  // 1. Pacing insight
  if (velocity.totalBudget > 0) {
    final expectedPct = (velocity.daysElapsed / velocity.daysInMonth * 100);
    final actualSpentPct = velocity.totalBudget > 0
        ? (thisMonthSpent / velocity.totalBudget * 100)
        : 0.0;
    if (actualSpentPct > expectedPct * 1.2) {
      insights.add(
        SpendingInsight(
          type: InsightType.pacingWarning,
          title: 'Spending faster than budget',
          message:
              "You've spent ${actualSpentPct.toInt()}% of your budget by day ${velocity.daysElapsed} (expected ~${expectedPct.toInt()}%)",
          severity: InsightSeverity.warning,
          actionLabel: 'View Budget',
          actionTarget: 'budget',
        ),
      );
    } else if (actualSpentPct < expectedPct * 0.8) {
      insights.add(
        SpendingInsight(
          type: InsightType.pacingGood,
          title: 'On track with budget',
          message:
              "You've spent ${actualSpentPct.toInt()}% of your budget by day ${velocity.daysElapsed} — well within limits",
          severity: InsightSeverity.success,
        ),
      );
    }
  }

  // 2. Velocity vs last month
  if (velocity.velocityVsLastMonthPercent.abs() > 15) {
    final isFaster = velocity.velocityVsLastMonthPercent > 0;
    insights.add(
      SpendingInsight(
        type: isFaster ? InsightType.velocityUp : InsightType.velocityDown,
        title: isFaster ? 'Spending increased' : 'Spending decreased',
        message:
            'Daily average is ${velocity.velocityVsLastMonthPercent.abs().toInt()}% ${isFaster ? 'higher' : 'lower'} than last month',
        severity: isFaster ? InsightSeverity.warning : InsightSeverity.success,
      ),
    );
  }

  // 3. No-spend streak (from contribution graph data)
  final dailySpending = await ref.watch(
    dailySpendingProvider((year: now.year, categoryId: null)).future,
  );
  final streak = _calculateCurrentStreak(dailySpending, now);
  if (streak >= 3) {
    insights.add(
      SpendingInsight(
        type: InsightType.noSpendStreak,
        title: 'No-spend streak!',
        message:
            '$streak day${streak != 1 ? 's' : ''} without spending. Keep it going!',
        severity: InsightSeverity.success,
        actionLabel: 'View Calendar',
        actionTarget: 'calendar',
      ),
    );
  }

  // 4. Category delta vs last month
  final categoryDeltas = await _calculateCategoryDeltas(ref, now);
  for (final delta
      in categoryDeltas.where((d) => d.percentChange.abs() > 25).take(2)) {
    insights.add(
      SpendingInsight(
        type: delta.percentChange > 0
            ? InsightType.categoryUp
            : InsightType.categoryDown,
        title:
            '${delta.categoryName} spending ${delta.percentChange > 0 ? 'up' : 'down'}',
        message:
            '${delta.percentChange.abs().toInt()}% ${delta.percentChange > 0 ? 'increase' : 'decrease'} vs last month (${Formatters.formatCurrency(delta.currentAmount)})',
        severity: delta.percentChange > 0
            ? InsightSeverity.warning
            : InsightSeverity.success,
        actionLabel: 'View Transactions',
        actionTarget: 'transactions:${delta.categoryId}',
      ),
    );
  }

  // 5. Savings rate
  final incomeThisMonth = await ref.read(totalIncomeThisMonthProvider.future);
  final spentThisMonth = await ref.read(totalSpentThisMonthProvider.future);
  if (incomeThisMonth > 0) {
    final savingsRate =
        ((incomeThisMonth - spentThisMonth) / incomeThisMonth * 100).clamp(
          0,
          100,
        );
    insights.add(
      SpendingInsight(
        type: InsightType.savingsRate,
        title: 'Monthly savings rate',
        message:
            "You're saving ${savingsRate.toStringAsFixed(0)}% of your income (${Formatters.formatCurrency(incomeThisMonth - spentThisMonth)})",
        severity: savingsRate >= 20
            ? InsightSeverity.success
            : InsightSeverity.info,
      ),
    );
  }

  // 6. Biggest spending day this month
  final thisMonthDaily = dailySpending.entries
      .where((e) => e.key.month == now.month && e.key.year == now.year)
      .toList();
  if (thisMonthDaily.isNotEmpty) {
    final biggestDay = thisMonthDaily.reduce(
      (a, b) => a.value > b.value ? a : b,
    );
    if (biggestDay.value > 0) {
      insights.add(
        SpendingInsight(
          type: InsightType.biggestDay,
          title: 'Biggest spending day',
          message:
              '${Formatters.formatCurrency(biggestDay.value)} on ${Formatters.formatDateShort(biggestDay.key)}',
          severity: InsightSeverity.info,
        ),
      );
    }
  }

  return insights;
});

int _calculateCurrentStreak(Map<DateTime, double> dailySpending, DateTime now) {
  if (dailySpending.isEmpty) return 0;
  final today = DateTime(now.year, now.month, now.day);

  DateTime earliest = today;
  for (final date in dailySpending.keys) {
    if (date.isBefore(earliest)) earliest = date;
  }

  int streak = 0;
  for (int i = 0; i < 365; i++) {
    final checkDay = today.subtract(Duration(days: i));
    if (checkDay.isBefore(earliest)) break;
    final spent = dailySpending[checkDay] ?? 0;
    if (spent == 0) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

Future<List<CategoryDelta>> _calculateCategoryDeltas(
  Ref ref,
  DateTime now,
) async {
  final thisMonthTxns = await ref.read(thisMonthTransactionsProvider.future);
  final categories = await ref.read(categoriesProvider.future);

  // Build trailing 3-month average (months: now-3, now-2, now-1)
  final trailingMonths = List.generate(3, (i) {
    final date = DateTime(now.year, now.month - 3 + i);
    return Formatters.formatMonthKey(date);
  });

  // Aggregate spending across trailing 3 months by category
  final trailingByCat = <String, List<double>>{};
  for (final monthKey in trailingMonths) {
    final txns = await ref.read(transactionsByMonthProvider(monthKey).future);
    final catSums = <String, double>{};
    for (final t in txns.where(
      (t) => t.amount > 0 && t.categoryId != 'transfer',
    )) {
      catSums[t.categoryId] = (catSums[t.categoryId] ?? 0) + t.amount;
    }
    for (final entry in catSums.entries) {
      trailingByCat.putIfAbsent(entry.key, () => []);
      trailingByCat[entry.key]!.add(entry.value);
    }
  }

  final thisMonthByCat = <String, double>{};
  for (final t in thisMonthTxns.where(
    (t) => t.amount > 0 && t.categoryId != 'transfer',
  )) {
    thisMonthByCat[t.categoryId] =
        (thisMonthByCat[t.categoryId] ?? 0) + t.amount;
  }

  final deltas = <CategoryDelta>[];
  for (final entry in thisMonthByCat.entries) {
    final catId = entry.key;
    final current = entry.value;
    final cat = categories.where((c) => c.id == catId).firstOrNull;

    // Compute trailing 3-month average: sum of all months with data / 3
    final trailingAmounts = trailingByCat[catId] ?? [];
    final trailingAvg = trailingAmounts.isNotEmpty
        ? trailingAmounts.fold<double>(0, (s, a) => s + a) / 3.0
        : 0.0;

    if (trailingAvg > 0) {
      final pctChange = ((current - trailingAvg) / trailingAvg * 100);
      deltas.add(
        CategoryDelta(
          categoryId: catId,
          categoryName: cat?.name ?? catId,
          currentAmount: current,
          previousAmount: trailingAvg,
          percentChange: pctChange,
        ),
      );
    } else if (current > 0) {
      deltas.add(
        CategoryDelta(
          categoryId: catId,
          categoryName: cat?.name ?? catId,
          currentAmount: current,
          previousAmount: 0,
          percentChange: 100,
        ),
      );
    }
  }

  deltas.sort((a, b) => b.percentChange.abs().compareTo(a.percentChange.abs()));
  return deltas;
}

/// Custom report data for date range + categories
final customReportProvider = FutureProvider.autoDispose
    .family<
      CustomReportData,
      ({DateTime start, DateTime end, Set<String> categoryIds})
    >((ref, params) async {
      final transactions = await ref.watch(
        transactionsByDateRangeProvider(params).future,
      );
      final categories = await ref.watch(categoriesProvider.future);

      final income = transactions
          .where((t) => t.amount < 0)
          .fold<double>(0, (s, t) => s + t.amount.abs());
      final spent = transactions
          .where((t) => t.amount > 0 && t.categoryId != 'transfer')
          .fold<double>(0, (s, t) => s + t.amount);

      // By category
      final byCategory = <String, CategoryReportData>{};
      for (final t in transactions.where(
        (t) => t.amount > 0 && t.categoryId != 'transfer',
      )) {
        final cat = categories.where((c) => c.id == t.categoryId).firstOrNull;
        byCategory.update(
          t.categoryId,
          (v) => v.copyWith(amount: v.amount + t.amount, count: v.count + 1),
          ifAbsent: () => CategoryReportData(
            categoryId: t.categoryId,
            categoryName: cat?.name ?? t.categoryId,
            categoryColor: cat?.color ?? 0xFF6B7280,
            amount: t.amount,
            count: 1,
          ),
        );
      }

      // By month
      final byMonth = <String, MonthReportData>{};
      for (final t in transactions) {
        final monthKey = Formatters.formatMonthKey(t.date);
        final isIncome = t.amount < 0;
        byMonth.update(
          monthKey,
          (v) => v.copyWith(
            income: v.income + (isIncome ? t.amount.abs() : 0),
            spent:
                v.spent +
                (isIncome ? 0 : (t.categoryId != 'transfer' ? t.amount : 0)),
            count: v.count + 1,
          ),
          ifAbsent: () => MonthReportData(
            monthKey: monthKey,
            monthLabel: Formatters.formatMonth(t.date),
            income: isIncome ? t.amount.abs() : 0,
            spent: isIncome ? 0 : (t.categoryId != 'transfer' ? t.amount : 0),
            count: 1,
          ),
        );
      }

      // Daily for streak calculation
      final dailySpending = <DateTime, double>{};
      for (final t in transactions.where(
        (t) => t.amount > 0 && t.categoryId != 'transfer',
      )) {
        final dayKey = DateTime(t.date.year, t.date.month, t.date.day);
        dailySpending[dayKey] = (dailySpending[dayKey] ?? 0) + t.amount;
      }

      final streak = _calculateCurrentStreak(dailySpending, params.end);
      final longestStreak = _calculateLongestStreak(
        dailySpending,
        params.start,
        params.end,
      );

      return CustomReportData(
        startDate: params.start,
        endDate: params.end,
        totalIncome: income,
        totalSpent: spent,
        netSavings: income - spent,
        transactionCount: transactions.length,
        byCategory: byCategory.values.toList()
          ..sort((a, b) => b.amount.compareTo(a.amount)),
        byMonth: byMonth.values.toList()
          ..sort((a, b) => a.monthKey.compareTo(b.monthKey)),
        currentNoSpendStreak: streak,
        longestNoSpendStreak: longestStreak,
        generatedAt: DateTime.now(),
      );
    });

int _calculateLongestStreak(
  Map<DateTime, double> dailySpending,
  DateTime start,
  DateTime end,
) {
  if (dailySpending.isEmpty) return 0;
  int longest = 0;
  int current = 0;

  for (int i = 0; i <= end.difference(start).inDays; i++) {
    final day = start.add(Duration(days: i));
    final spent = dailySpending[day] ?? 0;
    if (spent == 0) {
      current++;
      if (current > longest) longest = current;
    } else {
      current = 0;
    }
  }
  return longest;
}

// ── Data Classes ──

class BudgetHealth {
  const BudgetHealth({
    required this.totalBudget,
    required this.totalSpent,
    required this.percentUsed,
    required this.status,
    required this.remaining,
    required this.categoryHealth,
  });
  final double totalBudget;
  final double totalSpent;
  final double percentUsed;
  final BudgetStatus status;
  final double remaining;
  final Map<String, CategoryBudgetHealth> categoryHealth;
}

enum BudgetStatus { healthy, warning, critical }

class CategoryBudgetHealth {
  const CategoryBudgetHealth({
    required this.categoryId,
    required this.allocated,
    required this.spent,
    required this.percentUsed,
    required this.status,
  });
  final String categoryId;
  final double allocated;
  final double spent;
  final double percentUsed;
  final BudgetStatus status;
}

class SpendingVelocity {
  const SpendingVelocity({
    required this.dailyAverage,
    required this.projectedMonthEnd,
    required this.daysElapsed,
    required this.daysInMonth,
    required this.pacingVsBudgetPercent,
    required this.velocityVsLastMonthPercent,
    required this.totalBudget,
  });
  final double dailyAverage;
  final double projectedMonthEnd;
  final int daysElapsed;
  final int daysInMonth;
  final double pacingVsBudgetPercent;
  final double velocityVsLastMonthPercent;
  final double totalBudget;
}

class SpendingInsight {
  const SpendingInsight({
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    this.actionLabel,
    this.actionTarget,
  });
  final InsightType type;
  final String title;
  final String message;
  final InsightSeverity severity;
  final String? actionLabel;
  final String? actionTarget;
}

enum InsightType {
  pacingWarning,
  pacingGood,
  velocityUp,
  velocityDown,
  noSpendStreak,
  categoryUp,
  categoryDown,
  savingsRate,
  biggestDay,
}

enum InsightSeverity { success, warning, info, critical }

class CategoryDelta {
  const CategoryDelta({
    required this.categoryId,
    required this.categoryName,
    required this.currentAmount,
    required this.previousAmount,
    required this.percentChange,
  });
  final String categoryId;
  final String categoryName;
  final double currentAmount;
  final double previousAmount;
  final double percentChange;
}

class CustomReportData {
  const CustomReportData({
    required this.startDate,
    required this.endDate,
    required this.totalIncome,
    required this.totalSpent,
    required this.netSavings,
    required this.transactionCount,
    required this.byCategory,
    required this.byMonth,
    required this.currentNoSpendStreak,
    required this.longestNoSpendStreak,
    required this.generatedAt,
  });
  final DateTime startDate;
  final DateTime endDate;
  final double totalIncome;
  final double totalSpent;
  final double netSavings;
  final int transactionCount;
  final List<CategoryReportData> byCategory;
  final List<MonthReportData> byMonth;
  final int currentNoSpendStreak;
  final int longestNoSpendStreak;
  final DateTime generatedAt;
}

class CategoryReportData {
  const CategoryReportData({
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.amount,
    required this.count,
  });
  final String categoryId;
  final String categoryName;
  final int categoryColor;
  final double amount;
  final int count;

  CategoryReportData copyWith({double? amount, int? count}) {
    return CategoryReportData(
      categoryId: categoryId,
      categoryName: categoryName,
      categoryColor: categoryColor,
      amount: amount ?? this.amount,
      count: count ?? this.count,
    );
  }
}

class MonthReportData {
  const MonthReportData({
    required this.monthKey,
    required this.monthLabel,
    required this.income,
    required this.spent,
    required this.count,
  });
  final String monthKey;
  final String monthLabel;
  final double income;
  final double spent;
  final int count;

  double get net => income - spent;

  MonthReportData copyWith({double? income, double? spent, int? count}) {
    return MonthReportData(
      monthKey: monthKey,
      monthLabel: monthLabel,
      income: income ?? this.income,
      spent: spent ?? this.spent,
      count: count ?? this.count,
    );
  }
}
