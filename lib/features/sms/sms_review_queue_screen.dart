import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/sms_parser.dart';
import '../../core/utils/duplicate_detector.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/services/sms_listener_service.dart';

/// Screen for reviewing pending SMS-detected transactions.
class SmsReviewQueueScreen extends ConsumerStatefulWidget {
  const SmsReviewQueueScreen({super.key});

  @override
  ConsumerState<SmsReviewQueueScreen> createState() => _SmsReviewQueueScreenState();
}

class _SmsReviewQueueScreenState extends ConsumerState<SmsReviewQueueScreen> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final queue = ref.watch(smsReviewQueueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Review Queue'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.scanLine, size: 20),
            tooltip: 'Scan SMS Inbox',
            onPressed: _scanSmsInbox,
          ),
          if (queue.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(LucideIcons.ellipsisVertical, size: 18, color: colorScheme.onSurfaceVariant),
              onSelected: (v) {
                if (v == 'confirm_all') _confirmAll();
                if (v == 'discard_all') _discardAll();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'confirm_all', child: Text('Confirm all')),
                const PopupMenuItem(value: 'discard_all', child: Text('Discard all')),
              ],
            ),
        ],
      ),
      body: queue.isEmpty
          ? _EmptyQueue(colorScheme: colorScheme, onScanInbox: _scanSmsInbox)
          : ListView(
              padding: AppConstants.screenPadding,
              children: [
                // Queue stats header
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppConstants.cardRadiusSmall),
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.messageSquare, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${queue.length} pending transaction${queue.length != 1 ? 's' : ''}',
                              style: AppTheme.displayStyle(
                                size: 16, weight: FontWeight.w600, color: colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'Review and confirm each to add to your ledger',
                              style: AppTheme.bodyStyle(
                                size: 12, color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 200.ms),

                const SizedBox(height: 16),

                // Bulk actions
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _confirmAll,
                        icon: const Icon(LucideIcons.checkCheck, size: 16),
                        label: Text('Confirm all (${queue.length})',
                            style: AppTheme.bodyStyle(size: 13, weight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          backgroundColor: AppColors.success.withValues(alpha: 0.15),
                          foregroundColor: AppColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _discardAll,
                        icon: const Icon(LucideIcons.x, size: 16),
                        label: Text('Discard all',
                            style: AppTheme.bodyStyle(size: 13, weight: FontWeight.w500)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          foregroundColor: AppColors.error,
                          side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
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
                      Text('Swipe left to discard, tap to review',
                          style: AppTheme.bodyStyle(
                            size: 11, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
                    ],
                  ),
                ),

                // Queue items
                ...queue.map((txn) => _QueueItemCard(
                  txn: txn,
                  colorScheme: colorScheme,
                  onConfirm: () => _confirmItem(txn.id),
                  onConfirmWithCategory: (catId, note) => _confirmItem(txn.id, overrideCategory: catId, overrideNote: note),
                  onDiscard: () => _discardItem(txn.id),
                )),
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  Future<void> _confirmItem(String id, {String? overrideCategory, String? overrideNote}) async {
    if (!mounted) return;
    final notifier = ref.read(smsReviewQueueProvider.notifier);
    await notifier.confirmItem(id, overrideCategory: overrideCategory, overrideNote: overrideNote);
    ref.invalidate(transactionsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction confirmed ✓'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
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
            Icon(LucideIcons.checkCheck, size: 20, color: AppColors.success),
            const SizedBox(width: 8),
            Text('Confirm all?', style: AppTheme.displayStyle(size: 18, weight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'Add all ${ref.read(smsReviewQueueProvider).length} pending transactions to your ledger?',
          style: AppTheme.bodyStyle(size: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTheme.bodyStyle(color: localColorScheme.onSurfaceVariant)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All transactions confirmed ✓'),
            behavior: SnackBarBehavior.floating,
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
            Icon(LucideIcons.x, size: 20, color: AppColors.error),
            const SizedBox(width: 8),
            Text('Discard all?', style: AppTheme.displayStyle(size: 18, weight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'Remove all pending SMS transactions? This cannot be undone.',
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

  Future<void> _scanSmsInbox() async {
    final listener = SmsListenerService();
    final granted = await listener.isPermissionGranted();
    if (!granted) {
      final req = await listener.requestPermission();
      if (!req && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS permission is required to scan inbox')),
        );
        return;
      }
    }
    final messages = await listener.scanInbox();
    if (!mounted) return;
    if (messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No new SMS transactions found in inbox')),
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
        keywordToCategory: keywordToCategory.isNotEmpty ? keywordToCategory : null,
        dateOverride: DateTime.fromMillisecondsSinceEpoch(sms.timestamp, isUtc: true).toLocal(),
      );
      if (parsed != null && !queueNotifier.isProcessed(parsed.id) && !queueNotifier.isAlreadyInQueue(parsed.id)) {
        queueNotifier.addToQueue(parsed);
        added++;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(added > 0 ? 'Found $added new transaction${added != 1 ? 's' : ''}' : 'No new SMS transactions found'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// Empty state for the review queue
class _EmptyQueue extends StatelessWidget {
  final ColorScheme colorScheme;
  final VoidCallback onScanInbox;
  const _EmptyQueue({required this.colorScheme, required this.onScanInbox});

  @override
  Widget build(BuildContext context) {
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
            child: Icon(LucideIcons.inbox, size: 36,
                color: colorScheme.primary.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 16),
          Text('All caught up', style: AppTheme.displayStyle(
            size: 18, weight: FontWeight.w600, color: colorScheme.onSurface)),
          const SizedBox(height: 6),
          Text('No pending SMS transactions to review',
              style: AppTheme.bodyStyle(size: 13, color: colorScheme.onSurfaceVariant)),
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

/// Individual queue item with swipe-to-discard, duplicate detection, pocket money linking, editable note, and category picker
class _QueueItemCard extends ConsumerStatefulWidget {
  final ParsedSmsTxn txn;
  final ColorScheme colorScheme;
  final VoidCallback onConfirm;
  final void Function(String catId, String? note) onConfirmWithCategory;
  final VoidCallback onDiscard;

  const _QueueItemCard({
    required this.txn,
    required this.colorScheme,
    required this.onConfirm,
    required this.onConfirmWithCategory,
    required this.onDiscard,
  });

  @override
  ConsumerState<_QueueItemCard> createState() => _QueueItemCardState();
}

class _QueueItemCardState extends ConsumerState<_QueueItemCard> {
  String? _editingCategory;
  bool _showCategoryPicker = false;
  late TextEditingController _noteCtrl;
  final FocusNode _noteFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _noteFocus.dispose();
    super.dispose();
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
        HapticFeedback.mediumImpact();
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
          boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
          border: Border(
            left: BorderSide(
              color: hasDuplicate
                  ? AppColors.error
                  : (widget.txn.isIncome ? AppColors.success : AppColors.warning),
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Duplicate warning banner if detected
            if (hasDuplicate && matchedDup != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.error.withValues(alpha: 0.1),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.alertTriangle, size: 14, color: AppColors.error),
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
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: widget.txn.isIncome
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.warning.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    widget.txn.isIncome ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
                    size: 18,
                    color: widget.txn.isIncome ? AppColors.success : AppColors.warning,
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
                            widget.txn.isIncome ? LucideIcons.plusCircle : LucideIcons.minusCircle,
                            size: 14,
                            color: widget.txn.isIncome ? AppColors.success : AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.txn.isIncome ? '+' : '-'}${Formatters.formatCurrency(widget.txn.amount)}',
                            style: AppTheme.financialStyle(
                              size: 18, weight: FontWeight.w700,
                              color: widget.txn.isIncome ? AppColors.success : widget.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                color: widget.txn.isIncome ? AppColors.success : widget.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${Formatters.formatDateShort(widget.txn.date)} · detected ${Formatters.formatDateShort(widget.txn.detectedAt)}',
                        style: AppTheme.bodyStyle(
                          size: 10, color: widget.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                // Category badge
                GestureDetector(
                  onTap: () => setState(() => _showCategoryPicker = !_showCategoryPicker),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: widget.colorScheme.primary.withValues(alpha: 0.1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _editingCategory ?? widget.txn.categoryId.toUpperCase(),
                          style: AppTheme.bodyStyle(
                            size: 10, weight: FontWeight.w600,
                            color: widget.colorScheme.primary),
                        ),
                        const SizedBox(width: 2),
                        Icon(LucideIcons.chevronDown, size: 12, color: widget.colorScheme.primary),
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
                  size: 13, color: widget.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Add personal note (optional)...',
                  hintStyle: AppTheme.bodyStyle(
                    size: 13, color: widget.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: widget.colorScheme.outline.withValues(alpha: 0.15)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: widget.colorScheme.outline.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: widget.colorScheme.primary.withValues(alpha: 0.4)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: widget.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                  isDense: true,
                ),
                maxLines: 2,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                    ),
                    child: Text('Discard', style: AppTheme.bodyStyle(
                      size: 12, color: AppColors.error, weight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(width: 8),

                GestureDetector(
                  onTap: () => widget.onConfirmWithCategory(
                    _editingCategory ?? widget.txn.categoryId,
                    _noteCtrl.text.trim(),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.success.withValues(alpha: 0.12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.check, size: 14, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text('Confirm', style: AppTheme.bodyStyle(
                          size: 12, color: AppColors.success, weight: FontWeight.w600)),
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
  final String currentCategoryId;
  final ValueChanged<String> onChanged;
  final ColorScheme colorScheme;
  final bool isIncome;

  const _CategoryPicker({
    required this.currentCategoryId,
    required this.onChanged,
    required this.colorScheme,
    this.isIncome = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    // Show income categories for income items, expense for expense items
    final catList = isIncome
        ? categories.where((c) => c.type == 'income' || c.type == 'expense').toList()
        : categories.where((c) => c.type == 'expense').toList();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: Wrap(
        spacing: 6, runSpacing: 6,
        children: [
          // Clear/reset option
          GestureDetector(
            onTap: () => onChanged(''),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
              ),
              child: Text('Cancel', style: AppTheme.bodyStyle(
                size: 11, weight: FontWeight.w500, color: colorScheme.onSurfaceVariant)),
            ),
          ),
          ...catList.map((cat) {
            final selected = cat.id == currentCategoryId;
            final catColor = Color(cat.color);
            return GestureDetector(
              onTap: () => onChanged(cat.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: selected
                      ? catColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                  border: selected
                      ? Border.all(color: catColor.withValues(alpha: 0.4))
                      : null,
                ),
                child: Text(cat.name, style: AppTheme.bodyStyle(
                  size: 11, weight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? catColor : colorScheme.onSurfaceVariant)),
              ),
            );
          }),
        ],
      ),
    );
  }
}
