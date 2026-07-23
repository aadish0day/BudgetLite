import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/icon_helper.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../core/database/database.dart';
import '../../providers/database_provider.dart';
import '../../core/widgets/insight_cards.dart';
import 'spend_calendar.dart';
import 'contribution_graph.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final transactions = ref.watch(thisMonthTransactionsProvider).valueOrNull ?? [];
    final budgets = ref.watch(thisMonthBudgetsProvider).valueOrNull ?? [];

    // Exclude transfer entries from spending (transfers are balance-neutral)
    final categorySpending = <String, double>{};
    for (final t in transactions.where((t) => t.amount > 0 && t.categoryId != 'transfer')) {
      categorySpending[t.categoryId] =
          (categorySpending[t.categoryId] ?? 0) + t.amount;
    }

    final totalSpent = categorySpending.values.fold<double>(0, (a, b) => a + b);
    final totalBudget = budgets.fold<double>(0, (s, b) => s + b.allocatedAmount);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Insights',
          style: AppTheme.displayStyle(
            size: 17,
            weight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: AppConstants.screenPadding,
        children: [
          // Summary cards
          Row(
            children: [
              _SummaryCard(
                label: 'Total Spent',
                value: Formatters.formatCurrency(totalSpent),
                icon: LucideIcons.trendingDown,
                color: AppColors.error,
              ),
              const SizedBox(width: 12),
              _SummaryCard(
                label: 'Budget Used',
                value: Formatters.formatPercentage(
                  totalBudget > 0 ? (totalSpent / totalBudget) * 100 : 0,
                ),
                icon: LucideIcons.chartPie,
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Pie chart
          Text(
            'Spending by Category',
            style: AppTheme.displayStyle(
              size: 16,
              weight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.cardRadius),
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
            ),
            padding: AppConstants.cardPadding,
            child: categorySpending.isEmpty
                ? _ChartEmptyState()
                : SizedBox(
                    height: 220,
                    child: Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sections: _buildPieSections(
                                  categorySpending, categories, colorScheme),
                              centerSpaceRadius: 40,
                              sectionsSpace: 2,
                              borderData: FlBorderData(show: false),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children:
                              categorySpending.entries.take(5).map((entry) {
                            final cat = categories
                                .where((c) => c.id == entry.key)
                                .firstOrNull;
                            final pct = totalSpent > 0
                                ? (entry.value / totalSpent * 100)
                                : 0.0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(cat?.color ?? 0xFF6B7280),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${cat?.name ?? '?'} ${pct.toStringAsFixed(0)}%',
                                    style: AppTheme.bodyStyle(
                                      size: 11,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
          ).animate().fadeIn(duration: 500.ms),
          const SizedBox(height: 24),

          // ── Smart Insights ──
          if (categorySpending.isNotEmpty) ...[
            _SmartInsights(
              categorySpending: categorySpending,
              categories: categories,
              totalSpent: totalSpent,
              budgets: budgets,
            ),
            const SizedBox(height: 24),
          ],

          // ── Budget vs Actual ──
          if (budgets.isNotEmpty) ...[
            Text(
              'Budget vs Actual',
              style: AppTheme.displayStyle(
                size: 16,
                weight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
              ),
              padding: AppConstants.cardPadding,
              child: Column(
                children: budgets.map((budget) {
                  final category = categories.where((c) => c.id == budget.categoryId).firstOrNull;
                  final spent = categorySpending[budget.categoryId] ?? 0;
                  final allocated = budget.allocatedAmount;
                  final ratio = allocated > 0 ? (spent / allocated).clamp(0, 1).toDouble() : 0.0;
                  final remaining = allocated - spent;
                  final isOver = spent > allocated;
                  final catColor = Color(category?.color ?? 0xFF6B7280);
                  final pct = allocated > 0 ? (spent / allocated * 100) : 0.0;

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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${pct.toStringAsFixed(0)}%',
                                  style: AppTheme.financialStyle(
                                    size: 14,
                                    weight: FontWeight.w700,
                                    color: isOver ? AppColors.error : colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  isOver
                                      ? '${Formatters.formatCurrency(remaining.abs())} over'
                                      : '${Formatters.formatCurrency(remaining)} left',
                                  style: AppTheme.bodyStyle(
                                    size: 10,
                                    color: isOver
                                        ? AppColors.error.withValues(alpha: 0.8)
                                        : AppColors.success.withValues(alpha: 0.8),
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
                            backgroundColor: colorScheme.surfaceContainerHighest,
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
            ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
            const SizedBox(height: 24),
          ],

          // ── Weekly Trends ──
          if (transactions.isNotEmpty) ...[
            Text(
              'This Week vs Last Week',
              style: AppTheme.displayStyle(
                size: 16,
                weight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
              ),
              padding: AppConstants.cardPadding,
              child: SizedBox(
                height: 200,
                child: _WeeklyChart(transactions: transactions),
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 150.ms),
            const SizedBox(height: 24),
          ],

          // ── Spending by Day of Week ──
          Text(
            'Spending by Day of Week',
            style: AppTheme.displayStyle(
              size: 16,
              weight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.cardRadius),
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
            ),
            padding: AppConstants.cardPadding,
            child: SizedBox(
              height: 200,
              child: _DayOfWeekChart(),
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
          const SizedBox(height: 24),

          // Monthly trend
          Text(
            '6-Month Trend',
            style: AppTheme.displayStyle(
              size: 16,
              weight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.cardRadius),
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
            ),
            padding: AppConstants.cardPadding,
            child: SizedBox(
              height: 200,
              child: _TrendChart(),
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 100.ms),
          // ── Interactive Spend Calendar ──
          const SizedBox(height: 24),
          const SpendCalendar(),
          const SizedBox(height: 12),

          // ── Contribution Graph ──
          const SizedBox(height: 24),
          const ContributionGraph(),

          // ── Year in Review ──
          const YearInReview(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(
    Map<String, double> spending,
    List<Category> categories,
    ColorScheme colorScheme,
  ) {
    final total = spending.values.fold<double>(0, (a, b) => a + b);
    return spending.entries.map((entry) {
      final cat =
          categories.where((c) => c.id == entry.key).firstOrNull;
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

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.cardRadiusSmall),
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: color.withValues(alpha: 0.12),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: AppTheme.financialStyle(
                size: 20,
                weight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTheme.bodyStyle(
                size: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final date = DateTime(now.year, now.month - 5 + i, 1);
      return Formatters.formatMonthKey(date);
    });

    return FutureBuilder<List<double>>(
      future: Future.wait(months.map((m) async {
        final txns = await ref.read(transactionsByMonthProvider(m).future);
        return txns
            .where((t) => t.amount > 0 && t.categoryId != 'transfer')
            .fold<double>(0, (sum, t) => sum + t.amount);
      })),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final maxVal = data.reduce(max);
        final minVal = data.reduce(min);
        final range = maxVal - minVal > 0 ? maxVal - minVal : 1.0;

        return LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawHorizontalLine: true,
              drawVerticalLine: false,
              horizontalInterval: range / 4,
              getDrawingHorizontalLine: (value) => FlLine(
                color: colorScheme.outline.withValues(alpha: 0.08),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= months.length) {
                      return const SizedBox.shrink();
                    }
                    final date = DateTime(now.year, now.month - 5 + idx, 1);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        Formatters.formatDateShort(date),
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
                spots: List.generate(data.length,
                    (i) => FlSpot(i.toDouble(), data[i])),
                isCurved: true,
                color: AppColors.primary,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
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
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final List<Transaction> transactions;

  const _WeeklyChart({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    // This week (Monday to Sunday)
    final thisMonday = now.subtract(Duration(days: now.weekday - 1));
    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    final thisWeekEnd = thisMonday.add(const Duration(days: 7));

    // Group spending by day of week (Mon-Sun)
    List<double> thisWeek = List.filled(7, 0);
    List<double> lastWeek = List.filled(7, 0);

    // Exclude transfer entries from weekly chart (transfers are balance-neutral)
    for (final t in transactions.where((t) => t.amount > 0 && t.categoryId != 'transfer')) {
      if (t.date.isAfter(thisMonday) && t.date.isBefore(thisWeekEnd)) {
        final dayIdx = t.date.weekday - 1; // 0 = Monday
        if (dayIdx >= 0 && dayIdx < 7) thisWeek[dayIdx] += t.amount;
      } else if (t.date.isAfter(lastMonday) && t.date.isBefore(thisMonday)) {
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
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= dayLabels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    dayLabels[idx],
                    style: AppTheme.bodyStyle(size: 9, color: colorScheme.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: lastWeek[i],
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                width: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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
    for (final t in allTransactions.where((t) => t.amount > 0 && t.categoryId != 'transfer')) {
      dayTotals[t.date.weekday - 1] =
          (dayTotals[t.date.weekday - 1] ?? 0) + t.amount;
    }

    final hasData = dayTotals.values.any((v) => v > 0);
    if (!hasData) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.calendarDays, size: 32, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text('No data to show', style: AppTheme.bodyStyle(size: 13, color: colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final maxVal = dayTotals.values.reduce(max);
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Find highest spending day
    final maxDayIdx = dayTotals.entries.reduce((a, b) => a.value > b.value ? a : b).key;
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
                  getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                    '${dayLabels[group.x.toInt()]}\n₹${rod.toY.toStringAsFixed(0)}',
                    TextStyle(
                      color: group.x == maxDayIdx ? AppColors.primary : Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= dayLabels.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          dayLabels[idx],
                          style: AppTheme.bodyStyle(
                            size: 9,
                            color: colorScheme.onSurfaceVariant,
                            weight: idx == maxDayIdx ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
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
                      color: isMax ? AppColors.primary : colorScheme.primary.withValues(alpha: 0.35),
                      width: isMax ? 14 : 10,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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

class _SmartInsights extends StatelessWidget {
  final Map<String, double> categorySpending;
  final List<Category> categories;
  final double totalSpent;
  final List<Budget> budgets;

  const _SmartInsights({
    required this.categorySpending,
    required this.categories,
    required this.totalSpent,
    required this.budgets,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Find the top category by spending
    final topEntry = categorySpending.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topCat = topEntry.isNotEmpty
        ? categories.where((c) => c.id == topEntry.first.key).firstOrNull
        : null;

    // Check if any category is over budget
    final overBudgetCats = budgets.where((b) {
      final spent = categorySpending[b.categoryId] ?? 0;
      return spent > b.allocatedAmount && b.allocatedAmount > 0;
    }).toList();

    // Calculate avg daily spend
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final avgDaily = totalSpent / daysInMonth;

    final insights = <Widget>[];

    // Insight 1: Top category
    if (topCat != null && topEntry.isNotEmpty) {
      final pct = (topEntry.first.value / totalSpent * 100);
      insights.add(_InsightRow(
        icon: LucideIcons.trendingUp,
        iconColor: Color(topCat.color),
        text: '${topCat.name} is your highest spend at ${pct.toStringAsFixed(0)}% of total',
        colorScheme: colorScheme,
      ));
    }

    // Insight 2: Daily average
    insights.add(_InsightRow(
      icon: LucideIcons.calendarDays,
      iconColor: colorScheme.primary,
      text: 'You spend ₹${avgDaily.toStringAsFixed(0)} per day on average',
      colorScheme: colorScheme,
    ));

    // Insight 3: Over budget
    for (final b in overBudgetCats) {
      final cat = categories.where((c) => c.id == b.categoryId).firstOrNull;
      final spent = categorySpending[b.categoryId] ?? 0;
      final overPct = ((spent - b.allocatedAmount) / b.allocatedAmount * 100);
      insights.add(_InsightRow(
        icon: LucideIcons.triangleAlert,
        iconColor: AppColors.error,
        text: '${cat?.name ?? 'Category'} is over budget by ${overPct.toStringAsFixed(0)}%',
        colorScheme: colorScheme,
      ));
    }

    // Insight 4: Budget health
    if (budgets.isNotEmpty) {
      final totalBudget = budgets.fold<double>(0, (s, b) => s + b.allocatedAmount);
      if (totalBudget > 0) {
        final used = (totalSpent / totalBudget * 100);
        final remaining = totalBudget - totalSpent;
        insights.add(_InsightRow(
          icon: used > 100 ? LucideIcons.trendingDown : LucideIcons.trendingUp,
          iconColor: used > 100 ? AppColors.error : AppColors.success,
          text: used > 100
              ? 'You\'ve exceeded your total budget by ${Formatters.formatCurrency(remaining.abs())}'
              : 'You have ${Formatters.formatCurrency(remaining)} left of your total budget',
          colorScheme: colorScheme,
        ));
      }
    }

    if (insights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.lightbulb, size: 16, color: AppColors.warning),
            const SizedBox(width: 6),
            Text(
              'Smart Insights',
              style: AppTheme.displayStyle(
                size: 16,
                weight: FontWeight.w600,
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
            boxShadow: colorScheme.brightness == Brightness.dark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
          ),
          padding: AppConstants.cardPadding,
          child: Column(
            children: insights,
          ),
        ),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final ColorScheme colorScheme;

  const _InsightRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.1),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodyStyle(
                size: 12,
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.chartBar,
            size: 40,
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
}
