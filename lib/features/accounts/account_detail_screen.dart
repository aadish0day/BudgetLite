import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:drift/drift.dart' show Value;
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/icon_helper.dart';
import '../../core/database/database.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/database_provider.dart';

/// Account detail screen showing balance history, linked transactions,
/// and transfer activity for a single account.
class AccountDetailScreen extends ConsumerWidget {
  final Account account;

  const AccountDetailScreen({super.key, required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final transactionsAsync = ref.watch(transactionsByAccountIdProvider(account.id));
    final balanceHistoryAsync = ref.watch(accountBalanceHistoryProvider(account.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          account.name,
          style: AppTheme.displayStyle(
            size: 17,
            weight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.pencil, size: 18),
            onPressed: () => _showEditDialog(context, ref, account),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(transactionsByAccountIdProvider(account.id));
          ref.invalidate(accountBalanceHistoryProvider(account.id));
          ref.invalidate(accountsListProvider);
        },
        child: ListView(
          padding: AppConstants.screenPadding,
          children: [
            // ── Balance Header ──
            _BalanceHeader(account: account),
            const SizedBox(height: 24),

            // ── Balance History Chart ──
            Text(
              'Balance History',
              style: AppTheme.displayStyle(
                size: 16,
                weight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
              ),
              padding: AppConstants.cardPadding,
              child: balanceHistoryAsync.when(
                data: (history) => history.length < 2
                    ? _ChartEmptyState()
                    : _BalanceChart(points: history, isDark: isDark),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _ChartEmptyState(),
              ),
            ).animate().fadeIn(duration: 500.ms),
            const SizedBox(height: 24),

            // ── Transaction History ──
            Text(
              'Transactions',
              style: AppTheme.displayStyle(
                size: 16,
                weight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            transactionsAsync.when(
              data: (txns) => txns.isEmpty
                  ? _EmptyTransactionState()
                  : _TransactionList(
                      transactions: txns,
                      accountId: account.id,
                    ),
              loading: () => const _TransactionSkeleton(),
              error: (_, _) => _EmptyTransactionState(),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Account account) {
    final nameCtrl = TextEditingController(text: account.name);
    final balanceCtrl = TextEditingController(text: account.balance.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Account Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balanceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Balance', prefixText: '₹ '),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final db = ref.read(databaseProvider);
              await (db.update(db.accounts)..where((a) => a.id.equals(account.id)))
                  .write(AccountsCompanion(
                name: Value(name),
                balance: Value(double.tryParse(balanceCtrl.text) ?? account.balance),
              ));
              ref.invalidate(accountsListProvider);
              ref.invalidate(accountBalanceHistoryProvider(account.id));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// ── Balance Header Card ──
class _BalanceHeader extends StatelessWidget {
  final Account account;
  const _BalanceHeader({required this.account});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final isPositive = account.balance >= 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.primary.withValues(alpha: 0.15), Colors.transparent]
              : [AppColors.primary.withValues(alpha: 0.06), Colors.transparent],
        ),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      padding: AppConstants.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isPositive
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.error.withValues(alpha: 0.12),
                ),
                child: Icon(
                  account.id == 'default' ? LucideIcons.wallet : LucideIcons.creditCard,
                  size: 22,
                  color: isPositive ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: AppTheme.displayStyle(
                      size: 18,
                      weight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    account.currency,
                    style: AppTheme.bodyStyle(
                      size: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Balance
          Text(
            'Current Balance',
            style: AppTheme.bodyStyle(
              size: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Formatters.formatCurrency(account.balance, currency: account.currency),
            style: AppTheme.financialStyle(
              size: 36,
              weight: FontWeight.w700,
              color: isPositive ? colorScheme.onSurface : AppColors.error,
              letterSpacing: -1.0,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

/// ── Balance History Line Chart ──
class _BalanceChart extends StatelessWidget {
  final List<({DateTime date, double balance})> points;
  final bool isDark;

  const _BalanceChart({
    required this.points,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (points.isEmpty) return _ChartEmptyState();

    final balances = points.map((p) => p.balance).toList();
    final minBal = balances.reduce(min);
    final maxBal = balances.reduce(max);
    final range = maxBal - minBal;
    // Add 15% padding
    final yMin = minBal - range * 0.15;
    final yMax = maxBal + range * 0.15;
    final effectiveRange = yMax - yMin;

    // Use index-based X axis and show date labels for a subset
    final step = max(1, (points.length / 6).ceil());

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          horizontalInterval: effectiveRange / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outline.withValues(alpha: 0.08),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    '₹${value.toStringAsFixed(0)}',
                    style: AppTheme.financialStyle(
                      size: 9,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: step.toDouble(),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    Formatters.formatDateShort(points[idx].date),
                    style: AppTheme.bodyStyle(
                      size: 9,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: yMin,
        maxY: yMax,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(points.length, (i) {
              return FlSpot(i.toDouble(), points[i].balance);
            }),
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.primary.withValues(alpha: 0.9),
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: points.length < 15,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: AppColors.primary,
                  strokeWidth: 1.5,
                  strokeColor: colorScheme.surface,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.primary.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.spotIndex;
                final p = points[idx];
                return LineTooltipItem(
                  '${Formatters.formatDate(p.date)}\n${Formatters.formatCurrency(p.balance)}',
                  TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

/// ── Transaction List ──
class _TransactionList extends StatelessWidget {
  final List<Transaction> transactions;
  final String accountId;

  const _TransactionList({
    required this.transactions,
    required this.accountId,
  });

  @override
  Widget build(BuildContext context) {
    // Group transactions by month
    final grouped = <String, List<Transaction>>{};
    for (final t in transactions) {
      final key = Formatters.formatMonth(t.date);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(t);
    }

    return Column(
      children: grouped.entries.map((entry) {
        return _MonthGroup(
          monthLabel: entry.key,
          transactions: entry.value,
          accountId: accountId,
        );
      }).toList(),
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms);
  }
}

/// ── Month Group ──
class _MonthGroup extends StatelessWidget {
  final String monthLabel;
  final List<Transaction> transactions;
  final String accountId;

  const _MonthGroup({
    required this.monthLabel,
    required this.transactions,
    required this.accountId,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate net change for this month
    final netChange = transactions.fold<double>(0, (sum, t) => sum - t.amount);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                monthLabel,
                style: AppTheme.displayStyle(
                  size: 14,
                  weight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '${netChange >= 0 ? '+' : ''}${Formatters.formatCurrency(netChange)}',
                style: AppTheme.financialStyle(
                  size: 13,
                  weight: FontWeight.w600,
                  color: netChange >= 0 ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...transactions.map((t) => _AccountTransactionRow(
            transaction: t,
            isTransfer: t.categoryId == 'transfer',
            accountId: accountId,
          )),
        ],
      ),
    );
  }
}

/// ── Account Transaction Row ──
class _AccountTransactionRow extends ConsumerWidget {
  final Transaction transaction;
  final bool isTransfer;
  final String accountId;

  const _AccountTransactionRow({
    required this.transaction,
    required this.isTransfer,
    required this.accountId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final category = categories.where((c) => c.id == transaction.categoryId).firstOrNull;
    final catColor = Color(category?.color ?? 0xFF6B7280);

    final isIncoming = transaction.amount < 0; // income-like (negative amount = credit)

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isTransfer
                  ? AppColors.tertiary.withValues(alpha: 0.1)
                  : catColor.withValues(alpha: 0.1),
            ),
            child: Icon(
              isTransfer ? LucideIcons.arrowLeftRight : getCategoryIcon(category?.icon ?? ''),
              size: 16,
              color: isTransfer ? AppColors.tertiary : catColor,
            ),
          ),
          const SizedBox(width: 10),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isTransfer
                          ? (isIncoming ? 'Transfer In' : 'Transfer Out')
                          : (category?.name ?? 'Unknown'),
                      style: AppTheme.bodyStyle(
                        size: 13,
                        weight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (isTransfer)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: AppColors.tertiary.withValues(alpha: 0.1),
                        ),
                        child: Text(
                          'Transfer',
                          style: AppTheme.bodyStyle(
                            size: 8,
                            weight: FontWeight.w600,
                            color: AppColors.tertiary,
                          ),
                        ),
                      ),
                  ],
                ),
                if (transaction.note != null && transaction.note!.isNotEmpty)
                  Text(
                    transaction.note!,
                    style: AppTheme.bodyStyle(
                      size: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  Formatters.formatDateShort(transaction.date),
                  style: AppTheme.bodyStyle(
                    size: 10,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // Amount
          Text(
            isIncoming
                ? '+${Formatters.formatCurrency(transaction.amount.abs())}'
                : '-${Formatters.formatCurrency(transaction.amount)}',
            style: AppTheme.financialStyle(
              size: 13,
              weight: FontWeight.w700,
              color: isIncoming ? AppColors.success : AppColors.error,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// ── Empty State ──
class _EmptyTransactionState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      width: double.infinity,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.06),
            ),
            child: Icon(
              LucideIcons.receiptText,
              size: 28,
              color: colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No transactions yet',
            style: AppTheme.displayStyle(
              size: 16,
              weight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Transactions for this account will appear here',
            style: AppTheme.bodyStyle(
              size: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// ── Chart Empty State ──
class _ChartEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.chartLine,
            size: 32,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            'Not enough data',
            style: AppTheme.bodyStyle(
              size: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// ── Transaction Skeleton ──
class _TransactionSkeleton extends StatelessWidget {
  const _TransactionSkeleton();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shimmerColor = colorScheme.primary.withValues(alpha: 0.04);

    return Column(
      children: List.generate(4, (i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: colorScheme.surfaceContainerHighest,
              ),
            ).animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 1200.ms, delay: (i * 100).ms, color: shimmerColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100 + (i * 20).toDouble(),
                    height: 13,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ).animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 1200.ms, delay: (150 + i * 100).ms, color: shimmerColor),
                  const SizedBox(height: 6),
                  Container(
                    width: 50, height: 10,
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
              width: 56, height: 15,
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
