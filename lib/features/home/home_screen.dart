import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/icon_helper.dart';
import '../../core/utils/notification_service.dart';
import '../../core/widgets/arc_progress.dart';
import '../../core/widgets/animated_number.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../core/database/database.dart';
import '../../providers/database_provider.dart';
import '../subscriptions/subscriptions_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalSpent = ref.watch(totalSpentThisMonthProvider);
    final monthlyIncome = ref.watch(monthlyIncomeProvider);
    final budgets = ref.watch(thisMonthBudgetsProvider);
    final transactions = ref.watch(thisMonthTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'Dashboard',
              style: AppTheme.displayStyle(
                size: 17,
                weight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              Formatters.formatMonth(DateTime.now()),
              style: AppTheme.bodyStyle(
                size: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(thisMonthTransactionsProvider.future),
        child: ListView(
          padding: AppConstants.screenPadding,
          children: [
            // ── Open-air balance (signature staggered entrance) ──
            _Balance(
              spent: totalSpent.valueOrNull ?? 0,
              remaining: (monthlyIncome.valueOrNull ?? 0) - (totalSpent.valueOrNull ?? 0),
              monthlyIncome: monthlyIncome.valueOrNull ?? 0,
            ),
            const SizedBox(height: 28),

            // ── Budget section ──
            budgets.when(
              data: (budgetList) => budgetList.isEmpty
                  ? _QuickBudgetSetup()
                  : _BudgetOverview(budgets: budgetList),
              loading: () => const _BudgetSkeleton(),
              error: (_, _) => _QuickBudgetSetup(),
            ),

            const SizedBox(height: 28),

            // ── Upcoming Payments ──
            const _UpcomingPayments(),
            const SizedBox(height: 28),

            // ── Recent transactions header ──
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Transactions',
                    style: AppTheme.displayStyle(
                      size: 16,
                      weight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ref.read(currentTabProvider.notifier).state = 1,
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
            ),

            transactions.when(
              data: (txns) => txns.take(5).isEmpty
                  ? _EmptyState()
                  : Column(
                      children: txns.take(5).map((t) => _TransactionRow(transaction: t)).toList(),
                    ),
              loading: () => const _TransactionSkeleton(),
              error: (_, _) => _EmptyState(),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

/// Balance hero — signature staggered entrance.
/// Label fades in first, then the big number slides up, then income/spent row.
class _Balance extends StatelessWidget {
  final double spent;
  final double remaining;
  final double monthlyIncome;

  const _Balance({
    required this.spent,
    required this.remaining,
    required this.monthlyIncome,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final spentRatio = monthlyIncome > 0 ? (spent / monthlyIncome).clamp(0, 1).toDouble() : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Staggered label — enters first
        Text(
          'Total Balance',
          style: AppTheme.bodyStyle(
            size: 12,
            weight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08, curve: Curves.easeOutCubic),

        const SizedBox(height: 4),

        // Large balance figure — enters second (slight delay)
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AnimatedNumber(
              value: remaining,
              duration: 800.ms,
              curve: Curves.easeOutCubic,
              builder: (context, animatedValue, child) {
                return Text(
                  Formatters.formatCurrency(animatedValue, currency: 'INR'),
                  style: AppTheme.financialStyle(
                    size: 40,
                    weight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    letterSpacing: -1.0,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                remaining >= 0 ? 'On track' : 'Over budget',
                style: AppTheme.bodyStyle(
                  size: 11,
                  color: remaining >= 0
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms, delay: 150.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic),

        const SizedBox(height: 10),

        // Hairline separator
        Container(
          height: 1,
          color: colorScheme.outline.withValues(alpha: 0.15),
        ).animate().fadeIn(duration: 300.ms, delay: 300.ms),

        const SizedBox(height: 14),

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
              showTrack: true,
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
            ).animate().scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1, 1),
              duration: 400.ms,
              delay: 450.ms,
              curve: Curves.easeOutBack,
            ),
            const SizedBox(width: 20),

            // Income & Spent columns — staggered from the right
            Expanded(
              child: Row(
                children: [
                  _StatItem(
                    label: 'Income',
                    value: Formatters.formatCurrency(monthlyIncome, currency: 'INR'),
                    color: colorScheme.onSurface,
                    valueColor: AppColors.success,
                  ).animate().fadeIn(duration: 350.ms, delay: 500.ms).slideX(begin: 0.04, curve: Curves.easeOutCubic),
                  const SizedBox(width: 24),
                  _StatItem(
                    label: 'Spent',
                    value: Formatters.formatCurrency(spent, currency: 'INR'),
                    color: colorScheme.onSurface,
                    valueColor: colorScheme.onSurface,
                  ).animate().fadeIn(duration: 350.ms, delay: 600.ms).slideX(begin: 0.04, curve: Curves.easeOutCubic),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color valueColor;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.bodyStyle(
              size: 11,
              weight: FontWeight.w500,
              color: color.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTheme.financialStyle(
              size: 16,
              weight: FontWeight.w700,
              color: valueColor,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
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
          width: 160, height: 18,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
        ).animate(onPlay: (controller) => controller.repeat())
          .shimmer(duration: 1200.ms, color: colorScheme.primary.withValues(alpha: 0.08)),
        const SizedBox(height: 14),
        ...List.generate(3, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
          ).animate(onPlay: (controller) => controller.repeat())
            .shimmer(duration: 1200.ms, delay: (i * 200).ms, color: colorScheme.primary.withValues(alpha: 0.08)),
        )),
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
        boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
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
              weight: FontWeight.w600,
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
            onPressed: () => ref.read(currentTabProvider.notifier).state = 2,
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Set Up Budget'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }
}

/// Budget overview with arc progress indicators.
class _BudgetOverview extends ConsumerWidget {
  final List<Budget> budgets;

  const _BudgetOverview({required this.budgets});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final transactions = ref.watch(thisMonthTransactionsProvider).valueOrNull ?? [];
    final isDark = colorScheme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget Overview',
                style: AppTheme.displayStyle(
                  size: 16,
                  weight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              GestureDetector(
                onTap: () => ref.read(currentTabProvider.notifier).state = 2,
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
          final category = categories.where((c) => c.id == budget.categoryId).firstOrNull;
          final spent = transactions
              .where((t) => t.categoryId == budget.categoryId)
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
                boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
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
                    showTrack: true,
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
                            size: 14,
                            weight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'of ${Formatters.formatCurrency(budget.allocatedAmount)}',
                          style: AppTheme.bodyStyle(
                            size: 11,
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
                        Formatters.formatCurrency(spent),
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
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
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
    final allTransactions = ref.watch(transactionsProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    // Find recurring transactions and calculate next due date
    final upcoming = <_UpcomingPayment>[];
    final now = DateTime.now();
    for (final t in allTransactions.where((t) => t.isRecurring)) {
      final nextDate = NotificationService.calculateNextDueDate(
        lastDate: t.date,
        interval: t.recurringInterval,
      );
      if (nextDate != null) {
        final daysUntil = nextDate.difference(now).inDays;
        if (daysUntil <= 30) {
          final category = categories.where((c) => c.id == t.categoryId).firstOrNull;
          upcoming.add(_UpcomingPayment(
            transaction: t,
            category: category,
            nextDate: nextDate,
            daysUntil: daysUntil,
          ));
        }
      }
    }

    // Sort by days until due (closest first)
    upcoming.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(LucideIcons.bell, size: 16, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Upcoming Payments',
                  style: AppTheme.displayStyle(
                    size: 16,
                    weight: FontWeight.w600,
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
            boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
          ),
          padding: AppConstants.cardPadding,
          child: Column(
            children: upcoming.take(5).map((payment) {
              final catColor = Color(payment.category?.color ?? 0xFF6B7280);
              final isOverdue = payment.daysUntil < 0;
              final isSoon = payment.daysUntil <= 3 && !isOverdue;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: upcoming.indexOf(payment) < upcoming.length - 1 ? 14 : 0,
                ),
                child: Row(
                  children: [
                    // Category icon with urgency indicator
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppConstants.cardRadiusIcon),
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
                              size: 14,
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
                            // Mark as Paid button with scale-on-press
                            GestureDetector(
                              onTap: () => _markAsPaid(context, ref, payment),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.success.withValues(alpha: 0.1),
                                ),
                                child: Icon(
                                  LucideIcons.check,
                                  size: 16,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              Formatters.formatCurrency(payment.transaction.amount.abs()),
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    ).animate().fadeIn(duration: 500.ms);
  }
}

class _UpcomingPayment {
  final Transaction transaction;
  final Category? category;
  final DateTime nextDate;
  final int daysUntil;

  const _UpcomingPayment({
    required this.transaction,
    this.category,
    required this.nextDate,
    required this.daysUntil,
  });
}

/// Mark a recurring payment as paid — creates a transaction and advances the schedule
void _markAsPaid(BuildContext context, WidgetRef ref, _UpcomingPayment payment) {
  HapticFeedback.mediumImpact();
  final notifier = ref.read(transactionNotifierProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);

  // Save original transaction data for undo
  final originalTransaction = payment.transaction;

  // Fire async operations (fire-and-forget is acceptable here)
  unawaited(
    notifier.addTransaction(
      amount: payment.transaction.amount.abs(),
      categoryId: payment.transaction.categoryId,
      note: payment.transaction.note ?? payment.category?.name ?? 'Payment',
      date: DateTime.now(),
      paymentMethod: payment.transaction.paymentMethod,
      isRecurring: false,
    ).then((_) {
      // 2. Advance the recurring transaction's date
      final updated = Transaction(
        id: originalTransaction.id,
        amount: originalTransaction.amount,
        categoryId: originalTransaction.categoryId,
        accountId: originalTransaction.accountId,
        note: originalTransaction.note,
        date: DateTime.now(),
        paymentMethod: originalTransaction.paymentMethod,
        isRecurring: originalTransaction.isRecurring,
        recurringInterval: originalTransaction.recurringInterval,
        receiptImagePath: originalTransaction.receiptImagePath,
        createdAt: originalTransaction.createdAt,
      );
      notifier.updateTransaction(updated);
    }),
  );

  messenger.showSnackBar(
    SnackBar(
      content: Text('${payment.category?.name ?? "Payment"} paid, next cycle scheduled ✓'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );
}

/// Transaction row with hairline ledger styling.
class _TransactionRow extends ConsumerWidget {
  final Transaction transaction;

  const _TransactionRow({required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final category = categories.where((c) => c.id == transaction.categoryId).firstOrNull;
    final catColor = Color(category?.color ?? 0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Category icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: catColor.withValues(alpha: 0.1),
            ),
            child: Icon(
              getCategoryIcon(category?.icon ?? ''),
              size: 18,
              color: catColor,
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
                    size: 14,
                    weight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (transaction.note != null && transaction.note!.isNotEmpty)
                  Text(
                    transaction.note!,
                    style: AppTheme.bodyStyle(
                      size: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            transaction.amount < 0
                ? '+${Formatters.formatCurrency(transaction.amount.abs())}'
                : '-${Formatters.formatCurrency(transaction.amount)}',
            style: AppTheme.financialStyle(
              size: 14,
              weight: FontWeight.w600,
              color: transaction.amount < 0 ? AppColors.success : AppColors.error,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading skeleton for transactions — mirrors _TransactionRow shape.
class _TransactionSkeleton extends StatelessWidget {
  const _TransactionSkeleton();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shimmerColor = colorScheme.primary.withValues(alpha: 0.04);
    return Column(
      children: List.generate(4, (i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: colorScheme.surfaceContainerHighest,
              ),
            ).animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 1200.ms, delay: (i * 100).ms, color: shimmerColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100 + (i * 30).toDouble(),
                    height: 14,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ).animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 1200.ms, delay: (150 + i * 100).ms, color: shimmerColor),
                  const SizedBox(height: 6),
                  Container(
                    width: 60, height: 11,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ).animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 1200.ms, delay: (300 + i * 100).ms, color: shimmerColor),
                ],
              ),
            ),
            Container(
              width: 60, height: 16,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ).animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 1200.ms, delay: (100 + i * 100).ms, color: shimmerColor),
          ],
        ),
      )),
    );
  }
}

/// Empty state — more inviting illustration and clearer CTA.
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          // Decorative illustration container
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.08),
            ),
            child: Icon(
              LucideIcons.receiptText,
              size: 36,
              color: colorScheme.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: AppTheme.displayStyle(
              size: 16,
              weight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Tap the + button below to add your first expense or income',
              textAlign: TextAlign.center,
              style: AppTheme.bodyStyle(
                size: 13,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }
}
