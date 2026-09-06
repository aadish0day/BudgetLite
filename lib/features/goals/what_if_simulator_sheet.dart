import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/icon_helper.dart';
import '../../providers/budget_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/goal_provider.dart';

class WhatIfSimulatorSheet extends ConsumerStatefulWidget {
  const WhatIfSimulatorSheet({super.key});

  @override
  ConsumerState<WhatIfSimulatorSheet> createState() =>
      _WhatIfSimulatorSheetState();
}

class _WhatIfSimulatorSheetState extends ConsumerState<WhatIfSimulatorSheet> {
  final Map<String, double> _reductions = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _hasInitialized = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final budgetsAsync = ref.watch(thisMonthBudgetsProvider);
    final goalsAsync = ref.watch(goalsProvider);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: colorScheme.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    LucideIcons.flaskConical,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What-If Simulator',
                        style: AppTheme.displayStyle(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Adjust budgets to see impact on savings goals',
                        style: AppTheme.bodyStyle(
                          size: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: goalsAsync.when(
                data: (goals) {
                  return categoriesAsync.when(
                    data: (categories) {
                      return budgetsAsync.when(
                        data: (budgets) {
                          if (!_hasInitialized) {
                            _hasInitialized = true;
                            for (final b in budgets) {
                              _reductions[b.categoryId] = 0;
                            }
                          }
                          return _buildContent(
                            colorScheme,
                            isDark,
                            categories,
                            budgets,
                            goals,
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, _) =>
                            const Center(child: Text('Could not load budgets')),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) =>
                        const Center(child: Text('Could not load categories')),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) =>
                    const Center(child: Text('Could not load goals')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    ColorScheme colorScheme,
    bool isDark,
    List<Category> categories,
    List<Budget> budgets,
    List<Goal> goals,
  ) {
    final totalFreed = _reductions.values.fold<double>(0, (s, v) => s + v);
    final allocatedFreed = totalFreed / (goals.isEmpty ? 1 : goals.length);

    // Filter categories with budgets > 0 for adjustment
    final budgetedCategories = categories.where((c) {
      final budget = budgets.where((b) => b.categoryId == c.id).firstOrNull;
      return budget != null && budget.allocatedAmount > 0;
    }).toList();

    if (budgetedCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.wallet,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'Set budgets first',
              style: AppTheme.displayStyle(
                size: 16,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add category budgets in the Budget tab to simulate',
              style: AppTheme.bodyStyle(
                size: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        // Budget adjustments
        ...budgetedCategories.map((cat) {
          final budget = budgets.firstWhere((b) => b.categoryId == cat.id);
          final reduction = _reductions[cat.id] ?? 0;
          final catColor = Color(cat.color);
          return _buildAdjustmentRow(
            cat,
            budget,
            reduction,
            catColor,
            colorScheme,
          );
        }),
        const SizedBox(height: 16),

        // Freed up total
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.cardRadiusSmall),
            color: totalFreed > 0
                ? AppColors.success.withValues(alpha: 0.08)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            border: totalFreed > 0
                ? Border.all(color: AppColors.success.withValues(alpha: 0.2))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                totalFreed > 0 ? LucideIcons.trendingDown : LucideIcons.minus,
                size: 18,
                color: totalFreed > 0
                    ? AppColors.success
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  totalFreed > 0 ? 'Freed up per month' : 'No reductions yet',
                  style: AppTheme.bodyStyle(
                    size: 12,
                    weight: FontWeight.w500,
                    color: totalFreed > 0
                        ? AppColors.success
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: 300.ms,
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Text(
                  totalFreed > 0
                      ? Formatters.formatCurrency(totalFreed)
                      : '₹ 0',
                  key: ValueKey(totalFreed),
                  style: AppTheme.financialStyle(
                    size: 20,
                    weight: FontWeight.w700,
                    color: totalFreed > 0
                        ? AppColors.success
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (totalFreed > 0 && goals.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Impact on Goals',
            style: AppTheme.displayStyle(
              size: 14,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          ...goals.map(
            (goal) =>
                _buildGoalImpactCard(goal, allocatedFreed, colorScheme, isDark),
          ),
        ],

        if (totalFreed > 0 && goals.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Center(
              child: Text(
                'Create a savings goal to see impact',
                style: AppTheme.bodyStyle(
                  size: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAdjustmentRow(
    Category cat,
    Budget budget,
    double reduction,
    Color catColor,
    ColorScheme colorScheme,
  ) {
    final ctrl = _controllers.putIfAbsent(
      cat.id,
      () => TextEditingController(
        text: reduction > 0 ? reduction.toStringAsFixed(0) : '',
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.cardRadiusSmall),
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: catColor.withValues(alpha: 0.12),
              ),
              child: Icon(getCategoryIcon(cat.icon), size: 16, color: catColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat.name,
                    style: AppTheme.bodyStyle(
                      size: 13,
                      weight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    Formatters.formatCurrency(budget.allocatedAmount),
                    style: AppTheme.bodyStyle(
                      size: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 80,
              height: 34,
              child: TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                style: AppTheme.financialStyle(
                  size: 13,
                  color: AppColors.success,
                ),
                decoration: InputDecoration(
                  prefixText: '- ₹ ',
                  prefixStyle: AppTheme.financialStyle(
                    size: 11,
                    weight: FontWeight.w500,
                    color: AppColors.success.withValues(alpha: 0.7),
                  ),
                  hintText: '0',
                  hintStyle: AppTheme.financialStyle(
                    size: 13,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: colorScheme.outline.withValues(alpha: 0.15),
                    ),
                  ),
                  filled: true,
                  fillColor: reduction > 0
                      ? AppColors.success.withValues(alpha: 0.06)
                      : colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.3,
                        ),
                ),
                onChanged: (v) {
                  final val = double.tryParse(v) ?? 0;
                  setState(() {
                    _reductions[cat.id] = val
                        .clamp(0, budget.allocatedAmount)
                        .toDouble();
                  });
                },
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: () {
                setState(() {
                  _reductions[cat.id] = 0;
                  ctrl.clear();
                });
              },
              icon: Icon(
                LucideIcons.x,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalImpactCard(
    Goal goal,
    double allocatedFreed,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    if (goal.targetAmount <= 0) return const SizedBox.shrink();

    final goalColor = Color(goal.color);
    final remaining = goal.targetAmount - goal.currentAmount;
    if (remaining <= 0) return const SizedBox.shrink(); // Already achieved

    // Compute current monthly savings rate
    final monthsSinceCreated = max(
      1,
      DateTime.now().difference(goal.createdAt).inDays / 30,
    );
    final currentMonthlyRate = goal.currentAmount > 0
        ? goal.currentAmount / monthsSinceCreated
        : 0.0;

    // Fallback: if no actual savings, use the recommended pace
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(
      goal.targetDate.year,
      goal.targetDate.month,
      goal.targetDate.day,
    );
    final daysLeft = targetDay.difference(today).inDays;
    final yearlyPace = daysLeft > 0 ? remaining / max(1, daysLeft ~/ 30) : 0;

    final effectiveRate = currentMonthlyRate > 0
        ? currentMonthlyRate
        : yearlyPace;

    if (effectiveRate <= 0) {
      // Cannot compute — no savings history and no pace info
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.cardRadiusSmall),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: goalColor.withValues(alpha: 0.12),
                ),
                child: Icon(
                  _getGoalIcon(goal.icon),
                  size: 18,
                  color: goalColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: AppTheme.bodyStyle(
                        size: 13,
                        weight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Start contributing to see projections',
                      style: AppTheme.bodyStyle(
                        size: 10,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final monthsToGoal = (remaining / effectiveRate).clamp(0.0, 600.0);
    final newRate = effectiveRate + allocatedFreed;
    final newMonthsToGoal = (remaining / newRate).clamp(0.0, 600.0);
    final monthsSaved = max(0, monthsToGoal - newMonthsToGoal);

    // Format dates
    final currentProjectedDate = DateTime.now().add(
      Duration(days: (monthsToGoal * 30).round()),
    );
    final newProjectedDate = DateTime.now().add(
      Duration(days: (newMonthsToGoal * 30).round()),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.cardRadiusSmall),
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          border: Border.all(color: goalColor.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: goalColor.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    _getGoalIcon(goal.icon),
                    size: 18,
                    color: goalColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: AppTheme.bodyStyle(
                          size: 13,
                          weight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${Formatters.formatCurrency(goal.currentAmount)} / ${Formatters.formatCurrency(goal.targetAmount)}',
                        style: AppTheme.bodyStyle(
                          size: 10,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (monthsSaved > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: AppColors.success.withValues(alpha: 0.12),
                    ),
                    child: Text(
                      '${monthsSaved.round()}mo saved',
                      style: AppTheme.bodyStyle(
                        size: 10,
                        weight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Timeline comparison
            Row(
              children: [
                Expanded(
                  child: _TimelineBar(
                    label: 'Current',
                    months: monthsToGoal.round(),
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    projectedDate: currentProjectedDate,
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimelineBar(
                    label: 'With cuts',
                    months: newMonthsToGoal.round(),
                    color: AppColors.success,
                    projectedDate: newProjectedDate,
                    colorScheme: colorScheme,
                    highlighted: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getGoalIcon(String iconName) {
    return {
          'flag': LucideIcons.flag,
          'flight': LucideIcons.plane,
          'home': LucideIcons.house,
          'school': LucideIcons.graduationCap,
          'car': LucideIcons.carFront,
          'shopping': LucideIcons.shoppingBag,
        }[iconName] ??
        LucideIcons.flag;
  }
}

class _TimelineBar extends StatelessWidget {
  const _TimelineBar({
    required this.label,
    required this.months,
    required this.color,
    required this.projectedDate,
    required this.colorScheme,
    this.highlighted = false,
  });
  final String label;
  final int months;
  final Color color;
  final DateTime projectedDate;
  final ColorScheme colorScheme;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final yearStr = Formatters.formatDateShort(projectedDate);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: highlighted
            ? color.withValues(alpha: 0.08)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.bodyStyle(
              size: 10,
              weight: FontWeight.w600,
              color: highlighted ? color : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${months}mo',
            style: AppTheme.financialStyle(
              size: 18,
              weight: FontWeight.w800,
              color: highlighted ? color : colorScheme.onSurface,
            ),
          ),
          Text(
            yearStr,
            style: AppTheme.bodyStyle(
              size: 10,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
