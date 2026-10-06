import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:printing/printing.dart';

import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/accessibility_utils.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/icon_helper.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/insight_cards.dart';
import '../../core/widgets/loading_skeleton.dart';
import '../../core/widgets/metric_card.dart';
import '../../core/widgets/section_title.dart';
import '../../providers/budget_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/insights_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/transaction_provider.dart';
import 'pdf_report_generator.dart';
import 'spend_calendar.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final categoryMap = ref.watch(categoryMapProvider);
    final categorySpending = ref.watch(categorySpendingMapProvider);
    final transactionsAsync = ref.watch(thisMonthTransactionsProvider);
    final allTransactions = ref.watch(transactionsProvider).valueOrNull ?? [];
    final budgets = ref.watch(thisMonthBudgetsProvider).valueOrNull ?? [];
    final incomeThisMonth =
        ref.watch(totalIncomeThisMonthProvider).valueOrNull ?? 0.0;
    final totalSpentThisMonth =
        ref.watch(totalSpentThisMonthProvider).valueOrNull ?? 0.0;
    final spendingInsightsAsync = ref.watch(spendingInsightsProvider);

    final totalSpent = categorySpending.values.fold<double>(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(
        title: Text('Insights', style: AppTheme.displayStyle(size: 17)),
        actions: [
          IconButton(
            icon: Icon(
              LucideIcons.fileText,
              size: 20,
              color: colorScheme.onSurface,
            ),
            onPressed: () => _showCustomReportSheet(context, ref),
            tooltip: 'Custom Report',
          ),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const LoadingSkeleton(),
        error: (_, _) => const Center(child: Text('Failed to load insights')),
        data: (_) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(spendingInsightsProvider);
            ref.invalidate(thisMonthTransactionsProvider);
            ref.invalidate(spendingByMonthProvider);
            // Small delay to let the providers refresh
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: AppConstants.screenPadding,
            children: [
              // ── Dashboard Totals: Money In | Spent | Left ──
              _DashboardTotals(
                income: incomeThisMonth,
                spent: totalSpentThisMonth,
              ),
              const _BudgetHealthBanner(),
              const SizedBox(height: 24),

              // Pie chart
              Text(
                'Spending by Category',
                style: AppTheme.displayStyle(
                  size: 16,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        AppConstants.cardRadius,
                      ),
                      color: isDark ? AppColors.cardDark : AppColors.cardLight,
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.08),
                      ),
                      boxShadow: isDark
                          ? AppColors.cardShadowDark
                          : AppColors.cardShadowLight,
                    ),
                    padding: AppConstants.cardPadding,
                    child: categorySpending.isEmpty
                        ? const ChartEmptyState()
                        : SizedBox(
                            height: 220,
                            child: Row(
                              children: [
                                Expanded(
                                  child: RepaintBoundary(
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        PieChart(
                                        PieChartData(
                                          sections: _buildPieSections(
                                            categorySpending,
                                            categoryMap,
                                            colorScheme,
                                          ),
                                          centerSpaceRadius: 44,
                                          sectionsSpace: 2.5,
                                          borderData: FlBorderData(show: false),
                                          pieTouchData: PieTouchData(
                                            touchCallback:
                                                (
                                                  FlTouchEvent event,
                                                  PieTouchResponse? response,
                                                ) {
                                                  if (event is FlTapUpEvent &&
                                                      response?.touchedSection !=
                                                          null) {
                                                    final touchedIndex =
                                                        response!
                                                            .touchedSection!
                                                            .touchedSectionIndex;
                                                    if (touchedIndex >= 0 &&
                                                        touchedIndex <
                                                            categorySpending
                                                                .length) {
                                                      final categoryId =
                                                          categorySpending.keys
                                                              .elementAt(
                                                                touchedIndex,
                                                              );
                                                      ref
                                                              .read(
                                                                transactionFilterProvider
                                                                    .notifier,
                                                              )
                                                              .state =
                                                          categoryId;
                                                      ref
                                                              .read(
                                                                currentTabProvider
                                                                    .notifier,
                                                              )
                                                              .state =
                                                          1;
                                                    }
                                                  }
                                                },
                                          ),
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'TOTAL',
                                            style: AppTheme.bodyStyle(
                                              size: 9,
                                              weight: FontWeight.w700,
                                              color: colorScheme
                                                  .onSurfaceVariant
                                                  .withValues(alpha: 0.6),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            Formatters.formatCurrency(
                                              totalSpent,
                                            ),
                                            style: AppTheme.financialStyle(
                                              size: 13,
                                              weight: FontWeight.w700,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                                const SizedBox(width: 16),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children:
                                      (categorySpending.entries.toList()..sort(
                                            (a, b) =>
                                                b.value.compareTo(a.value),
                                          ))
                                          .take(5)
                                          .map((entry) {
                                            final cat = categoryMap[entry.key];
                                            final pct = totalSpent > 0
                                                ? (entry.value /
                                                      totalSpent *
                                                      100)
                                                : 0.0;
                                            final catColor = Color(
                                              cat?.color ?? 0xFF6B7280,
                                            );
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 4,
                                                  ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 22,
                                                    height: 22,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      color: catColor
                                                          .withValues(
                                                            alpha: 0.14,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      getCategoryIcon(
                                                        cat?.icon ?? 'help',
                                                      ),
                                                      size: 12,
                                                      color: catColor,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        cat?.name ?? 'Other',
                                                        style:
                                                            AppTheme.bodyStyle(
                                                              size: 11,
                                                              weight: FontWeight
                                                                  .w600,
                                                              color: colorScheme
                                                                  .onSurface,
                                                            ),
                                                      ),
                                                      Text(
                                                        '${Formatters.formatCurrency(entry.value)} (${pct.toStringAsFixed(0)}%)',
                                                        style: AppTheme.bodyStyle(
                                                          size: 10,
                                                          color: colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          })
                                          .toList(),
                                ),
                              ],
                            ),
                          ),
                  )
                  .animate(
                    target: AccessibilityUtils.shouldAnimate(context)
                        ? null
                        : 1.0,
                  )
                  .fadeIn(duration: AppConstants.animSlow),
              const SizedBox(height: 24),

              // ── Month-over-Month Bar Chart ──
              Text(
                'Month-over-Month',
                style: AppTheme.displayStyle(
                  size: 16,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              RepaintBoundary(
                child: _MonthOverMonthChart(
                  onBarTapped: (int monthIndex) {
                    final now = DateTime.now();
                    final targetDate = DateTime(
                      now.year,
                      now.month - 5 + monthIndex,
                    );
                    ref.read(calendarFocusTargetProvider.notifier).state =
                        targetDate;
                  },
                ),
              ),
              const SizedBox(height: 24),

              // ── Smart Insights (from provider — trailing 3-month avg, pacing) ──
              if (categorySpending.isNotEmpty) ...[
                _SmartInsightsSection(insightsAsync: spendingInsightsAsync),
                const SizedBox(height: 24),
              ],

              // ── Budget vs Actual ──
              if (budgets.isNotEmpty) ...[
                Text(
                  'Budget vs Actual',
                  style: AppTheme.displayStyle(
                    size: 16,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          AppConstants.cardRadius,
                        ),
                        color: isDark
                            ? AppColors.cardDark
                            : AppColors.cardLight,
                        boxShadow: isDark
                            ? AppColors.cardShadowDark
                            : AppColors.cardShadowLight,
                      ),
                      padding: AppConstants.cardPadding,
                      child: Column(
                        children: budgets.map((budget) {
                          final category = categoryMap[budget.categoryId];
                          final spent =
                              categorySpending[budget.categoryId] ?? 0;
                          final allocated = budget.allocatedAmount;
                          final ratio = allocated > 0
                              ? (spent / allocated).clamp(0, 1).toDouble()
                              : 0.0;
                          final remaining = allocated - spent;
                          final isOver = spent > allocated;
                          final catColor = Color(category?.color ?? 0xFF6B7280);
                          final pct = allocated > 0
                              ? (spent / allocated * 100)
                              : 0.0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: catColor.withValues(alpha: 0.12),
                                      ),
                                      child: Icon(
                                        getCategoryIcon(category?.icon ?? ''),
                                        size: 14,
                                        color: catColor,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            category?.name ?? 'Unknown',
                                            style: AppTheme.bodyStyle(
                                              size: 13,
                                              weight: FontWeight.w600,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                          Text(
                                            '${Formatters.formatCurrency(spent)} of ${Formatters.formatCurrency(allocated)}',
                                            style: AppTheme.bodyStyle(
                                              size: 10,
                                              color: colorScheme
                                                  .onSurfaceVariant
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${pct.toStringAsFixed(0)}%',
                                          style: AppTheme.financialStyle(
                                            size: 14,
                                            weight: FontWeight.w700,
                                            color: isOver
                                                ? AppColors.error
                                                : colorScheme.onSurface,
                                          ),
                                        ),
                                        Text(
                                          isOver
                                              ? '${Formatters.formatCurrency(remaining.abs())} over'
                                              : '${Formatters.formatCurrency(remaining)} left',
                                          style: AppTheme.bodyStyle(
                                            size: 10,
                                            color: isOver
                                                ? AppColors.error.withValues(
                                                    alpha: 0.8,
                                                  )
                                                : AppColors.success.withValues(
                                                    alpha: 0.8,
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Progress bar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: ratio > 1 ? 1.0 : ratio,
                                    minHeight: 6,
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isOver ? AppColors.error : catColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    )
                    .animate(
                      target: AccessibilityUtils.shouldAnimate(context)
                          ? null
                          : 1.0,
                    )
                    .fadeIn(duration: AppConstants.animSlow, delay: 200.ms),
                const SizedBox(height: 24),
              ],

              // ── Weekly Trends ──
              // Uses ALL transactions — "last week" usually spans the previous
              // month, which this month's dataset cannot see.
              if (allTransactions.isNotEmpty) ...[
                Text(
                  'This Week vs Last Week',
                  style: AppTheme.displayStyle(
                    size: 16,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                RepaintBoundary(
                  child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            AppConstants.cardRadius,
                          ),
                          color: isDark
                              ? AppColors.cardDark
                              : AppColors.cardLight,
                          boxShadow: isDark
                              ? AppColors.cardShadowDark
                              : AppColors.cardShadowLight,
                        ),
                        padding: AppConstants.cardPadding,
                        child: SizedBox(
                          height: 200,
                          child: _WeeklyChart(transactions: allTransactions),
                        ),
                      )
                      .animate(
                        target: AccessibilityUtils.shouldAnimate(context)
                            ? null
                            : 1.0,
                      )
                      .fadeIn(duration: AppConstants.animSlow, delay: 150.ms),
                ),
                const SizedBox(height: 24),
              ],

              // ── Spending by Day of Week ──
              Text(
                'Spending by Day of Week',
                style: AppTheme.displayStyle(
                  size: 16,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              RepaintBoundary(
                child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          AppConstants.cardRadius,
                        ),
                        color: isDark ? AppColors.cardDark : AppColors.cardLight,
                        boxShadow: isDark
                            ? AppColors.cardShadowDark
                            : AppColors.cardShadowLight,
                      ),
                      padding: AppConstants.cardPadding,
                      child: const SizedBox(
                        height: 200,
                        child: _DayOfWeekChart(),
                      ),
                    )
                    .animate(
                      target: AccessibilityUtils.shouldAnimate(context)
                          ? null
                          : 1.0,
                    )
                    .fadeIn(duration: AppConstants.animSlow, delay: 200.ms),
              ),
              const SizedBox(height: 24),

              // Monthly trend — with cumulative/monthly toggle
              const RepaintBoundary(child: _TrendChartWithToggle()),
              // ── Interactive Spend Calendar ──
              const SizedBox(height: 24),
              const RepaintBoundary(child: SpendCalendar()),
              // ── Year in Review ──
              const RepaintBoundary(child: YearInReview()),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(
    Map<String, double> spending,
    Map<String, Category> categoryMap,
    ColorScheme colorScheme,
  ) {
    final total = spending.values.fold<double>(0, (a, b) => a + b);
    return spending.entries.map((entry) {
      final cat = categoryMap[entry.key];
      final pct = total > 0 ? (entry.value / total * 100) : 0.0;
      return PieChartSectionData(
        value: entry.value,
        color: Color(cat?.color ?? 0xFF6B7280),
        radius: 50,
        title: '${pct.toStringAsFixed(0)}%',
        titleStyle: AppTheme.bodyStyle(
          size: 11,
          weight: FontWeight.w600,
          color: Colors.white,
        ),
      );
    }).toList();
  }
}

/// ── Dashboard Totals: Money In | Spent | Left ──
class _DashboardTotals extends StatelessWidget {
  const _DashboardTotals({required this.income, required this.spent});
  final double income;
  final double spent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final left = income - spent;
    final isNegative = left < 0;

    return Row(
      children: [
        Expanded(
          child: MetricCard(
            label: 'Money In',
            value: Formatters.formatCurrency(income),
            icon: LucideIcons.plusCircle,
            color: AppColors.success,
            isDark: isDark,
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricCard(
            label: 'Spent',
            value: Formatters.formatCurrency(spent),
            icon: LucideIcons.trendingDown,
            color: AppColors.error,
            isDark: isDark,
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricCard(
            label: 'Left',
            value: Formatters.formatCurrency(left.abs()),
            prefix: isNegative ? '-' : '',
            isNegative: isNegative,
            icon: isNegative ? LucideIcons.trendingDown : LucideIcons.wallet,
            color: isNegative ? AppColors.error : AppColors.primary,
            colorScheme: colorScheme,
            isDark: isDark,
            subtitle: isNegative
                ? '${Formatters.formatCurrency(left.abs())} over this month'
                : null,
          ),
        ),
      ],
    );
  }
}

class _BudgetHealthBanner extends ConsumerWidget {
  const _BudgetHealthBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(budgetHealthProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return healthAsync.when(
      data: (health) {
        if (health.totalBudget == 0) return const SizedBox.shrink();

        Color statusColor;
        String statusLabel;
        IconData statusIcon;

        switch (health.status) {
          case BudgetStatus.healthy:
            statusColor = AppColors.success;
            statusLabel = 'Healthy';
            statusIcon = LucideIcons.checkCircle2;
            break;
          case BudgetStatus.warning:
            statusColor = AppColors.warning;
            statusLabel = 'Warning';
            statusIcon = LucideIcons.alertTriangle;
            break;
          case BudgetStatus.critical:
            statusColor = AppColors.error;
            statusLabel = 'Critical';
            statusIcon = LucideIcons.alertOctagon;
            break;
        }

        final pct = health.percentUsed.clamp(0, 100).toDouble();

        final now = DateTime.now();
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final dayOfMonth = now.day.clamp(1, daysInMonth);
        final dailyAllowance = health.totalBudget / daysInMonth;
        final expectedSpent = dailyAllowance * dayOfMonth;
        final velocityDelta = health.totalSpent - expectedSpent;

        final isPacingGood = velocityDelta <= 0;
        final pacingColor = isPacingGood
            ? AppColors.success
            : AppColors.warning;
        final pacingText = isPacingGood
            ? 'Pacing: On Track (₹${dailyAllowance.toStringAsFixed(0)}/day allowance)'
            : 'Pacing: ₹${velocityDelta.toStringAsFixed(0)} ahead of schedule';

        return Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                boxShadow: isDark
                    ? AppColors.cardShadowDark
                    : AppColors.cardShadowLight,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: statusColor.withValues(alpha: 0.12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 13, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              'Budget Health: $statusLabel',
                              style: AppTheme.bodyStyle(
                                size: 11,
                                weight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${health.percentUsed.toStringAsFixed(0)}% used',
                        style: AppTheme.financialStyle(
                          size: 13,
                          weight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (pct / 100).clamp(0, 1),
                      minHeight: 6,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        isPacingGood ? LucideIcons.gauge : LucideIcons.zap,
                        size: 11,
                        color: pacingColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          pacingText,
                          style: AppTheme.bodyStyle(
                            size: 10,
                            weight: FontWeight.w500,
                            color: pacingColor,
                          ),
                        ),
                      ),
                      Text(
                        '${Formatters.formatCurrency(health.totalSpent)} / ${Formatters.formatCurrency(health.totalBudget)}',
                        style: AppTheme.bodyStyle(
                          size: 10,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
            .animate(
              target: AccessibilityUtils.shouldAnimate(context) ? null : 1.0,
            )
            .fadeIn(duration: AppConstants.animFast)
            .slideY(begin: 0.1, end: 0);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

// ── Month-over-Month Bar Chart ──
class _MonthOverMonthChart extends ConsumerWidget {
  const _MonthOverMonthChart({this.onBarTapped});
  final void Function(int monthIndex)? onBarTapped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final date = DateTime(now.year, now.month - 5 + i);
      return Formatters.formatMonthKey(date);
    });

    return FutureBuilder<({List<double> income, List<double> spending})>(
      future: Future.wait([
        Future.wait(
          months.map((m) async {
            final txns = await ref.read(transactionsByMonthProvider(m).future);
            return txns
                .where((t) => t.amount < 0)
                .fold<double>(0, (sum, t) => sum + t.amount.abs());
          }),
        ),
        Future.wait(
          months.map((m) async {
            final txns = await ref.read(transactionsByMonthProvider(m).future);
            return txns
                .where((t) => t.amount > 0 && t.categoryId != 'transfer')
                .fold<double>(0, (sum, t) => sum + t.amount);
          }),
        ),
      ]).then((results) => (income: results[0], spending: results[1])),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            ),
          );
        }

        final incomeData = snapshot.data!.income;
        final spendingData = snapshot.data!.spending;
        final maxVal = [...incomeData, ...spendingData].reduce(max);

        return Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.cardRadius),
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.08),
            ),
            boxShadow: isDark
                ? AppColors.cardShadowDark
                : AppColors.cardShadowLight,
          ),
          padding: AppConstants.cardPadding,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal * 1.2,
              barTouchData: BarTouchData(
                touchCallback:
                    (FlTouchEvent event, BarTouchResponse? response) {
                      if (event is FlTapUpEvent &&
                          response?.spot != null &&
                          onBarTapped != null) {
                        final barIndex = response!.spot!.touchedBarGroupIndex;
                        if (barIndex >= 0 && barIndex < months.length) {
                          onBarTapped!(barIndex);
                        }
                      }
                    },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final monthLabel = Formatters.formatDateShort(
                      DateTime(now.year, now.month - 5 + groupIndex),
                    );
                    final isIncome = rodIndex == 0;
                    return BarTooltipItem(
                      'Tap to view calendar\n$monthLabel\n${isIncome ? "Income" : "Spending"}: ${Formatters.formatCurrency(rod.toY)}',
                      TextStyle(
                        color: isIncome ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= months.length) {
                        return const SizedBox.shrink();
                      }
                      final date = DateTime(now.year, now.month - 5 + idx);
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          Formatters.formatDateShort(date),
                          style: AppTheme.bodyStyle(
                            size: 9,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: colorScheme.outline.withValues(alpha: 0.06),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(months.length, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: incomeData[i],
                      color: AppColors.success,
                      width: 8,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                    BarChartRodData(
                      toY: spendingData[i],
                      color: AppColors.error,
                      width: 8,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

/// Trend chart with cumulative/monthly toggle
class _TrendChartWithToggle extends ConsumerStatefulWidget {
  const _TrendChartWithToggle();

  @override
  ConsumerState<_TrendChartWithToggle> createState() =>
      _TrendChartWithToggleState();
}

class _TrendChartWithToggleState extends ConsumerState<_TrendChartWithToggle> {
  bool _isCumulative = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '6-Month Trend',
              style: AppTheme.displayStyle(
                size: 16,
                color: colorScheme.onSurface,
              ),
            ),
            // Toggle: Monthly / Cumulative
            GestureDetector(
              onTap: () => setState(() => _isCumulative = !_isCumulative),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: colorScheme.primary.withValues(alpha: 0.1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isCumulative
                          ? LucideIcons.barChart
                          : LucideIcons.trendingUp,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isCumulative ? 'Cumulative' : 'Monthly',
                      style: AppTheme.bodyStyle(
                        size: 11,
                        weight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                boxShadow: isDark
                    ? AppColors.cardShadowDark
                    : AppColors.cardShadowLight,
              ),
              padding: AppConstants.cardPadding,
              child: SizedBox(
                height: 200,
                child: _TrendChart(isCumulative: _isCumulative),
              ),
            )
            .animate(
              target: AccessibilityUtils.shouldAnimate(context) ? null : 1.0,
            )
            .fadeIn(duration: AppConstants.animSlow, delay: 100.ms),
      ],
    );
  }
}

class _TrendChart extends ConsumerWidget {
  const _TrendChart({this.isCumulative = false});
  final bool isCumulative;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final date = DateTime(now.year, now.month - 5 + i);
      return Formatters.formatMonthKey(date);
    });

    return FutureBuilder<List<double>>(
      future: Future.wait(
        months.map((m) async {
          final txns = await ref.read(transactionsByMonthProvider(m).future);
          return txns
              .where((t) => t.amount > 0 && t.categoryId != 'transfer')
              .fold<double>(0, (sum, t) => sum + t.amount);
        }),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var data = snapshot.data!;

        if (isCumulative) {
          double running = 0;
          data = data.map((v) {
            running += v;
            return running;
          }).toList();
        }

        final maxVal = data.reduce(max);
        final minVal = data.reduce(min);
        final range = maxVal - minVal > 0 ? maxVal - minVal : 1.0;
        final avgMonthly = data.isEmpty
            ? 0.0
            : (data.reduce((a, b) => a + b) / data.length);

        return Column(
          children: [
            // Averages summary chip bar
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.barChart2,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Monthly Avg: ${Formatters.formatCurrency(avgMonthly)}',
                        style: AppTheme.bodyStyle(
                          size: 11,
                          weight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Spending',
                        style: AppTheme.bodyStyle(
                          size: 10,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: range / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colorScheme.outline.withValues(alpha: 0.08),
                      strokeWidth: 1,
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) =>
                          colorScheme.surfaceContainerHigh,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            Formatters.formatCurrency(spot.y),
                            TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= months.length) {
                            return const SizedBox.shrink();
                          }
                          final date = DateTime(now.year, now.month - 5 + idx);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('MMM').format(date),
                              style: AppTheme.bodyStyle(
                                size: 10,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: maxVal * 1.15,
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        data.length,
                        (i) => FlSpot(i.toDouble(), data[i]),
                      ),
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: AppColors.primary,
                            strokeWidth: 2,
                            strokeColor: colorScheme.surface,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.transactions});
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    // This week (Monday to Sunday). Normalize boundaries to local midnight —
    // keeping `now`'s time-of-day pushed earlier-this-week transactions into
    // last week's bars.
    final today = DateTime(now.year, now.month, now.day);
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    final thisWeekEnd = thisMonday.add(const Duration(days: 7));

    // Group spending by day of week (Mon-Sun)
    final List<double> thisWeek = List.filled(7, 0);
    final List<double> lastWeek = List.filled(7, 0);

    // Exclude transfer entries from weekly chart (transfers are balance-neutral)
    for (final t in transactions.where(
      (t) => t.amount > 0 && t.categoryId != 'transfer',
    )) {
      if (!t.date.isBefore(thisMonday) && t.date.isBefore(thisWeekEnd)) {
        final dayIdx = t.date.weekday - 1; // 0 = Monday
        if (dayIdx >= 0 && dayIdx < 7) thisWeek[dayIdx] += t.amount;
      } else if (!t.date.isBefore(lastMonday) && t.date.isBefore(thisMonday)) {
        final dayIdx = t.date.weekday - 1;
        if (dayIdx >= 0 && dayIdx < 7) lastWeek[dayIdx] += t.amount;
      }
    }

    final maxVal = [...thisWeek, ...lastWeek].reduce(max);

    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final isThisWeek = rodIndex == 0;
              return BarTooltipItem(
                '${isThisWeek ? "This" : "Last"} ${dayLabels[groupIndex]}\n₹${rod.toY.toStringAsFixed(0)}',
                TextStyle(
                  color: isThisWeek ? AppColors.primary : Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= dayLabels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    dayLabels[idx],
                    style: AppTheme.bodyStyle(
                      size: 9,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outline.withValues(alpha: 0.06),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: thisWeek[i],
                color: AppColors.primary,
                width: 8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
              BarChartRodData(
                toY: lastWeek[i],
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                width: 8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _DayOfWeekChart extends ConsumerWidget {
  const _DayOfWeekChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final allTransactions = ref.watch(transactionsProvider).valueOrNull ?? [];

    // Aggregate spending by day of week across ALL data
    final dayTotals = <int, double>{0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
    // Exclude transfer entries from day-of-week chart (transfers are balance-neutral)
    for (final t in allTransactions.where(
      (t) => t.amount > 0 && t.categoryId != 'transfer',
    )) {
      dayTotals[t.date.weekday - 1] =
          (dayTotals[t.date.weekday - 1] ?? 0) + t.amount;
    }

    final hasData = dayTotals.values.any((v) => v > 0);
    if (!hasData) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.calendarDays,
              size: 32,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'No data to show',
              style: AppTheme.bodyStyle(
                size: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final maxVal = dayTotals.values.reduce(max);
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Find highest spending day
    final maxDayIdx = dayTotals.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    final totalAll = dayTotals.values.fold<double>(0, (a, b) => a + b);

    return Column(
      children: [
        // Summary line
        Container(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
                child: Text(
                  'Highest: ${dayLabels[maxDayIdx]}',
                  style: AppTheme.bodyStyle(
                    size: 11,
                    weight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Average spending per day (only days with spending)
              Text(
                'Avg ₹${(totalAll / dayTotals.values.where((v) => v > 0).length).toStringAsFixed(0)}/day',
                style: AppTheme.bodyStyle(
                  size: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal * 1.25,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                      BarTooltipItem(
                        '${dayLabels[group.x]}\n₹${rod.toY.toStringAsFixed(0)}',
                        TextStyle(
                          color: group.x == maxDayIdx
                              ? AppColors.primary
                              : Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= dayLabels.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          dayLabels[idx],
                          style: AppTheme.bodyStyle(
                            size: 9,
                            color: colorScheme.onSurfaceVariant,
                            weight: idx == maxDayIdx
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: colorScheme.outline.withValues(alpha: 0.06),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(7, (i) {
                final isMax = i == maxDayIdx;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: dayTotals[i] ?? 0,
                      color: isMax
                          ? AppColors.primary
                          : colorScheme.primary.withValues(alpha: 0.35),
                      width: isMax ? 14 : 10,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

/// ── Smart Insights Section (from provider) ──
class _SmartInsightsSection extends ConsumerWidget {
  const _SmartInsightsSection({required this.insightsAsync});
  final AsyncValue<List<SpendingInsight>> insightsAsync;

  void _handleTap(
    BuildContext context,
    WidgetRef ref,
    SpendingInsight insight,
  ) {
    HapticFeedback.lightImpact();
    final target = insight.actionTarget;
    if (target == null) return;

    if (target == 'budget') {
      final tab = budgetTabIndex(ref);
      if (tab != null) {
        ref.read(budgetHighlightProvider.notifier).state = 'income';
        ref.read(currentTabProvider.notifier).state = tab;
      }
    } else if (target == 'calendar') {
      // Scroll to bottom of the list where SpendCalendar lives
      Scrollable.of(context).position.animateTo(
        Scrollable.of(context).position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else if (target.startsWith('transactions:')) {
      final categoryId = target.split(':')[1];
      ref.read(transactionFilterProvider.notifier).state = categoryId;
      ref.read(currentTabProvider.notifier).state = 1;
    }
  }

  IconData _severityIcon(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.success:
        return LucideIcons.checkCircle2;
      case InsightSeverity.warning:
        return LucideIcons.alertTriangle;
      case InsightSeverity.critical:
        return LucideIcons.alertOctagon;
      case InsightSeverity.info:
        return LucideIcons.info;
    }
  }

  Color _severityColor(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.success:
        return AppColors.success;
      case InsightSeverity.warning:
        return AppColors.warning;
      case InsightSeverity.critical:
        return AppColors.error;
      case InsightSeverity.info:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return insightsAsync.when(
      data: (insights) {
        if (insights.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.lightbulb,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 6),
                Text(
                  'Smart Insights',
                  style: AppTheme.displayStyle(
                    size: 16,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                color: colorScheme.brightness == Brightness.dark
                    ? AppColors.cardDark
                    : AppColors.cardLight,
                boxShadow: colorScheme.brightness == Brightness.dark
                    ? AppColors.cardShadowDark
                    : AppColors.cardShadowLight,
              ),
              padding: AppConstants.cardPadding,
              child: Column(
                children: insights
                    .map(
                      (insight) => _InsightRow(
                        key: ValueKey(insight.title),
                        icon: _severityIcon(insight.severity),
                        iconColor: _severityColor(insight.severity),
                        text: '${insight.title}: ${insight.message}',
                        colorScheme: colorScheme,
                        onTap: insight.actionTarget != null
                            ? () => _handleTap(context, ref, insight)
                            : null,
                        actionLabel: insight.actionLabel,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _InsightRow extends StatefulWidget {
  const _InsightRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.colorScheme,
    this.onTap,
    this.actionLabel,
  });
  final IconData icon;
  final Color iconColor;
  final String text;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;
  final String? actionLabel;

  @override
  State<_InsightRow> createState() => _InsightRowState();
}

class _InsightRowState extends State<_InsightRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..value = 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.animateTo(
      0.94,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  void _onTapRelease() {
    _controller.animateTo(
      1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
    );
  }

  void _onTapCancel() {
    _controller.animateTo(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTappable = widget.onTap != null;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.92 + (value * 0.08),
            alignment: Alignment.centerLeft,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: isTappable
              ? () {
                  _onTapRelease();
                  widget.onTap!();
                }
              : null,
          onTapDown: isTappable ? _onTapDown : null,
          onTapCancel: isTappable ? _onTapCancel : null,
          borderRadius: BorderRadius.circular(10),
          hoverColor: widget.iconColor.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 1),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.iconColor.withValues(alpha: 0.1),
                  ),
                  child: Icon(widget.icon, size: 14, color: widget.iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.text,
                    style: AppTheme.bodyStyle(
                      size: 12,
                      color: widget.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
                if (isTappable && widget.actionLabel != null) ...[
                  const SizedBox(width: 8),
                  Transform.scale(
                    scale: _controller.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: widget.iconColor.withValues(alpha: 0.1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.actionLabel!,
                            style: AppTheme.bodyStyle(
                              size: 10,
                              weight: FontWeight.w600,
                              color: widget.iconColor,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 10,
                            color: widget.iconColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Custom Report Sheet ──

void _showCustomReportSheet(BuildContext context, WidgetRef ref) {
  final colorScheme = Theme.of(context).colorScheme;
  final isDark = colorScheme.brightness == Brightness.dark;
  DateTimeRange? selectedRange;
  final Set<String> selectedCategories = {};
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            expand: false,
            builder: (ctx, scrollController) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Custom Report',
                    style: AppTheme.displayStyle(color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select date range and filters, then export as PDF',
                    style: AppTheme.bodyStyle(
                      size: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Date range picker
                  const SectionTitle('Date Range'),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(now.year - 5),
                        lastDate: now,
                        initialDateRange:
                            selectedRange ??
                            DateTimeRange(
                              start: DateTime(now.year, now.month),
                              end: now,
                            ),
                      );
                      if (range != null) setState(() => selectedRange = range);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isDark
                            ? AppColors.raisedDark
                            : AppColors.raisedLight,
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.calendar,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedRange != null
                                  ? '${Formatters.formatDateShort(selectedRange!.start)} — ${Formatters.formatDateShort(selectedRange!.end)}'
                                  : 'Select date range',
                              style: AppTheme.bodyStyle(
                                color: selectedRange != null
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Category filter
                  const SectionTitle('Categories'),
                  const SizedBox(height: 12),
                  FutureBuilder<List<Category>>(
                    future: ref.read(categoriesProvider.future),
                    builder: (ctx, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      final cats = snap.data!
                          .where((c) => c.type == 'expense')
                          .toList();
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('All'),
                            selected: selectedCategories.isEmpty,
                            onSelected: (_) =>
                                setState(selectedCategories.clear),
                            selectedColor: colorScheme.primary.withValues(
                              alpha: 0.15,
                            ),
                            checkmarkColor: colorScheme.primary,
                          ),
                          ...cats.map(
                            (c) => FilterChip(
                              label: Text(c.name),
                              selected: selectedCategories.contains(c.id),
                              onSelected: (sel) => setState(() {
                                if (sel) {
                                  selectedCategories.add(c.id);
                                } else {
                                  selectedCategories.remove(c.id);
                                }
                              }),
                              selectedColor: Color(
                                c.color,
                              ).withValues(alpha: 0.15),
                              checkmarkColor: Color(c.color),
                              avatar: Icon(
                                getCategoryIcon(c.icon),
                                size: 14,
                                color: Color(c.color),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Export button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: selectedRange != null
                          ? () async {
                              Navigator.pop(ctx);
                              final params = (
                                start: selectedRange!.start,
                                end: selectedRange!.end,
                                categoryIds: selectedCategories.isEmpty
                                    ? <String>{}
                                    : selectedCategories,
                              );
                              final report = await ref.read(
                                customReportProvider(params).future,
                              );
                              if (context.mounted) {
                                await _generateAndSharePDF(context, report);
                              }
                            }
                          : null,
                      icon: const Icon(LucideIcons.download, size: 20),
                      label: const Text('Generate & Export PDF'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}

Future<void> _generateAndSharePDF(
  BuildContext context,
  CustomReportData data,
) async {
  try {
    final pdfBytes = await PdfReportGenerator.generateReportPdf(data);
    final fileName =
        'BudgetLite_Report_${DateFormat('yyyyMMdd').format(data.startDate)}_${DateFormat('yyyyMMdd').format(data.endDate)}.pdf';
    await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export PDF: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
