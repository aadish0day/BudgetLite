import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/database/database.dart';
import '../../providers/transaction_provider.dart';

/// ── Heatmap Calendar ──
/// Shows spending intensity per day as colored squares in a calendar grid.
class HeatmapCalendar extends ConsumerWidget {
  final List<Transaction> transactions;
  const HeatmapCalendar({super.key, required this.transactions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    // Build a map of daily spending totals for the current month
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final dailyTotals = <int, double>{};
    double maxDaily = 0;

    for (final t in transactions.where((t) => t.amount > 0)) {
      if (t.date.year == now.year && t.date.month == now.month) {
        dailyTotals[t.date.day] = (dailyTotals[t.date.day] ?? 0) + t.amount;
        maxDaily = max(maxDaily, dailyTotals[t.date.day]!);
      }
    }

    if (dailyTotals.isEmpty) return const SizedBox.shrink();

    // Find first day of month weekday for grid alignment
    final firstWeekday = DateTime(now.year, now.month, 1).weekday; // 1=Mon ... 7=Sun

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.calendar, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              'Spend Heatmap — ${Formatters.formatMonth(now)}',
              style: AppTheme.displayStyle(size: 16, weight: FontWeight.w600, color: colorScheme.onSurface),
            ),
          ],
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
            children: [
              // Day-of-week header
              Row(
                children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) => Expanded(
                  child: Center(
                    child: Text(d, style: AppTheme.bodyStyle(size: 9, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 8),
              // Calendar grid
              ...List.generate(_weeksInMonth(firstWeekday, daysInMonth), (weekIdx) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: List.generate(7, (dayOfWeek) {
                      final dayNum = weekIdx * 7 + dayOfWeek - firstWeekday + 2;
                      final isValid = dayNum >= 1 && dayNum <= daysInMonth;
                      final spent = dailyTotals[dayNum] ?? 0.0;
                      final intensity = maxDaily > 0 ? (spent / maxDaily) : 0.0;

                      Color cellColor;
                      if (!isValid) {
                        cellColor = Colors.transparent;
                      } else if (spent == 0) {
                        cellColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
                      } else if (intensity < 0.25) {
                        cellColor = AppColors.success.withValues(alpha: 0.2);
                      } else if (intensity < 0.5) {
                        cellColor = AppColors.warning.withValues(alpha: 0.3);
                      } else if (intensity < 0.75) {
                        cellColor = AppColors.warning.withValues(alpha: 0.6);
                      } else {
                        cellColor = AppColors.error.withValues(alpha: 0.5);
                      }

                      final isToday = isValid && dayNum == now.day;

                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: cellColor,
                            border: isToday ? Border.all(color: colorScheme.primary, width: 1.5) : null,
                          ),
                          child: Center(
                            child: isValid
                                ? Text(
                                    '$dayNum',
                                    style: AppTheme.bodyStyle(
                                      size: 10,
                                      weight: isToday ? FontWeight.w700 : FontWeight.w400,
                                      color: spent > 0
                                          ? (intensity > 0.5 ? Colors.white : colorScheme.onSurface)
                                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
              const SizedBox(height: 12),
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(color: AppColors.success.withValues(alpha: 0.2), label: 'Low'),
                  const SizedBox(width: 12),
                  _LegendDot(color: AppColors.warning.withValues(alpha: 0.3), label: 'Medium'),
                  const SizedBox(width: 12),
                  _LegendDot(color: AppColors.error.withValues(alpha: 0.5), label: 'High'),
                ],
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  int _weeksInMonth(int firstWeekday, int daysInMonth) {
    final totalCells = firstWeekday - 1 + daysInMonth;
    return (totalCells / 7).ceil();
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: color)),
        const SizedBox(width: 4),
        Text(label, style: AppTheme.bodyStyle(size: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

/// ── Year in Review ──
/// Shows spending summary for a completed calendar year.
/// If the current year hasn't completed yet, shows data labeled "so far".
class YearInReview extends ConsumerWidget {
  const YearInReview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final allTransactions = ref.watch(transactionsProvider).valueOrNull ?? [];

    if (allTransactions.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final yearStart = DateTime(now.year, 1, 1);
    final yearTxns = allTransactions.where((t) => t.date.isAfter(yearStart) || t.date.year == now.year).toList();

    if (yearTxns.isEmpty) return const SizedBox.shrink();

    final isYearComplete = now.month == 12 && now.day >= 31;
    final monthsElapsed = isYearComplete ? 12 : now.month;
    final label = isYearComplete ? '${now.year}' : '${now.year} (so far)';

    // Stats
    final totalSpent = yearTxns.where((t) => t.amount > 0).fold<double>(0, (s, t) => s + t.amount);
    final totalIncome = yearTxns.where((t) => t.amount < 0).fold<double>(0, (s, t) => s + t.amount.abs());
    final avgMonthlySpend = monthsElapsed > 0 ? totalSpent / monthsElapsed : 0.0;
    final totalTxns = yearTxns.length;
    final biggestSpend = yearTxns.where((t) => t.amount > 0).fold<double>(0, (s, t) => s > t.amount ? s : t.amount);
    final savingsRate = totalIncome > 0 ? ((totalIncome - totalSpent) / totalIncome * 100).clamp(0, 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.award, size: 16, color: isYearComplete ? AppColors.warning : colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              'Year in Review — $label',
              style: AppTheme.displayStyle(size: 16, weight: FontWeight.w600, color: colorScheme.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.cardRadius),
            gradient: LinearGradient(
              colors: isDark
                  ? [AppColors.primary.withValues(alpha: 0.12), AppColors.primary.withValues(alpha: 0.04)]
                  : [AppColors.primary.withValues(alpha: 0.06), AppColors.primary.withValues(alpha: 0.02)],
            ),
            border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
          ),
          padding: AppConstants.cardPadding,
          child: Column(
            children: [
              // Partial year banner
              if (!isYearComplete)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.primary.withValues(alpha: 0.08),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.info, size: 12, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Partial year data — $monthsElapsed month${monthsElapsed != 1 ? 's' : ''} so far',
                        style: AppTheme.bodyStyle(
                          size: 11,
                          color: colorScheme.primary,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              // Top row: big numbers
              Row(
                children: [
                  _YearStat(label: 'Total Spent', value: Formatters.formatCurrency(totalSpent), icon: LucideIcons.trendingDown, color: AppColors.error, compact: true),
                  const SizedBox(width: 12),
                  _YearStat(label: 'Total Income', value: Formatters.formatCurrency(totalIncome), icon: LucideIcons.trendingUp, color: AppColors.success, compact: true),
                ],
              ),
              const SizedBox(height: 16),
              // Stats grid
              Row(
                children: [
                  _MiniStat(label: 'Transactions', value: '$totalTxns', color: colorScheme.primary),
                  _MiniStat(label: 'Avg/Month', value: Formatters.formatCurrency(avgMonthlySpend), color: colorScheme.onSurface),
                  _MiniStat(label: 'Biggest', value: Formatters.formatCurrency(biggestSpend), color: AppColors.error),
                  _MiniStat(label: 'Saved', value: '${savingsRate.toStringAsFixed(0)}%', color: AppColors.success),
                ],
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }
}

class _YearStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool compact;

  const _YearStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.1)),
                child: Icon(icon, size: 12, color: color),
              ),
              const SizedBox(width: 4),
              Text(label, style: AppTheme.bodyStyle(size: 10, color: colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.financialStyle(size: compact ? 18 : 22, weight: FontWeight.w700, color: colorScheme.onSurface)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTheme.financialStyle(size: 14, weight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppTheme.bodyStyle(size: 9, color: colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
