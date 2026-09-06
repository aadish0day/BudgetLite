import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';
import '../database/database.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../utils/formatters.dart';
import '../utils/icon_helper.dart';

class TransactionRow extends ConsumerWidget {
  const TransactionRow({
    super.key,
    required this.transaction,
    this.showAutoBadge = true,
  });
  final Transaction transaction;
  final bool showAutoBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final category = categories
        .where((c) => c.id == transaction.categoryId)
        .firstOrNull;
    final catColor = Color(category?.color ?? 0xFF6B7280);
    final isBalanceHidden =
        ref.watch(balanceHiddenProvider).valueOrNull ?? false;

    return RepaintBoundary(
      child: Container(
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
                  if (transaction.payee != null &&
                      transaction.payee!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${transaction.amount < 0 ? "Sender" : "Paid to"}: ${transaction.payee}',
                        style: AppTheme.bodyStyle(
                          size: 11,
                          weight: FontWeight.w500,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.85,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (showAutoBadge && transaction.isRecurringInstance)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.sparkles,
                            size: 10,
                            color: AppColors.tertiary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Auto',
                            style: AppTheme.bodyStyle(
                              size: 9,
                              color: AppColors.tertiary.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  transaction.amount < 0
                      ? '+${Formatters.formatCurrency(transaction.amount.abs(), hide: isBalanceHidden)}'
                      : '-${Formatters.formatCurrency(transaction.amount, hide: isBalanceHidden)}',
                  style: AppTheme.financialStyle(
                    size: 14,
                    color: transaction.amount < 0
                        ? AppColors.success
                        : AppColors.error,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.formatDateShort(transaction.date),
                  style: AppTheme.bodyStyle(
                    size: 11,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
