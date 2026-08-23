import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/accessibility_utils.dart';
import '../../providers/goal_provider.dart';
import '../../core/database/database.dart';
import 'what_if_simulator_sheet.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final goals = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Savings Goals',
          style: AppTheme.displayStyle(
            size: 17,
            weight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'What-If Simulator',
            onPressed: () => _showSimulator(context),
            icon: Icon(LucideIcons.flaskConical, size: 18),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGoalSheet(context, ref),
        child: const Icon(LucideIcons.plus),
      ),
      body: goals.when(
        data: (goalList) {
          if (goalList.isEmpty) return _EmptyGoals();
          final allAchieved = goalList.every((g) => g.currentAmount >= g.targetAmount);
          return ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: AppConstants.screenPadding,
            children: [
              if (allAchieved)
                _AllGoalsAchieved(count: goalList.length),
              _GoalsPortfolioHeader(goals: goalList),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Goals (${goalList.length})',
                    style: AppTheme.displayStyle(
                      size: 15,
                      weight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showSimulator(context),
                    icon: const Icon(LucideIcons.flaskConical, size: 14),
                    label: const Text('Simulate All', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...goalList.map((goal) => _GoalCard(goal: goal, ref: ref)),
            ],
          );
        },
        loading: () => const _GoalsSkeleton(),
        error: (_, _) => _EmptyGoals(),
      ),
    );
  }

  void _showAddGoalSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddGoalSheet(),
    );
  }

  void _showSimulator(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const WhatIfSimulatorSheet(),
    );
  }
}

class _GoalsPortfolioHeader extends StatelessWidget {
  final List<Goal> goals;
  const _GoalsPortfolioHeader({required this.goals});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    final totalTarget = goals.fold<double>(0, (sum, g) => sum + g.targetAmount);
    final totalSaved = goals.fold<double>(0, (sum, g) => sum + g.currentAmount);
    final totalRemaining = (totalTarget - totalSaved).clamp(0.0, double.infinity);
    final overallProgress = totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0;
    final activeCount = goals.where((g) => g.currentAmount < g.targetAmount).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [colorScheme.primaryContainer.withValues(alpha: 0.7), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : colorScheme.primary.withValues(alpha: 0.15),
        ),
        boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.target, size: 18, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Savings Portfolio',
                    style: AppTheme.displayStyle(size: 16, weight: FontWeight.w600, color: colorScheme.onSurface),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(overallProgress * 100).toStringAsFixed(0)}% Overall',
                  style: AppTheme.bodyStyle(size: 11, weight: FontWeight.w700, color: AppColors.success),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL SAVED', style: AppTheme.bodyStyle(size: 10, weight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.formatCurrency(totalSaved),
                      style: AppTheme.financialStyle(size: 22, weight: FontWeight.w700, color: colorScheme.primary),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: colorScheme.outline.withValues(alpha: 0.15)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TARGET GOAL', style: AppTheme.bodyStyle(size: 10, weight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.formatCurrency(totalTarget),
                      style: AppTheme.financialStyle(size: 22, weight: FontWeight.w700, color: colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: overallProgress,
              minHeight: 8,
              backgroundColor: colorScheme.outline.withValues(alpha: 0.12),
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$activeCount active goal${activeCount == 1 ? '' : 's'}',
                style: AppTheme.bodyStyle(size: 12, color: colorScheme.onSurfaceVariant),
              ),
              Text(
                '${Formatters.formatCurrency(totalRemaining)} left to save',
                style: AppTheme.bodyStyle(size: 12, weight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final WidgetRef ref;

  const _GoalCard({required this.goal, required this.ref});

  void _showContributeSheet(BuildContext context) {
    final amountCtrl = TextEditingController();
    bool _ctrlDisposed = false;
    void _safeDisposeCtrl() {
      if (!_ctrlDisposed) {
        _ctrlDisposed = true;
        amountCtrl.dispose();
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Contribute to ${goal.name}',
                    style: AppTheme.displayStyle(
                      size: 20, weight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Saved: ${Formatters.formatCurrency(goal.currentAmount)} of ${Formatters.formatCurrency(goal.targetAmount)}',
                    style: AppTheme.bodyStyle(
                      size: 13, color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: AppTheme.financialStyle(size: 24, weight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Amount to add',
                      prefixText: '₹ ',
                      prefixStyle: AppTheme.financialStyle(size: 24, weight: FontWeight.w700),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _safeDisposeCtrl();
                            Navigator.pop(ctx);
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () async {
                            final amount = double.tryParse(amountCtrl.text);
                            if (amount != null && amount > 0) {
                              final isAchievedNow = (goal.currentAmount + amount) >= goal.targetAmount;
                              await ref.read(goalNotifierProvider.notifier)
                                  .updateGoalProgress(goal.id, amount);
                              if (!context.mounted) return;
                              _safeDisposeCtrl();
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isAchievedNow
                                        ? 'Goal Achieved! Added ₹${amount.toStringAsFixed(0)} to ${goal.name}!'
                                        : '₹${amount.toStringAsFixed(0)} added to ${goal.name}',
                                  ),
                                  backgroundColor: isAchievedNow ? AppColors.success : null,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Add Funds'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(_safeDisposeCtrl);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final progress = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount).clamp(0, 1).toDouble()
        : 0.0;
    final isGoalExceeded = goal.currentAmount >= goal.targetAmount;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(goal.targetDate.year, goal.targetDate.month, goal.targetDate.day);
    final daysLeft = targetDay.difference(today).inDays;
    final goalColor = Color(goal.color);
    final remainingAmount = (goal.targetAmount - goal.currentAmount).clamp(0.0, double.infinity);
    final neededPerDay = daysLeft > 0 ? (remainingAmount / daysLeft).roundToDouble() : 0;
    final monthlyPace = neededPerDay * 30;

    // Goal Health Calculation
    final String healthLabel;
    final Color healthColor;
    if (isGoalExceeded) {
      healthLabel = 'Achieved';
      healthColor = AppColors.success;
    } else if (daysLeft <= 0) {
      healthLabel = 'Overdue';
      healthColor = AppColors.error;
    } else if (progress >= 0.75) {
      healthLabel = '75% Complete';
      healthColor = AppColors.success;
    } else if (progress >= 0.4) {
      healthLabel = 'On Track';
      healthColor = AppColors.primary;
    } else {
      healthLabel = 'Needs Pace';
      healthColor = AppColors.warning;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
        border: Border.all(
          color: isGoalExceeded
              ? AppColors.success.withValues(alpha: 0.4)
              : colorScheme.outline.withValues(alpha: 0.08),
          width: isGoalExceeded ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: goalColor.withValues(alpha: 0.12),
                ),
                child: Icon(
                  _getIcon(goal.icon),
                  color: goalColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: AppTheme.displayStyle(
                        size: 16,
                        weight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isGoalExceeded
                          ? 'Completed'
                          : daysLeft > 0
                              ? '$daysLeft days left • Target ${Formatters.formatDateShort(goal.targetDate)}'
                              : 'Target passed',
                      style: AppTheme.bodyStyle(
                        size: 12,
                        color: isGoalExceeded ? AppColors.success : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: healthColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  healthLabel,
                  style: AppTheme.bodyStyle(size: 11, weight: FontWeight.w600, color: healthColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Financial Metrics Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SAVED', style: AppTheme.bodyStyle(size: 10, weight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.formatCurrency(goal.currentAmount),
                    style: AppTheme.financialStyle(size: 18, weight: FontWeight.w700, color: goalColor),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('REMAINING', style: AppTheme.bodyStyle(size: 10, weight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.formatCurrency(remainingAmount),
                    style: AppTheme.financialStyle(size: 18, weight: FontWeight.w700, color: colorScheme.onSurface),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Integrated Custom Progress Bar with Milestone Ticks
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: isGoalExceeded ? 1.0 : progress,
                  minHeight: 10,
                  backgroundColor: colorScheme.outline.withValues(alpha: 0.1),
                  color: goalColor,
                ),
              ),
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(3, (i) => Container(
                    width: 2,
                    height: 10,
                    color: colorScheme.surface.withValues(alpha: 0.7),
                  )),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(progress * 100).toStringAsFixed(0)}% saved', style: AppTheme.bodyStyle(size: 11, weight: FontWeight.w600, color: goalColor)),
              if (daysLeft > 0 && remainingAmount > 0)
                Text(
                  daysLeft < 30 ? '₹${neededPerDay.toStringAsFixed(0)}/day needed' : '₹${monthlyPace.toStringAsFixed(0)}/mo needed',
                  style: AppTheme.bodyStyle(size: 11, color: colorScheme.onSurfaceVariant),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Action Button Row
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showContributeSheet(context),
                  icon: const Icon(LucideIcons.wallet, size: 16),
                  label: Text(
                    goal.currentAmount >= goal.targetAmount ? 'Completed' : 'Contribute',
                    style: AppTheme.bodyStyle(size: 13, weight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: goalColor.withValues(alpha: 0.15),
                    foregroundColor: goalColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) => const WhatIfSimulatorSheet(),
                  );
                },
                icon: const Icon(LucideIcons.flaskConical, size: 16),
                tooltip: 'Simulate',
                style: IconButton.styleFrom(
                  side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              IconButton.outlined(
                onPressed: () => _confirmDelete(context),
                icon: Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
                tooltip: 'Delete',
                style: IconButton.styleFrom(
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(target: AccessibilityUtils.shouldAnimate(context) ? null : 1.0).fadeIn(duration: AppConstants.animNormal, curve: Curves.easeOutCubic).slideY(begin: 0.04, duration: AppConstants.animNormal, curve: Curves.easeOutCubic);
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: Text('Are you sure you want to delete "${goal.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(goalNotifierProvider.notifier).deleteGoal(goal.id);
              Navigator.pop(ctx);
            },
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String iconName) {
    return {
      'flag': LucideIcons.flag,
      'flight': LucideIcons.plane,
      'home': LucideIcons.house,
      'school': LucideIcons.graduationCap,
      'car': LucideIcons.carFront,
      'shopping': LucideIcons.shoppingBag,
    }[iconName] ?? LucideIcons.flag;
  }
}

class _EmptyGoals extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.flag,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No savings goals yet',
            style: AppTheme.displayStyle(
              size: 18,
              weight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a goal to start saving for what matters',
            style: AppTheme.bodyStyle(
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Celebration banner shown when every active goal has been achieved.
class _AllGoalsAchieved extends StatelessWidget {
  final int count;
  const _AllGoalsAchieved({required this.count});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: AppConstants.cardPadding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        gradient: LinearGradient(
          colors: [
            AppColors.success.withValues(alpha: isDark ? 0.15 : 0.08),
            AppColors.primary.withValues(alpha: isDark ? 0.10 : 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withValues(alpha: 0.15),
            ),
            child: Icon(
              LucideIcons.trophy,
              color: AppColors.success,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All goals achieved!',
                  style: AppTheme.displayStyle(
                    size: 16,
                    weight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You\'ve hit $count goal${count == 1 ? '' : 's'}. Keep it up!',
                  style: AppTheme.bodyStyle(
                    size: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(target: AccessibilityUtils.shouldAnimate(context) ? null : 1.0).fadeIn(duration: AppConstants.animSlow).slideY(begin: -0.05, duration: AppConstants.animNormal, curve: Curves.easeOutCubic);
  }
}

class _AddGoalSheet extends ConsumerStatefulWidget {
  const _AddGoalSheet();

  @override
  ConsumerState<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<_AddGoalSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  late DateTime _targetDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _targetDate = DateTime.now().add(const Duration(days: 365));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'New Savings Goal',
            style: AppTheme.displayStyle(
              size: 20, weight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Goal Name'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Target Amount',
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _targetDate,
                firstDate: DateTime.now(),
                lastDate: DateTime(2035),
              );
              if (date != null) setState(() => _targetDate = date);
            },
            icon: const Icon(LucideIcons.calendarDays, size: 16),
            label: Text('Target: ${Formatters.formatDate(_targetDate)}'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSaving ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Create Goal',
                    style: AppTheme.bodyStyle(
                      size: 15, weight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _submit() async {
    if (_isSaving) return;
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text);
    if (name.isEmpty || amount == null || amount <= 0) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(goalNotifierProvider.notifier).addGoal(
        name: name,
        targetAmount: amount,
        targetDate: _targetDate,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _GoalsSkeleton extends StatelessWidget {
  const _GoalsSkeleton();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: AppConstants.screenPadding,
      children: List.generate(3, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppConstants.cardRadiusSmall),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 140, height: 16,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 100, height: 12,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity, height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppConstants.cardRadiusSmall),
                ),
              ),
            ],
          ),
        ).animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, delay: (i * 200).ms, color: colorScheme.primary.withValues(alpha: 0.08)),
      )),
    );
  }
}
