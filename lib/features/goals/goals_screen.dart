import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/arc_progress.dart';
import '../../providers/goal_provider.dart';
import '../../core/database/database.dart';

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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGoalSheet(context, ref),
        child: const Icon(LucideIcons.plus),
      ),
      body: goals.when(
        data: (goalList) {
          if (goalList.isEmpty) return _EmptyGoals();
          return ListView(
            padding: AppConstants.screenPadding,
            children: [
              Text(
                '${goalList.length} goals',
                style: AppTheme.bodyStyle(
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ...goalList.map((goal) => _GoalCard(goal: goal, ref: ref)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
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
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final WidgetRef ref;

  const _GoalCard({required this.goal, required this.ref});

  void _showContributeSheet(BuildContext context) {
    final amountCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
                'Contribute to ${goal.name}',
                style: AppTheme.displayStyle(
                  size: 20, weight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Current: ${Formatters.formatCurrency(goal.currentAmount)} / ${Formatters.formatCurrency(goal.targetAmount)}',
                style: AppTheme.bodyStyle(
                  size: 14, color: colorScheme.onSurfaceVariant,
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
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        final amount = double.tryParse(amountCtrl.text);
                        if (amount != null && amount > 0) {
                          ref.read(goalNotifierProvider.notifier)
                              .updateGoalProgress(goal.id, amount);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('₹${amount.toStringAsFixed(0)} added to ${goal.name}'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Add Funds'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final progress = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount).clamp(0, 1).toDouble()
        : 0.0;
    final remaining = goal.targetAmount - goal.currentAmount;
    final daysLeft = goal.targetDate.difference(DateTime.now()).inDays;
    final goalColor = Color(goal.color);
    final neededPerDay = daysLeft > 0 ? (remaining / daysLeft).roundToDouble() : 0;
    final monthlyPace = neededPerDay * 30;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
      ),
      padding: AppConstants.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      goalColor.withValues(alpha: 0.3),
                      goalColor.withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    _getIcon(goal.icon),
                    color: goalColor,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
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
                      daysLeft > 0 ? '$daysLeft days left' : 'Overdue',
                      style: AppTheme.bodyStyle(
                        size: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ArcProgress(
                progress: progress,
                color: goalColor,
                size: 56,
                strokeWidth: 5,
                center: Center(
                  child: Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: AppTheme.financialStyle(
                      size: 14,
                      weight: FontWeight.w700,
                      color: goalColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saved',
                    style: AppTheme.bodyStyle(
                      size: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    Formatters.formatCurrency(goal.currentAmount),
                    style: AppTheme.financialStyle(
                      size: 16,
                      weight: FontWeight.w700,
                      color: goalColor,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Remaining',
                    style: AppTheme.bodyStyle(
                      size: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    Formatters.formatCurrency(remaining),
                    style: AppTheme.displayStyle(
                      size: 16,
                      weight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // ── Pace indicator ──
          if (daysLeft > 0 && remaining > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(LucideIcons.gauge, size: 14, color: goalColor.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    daysLeft < 30
                        ? 'Need ₹${neededPerDay.toStringAsFixed(0)}/day to reach goal'
                        : '₹${monthlyPace.toStringAsFixed(0)}/month recommended',
                    style: AppTheme.bodyStyle(
                      size: 11,
                      color: goalColor.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          // ── Contribute button ──
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => _showContributeSheet(context),
              icon: const Icon(LucideIcons.wallet, size: 16),
              label: Text(
                goal.currentAmount >= goal.targetAmount
                    ? 'Goal Completed! 🎉'
                    : 'Contribute',
                style: AppTheme.bodyStyle(size: 13, weight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: goalColor.withValues(alpha: 0.12),
                foregroundColor: goalColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, curve: Curves.easeOutCubic).slideY(begin: 0.06, duration: 400.ms, curve: Curves.easeOutCubic);
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
