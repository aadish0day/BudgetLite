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
import '../../core/database/database.dart';
import '../../providers/database_provider.dart';
import 'add_transaction_sheet.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String? _selectedCategory;
  final _searchCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minAmount;
  double? _maxAmount;
  bool _showFilters = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _editTransaction(Transaction t) {
    HapticFeedback.mediumImpact();
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

  Future<void> _deleteWithUndo(Transaction t) async {
    final colorScheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);

    // Show confirm dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(LucideIcons.trash2, size: 20, color: AppColors.error),
            const SizedBox(width: 8),
            Text(
              'Delete this transaction?',
              style: AppTheme.displayStyle(size: 18, weight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(
          '₹${t.amount.abs().toStringAsFixed(0)} — ${t.note ?? "Transaction"} on ${Formatters.formatDateShort(t.date)}',
          style: AppTheme.bodyStyle(size: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTheme.bodyStyle(color: colorScheme.onSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error.withValues(alpha: 0.15),
              foregroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Store reference before deletion for potential undo
    final notifier = ref.read(transactionNotifierProvider.notifier);
    final deletedTxn = t;

    await notifier.deleteTransaction(t.id);

    // Show undo snackbar
    messenger.showSnackBar(
      SnackBar(
        content: Text('${deletedTxn.note ?? "Transaction"} deleted'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await notifier.addTransaction(
              amount: deletedTxn.amount.abs(),
              categoryId: deletedTxn.categoryId,
              note: deletedTxn.note,
              date: deletedTxn.date,
              paymentMethod: deletedTxn.paymentMethod,
              isRecurring: deletedTxn.isRecurring,
              recurringInterval: deletedTxn.recurringInterval,
              receiptImagePath: deletedTxn.receiptImagePath,
            );
          },
        ),
      ),
    );
  }

  List<Transaction> _applyFilters(List<Transaction> txns) {
    return txns.where((t) {
      // Category filter
      if (_selectedCategory != null && t.categoryId != _selectedCategory) return false;

      // Search by note
      if (_searchCtrl.text.isNotEmpty) {
        final query = _searchCtrl.text.toLowerCase();
        final note = t.note?.toLowerCase() ?? '';
        final catName = ref.read(categoriesProvider).valueOrNull
            ?.where((c) => c.id == t.categoryId)
            .firstOrNull
            ?.name
            .toLowerCase() ?? '';
        if (!note.contains(query) && !catName.contains(query)) return false;
      }

      // Date range
      if (_startDate != null && t.date.isBefore(_startDate!)) return false;
      if (_endDate != null && t.date.isAfter(_endDate!.add(const Duration(days: 1)))) return false;

      // Amount range
      final absAmt = t.amount.abs();
      if (_minAmount != null && absAmt < _minAmount!) return false;
      if (_maxAmount != null && absAmt > _maxAmount!) return false;

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(thisMonthTransactionsProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Transactions',
          style: AppTheme.displayStyle(
            size: 17,
            weight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _showFilters = !_showFilters),
            icon: Icon(
              _showFilters ? LucideIcons.slidersHorizontal : LucideIcons.search,
              size: 20,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar (category chips)
          _FilterBar(
            selectedCategory: _selectedCategory,
            onCategoryChanged: (v) => setState(() => _selectedCategory = v),
            categories: categories,
          ),

          // Expandable search & advanced filters
          if (_showFilters)
            _AdvancedFilters(
              searchCtrl: _searchCtrl,
              startDate: _startDate,
              endDate: _endDate,
              minAmount: _minAmount,
              maxAmount: _maxAmount,
              onSearchChanged: () => setState(() {}),
              onStartDateChanged: (d) => setState(() => _startDate = d),
              onEndDateChanged: (d) => setState(() => _endDate = d),
              onMinAmountChanged: (v) => setState(() => _minAmount = v),
              onMaxAmountChanged: (v) => setState(() => _maxAmount = v),
              onClear: () => setState(() {
                _searchCtrl.clear();
                _startDate = null;
                _endDate = null;
                _minAmount = null;
                _maxAmount = null;
                _selectedCategory = null;
              }),
            ).animate().slideY(begin: -0.1, duration: 200.ms).fadeIn(duration: 200.ms),

          Expanded(
            child: transactions.when(
              data: (txns) {
                final filtered = _applyFilters(txns);
                if (filtered.isEmpty) {
                  return _EmptyTransactions(
                    hasFilters: _selectedCategory != null ||
                        _searchCtrl.text.isNotEmpty ||
                        _startDate != null ||
                        _minAmount != null,
                  );
                }
                return ListView.builder(
                  padding: AppConstants.screenPadding,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final t = filtered[index];
                    return _TransactionCard(
                      transaction: t,
                      category: categories.where((c) => c.id == t.categoryId).firstOrNull,
                      onTap: () => _editTransaction(t),
                      onDelete: (transaction) {
                        _deleteWithUndo(transaction);
                      },
                    ).animate().fadeIn(
                      duration: 300.ms,
                      delay: (index * 50).ms,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _EmptyTransactions(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search & advanced filters panel ──
class _AdvancedFilters extends StatelessWidget {
  final TextEditingController searchCtrl;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minAmount;
  final double? maxAmount;
  final VoidCallback onSearchChanged;
  final ValueChanged<DateTime?> onStartDateChanged;
  final ValueChanged<DateTime?> onEndDateChanged;
  final ValueChanged<double?> onMinAmountChanged;
  final ValueChanged<double?> onMaxAmountChanged;
  final VoidCallback onClear;

  const _AdvancedFilters({
    required this.searchCtrl,
    required this.startDate,
    required this.endDate,
    required this.minAmount,
    required this.maxAmount,
    required this.onSearchChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onMinAmountChanged,
    required this.onMaxAmountChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        children: [
          // Search field
          TextField(
            controller: searchCtrl,
            onChanged: (_) => onSearchChanged(),
            style: AppTheme.bodyStyle(size: 14),
            decoration: InputDecoration(
              hintText: 'Search by note or category...',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () {
                        searchCtrl.clear();
                        onSearchChanged();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 10),

          // Date range & amount range
          Row(
            children: [
              // Start date
              Expanded(
                child: _FilterChip(
                  label: startDate != null
                      ? 'From ${startDate!.day}/${startDate!.month}'
                      : 'From date',
                  selected: startDate != null,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) onStartDateChanged(date);
                  },
                  onClear: startDate != null ? () => onStartDateChanged(null) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterChip(
                  label: endDate != null
                      ? 'To ${endDate!.day}/${endDate!.month}'
                      : 'To date',
                  selected: endDate != null,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: endDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) onEndDateChanged(date);
                  },
                  onClear: endDate != null ? () => onEndDateChanged(null) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  style: AppTheme.bodyStyle(size: 13),
                  decoration: InputDecoration(
                    hintText: 'Min ₹',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    isDense: true,
                  ),
                  onChanged: (v) => onMinAmountChanged(double.tryParse(v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  style: AppTheme.bodyStyle(size: 13),
                  decoration: InputDecoration(
                    hintText: 'Max ₹',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    isDense: true,
                  ),
                  onChanged: (v) => onMaxAmountChanged(double.tryParse(v)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: colorScheme.error.withValues(alpha: 0.1),
                  ),
                  child: Icon(LucideIcons.rotateCcw, size: 18, color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Filter chip with optional clear button ──
class _FilterChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onClear,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: widget.selected
                ? colorScheme.primary.withValues(alpha: 0.12)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            border: widget.selected
                ? Border.all(color: colorScheme.primary.withValues(alpha: 0.3))
                : Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: AppTheme.bodyStyle(
                  size: 11,
                  weight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                  color: widget.selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
              ),
              if (widget.onClear != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: widget.onClear,
                  child: Icon(LucideIcons.x, size: 12, color: colorScheme.primary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Category filter bar ──
class _FilterBar extends StatelessWidget {
  final String? selectedCategory;
  final void Function(String?) onCategoryChanged;
  final List<Category> categories;

  const _FilterBar({
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _CategoryChip(
              label: 'All',
              selected: selectedCategory == null,
              onTap: () => onCategoryChanged(null),
            ),
            const SizedBox(width: 8),
            ...categories.map((c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _CategoryChip(
                    label: c.name,
                    selected: selectedCategory == c.id,
                    color: Color(c.color),
                    onTap: () => onCategoryChanged(c.id),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? (color ?? colorScheme.primary).withValues(alpha: 0.15)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: selected
              ? Border.all(color: (color ?? colorScheme.primary).withValues(alpha: 0.3))
              : null,
        ),
        child: Text(
          label,
          style: AppTheme.bodyStyle(
            size: 13,
            weight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? (color ?? colorScheme.primary) : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── Transaction card with tap-to-edit ──
class _TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final Category? category;
  final VoidCallback onTap;
  final ValueChanged<Transaction> onDelete;

  const _TransactionCard({
    required this.transaction,
    required this.category,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final catColor = Color(category?.color ?? 0xFF6B7280);

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        onDelete(transaction);
        HapticFeedback.mediumImpact();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.cardRadiusSmall),
          color: AppColors.error,
        ),
        child: const Icon(LucideIcons.trash2, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.cardRadiusSmall),
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppConstants.cardRadiusIcon),
                  color: catColor.withValues(alpha: 0.12),
                ),
                child: Icon(
                  getCategoryIcon(category?.icon ?? ''),
                  size: 22,
                  color: catColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category?.name ?? 'Unknown',
                      style: AppTheme.bodyStyle(
                        size: 14,
                        weight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (transaction.note != null && transaction.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          transaction.note!,
                          style: AppTheme.bodyStyle(
                            size: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          Formatters.formatDate(transaction.date),
                          style: AppTheme.bodyStyle(
                            size: 11,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                        if (transaction.isRecurringInstance) ...[
                          const SizedBox(width: 6),
                          Icon(LucideIcons.sparkles, size: 10, color: AppColors.tertiary.withValues(alpha: 0.7)),
                          const SizedBox(width: 2),
                          Text(
                            'Auto',
                            style: AppTheme.bodyStyle(
                              size: 9,
                              color: AppColors.tertiary.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                        if (transaction.isRecurring) ...[
                          const SizedBox(width: 6),
                          Icon(LucideIcons.rotateCw, size: 10, color: colorScheme.primary.withValues(alpha: 0.6)),
                          const SizedBox(width: 2),
                          Text(
                            'Repeating',
                            style: AppTheme.bodyStyle(
                              size: 9,
                              color: colorScheme.primary.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    transaction.amount < 0
                        ? '+${Formatters.formatCurrency(transaction.amount.abs())}'
                        : '-${Formatters.formatCurrency(transaction.amount)}',
                    style: AppTheme.financialStyle(
                      size: 15,
                      weight: FontWeight.w600,
                      color: transaction.amount < 0 ? AppColors.success : AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: colorScheme.surfaceContainerHighest,
                    ),
                    child: Text(
                      transaction.paymentMethod,
                      style: AppTheme.bodyStyle(
                        size: 9,
                        weight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],      ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.02, duration: 300.ms),
    ),
  ),
);
  }
}

class _EmptyTransactions extends StatelessWidget {
  final bool hasFilters;

  const _EmptyTransactions({this.hasFilters = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilters ? LucideIcons.searchX : LucideIcons.receiptText,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No matching transactions' : 'No transactions found',
            style: AppTheme.displayStyle(
              size: 18,
              weight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Try adjusting your filters'
                : 'Add your first transaction to get started',
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
