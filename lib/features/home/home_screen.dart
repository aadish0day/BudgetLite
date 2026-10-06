import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/accessibility_utils.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/icon_helper.dart';
import '../../core/utils/notification_service.dart';
import '../../core/widgets/arc_progress.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_skeleton.dart';
import '../../core/widgets/stat_item.dart';
import '../../core/widgets/transaction_row.dart';
import '../../providers/budget_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../settings/settings_screen.dart';
import '../subscriptions/subscriptions_screen.dart';
import 'reimbursement_tracker_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalSpent = ref.watch(totalSpentThisMonthProvider);
    final monthlyIncome = ref.watch(monthlyIncomeProvider);
    final budgets = ref.watch(thisMonthBudgetsProvider);
    final transactions = ref.watch(recentTransactionsProvider);
    final initialBalance = ref.watch(initialBalanceProvider).valueOrNull ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'Pocket Money Dashboard',
              style: AppTheme.displayStyle(
                size: 17,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              'This Month • ${Formatters.formatMonth(DateTime.now())}',
              style: AppTheme.bodyStyle(
                size: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final hidden =
                  ref.watch(balanceHiddenProvider).valueOrNull ?? false;
              return IconButton(
                icon: Icon(
                  hidden ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 20,
                  color: hidden
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                tooltip: hidden ? 'Show Balances' : 'Hide Balances',
                onPressed: () {
                  ref
                      .read(settingsNotifierProvider.notifier)
                      .setBalanceHidden(!hidden);
                },
              );
            },
          ),
          IconButton(
            icon: Icon(
              LucideIcons.settings,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.refresh(thisMonthTransactionsProvider.future),
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: AppConstants.screenPadding,
          children: [
            // ── Student Pocket Money Hero Balance ──
            _Balance(
              spent: totalSpent.valueOrNull ?? 0,
              remaining:
                  initialBalance +
                  (monthlyIncome.valueOrNull ?? 0) -
                  (totalSpent.valueOrNull ?? 0),
              monthlyIncome: monthlyIncome.valueOrNull ?? 0,
              initialBalance: initialBalance,
              onEditBalance: () =>
                  _showEditBalanceDialog(context, ref, initialBalance),
            ),
            const SizedBox(height: 28),

            // ── Pending Reimbursements Banner ──
            const _ReimbursementBanner(),

            // ── Budget Overview Section (Conditional) ──
            Consumer(
              builder: (context, ref, _) {
                final isBudgetEnabled =
                    ref.watch(budgetModuleEnabledProvider).valueOrNull ?? true;
                if (!isBudgetEnabled) return const SizedBox.shrink();
                return Column(
                  children: [
                    budgets.when(
                      data: (budgetList) => budgetList.isEmpty
                          ? _QuickBudgetSetup()
                          : _BudgetOverview(budgets: budgetList),
                      loading: () => const _BudgetSkeleton(),
                      error: (_, _) => _QuickBudgetSetup(),
                    ),
                    const SizedBox(height: 28),
                  ],
                );
              },
            ),

            // ── Upcoming Payments / Subscriptions ──
            const _UpcomingPayments(),
            const SizedBox(height: 28),

            // ── Recent transactions header ──
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Expenses',
                    style: AppTheme.displayStyle(
                      size: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(currentTabProvider.notifier).state = 1,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                    child: Text(
                      'View All',
                      style: AppTheme.bodyStyle(
                        size: 13,
                        weight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            transactions.when(
              data: (txns) => txns.isEmpty
                  ? const EmptyState()
                  : Column(
                      children: txns
                          .map((t) => TransactionRow(transaction: t))
                          .toList(),
                    ),
              loading: () => const TransactionSkeleton(),
              error: (_, _) => const EmptyState(),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  void _showEditBalanceDialog(
    BuildContext context,
    WidgetRef ref,
    double currentBalance,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _EditBalanceDialog(
        currentBalance: currentBalance,
        onSave: (value) {
          final db = ref.read(databaseProvider);
          updateInitialBalance(db, value);
        },
      ),
    );
  }
}

class _EditBalanceDialog extends StatefulWidget {
  const _EditBalanceDialog({
    required this.currentBalance,
    required this.onSave,
  });

  final double currentBalance;
  final ValueChanged<double> onSave;

  @override
  State<_EditBalanceDialog> createState() => _EditBalanceDialogState();
}

class _EditBalanceDialogState extends State<_EditBalanceDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentBalance > 0
          ? widget.currentBalance.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              LucideIcons.wallet,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Set Initial Balance',
              style: AppTheme.displayStyle(size: 16),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter the amount you currently have. This is your starting balance before any income or expenses this month.',
            style: AppTheme.bodyStyle(
              size: 12,
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: AppTheme.financialStyle(
              size: 24,
              weight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: AppTheme.financialStyle(
                size: 24,
                weight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
              hintText: '0',
              hintStyle: AppTheme.financialStyle(
                size: 24,
                weight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: AppTheme.bodyStyle(
              weight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            final value = double.tryParse(text);
            if (text.isEmpty || value == null || value < 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Enter a valid amount'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }
            widget.onSave(value);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Balance hero — Student Edition Pocket Money & Daily Safe Spend framing.
class _Balance extends ConsumerWidget {
  const _Balance({
    required this.spent,
    required this.remaining,
    required this.monthlyIncome,
    this.initialBalance = 0,
    this.onEditBalance,
  });
  final double spent;
  final double remaining;
  final double monthlyIncome;
  final double initialBalance;
  final VoidCallback? onEditBalance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final isBalanceHidden =
        ref.watch(balanceHiddenProvider).valueOrNull ?? false;
    final spentRatio = monthlyIncome > 0
        ? (spent / monthlyIncome).clamp(0, 1).toDouble()
        : 0.0;

    return Container(
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
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Staggered label — enters first
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Pocket Money Balance',
                        style: AppTheme.bodyStyle(
                          size: 12,
                          weight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (onEditBalance != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: onEditBalance,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.primary.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                              child: Icon(
                                LucideIcons.pencil,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  GestureDetector(
                    onTap: onEditBalance,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: initialBalance > 0
                            ? AppColors.success.withValues(alpha: 0.12)
                            : colorScheme.primary.withValues(alpha: 0.12),
                      ),
                      child: Text(
                        initialBalance > 0
                            ? 'Starting: ${Formatters.formatCurrency(initialBalance, hide: isBalanceHidden)}'
                            : 'Set Balance',
                        style: AppTheme.bodyStyle(
                          size: 10,
                          weight: FontWeight.w600,
                          color: initialBalance > 0
                              ? AppColors.success
                              : colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Large balance figure
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: remaining),
                    duration: 800.ms,
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedValue, child) {
                      return Text(
                        Formatters.formatCurrency(
                          animatedValue,
                          hide: isBalanceHidden,
                        ),
                        style: AppTheme.financialStyle(
                          size: 38,
                          weight: FontWeight.w700,
                          color: colorScheme.onSurface,
                          letterSpacing: -1,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: remaining >= 0
                            ? AppColors.success.withValues(alpha: 0.12)
                            : AppColors.error.withValues(alpha: 0.12),
                      ),
                      child: Text(
                        remaining >= 0 ? 'On Track' : 'Over Limit',
                        style: AppTheme.bodyStyle(
                          size: 11,
                          weight: FontWeight.w600,
                          color: remaining >= 0
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Income / Spent / Arc — enters third
              Row(
                children: [
                  // Arc progress on the left
                  ArcProgress(
                        progress: spentRatio,
                        color: spentRatio > 0.9
                            ? AppColors.error
                            : spentRatio > 0.7
                            ? AppColors.warning
                            : colorScheme.primary,
                        size: 52,
                        strokeWidth: 5,
                        center: Center(
                          child: Text(
                            '${(spentRatio * 100).toStringAsFixed(0)}%',
                            style: AppTheme.financialStyle(
                              size: 14,
                              weight: FontWeight.w700,
                              color: spentRatio > 0.9
                                  ? AppColors.error
                                  : spentRatio > 0.7
                                  ? AppColors.warning
                                  : colorScheme.primary,
                            ),
                          ),
                        ),
                      )
                      .animate(
                        target: AccessibilityUtils.shouldAnimate(context)
                            ? null
                            : 1.0,
                      )
                      .scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1, 1),
                        duration: AppConstants.animSlow,
                        delay: 450.ms,
                        curve: Curves.easeOutBack,
                      ),
                  const SizedBox(width: 20),

                  Expanded(
                    child: Row(
                      children: [
                        StatItem(
                          label: 'Pocket Money',
                          value: Formatters.formatCurrency(
                            monthlyIncome,
                            hide: isBalanceHidden,
                          ),
                          color: colorScheme.onSurface,
                          valueColor: AppColors.success,
                          delayMs: 500,
                        ),
                        const SizedBox(width: 24),
                        StatItem(
                          label: 'Spent',
                          value: Formatters.formatCurrency(
                            spent,
                            hide: isBalanceHidden,
                          ),
                          color: colorScheme.onSurface,
                          valueColor: colorScheme.onSurface,
                          delayMs: 600,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
        .animate(target: AccessibilityUtils.shouldAnimate(context) ? null : 1.0)
        .fadeIn(duration: AppConstants.animSlow)
        .slideY(begin: 0.08, end: 0);
  }
}

/// Loading skeleton for the budget section — mirrors _BudgetOverview shape.
class _BudgetSkeleton extends StatelessWidget {
  const _BudgetSkeleton();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
              width: 160,
              height: 18,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            )
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(
              duration: 1200.ms,
              color: colorScheme.primary.withValues(alpha: 0.08),
            ),
        const SizedBox(height: 14),
        ...List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child:
                Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    )
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(
                      duration: 1200.ms,
                      delay: (i * 200).ms,
                      color: colorScheme.primary.withValues(alpha: 0.08),
                    ),
          ),
        ),
      ],
    );
  }
}

/// Quick budget setup CTA — shown when no budgets exist.
class _QuickBudgetSetup extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
        boxShadow: isDark
            ? AppColors.cardShadowDark
            : AppColors.cardShadowLight,
      ),
      padding: AppConstants.cardPadding,
      child: Column(
        children: [
          Icon(
            LucideIcons.wallet,
            size: 44,
            color: colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No budget set for this month',
            style: AppTheme.displayStyle(
              size: 16,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Set your monthly budget to track spending',
            style: AppTheme.bodyStyle(
              size: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              final tab = budgetTabIndex(ref);
              if (tab != null) {
                ref.read(currentTabProvider.notifier).state = tab;
              }
            },
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Set Up Budget'),
          ),
        ],
      ),
    );
  }
}

/// Budget overview with arc progress indicators.
class _BudgetOverview extends ConsumerWidget {
  const _BudgetOverview({required this.budgets});
  final List<Budget> budgets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final transactions =
        ref.watch(thisMonthTransactionsProvider).valueOrNull ?? [];
    final isDark = colorScheme.brightness == Brightness.dark;
    final isBalanceHidden =
        ref.watch(balanceHiddenProvider).valueOrNull ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Budget Overview',
              style: AppTheme.displayStyle(
                size: 16,
                color: colorScheme.onSurface,
              ),
            ),
            GestureDetector(
              onTap: () {
                final tab = budgetTabIndex(ref);
                if (tab != null) {
                  ref.read(currentTabProvider.notifier).state = tab;
                }
              },
              child: Text(
                'Details',
                style: AppTheme.bodyStyle(
                  size: 12,
                  weight: FontWeight.w500,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...budgets.take(4).map((budget) {
          final category = categories
              .where((c) => c.id == budget.categoryId)
              .firstOrNull;
          final spent = transactions
              .where((t) => t.amount > 0 && t.categoryId == budget.categoryId)
              .fold<double>(0, (sum, t) => sum + t.amount);
          final ratio = budget.allocatedAmount > 0
              ? (spent / budget.allocatedAmount).clamp(0, 1).toDouble()
              : 0.0;
          final catColor = Color(category?.color ?? 0xFF6B7280);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.08),
                ),
                boxShadow: isDark
                    ? AppColors.cardShadowDark
                    : AppColors.cardShadowLight,
              ),
              padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
              child: Row(
                children: [
                  // Arc progress — small signature ring
                  ArcProgress(
                    progress: ratio,
                    color: catColor,
                    size: 36,
                    strokeWidth: 3.5,
                    center: Padding(
                      padding: const EdgeInsets.all(2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${(ratio * 100).toStringAsFixed(0)}%',
                          style: AppTheme.financialStyle(
                            size: 11,
                            weight: FontWeight.w700,
                            color: catColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category?.name ?? 'Unknown',
                          style: AppTheme.bodyStyle(
                            weight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'of ${Formatters.formatCurrency(budget.allocatedAmount, hide: isBalanceHidden)}',
                          style: AppTheme.bodyStyle(
                            size: 11,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.formatCurrency(spent, hide: isBalanceHidden),
                        style: AppTheme.financialStyle(
                          size: 14,
                          weight: FontWeight.w700,
                          color: spent > budget.allocatedAmount
                              ? AppColors.error
                              : colorScheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        budget.allocatedAmount > 0
                            ? '${(ratio * 100).toStringAsFixed(0)}%'
                            : '-',
                        style: AppTheme.bodyStyle(
                          size: 10,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// ── Upcoming recurring payments section ──
class _UpcomingPayments extends ConsumerWidget {
  const _UpcomingPayments();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final recurringList =
        ref.watch(recurringTransactionsProvider).valueOrNull ?? [];
    final isBalanceHidden =
        ref.watch(balanceHiddenProvider).valueOrNull ?? false;

    // Filter payments due within 30 days
    final upcoming = recurringList
        .where((r) => r.daysUntil <= 30)
        .map(
          (r) => _UpcomingPayment(
            transaction: r.transaction,
            category: r.category,
            nextDate: r.nextDate,
            daysUntil: r.daysUntil,
          ),
        )
        .toList();

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.bell,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Upcoming Payments',
                      style: AppTheme.displayStyle(
                        size: 16,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SubscriptionAuditScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'View All',
                    style: AppTheme.bodyStyle(
                      size: 12,
                      weight: FontWeight.w500,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                boxShadow: isDark
                    ? AppColors.cardShadowDark
                    : AppColors.cardShadowLight,
              ),
              padding: AppConstants.cardPadding,
              child: Column(
                children: upcoming.take(5).map((payment) {
                  final catColor = Color(payment.category?.color ?? 0xFF6B7280);
                  final isOverdue = payment.daysUntil < 0;
                  final isSoon = payment.daysUntil <= 3 && !isOverdue;

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: upcoming.indexOf(payment) < upcoming.length - 1
                          ? 14
                          : 0,
                    ),
                    child: Row(
                      children: [
                        // Category icon with urgency indicator
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppConstants.cardRadiusIcon,
                            ),
                            color: isOverdue
                                ? AppColors.error.withValues(alpha: 0.12)
                                : isSoon
                                ? AppColors.warning.withValues(alpha: 0.12)
                                : catColor.withValues(alpha: 0.12),
                          ),
                          child: Icon(
                            getCategoryIcon(payment.category?.icon ?? ''),
                            size: 18,
                            color: isOverdue
                                ? AppColors.error
                                : isSoon
                                ? AppColors.warning
                                : catColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                payment.category?.name ?? 'Unknown',
                                style: AppTheme.bodyStyle(
                                  weight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              if (payment.transaction.note != null &&
                                  payment.transaction.note!.isNotEmpty)
                                Text(
                                  payment.transaction.note!,
                                  style: AppTheme.bodyStyle(
                                    size: 11,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Mark as Paid button with accessibility tooltip and 48x48 hit target
                                IconButton(
                                  onPressed: () =>
                                      _markAsPaid(context, ref, payment),
                                  tooltip:
                                      'Mark ${payment.category?.name ?? "payment"} as paid',
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                    backgroundColor: AppColors.success
                                        .withValues(alpha: 0.1),
                                  ),
                                  icon: const Icon(
                                    LucideIcons.check,
                                    size: 18,
                                    color: AppColors.success,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  Formatters.formatCurrency(
                                    payment.transaction.amount.abs(),
                                    hide: isBalanceHidden,
                                  ),
                                  style: AppTheme.financialStyle(
                                    size: 14,
                                    weight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: isOverdue
                                    ? AppColors.error.withValues(alpha: 0.12)
                                    : isSoon
                                    ? AppColors.warning.withValues(alpha: 0.12)
                                    : colorScheme.surfaceContainerHighest,
                              ),
                              child: Text(
                                isOverdue
                                    ? 'Overdue'
                                    : payment.daysUntil == 0
                                    ? 'Today'
                                    : payment.daysUntil == 1
                                    ? 'Tomorrow'
                                    : '${payment.daysUntil}d',
                                style: AppTheme.bodyStyle(
                                  size: 10,
                                  weight: FontWeight.w600,
                                  color: isOverdue
                                      ? AppColors.error
                                      : isSoon
                                      ? AppColors.warning
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        )
        .animate(target: AccessibilityUtils.shouldAnimate(context) ? null : 1.0)
        .fadeIn(duration: AppConstants.animSlow);
  }
}

class _UpcomingPayment {
  const _UpcomingPayment({
    required this.transaction,
    this.category,
    required this.nextDate,
    required this.daysUntil,
  });
  final Transaction transaction;
  final Category? category;
  final DateTime nextDate;
  final int daysUntil;
}

/// Mark a recurring payment as paid — creates a transaction and advances the schedule
void _markAsPaid(
  BuildContext context,
  WidgetRef ref,
  _UpcomingPayment payment,
) {
  HapticFeedback.mediumImpact();
  final notifier = ref.read(transactionNotifierProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);

  final originalTransaction = payment.transaction;
  final wasIncome = originalTransaction.amount < 0;

  final nextDue = NotificationService.calculateNextDueDate(
    lastDate: originalTransaction.date,
    interval: originalTransaction.recurringInterval,
  );

  unawaited(
    notifier
        .addTransaction(
          amount: originalTransaction.amount.abs(),
          categoryId: originalTransaction.categoryId,
          note: originalTransaction.note ?? payment.category?.name ?? 'Payment',
          date: DateTime.now(),
          paymentMethod: originalTransaction.paymentMethod,
          isIncome: wasIncome,
        )
        .then((_) {
          if (nextDue == null) return;
          final updated = Transaction(
            id: originalTransaction.id,
            amount: originalTransaction.amount,
            categoryId: originalTransaction.categoryId,
            accountId: 'default',
            note: originalTransaction.note,
            date: nextDue,
            paymentMethod: originalTransaction.paymentMethod,
            isRecurring: originalTransaction.isRecurring,
            isRecurringInstance: originalTransaction.isRecurringInstance,
            recurringInterval: originalTransaction.recurringInterval,
            recurringEndDate: originalTransaction.recurringEndDate,
            receiptImagePath: originalTransaction.receiptImagePath,
            createdAt: originalTransaction.createdAt,
          );
          notifier.updateTransaction(updated);
        }),
  );

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        '${payment.category?.name ?? "Payment"} paid, next cycle scheduled ✓',
      ),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );
}

class _ReimbursementBanner extends ConsumerWidget {
  const _ReimbursementBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingReimbursementsProvider);
    final totalPendingAsync = ref.watch(totalPendingReimbursementProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return pendingAsync.when(
      data: (txns) {
        if (txns.isEmpty) return const SizedBox.shrink();
        final total = totalPendingAsync.valueOrNull ?? 0.0;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => const ReimbursementTrackerSheet(),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 28),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.cardRadius),
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
              ),
              boxShadow: isDark
                  ? AppColors.cardShadowDark
                  : AppColors.cardShadowLight,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: colorScheme.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    LucideIcons.handCoins,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Owed to You',
                            style: AppTheme.bodyStyle(
                              size: 13,
                              weight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: colorScheme.primary.withValues(
                                alpha: 0.15,
                              ),
                            ),
                            child: Text(
                              '${txns.length} item${txns.length == 1 ? "" : "s"}',
                              style: AppTheme.bodyStyle(
                                size: 10,
                                weight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Click to view & settle reimbursements',
                        style: AppTheme.bodyStyle(
                          size: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  Formatters.formatCurrency(total),
                  style: AppTheme.financialStyle(
                    size: 15,
                    weight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
