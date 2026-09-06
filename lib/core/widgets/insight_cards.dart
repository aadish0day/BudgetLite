import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import '../../providers/transaction_provider.dart';

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
    // Only transactions dated within the current year — future-dated entries
    // (date pickers allow years ahead) previously leaked into these stats.
    final yearTxns = allTransactions
        .where((t) => t.date.year == now.year)
        .toList();

    if (yearTxns.isEmpty) return const SizedBox.shrink();

    final isYearComplete = now.month == 12 && now.day >= 31;
    final monthsElapsed = isYearComplete ? 12 : now.month;
    final label = isYearComplete ? '${now.year}' : '${now.year} (so far)';

    // Stats
    final totalSpent = yearTxns
        .where((t) => t.amount > 0)
        .fold<double>(0, (s, t) => s + t.amount);
    final totalIncome = yearTxns
        .where((t) => t.amount < 0)
        .fold<double>(0, (s, t) => s + t.amount.abs());
    final avgMonthlySpend = monthsElapsed > 0
        ? totalSpent / monthsElapsed
        : 0.0;
    final totalTxns = yearTxns.length;
    final biggestSpend = yearTxns
        .where((t) => t.amount > 0)
        .fold<double>(0, (s, t) => s > t.amount ? s : t.amount);
    final savingsRate = totalIncome > 0
        ? ((totalIncome - totalSpent) / totalIncome * 100).clamp(0, 100)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.award,
              size: 16,
              color: isYearComplete ? AppColors.warning : colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Year in Review — $label',
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
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      AppColors.primary.withValues(alpha: 0.12),
                      AppColors.primary.withValues(alpha: 0.04),
                    ]
                  : [
                      AppColors.primary.withValues(alpha: 0.06),
                      AppColors.primary.withValues(alpha: 0.02),
                    ],
            ),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
          padding: AppConstants.cardPadding,
          child: Column(
            children: [
              // Partial year banner
              if (!isYearComplete)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.primary.withValues(alpha: 0.08),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.info,
                        size: 12,
                        color: colorScheme.primary,
                      ),
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
                  _YearStat(
                    label: 'Total Spent',
                    value: Formatters.formatCurrency(totalSpent),
                    icon: LucideIcons.trendingDown,
                    color: AppColors.error,
                    compact: true,
                  ),
                  const SizedBox(width: 12),
                  _YearStat(
                    label: 'Total Income',
                    value: Formatters.formatCurrency(totalIncome),
                    icon: LucideIcons.trendingUp,
                    color: AppColors.success,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Stats grid
              Row(
                children: [
                  _MiniStat(
                    label: 'Transactions',
                    value: '$totalTxns',
                    color: colorScheme.primary,
                  ),
                  _MiniStat(
                    label: 'Avg/Month',
                    value: Formatters.formatCurrency(avgMonthlySpend),
                    color: colorScheme.onSurface,
                  ),
                  _MiniStat(
                    label: 'Biggest',
                    value: Formatters.formatCurrency(biggestSpend),
                    color: AppColors.error,
                  ),
                  _MiniStat(
                    label: 'Saved',
                    value: '${savingsRate.toStringAsFixed(0)}%',
                    color: AppColors.success,
                  ),
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
  const _YearStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.compact = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool compact;

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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.1),
                ),
                child: Icon(icon, size: 12, color: color),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTheme.bodyStyle(
                  size: 10,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTheme.financialStyle(
              size: compact ? 18 : 22,
              weight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.financialStyle(
              size: 14,
              weight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.bodyStyle(
              size: 9,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
