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
import '../../providers/transaction_provider.dart';
import 'dart:async';
import '../../core/database/database.dart';
import '../transactions/add_transaction_sheet.dart';

/// Dedicated screen for auditing all recurring payments and subscriptions.
class SubscriptionAuditScreen extends ConsumerStatefulWidget {
  const SubscriptionAuditScreen({super.key});

  @override
  ConsumerState<SubscriptionAuditScreen> createState() => _SubscriptionAuditScreenState();
}

class _SubscriptionAuditScreenState extends ConsumerState<SubscriptionAuditScreen> {
  String? _filterInterval;
  String? _filterCategoryId;
  String _sortBy = 'date'; // 'date', 'amount', 'name'

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final recurring = ref.watch(recurringTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Audit'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(LucideIcons.arrowUpDown, size: 18, color: colorScheme.onSurfaceVariant),
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'date', child: Text('Sort by due date',
                  style: AppTheme.bodyStyle(size: 13, weight: _sortBy == 'date' ? FontWeight.w600 : FontWeight.w400))),
              PopupMenuItem(value: 'amount', child: Text('Sort by amount',
                  style: AppTheme.bodyStyle(size: 13, weight: _sortBy == 'amount' ? FontWeight.w600 : FontWeight.w400))),
              PopupMenuItem(value: 'name', child: Text('Sort by name',
                  style: AppTheme.bodyStyle(size: 13, weight: _sortBy == 'name' ? FontWeight.w600 : FontWeight.w400))),
            ],
          ),
        ],
      ),
      body: recurring.when(
        data: (payments) => _buildContent(context, colorScheme, payments),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.alertCircle, size: 48, color: AppColors.error.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              const Text('Could not load subscriptions'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme colorScheme, List<RecurringPaymentInfo> payments) {
    // Apply filters
    var filtered = payments.where((p) {
      if (_filterInterval != null && p.transaction.recurringInterval != _filterInterval) return false;
      if (_filterCategoryId != null && p.transaction.categoryId != _filterCategoryId) return false;
      return true;
    }).toList();

    // Sort
    switch (_sortBy) {
      case 'amount':
        filtered.sort((a, b) => b.transaction.amount.abs().compareTo(a.transaction.amount.abs()));
        break;
      case 'name':
        filtered.sort((a, b) => (a.category?.name ?? '').compareTo(b.category?.name ?? ''));
        break;
      default:
        filtered.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
    }

    // Compute stats
    final totalMonthly = filtered.fold<double>(0, (s, p) => s + p.monthlyCost);
    final totalAnnual = filtered.fold<double>(0, (s, p) => s + p.annualCost);
    final overdueCount = filtered.where((p) => p.isOverdue).length;
    final dueSoonCount = filtered.where((p) => p.isDueSoon || p.isDueToday).length;
    final unusedCount = filtered.where((p) => p.isPossiblyUnused).length;
    final upcoming = filtered.where((p) => p.daysUntil > 3).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: 0.08),
              ),
              child: Icon(LucideIcons.rotateCw, size: 36,
                  color: colorScheme.primary.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 16),
            Text('No subscriptions found', style: AppTheme.displayStyle(
              size: 18, weight: FontWeight.w600, color: colorScheme.onSurface)),
            const SizedBox(height: 6),
            Text('Create a recurring transaction to see it here',
                style: AppTheme.bodyStyle(size: 13, color: colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ListView(
      padding: AppConstants.screenPadding,
      children: [
        // ── Stats header ──
        _StatsHeader(
          totalMonthly: totalMonthly,
          totalAnnual: totalAnnual,
          activeCount: filtered.length,
          overdueCount: overdueCount,
          dueSoonCount: dueSoonCount,
          unusedCount: unusedCount,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 20),

        // ── Filter chips ──
        _FilterRow(
          selectedInterval: _filterInterval,
          selectedCategoryId: _filterCategoryId,
          onIntervalChanged: (v) => setState(() => _filterInterval = v),
          onCategoryChanged: (v) => setState(() => _filterCategoryId = v),
          onClear: () => setState(() { _filterInterval = null; _filterCategoryId = null; }),
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 16),

        // ── Section: Overdue ──
        if (overdueCount > 0) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: AppColors.error.withValues(alpha: 0.12),
                  ),
                  child: Text('Overdue', style: AppTheme.bodyStyle(
                    size: 11, weight: FontWeight.w600, color: AppColors.error)),
                ),
                const SizedBox(width: 8),
                Text('$overdueCount payment${overdueCount != 1 ? "s" : ""}',
                    style: AppTheme.bodyStyle(size: 11, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          ...filtered.where((p) => p.isOverdue).map((p) => _SubscriptionCard(
            payment: p, colorScheme: colorScheme,
            onMarkPaid: () => markRecurringAsPaid(context, ref, p),
            onEdit: () => _editTransaction(p.transaction),
            onDelete: () => _deleteSubscription(p),
          )),
          const SizedBox(height: 12),
        ],

        // ── Section: Due Soon (including today) ──
        if (dueSoonCount > 0) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: AppColors.warning.withValues(alpha: 0.12),
                  ),
                  child: Text('Due Soon', style: AppTheme.bodyStyle(
                    size: 11, weight: FontWeight.w600, color: AppColors.warning)),
                ),
                const SizedBox(width: 8),
                Text('$dueSoonCount payment${dueSoonCount != 1 ? "s" : ""}',
                    style: AppTheme.bodyStyle(size: 11, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          ...filtered.where((p) => p.isDueSoon || p.isDueToday).map((p) => _SubscriptionCard(
            payment: p, colorScheme: colorScheme,
            onMarkPaid: () => markRecurringAsPaid(context, ref, p),
            onEdit: () => _editTransaction(p.transaction),
            onDelete: () => _deleteSubscription(p),
          )),
          const SizedBox(height: 12),
        ],

        // ── Section: Upcoming ──
        if (upcoming.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(LucideIcons.calendarDays, size: 16, color: colorScheme.primary.withValues(alpha: 0.6)),
                const SizedBox(width: 6),
                Text('Upcoming (${upcoming.length})',
                    style: AppTheme.bodyStyle(size: 13, weight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          ...upcoming.map((p) => _SubscriptionCard(
            payment: p, colorScheme: colorScheme,
            onMarkPaid: () => markRecurringAsPaid(context, ref, p),
            onEdit: () => _editTransaction(p.transaction),
            onDelete: () => _deleteSubscription(p),
          )),
        ],

        const SizedBox(height: 80),
      ],
    );
  }

  void _editTransaction(Transaction t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddTransactionSheet(transaction: t),
    );
  }

  Future<void> _deleteSubscription(RecurringPaymentInfo p) async {
    final localColorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(LucideIcons.trash2, size: 20, color: AppColors.error),
            const SizedBox(width: 8),
            Text('Remove subscription?', style: AppTheme.displayStyle(size: 18, weight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'Remove "${p.category?.name ?? 'Subscription'}" (₹${p.transaction.amount.abs().toStringAsFixed(0)}/${p.intervalLabel.toLowerCase()})?\n'
          'This will delete the recurring template.',
          style: AppTheme.bodyStyle(size: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTheme.bodyStyle(color: localColorScheme.onSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error.withValues(alpha: 0.15),
              foregroundColor: AppColors.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final notifier = ref.read(transactionNotifierProvider.notifier);
      await notifier.deleteTransaction(p.transaction.id);
      ref.invalidate(recurringTransactionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${p.category?.name ?? "Subscription"} removed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

/// ── Stats header: summary cards ──
class _StatsHeader extends StatelessWidget {
  final double totalMonthly;
  final double totalAnnual;
  final int activeCount;
  final int overdueCount;
  final int dueSoonCount;
  final int unusedCount;
  final ColorScheme colorScheme;

  const _StatsHeader({
    required this.totalMonthly,
    required this.totalAnnual,
    required this.activeCount,
    required this.overdueCount,
    required this.dueSoonCount,
    required this.unusedCount,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
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
          // Annual total — hero number
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Annual cost', style: AppTheme.bodyStyle(
                size: 11, weight: FontWeight.w500, color: colorScheme.onSurfaceVariant)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: totalAnnual > 0 ? AppColors.warning.withValues(alpha: 0.12) : Colors.transparent,
                ),
                child: Text(
                  Formatters.formatCurrency(totalAnnual),
                  style: AppTheme.financialStyle(
                    size: 28, weight: FontWeight.w700, color: colorScheme.onSurface, letterSpacing: -0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${Formatters.formatCurrency(totalMonthly)} / month',
            style: AppTheme.bodyStyle(size: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),

          // Stats row
          Row(
            children: [
              _StatBadge(
                icon: LucideIcons.rotateCw, label: 'Active', value: '$activeCount',
                color: colorScheme.primary, colorScheme: colorScheme,
              ),
              const SizedBox(width: 12),
              if (overdueCount > 0)
                _StatBadge(
                  icon: LucideIcons.alertTriangle, label: 'Overdue', value: '$overdueCount',
                  color: AppColors.error, colorScheme: colorScheme,
                ),
              if (overdueCount > 0) const SizedBox(width: 12),
              if (dueSoonCount > 0)
                _StatBadge(
                  icon: LucideIcons.bell, label: 'Due soon', value: '$dueSoonCount',
                  color: AppColors.warning, colorScheme: colorScheme,
                ),
              if (dueSoonCount > 0 && unusedCount > 0) const SizedBox(width: 12),
              if (unusedCount > 0)
                _StatBadge(
                  icon: LucideIcons.rotateCw, label: 'Unused', value: '$unusedCount',
                  color: AppColors.warning, colorScheme: colorScheme,
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05);
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ColorScheme colorScheme;

  const _StatBadge({
    required this.icon, required this.label, required this.value,
    required this.color, required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withValues(alpha: 0.08),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(value, style: AppTheme.displayStyle(size: 18, weight: FontWeight.w700, color: colorScheme.onSurface)),
            Text(label, style: AppTheme.bodyStyle(size: 9, color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// ── Filter row ──
class _FilterRow extends StatelessWidget {
  final String? selectedInterval;
  final String? selectedCategoryId;
  final ValueChanged<String?> onIntervalChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback? onClear;
  final ColorScheme colorScheme;

  const _FilterRow({
    required this.selectedInterval,
    required this.selectedCategoryId,
    required this.onIntervalChanged,
    required this.onCategoryChanged,
    this.onClear,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (selectedInterval != null || selectedCategoryId != null)
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.error.withValues(alpha: 0.1),
                ),
                child: Icon(LucideIcons.rotateCcw, size: 14, color: AppColors.error),
              ),
            ),
          _buildChip('All', selectedInterval == null && selectedCategoryId == null, () {
            onIntervalChanged(null);
            onCategoryChanged(null);
          }),
          const SizedBox(width: 6),
          _buildChip('Monthly', selectedInterval == 'monthly', () => onIntervalChanged('monthly')),
          const SizedBox(width: 6),
          _buildChip('Yearly', selectedInterval == 'yearly', () => onIntervalChanged('yearly')),
          const SizedBox(width: 6),
          _buildChip('Weekly', selectedInterval == 'weekly', () => onIntervalChanged('weekly')),
        ],
      ),
    );
  }

  Widget _buildChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.15)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: selected
              ? Border.all(color: colorScheme.primary.withValues(alpha: 0.3))
              : null,
        ),
        child: Text(label, style: AppTheme.bodyStyle(
          size: 12, weight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant)),
      ),
    );
  }
}

/// ── Individual subscription card ──
class _SubscriptionCard extends StatelessWidget {
  final RecurringPaymentInfo payment;
  final ColorScheme colorScheme;
  final VoidCallback onMarkPaid;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SubscriptionCard({
    required this.payment,
    required this.colorScheme,
    required this.onMarkPaid,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = Color(payment.category?.color ?? 0xFF6B7280);
    final isDark = colorScheme.brightness == Brightness.dark;
    final isOverdue = payment.isOverdue;
    final isDueSoon = payment.isDueSoon || payment.isDueToday;
    final isUnused = payment.isPossiblyUnused;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.cardRadiusSmall),
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
            border: isOverdue
                ? Border.all(color: AppColors.error.withValues(alpha: 0.3))
                : isDueSoon
                    ? Border.all(color: AppColors.warning.withValues(alpha: 0.25))
                    : null,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: icon, name, amount
              Row(
                children: [
                  // Category icon with urgency ring
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppConstants.cardRadiusIcon),
                      color: isOverdue
                          ? AppColors.error.withValues(alpha: 0.12)
                          : isDueSoon
                              ? AppColors.warning.withValues(alpha: 0.12)
                              : catColor.withValues(alpha: 0.12),
                    ),
                    child: Icon(getCategoryIcon(payment.category?.icon ?? ''),
                        size: 20,
                        color: isOverdue ? AppColors.error : isDueSoon ? AppColors.warning : catColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(payment.category?.name ?? 'Subscription',
                            style: AppTheme.bodyStyle(
                              size: 14, weight: FontWeight.w600, color: colorScheme.onSurface)),
                        if (payment.transaction.note != null && payment.transaction.note!.isNotEmpty)
                          Text(payment.transaction.note!, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: AppTheme.bodyStyle(size: 11, color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Formatters.formatCurrency(payment.transaction.amount.abs()),
                          style: AppTheme.financialStyle(
                            size: 15, weight: FontWeight.w700, color: colorScheme.onSurface, letterSpacing: -0.3)),
                      Text(payment.intervalLabel,
                          style: AppTheme.bodyStyle(size: 10, color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Bottom row: next due date, actions
              Row(
                children: [
                  // Due date badge
                  _DueDateBadge(
                    daysUntil: payment.daysUntil,
                    isOverdue: isOverdue,
                    isDueSoon: isDueSoon,
                    nextDate: payment.nextDate,
                    colorScheme: colorScheme,
                  ),
                  const Spacer(),

                  if (isUnused)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: AppColors.warning.withValues(alpha: 0.12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.rotateCw, size: 10, color: AppColors.warning),
                        const SizedBox(width: 3),
                        Text('Possibly unused',
                            style: AppTheme.bodyStyle(
                              size: 8, weight: FontWeight.w600, color: AppColors.warning)),
                      ],
                    ),
                  ),
                  if (isUnused) const SizedBox(width: 6),
                  // Monthly cost indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                    child: Text('${Formatters.formatCurrency(payment.monthlyCost)}/mo',
                        style: AppTheme.bodyStyle(
                          size: 9, weight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                  ),
                  const SizedBox(width: 8),

                  // Mark as paid button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onMarkPaid();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success.withValues(alpha: 0.1),
                      ),
                      child: Icon(LucideIcons.check, size: 16, color: AppColors.success),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Delete button
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.error.withValues(alpha: 0.1),
                      ),
                      child: Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueDateBadge extends StatelessWidget {
  final int daysUntil;
  final bool isOverdue;
  final bool isDueSoon;
  final DateTime nextDate;
  final ColorScheme colorScheme;

  const _DueDateBadge({
    required this.daysUntil, required this.isOverdue, required this.isDueSoon,
    required this.nextDate, required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isOverdue
            ? AppColors.error.withValues(alpha: 0.12)
            : isDueSoon
                ? AppColors.warning.withValues(alpha: 0.12)
                : colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOverdue ? LucideIcons.alertTriangle : LucideIcons.clock,
            size: 12,
            color: isOverdue ? AppColors.error : isDueSoon ? AppColors.warning : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            isOverdue
                ? 'Overdue ${daysUntil.abs()}d'
                : isDueSoon && daysUntil == 0
                    ? 'Today'
                    : isDueSoon && daysUntil == 1
                        ? 'Tomorrow'
                        : '${daysUntil}d',
            style: AppTheme.bodyStyle(
              size: 11, weight: FontWeight.w600,
              color: isOverdue ? AppColors.error : isDueSoon ? AppColors.warning : colorScheme.onSurfaceVariant,
            ),
          ),
          if (!isOverdue && daysUntil > 3) ...[
            const SizedBox(width: 4),
            Text(Formatters.formatDateShort(nextDate),
                style: AppTheme.bodyStyle(size: 9, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
          ],
        ],
      ),
    );
  }
}

// ── Free-standing mark-as-paid function (reusable outside home_screen) ──
void markRecurringAsPaid(BuildContext context, WidgetRef ref, RecurringPaymentInfo payment) {
  HapticFeedback.mediumImpact();
  final notifier = ref.read(transactionNotifierProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  final original = payment.transaction;

  unawaited(
    notifier.addTransaction(
      amount: original.amount.abs(),
      categoryId: original.categoryId,
      note: original.note ?? payment.category?.name ?? 'Payment',
      date: DateTime.now(),
      paymentMethod: original.paymentMethod,
      isRecurring: false,
    ).then((_) {
      final updated = Transaction(
        id: original.id,
        amount: original.amount,
        categoryId: original.categoryId,
        accountId: 'default',
        note: original.note,
        date: DateTime.now(),
        paymentMethod: original.paymentMethod,
        isRecurring: original.isRecurring,
        isRecurringInstance: original.isRecurringInstance,
        recurringInterval: original.recurringInterval,
        recurringEndDate: original.recurringEndDate,
        receiptImagePath: original.receiptImagePath,
        createdAt: original.createdAt,
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
