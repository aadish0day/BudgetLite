import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/icon_helper.dart';
import '../../core/utils/notification_service.dart';
import 'package:drift/drift.dart' show Value;
import '../../core/database/database.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/database_provider.dart';

class ReimbursementTrackerSheet extends ConsumerWidget {
  const ReimbursementTrackerSheet({super.key});

  String _extractPerson(Transaction t) {
    final note = t.note ?? '';
    final payee = t.payee ?? '';
    final match = RegExp(r'\[Owed by:\s*([^\]]+)\]', caseSensitive: false).firstMatch('$note $payee');
    if (match != null) {
      return match.group(1)?.trim() ?? 'Someone';
    }
    return 'Parents';
  }

  Future<void> _settleTransaction(BuildContext context, WidgetRef ref, Transaction t) async {
    HapticFeedback.mediumImpact();
    final person = _extractPerson(t);
    final notifier = ref.read(transactionNotifierProvider.notifier);
    
    // Add incoming reimbursement transaction
    await notifier.addTransaction(
      amount: t.amount.abs(),
      categoryId: 'income',
      note: 'Reimbursement received from $person',
      date: DateTime.now(),
      paymentMethod: t.paymentMethod,
      isIncome: true,
    );

    // Update original transaction note to remove pending tag
    final db = ref.read(databaseProvider);
    final cleanNote = (t.note ?? '')
        .replaceAll(RegExp(r'\[Owed by:\s*[^\]]+\]', caseSensitive: false), '')
        .trim();
    await (db.update(db.transactions)..where((tbl) => tbl.id.equals(t.id))).write(
      TransactionsCompanion(note: Value(cleanNote.isEmpty ? null : cleanNote)),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked ₹${t.amount.abs().toStringAsFixed(0)} settled from $person!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _scheduleReminder(BuildContext context, Transaction t) async {
    HapticFeedback.lightImpact();
    final person = _extractPerson(t);
    final reminderTime = DateTime.now().add(const Duration(days: 1));

    await NotificationService.instance.scheduleReimbursementReminder(
      id: t.id.hashCode,
      person: person,
      amount: t.amount.abs(),
      scheduledDate: reminderTime,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder set to ask $person tomorrow at ${reminderTime.hour}:${reminderTime.minute.toString().padLeft(2, '0')}!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final pendingAsync = ref.watch(pendingReimbursementsProvider);
    final totalPendingAsync = ref.watch(totalPendingReimbursementProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: colorScheme.primary.withValues(alpha: 0.12),
                ),
                child: Icon(LucideIcons.handCoins, size: 20, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reimbursements Owed to You',
                      style: AppTheme.displayStyle(size: 16, weight: FontWeight.w600),
                    ),
                    Text(
                      'Track & collect money paid on behalf of others',
                      style: AppTheme.bodyStyle(size: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total Pending Card Banner
          totalPendingAsync.when(
            data: (total) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                color: colorScheme.primary.withValues(alpha: 0.1),
                border: Border.all(color: colorScheme.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL PENDING',
                        style: AppTheme.bodyStyle(size: 10, weight: FontWeight.w700, color: colorScheme.primary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.formatCurrency(total),
                        style: AppTheme.financialStyle(size: 22, weight: FontWeight.w700, color: colorScheme.onSurface),
                      ),
                    ],
                  ),
                  Icon(LucideIcons.arrowDownLeft, size: 28, color: AppColors.success),
                ],
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // List of pending items
          pendingAsync.when(
            data: (txns) {
              if (txns.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(LucideIcons.checkCircle2, size: 40, color: AppColors.success.withValues(alpha: 0.7)),
                        const SizedBox(height: 8),
                        Text(
                          'All reimbursements settled!',
                          style: AppTheme.bodyStyle(size: 14, weight: FontWeight.w600),
                        ),
                        Text(
                          'No pending money owed to you.',
                          style: AppTheme.bodyStyle(size: 12, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: txns.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final t = txns[index];
                    final person = _extractPerson(t);
                    final cat = categories.where((c) => c.id == t.categoryId).firstOrNull;
                    final catColor = Color(cat?.color ?? 0xFF6B7280);

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isDark ? AppColors.cardDark : AppColors.cardLight,
                        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: catColor.withValues(alpha: 0.12),
                            ),
                            child: Icon(
                              getCategoryIcon(cat?.icon ?? ''),
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
                                  'Owed by $person',
                                  style: AppTheme.bodyStyle(size: 13, weight: FontWeight.w600),
                                ),
                                Text(
                                  '${cat?.name ?? "Expense"} • ${Formatters.formatDateShort(t.date)}',
                                  style: AppTheme.bodyStyle(size: 11, color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                Formatters.formatCurrency(t.amount.abs()),
                                style: AppTheme.financialStyle(size: 14, weight: FontWeight.w700, color: colorScheme.onSurface),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(LucideIcons.bell, size: 16, color: colorScheme.primary),
                                    tooltip: 'Remind Me',
                                    onPressed: () => _scheduleReminder(context, t),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      backgroundColor: AppColors.success,
                                    ),
                                    onPressed: () => _settleTransaction(context, ref, t),
                                    child: const Text('Settle', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
