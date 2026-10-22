import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/services/sms_listener_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/duplicate_detector.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/sms_parser.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';

/// Screen for reviewing pending SMS-detected transactions.
class SmsReviewQueueScreen extends ConsumerStatefulWidget {
  const SmsReviewQueueScreen({super.key});

  @override
  ConsumerState<SmsReviewQueueScreen> createState() =>
      _SmsReviewQueueScreenState();
}

class _SmsReviewQueueScreenState extends ConsumerState<SmsReviewQueueScreen> {
  int? _filterMonths;
  bool _isScanning = false;

  DateTime _calculateCutoff(int months) {
    final now = DateTime.now();
    var y = now.year;
    var m = now.month - months;
    while (m <= 0) {
      m += 12;
      y -= 1;
    }
    return DateTime(y, m, now.day.clamp(1, 28));
  }

  List<ParsedSmsTxn> _getFilteredQueue(List<ParsedSmsTxn> queue) {
    if (_filterMonths == null) return queue;
    final cutoff = _calculateCutoff(_filterMonths!);
    return queue
        .where(
          (t) =>
              t.date.isAfter(cutoff) || t.date.isAtSameMomentAs(cutoff),
        )
        .toList();
  }

  int _countForMonths(List<ParsedSmsTxn> queue, int months) {
    final cutoff = _calculateCutoff(months);
    return queue
        .where(
          (t) =>
              t.date.isAfter(cutoff) || t.date.isAtSameMomentAs(cutoff),
        )
        .length;
  }

  Widget _buildFilterChip(
    String label,
    int count,
    bool isSelected,
    VoidCallback onTap,
    ColorScheme colorScheme,
  ) {
    return FilterChip(
      selected: isSelected,
      label: Text(
        '$label ($count)',
        style: AppTheme.bodyStyle(
          size: 12,
          weight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
      backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.primary,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      onSelected: (_) => onTap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final queue = ref.watch(smsReviewQueueProvider);
    final filteredQueue = _getFilteredQueue(queue);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Review Queue'),
        actions: [
          IconButton(
            icon: _isScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.scanLine, size: 20),
            tooltip: 'Scan SMS Inbox',
            onPressed: _isScanning ? null : _showScanPeriodSheet,
          ),
          if (queue.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(
                LucideIcons.ellipsisVertical,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              onSelected: (v) {
                if (v == 'confirm_filtered') _confirmFiltered(filteredQueue);
                if (v == 'discard_filtered') _discardFiltered(filteredQueue);
                if (v == 'confirm_all') _confirmAll();
                if (v == 'discard_all') _discardAll();
              },
              itemBuilder: (_) => [
                if (_filterMonths != null) ...[
                  PopupMenuItem(
                    value: 'confirm_filtered',
                    child: Text('Confirm visible (${filteredQueue.length})'),
                  ),
                  PopupMenuItem(
                    value: 'discard_filtered',
                    child: Text('Discard visible (${filteredQueue.length})'),
                  ),
                  const PopupMenuDivider(),
                ],
                PopupMenuItem(
                  value: 'confirm_all',
                  child: Text('Confirm all (${queue.length})'),
                ),
                PopupMenuItem(
                  value: 'discard_all',
                  child: Text('Discard all (${queue.length})'),
                ),
              ],
            ),
        ],
      ),
      body: queue.isEmpty
          ? _EmptyQueue(
              colorScheme: colorScheme,
              onScanInbox: _showScanPeriodSheet,
            )
          : ListView(
              padding: AppConstants.screenPadding,
              children: [
                // Queue stats header
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      AppConstants.cardRadiusSmall,
                    ),
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.messageSquare,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _filterMonths != null
                                  ? '${filteredQueue.length} of ${queue.length} pending'
                                  : '${queue.length} pending transaction${queue.length != 1 ? 's' : ''}',
                              style: AppTheme.displayStyle(
                                size: 16,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              _filterMonths != null
                                  ? 'Filtered to last ${_filterMonths == 12 ? '1 year' : '$_filterMonths months'}'
                                  : 'Review and confirm each to add to your ledger',
                              style: AppTheme.bodyStyle(
                                size: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 200.ms),

                const SizedBox(height: 12),

                // Timeframe filter chips
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip(
                        'All',
                        queue.length,
                        _filterMonths == null,
                        () => setState(() => _filterMonths = null),
                        colorScheme,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        '1M',
                        _countForMonths(queue, 1),
                        _filterMonths == 1,
                        () => setState(() => _filterMonths = 1),
                        colorScheme,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        '2M',
                        _countForMonths(queue, 2),
                        _filterMonths == 2,
                        () => setState(() => _filterMonths = 2),
                        colorScheme,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        '3M',
                        _countForMonths(queue, 3),
                        _filterMonths == 3,
                        () => setState(() => _filterMonths = 3),
                        colorScheme,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        '6M',
                        _countForMonths(queue, 6),
                        _filterMonths == 6,
                        () => setState(() => _filterMonths = 6),
                        colorScheme,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        '9M',
                        _countForMonths(queue, 9),
                        _filterMonths == 9,
                        () => setState(() => _filterMonths = 9),
                        colorScheme,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        '1Y',
                        _countForMonths(queue, 12),
                        _filterMonths == 12,
                        () => setState(() => _filterMonths = 12),
                        colorScheme,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Bulk actions
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: filteredQueue.isEmpty
                            ? null
                            : () => _filterMonths != null
                                ? _confirmFiltered(filteredQueue)
                                : _confirmAll(),
                        icon: const Icon(LucideIcons.checkCheck, size: 16),
                        label: Text(
                          _filterMonths != null
                              ? 'Confirm visible (${filteredQueue.length})'
                              : 'Confirm all (${queue.length})',
                          style: AppTheme.bodyStyle(
                            size: 13,
                            weight: FontWeight.w600,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          backgroundColor: AppColors.success.withValues(
                            alpha: 0.15,
                          ),
                          foregroundColor: AppColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: filteredQueue.isEmpty
                            ? null
                            : () => _filterMonths != null
                                ? _discardFiltered(filteredQueue)
                                : _discardAll(),
                        icon: const Icon(LucideIcons.x, size: 16),
                        label: Text(
                          _filterMonths != null
                              ? 'Discard visible'
                              : 'Discard all',
                          style: AppTheme.bodyStyle(
                            size: 13,
                            weight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          foregroundColor: AppColors.error,
                          side: BorderSide(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 200.ms, delay: 100.ms),

                const SizedBox(height: 16),

                // Divider
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        'Swipe left to discard, tap to review',
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

                // Queue items or empty filtered state
                if (filteredQueue.isEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          LucideIcons.calendarX,
                          size: 32,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No pending transactions in this period',
                          style: AppTheme.bodyStyle(
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select another timeframe filter or scan older messages.',
                          textAlign: TextAlign.center,
                          style: AppTheme.bodyStyle(
                            size: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => setState(() => _filterMonths = null),
                          icon: const Icon(LucideIcons.layers, size: 14),
                          label: Text('Show all (${queue.length})'),
                        ),
                      ],
                    ),
                  )
                else
                  ...filteredQueue.map(
                    (txn) => _QueueItemCard(
                      txn: txn,
                      colorScheme: colorScheme,
                      onConfirm: () => _confirmItem(txn.id),
                      onConfirmWithCategory: (catId, note, applyRuleToAll, tagToApply) => _confirmItem(
                        txn.id,
                        overrideCategory: catId,
                        overrideNote: note,
                        applyRuleToAll: applyRuleToAll,
                        tagToApply: tagToApply,
                      ),
                      onDiscard: () => _discardItem(txn.id),
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  Future<void> _confirmItem(
    String id, {
    String? overrideCategory,
    String? overrideNote,
    bool applyRuleToAll = false,
    String? tagToApply,
  }) async {
    if (!mounted) return;
    final notifier = ref.read(smsReviewQueueProvider.notifier);
    final pastUpdated = await notifier.confirmItem(
      id,
      overrideCategory: overrideCategory,
      overrideNote: overrideNote,
      applyRuleToAll: applyRuleToAll,
      tagToApply: tagToApply,
    );
    ref.invalidate(transactionsProvider);
    if (mounted) {
      final colorScheme = Theme.of(context).colorScheme;
      final msg = pastUpdated > 0
          ? 'Confirmed & updated $pastUpdated past transaction${pastUpdated != 1 ? "s" : ""} ✓'
          : 'Transaction confirmed ✓';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: AppTheme.bodyStyle(
              size: 13,
              weight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          backgroundColor: colorScheme.surfaceContainerHighest,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _discardItem(String id) async {
    final notifier = ref.read(smsReviewQueueProvider.notifier);
    await notifier.discardItem(id);
  }

  Future<void> _confirmAll() async {
    if (!mounted) return;
    final localColorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              LucideIcons.checkCheck,
              size: 20,
              color: AppColors.success,
            ),
            const SizedBox(width: 8),
            Text('Confirm all?', style: AppTheme.displayStyle()),
          ],
        ),
        content: Text(
          'Add all ${ref.read(smsReviewQueueProvider).length} pending transactions to your ledger?',
          style: AppTheme.bodyStyle(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTheme.bodyStyle(
                color: localColorScheme.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm All'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final notifier = ref.read(smsReviewQueueProvider.notifier);
      await notifier.confirmAll();
      ref.invalidate(transactionsProvider);
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'All transactions confirmed ✓',
              style: AppTheme.bodyStyle(
                size: 13,
                weight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            backgroundColor: colorScheme.surfaceContainerHighest,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.12),
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _discardAll() async {
    if (!mounted) return;
    final localColorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(LucideIcons.x, size: 20, color: AppColors.error),
            const SizedBox(width: 8),
            Text('Discard all?', style: AppTheme.displayStyle()),
          ],
        ),
        content: Text(
          'Remove all pending SMS transactions? This cannot be undone.',
          style: AppTheme.bodyStyle(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTheme.bodyStyle(
                color: localColorScheme.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error.withValues(alpha: 0.15),
              foregroundColor: AppColors.error,
            ),
            child: const Text('Discard All'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final notifier = ref.read(smsReviewQueueProvider.notifier);
      await notifier.discardAll();
    }
  }

  Future<void> _confirmFiltered(List<ParsedSmsTxn> items) async {
    if (!mounted || items.isEmpty) return;
    final localColorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              LucideIcons.checkCheck,
              size: 20,
              color: AppColors.success,
            ),
            const SizedBox(width: 8),
            Text('Confirm visible?', style: AppTheme.displayStyle()),
          ],
        ),
        content: Text(
          'Add ${items.length} visible transaction${items.length != 1 ? 's' : ''} to your ledger?',
          style: AppTheme.bodyStyle(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTheme.bodyStyle(
                color: localColorScheme.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final notifier = ref.read(smsReviewQueueProvider.notifier);
      await notifier.confirmItems(items.map((t) => t.id).toList());
      ref.invalidate(transactionsProvider);
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${items.length} transaction${items.length != 1 ? 's' : ''} confirmed ✓',
              style: AppTheme.bodyStyle(
                size: 13,
                weight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            backgroundColor: colorScheme.surfaceContainerHighest,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.12),
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _discardFiltered(List<ParsedSmsTxn> items) async {
    if (!mounted || items.isEmpty) return;
    final localColorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(LucideIcons.x, size: 20, color: AppColors.error),
            const SizedBox(width: 8),
            Text('Discard visible?', style: AppTheme.displayStyle()),
          ],
        ),
        content: Text(
          'Remove ${items.length} visible pending SMS transaction${items.length != 1 ? 's' : ''}? This cannot be undone.',
          style: AppTheme.bodyStyle(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTheme.bodyStyle(
                color: localColorScheme.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error.withValues(alpha: 0.15),
              foregroundColor: AppColors.error,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final notifier = ref.read(smsReviewQueueProvider.notifier);
      await notifier.discardItems(items.map((t) => t.id).toList());
    }
  }

  void _showScanPeriodSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final options = [
          (1, '1 Month', 'Past 30 days'),
          (2, '2 Months', 'Past 60 days'),
          (3, '3 Months', 'Past 90 days (Quarter)'),
          (6, '6 Months', 'Past 180 days (Half year)'),
          (9, '9 Months', 'Past 270 days'),
          (12, '12 Months / 1 Year', 'Past year (365 days)'),
          (null, 'All SMS', 'Full inbox search without time limit'),
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      LucideIcons.scanLine,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Scan SMS Inbox',
                      style: AppTheme.displayStyle(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Select how far back to look for UPI transaction messages:',
                  style: AppTheme.bodyStyle(
                    size: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ...options.map((opt) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        opt.$1 == null
                            ? LucideIcons.inbox
                            : LucideIcons.calendar,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      opt.$2,
                      style: AppTheme.bodyStyle(
                        weight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      opt.$3,
                      style: AppTheme.bodyStyle(
                        size: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(LucideIcons.chevronRight, size: 16),
                    onTap: () {
                      Navigator.pop(ctx);
                      _scanSmsInbox(months: opt.$1);
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _scanSmsInbox({int? months}) async {
    if (_isScanning) return;
    setState(() => _isScanning = true);
    try {
      final listener = SmsListenerService();
      final granted = await listener.isPermissionGranted();
      if (!granted) {
        final req = await listener.requestPermission();
        if (!req && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SMS permission is required to scan inbox'),
            ),
          );
          return;
        }
      }

      if (mounted) {
        final label = months == null
            ? 'entire inbox'
            : months == 12
                ? 'last 1 year'
                : 'last $months months';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scanning $label for UPI messages...'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      final messages = await listener.scanInbox(months: months);
      if (!mounted) return;
      if (messages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No new SMS transactions found in inbox'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final userRules = ref.read(autoCategorizationRulesProvider);
      final Map<String, String> keywordToCategory = {};
      for (final rule in userRules) {
        keywordToCategory[rule.keyword.toLowerCase()] = rule.categoryId;
      }
      final queueNotifier = ref.read(smsReviewQueueProvider.notifier);
      int added = 0;
      for (final sms in messages) {
        final parsed = SmsParser.parseMessage(
          sms.body,
          keywordToCategory: keywordToCategory.isNotEmpty
              ? keywordToCategory
              : null,
          dateOverride: DateTime.fromMillisecondsSinceEpoch(
            sms.timestamp,
            isUtc: true,
          ).toLocal(),
        );
        if (parsed != null &&
            !queueNotifier.isProcessed(parsed.id) &&
            !queueNotifier.isAlreadyInQueue(parsed.id)) {
          unawaited(queueNotifier.addToQueue(parsed));
          added++;
        }
      }
      if (mounted) {
        if (months != null) {
          setState(() => _filterMonths = months);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              added > 0
                  ? 'Found $added new transaction${added != 1 ? 's' : ''}'
                  : 'No new SMS transactions found',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }
}

/// Empty state for the review queue
class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue({required this.colorScheme, required this.onScanInbox});
  final ColorScheme colorScheme;
  final VoidCallback onScanInbox;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.08),
            ),
            child: Icon(
              LucideIcons.inbox,
              size: 36,
              color: colorScheme.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'All caught up',
            style: AppTheme.displayStyle(color: colorScheme.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            'No pending SMS transactions to review',
            style: AppTheme.bodyStyle(
              size: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onScanInbox,
            icon: const Icon(LucideIcons.scanLine, size: 16),
            label: const Text('Scan SMS Inbox'),
          ),
        ],
      ),
    );
  }
}

/// Individual queue item with swipe-to-discard, duplicate detection, pocket money linking, editable note, tag manager, payee auto-rule toggle, and category picker
class _QueueItemCard extends ConsumerStatefulWidget {
  const _QueueItemCard({
    required this.txn,
    required this.colorScheme,
    required this.onConfirm,
    required this.onConfirmWithCategory,
    required this.onDiscard,
  });
  final ParsedSmsTxn txn;
  final ColorScheme colorScheme;
  final VoidCallback onConfirm;
  final void Function(
    String catId,
    String? note,
    bool applyRuleToAll,
    String? tagToApply,
  ) onConfirmWithCategory;
  final VoidCallback onDiscard;

  @override
  ConsumerState<_QueueItemCard> createState() => _QueueItemCardState();
}

class _QueueItemCardState extends ConsumerState<_QueueItemCard> {
  String? _editingCategory;
  bool _showCategoryPicker = false;
  bool _showTagPicker = false;
  bool _applyRuleToAll = false;
  late TextEditingController _noteCtrl;
  late TextEditingController _tagCtrl;
  final FocusNode _noteFocus = FocusNode();
  final FocusNode _tagFocus = FocusNode();

  static const List<String> _suggestedTags = [
    'Cig',
    'Chai',
    'Food',
    'Snacks',
    'Grocery',
    'Travel',
    'Personal',
    'Bills',
    'Medicine',
  ];

  static final RegExp _tagRegex = RegExp(r'\s*\[([^\]]+)\]\s*$');

  @override
  void initState() {
    super.initState();
    final note = widget.txn.note;
    final match = _tagRegex.firstMatch(note);
    if (match != null) {
      _noteCtrl = TextEditingController(
        text: note.substring(0, match.start).trim(),
      );
      _tagCtrl = TextEditingController(text: match.group(1)?.trim() ?? '');
    } else {
      _noteCtrl = TextEditingController(text: note);
      _tagCtrl = TextEditingController(text: '');
    }

    if (widget.txn.payee != null && widget.txn.payee!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final rule = ref.read(payeeTagRulesProvider.notifier).findRuleForPayee(widget.txn.payee);
        if (rule != null) {
          if (_tagCtrl.text.isEmpty) {
            setState(() {
              _tagCtrl.text = rule.tag;
              if (rule.categoryId != null && _editingCategory == null) {
                _editingCategory = rule.categoryId;
              }
            });
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _tagCtrl.dispose();
    _noteFocus.dispose();
    _tagFocus.dispose();
    super.dispose();
  }

  String? _buildFinalNote() {
    final base = _noteCtrl.text.trim();
    final tag = _tagCtrl.text.replaceAll('[', '').replaceAll(']', '').trim();
    if (base.isEmpty && tag.isEmpty) return null;
    if (tag.isNotEmpty) {
      return base.isNotEmpty ? '$base [$tag]' : '[$tag]';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.colorScheme.brightness == Brightness.dark;

    // 1. Duplicate detection check
    final allTxns = ref.watch(transactionsProvider).valueOrNull ?? [];
    final dupResult = DuplicateDetector.findDuplicates(
      existingTransactions: allTxns,
      amount: widget.txn.amount,
      date: widget.txn.date,
      note: widget.txn.note,
      isIncome: widget.txn.isIncome,
    );
    final hasDuplicate = dupResult.isNotEmpty;
    final matchedDup = hasDuplicate ? dupResult.first : null;

    final rulesNotifier = ref.watch(payeeTagRulesProvider.notifier);
    final matchedRule = rulesNotifier.findRuleForPayee(widget.txn.payee);

    return Dismissible(
      key: Key('sms_${widget.txn.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.cardRadiusSmall),
          color: AppColors.error,
        ),
        child: const Icon(LucideIcons.x, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async {
        unawaited(HapticFeedback.mediumImpact());
        return true;
      },
      onDismissed: (_) {
        widget.onDiscard();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.cardRadiusSmall),
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          boxShadow: isDark
              ? AppColors.cardShadowDark
              : AppColors.cardShadowLight,
          border: Border(
            left: BorderSide(
              color: hasDuplicate
                  ? AppColors.error
                  : (widget.txn.isIncome
                        ? AppColors.success
                        : AppColors.warning),
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payee / Merchant header if present
            if (widget.txn.payee != null && widget.txn.payee!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      widget.txn.isIncome
                          ? LucideIcons.userCheck
                          : LucideIcons.store,
                      size: 14,
                      color: widget.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${widget.txn.isIncome ? "From" : "Paid to"}: ${widget.txn.payee!}',
                        style: AppTheme.bodyStyle(
                          size: 13,
                          weight: FontWeight.w700,
                          color: widget.colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (matchedRule != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: widget.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.sparkles,
                              size: 10,
                              color: widget.colorScheme.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Auto-rule',
                              style: AppTheme.bodyStyle(
                                size: 9,
                                weight: FontWeight.w600,
                                color: widget.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

            // Duplicate warning banner if detected
            if (hasDuplicate && matchedDup != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.error.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.alertTriangle,
                      size: 14,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Possible Duplicate: Matches existing ₹${Formatters.formatCurrency(matchedDup.amount.abs())} on ${Formatters.formatDateShort(matchedDup.date)}',
                        style: AppTheme.bodyStyle(
                          size: 11,
                          weight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Top row: amount, direction badge, category
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: widget.txn.isIncome
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.warning.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    widget.txn.isIncome
                        ? LucideIcons.arrowDownLeft
                        : LucideIcons.arrowUpRight,
                    size: 18,
                    color: widget.txn.isIncome
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            widget.txn.isIncome
                                ? LucideIcons.plusCircle
                                : LucideIcons.minusCircle,
                            size: 14,
                            color: widget.txn.isIncome
                                ? AppColors.success
                                : AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.txn.isIncome ? '+' : '-'}${Formatters.formatCurrency(widget.txn.amount)}',
                            style: AppTheme.financialStyle(
                              size: 18,
                              weight: FontWeight.w700,
                              color: widget.txn.isIncome
                                  ? AppColors.success
                                  : widget.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: widget.txn.isIncome
                                  ? AppColors.success.withValues(alpha: 0.12)
                                  : widget.colorScheme.surfaceContainerHighest,
                            ),
                            child: Text(
                              widget.txn.isIncome ? 'Income' : 'Expense',
                              style: AppTheme.bodyStyle(
                                size: 9,
                                weight: FontWeight.w600,
                                color: widget.txn.isIncome
                                    ? AppColors.success
                                    : widget.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${Formatters.formatDateShort(widget.txn.date)} · detected ${Formatters.formatDateShort(widget.txn.detectedAt)}',
                        style: AppTheme.bodyStyle(
                          size: 10,
                          color: widget.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Category badge
                GestureDetector(
                  onTap: () => setState(
                    () => _showCategoryPicker = !_showCategoryPicker,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: widget.colorScheme.primary.withValues(alpha: 0.1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _editingCategory ??
                              widget.txn.categoryId.toUpperCase(),
                          style: AppTheme.bodyStyle(
                            size: 10,
                            weight: FontWeight.w600,
                            color: widget.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          LucideIcons.chevronDown,
                          size: 12,
                          color: widget.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Note — personal editable note field
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 48),
              child: TextField(
                controller: _noteCtrl,
                focusNode: _noteFocus,
                style: AppTheme.bodyStyle(
                  size: 13,
                  color: widget.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Add personal note (optional)...',
                  hintStyle: AppTheme.bodyStyle(
                    size: 13,
                    color: widget.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: widget.colorScheme.outline.withValues(alpha: 0.15),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: widget.colorScheme.outline.withValues(alpha: 0.15),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: widget.colorScheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: widget.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.2),
                  isDense: true,
                ),
                maxLines: 2,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),

            // Tag chips & tag editor
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_tagCtrl.text.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.colorScheme.secondaryContainer
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: widget.colorScheme.secondary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.tag,
                                size: 12,
                                color: widget.colorScheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _tagCtrl.text,
                                style: AppTheme.bodyStyle(
                                  size: 11,
                                  weight: FontWeight.w600,
                                  color: widget.colorScheme.secondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => setState(() => _tagCtrl.clear()),
                                child: Icon(
                                  LucideIcons.x,
                                  size: 12,
                                  color: widget.colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () => setState(
                            () => _showTagPicker = !_showTagPicker,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: widget
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: widget.colorScheme.outline.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.tag,
                                  size: 12,
                                  color: widget.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '+ Add Tag',
                                  style: AppTheme.bodyStyle(
                                    size: 11,
                                    weight: FontWeight.w500,
                                    color:
                                        widget.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (!_showTagPicker)
                        GestureDetector(
                          onTap: () => setState(() => _showTagPicker = true),
                          child: Text(
                            'Edit tag',
                            style: AppTheme.bodyStyle(
                              size: 11,
                              color: widget.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_showTagPicker) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _suggestedTags.map((t) {
                        final isSel =
                            _tagCtrl.text.toLowerCase() == t.toLowerCase();
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _tagCtrl.text = isSel ? '' : t;
                              if (widget.txn.payee != null &&
                                  widget.txn.payee!.isNotEmpty &&
                                  !isSel) {
                                _applyRuleToAll = true;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? widget.colorScheme.primary.withValues(
                                      alpha: 0.15,
                                    )
                                  : widget.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSel
                                    ? widget.colorScheme.primary
                                    : widget.colorScheme.outline.withValues(
                                        alpha: 0.15,
                                      ),
                              ),
                            ),
                            child: Text(
                              t,
                              style: AppTheme.bodyStyle(
                                size: 11,
                                weight: isSel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSel
                                    ? widget.colorScheme.primary
                                    : widget.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _tagCtrl,
                      focusNode: _tagFocus,
                      style: AppTheme.bodyStyle(size: 12),
                      decoration: InputDecoration(
                        hintText: 'Custom tag (e.g. cig)...',
                        hintStyle: AppTheme.bodyStyle(
                          size: 12,
                          color: widget.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        prefixIcon: const Icon(LucideIcons.tag, size: 14),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        if (val.trim().isNotEmpty &&
                            widget.txn.payee != null &&
                            widget.txn.payee!.isNotEmpty) {
                          setState(() => _applyRuleToAll = true);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),

            // Payee Auto-rule toggle
            if (widget.txn.payee != null &&
                widget.txn.payee!.isNotEmpty &&
                _tagCtrl.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 48),
                child: Row(
                  children: [
                    SizedBox(
                      height: 20,
                      width: 20,
                      child: Checkbox(
                        value: _applyRuleToAll,
                        onChanged: (val) =>
                            setState(() => _applyRuleToAll = val ?? false),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _applyRuleToAll = !_applyRuleToAll),
                        child: Text(
                          'Apply "${_tagCtrl.text.trim()}" to all past & future from ${widget.txn.payee!}',
                          style: AppTheme.bodyStyle(
                            size: 11,
                            weight: FontWeight.w600,
                            color: widget.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Category picker (expandable)
            if (_showCategoryPicker)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 48),
                child: _CategoryPicker(
                  currentCategoryId: _editingCategory ?? widget.txn.categoryId,
                  onChanged: (catId) {
                    setState(() {
                      _editingCategory = catId.isEmpty ? null : catId;
                      _showCategoryPicker = false;
                    });
                  },
                  colorScheme: widget.colorScheme,
                  isIncome: widget.txn.isIncome,
                ),
              ),

            const SizedBox(height: 8),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: widget.onDiscard,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      'Discard',
                      style: AppTheme.bodyStyle(
                        size: 12,
                        color: AppColors.error,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                GestureDetector(
                  onTap: () {
                    final cleanTag = _tagCtrl.text
                        .replaceAll('[', '')
                        .replaceAll(']', '')
                        .trim();
                    widget.onConfirmWithCategory(
                      _editingCategory ?? widget.txn.categoryId,
                      _buildFinalNote(),
                      _applyRuleToAll,
                      cleanTag.isNotEmpty ? cleanTag : null,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.success.withValues(alpha: 0.12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.check,
                          size: 14,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Confirm',
                          style: AppTheme.bodyStyle(
                            size: 12,
                            color: AppColors.success,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
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

/// Inline category picker for changing the category on a pending SMS item
class _CategoryPicker extends ConsumerWidget {
  const _CategoryPicker({
    required this.currentCategoryId,
    required this.onChanged,
    required this.colorScheme,
    this.isIncome = false,
  });
  final String currentCategoryId;
  final ValueChanged<String> onChanged;
  final ColorScheme colorScheme;
  final bool isIncome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    // Show income categories for income items, expense for expense items
    final catList = isIncome
        ? categories
              .where((c) => c.type == 'income' || c.type == 'expense')
              .toList()
        : categories.where((c) => c.type == 'expense').toList();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          // Clear/reset option
          GestureDetector(
            onTap: () => onChanged(''),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                'Cancel',
                style: AppTheme.bodyStyle(
                  size: 11,
                  weight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          ...catList.map((cat) {
            final selected = cat.id == currentCategoryId;
            final catColor = Color(cat.color);
            return GestureDetector(
              onTap: () => onChanged(cat.id),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: selected
                      ? catColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                  border: selected
                      ? Border.all(color: catColor.withValues(alpha: 0.4))
                      : null,
                ),
                child: Text(
                  cat.name,
                  style: AppTheme.bodyStyle(
                    size: 11,
                    weight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? catColor : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
