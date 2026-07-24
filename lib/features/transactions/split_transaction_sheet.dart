import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/icon_helper.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/database_provider.dart';
import '../../core/database/database.dart';

/// A bottom sheet for splitting a transaction across multiple categories.
/// User enters a total amount and allocates portions to different categories.
class SplitTransactionSheet extends ConsumerStatefulWidget {
  const SplitTransactionSheet({super.key});

  @override
  ConsumerState<SplitTransactionSheet> createState() => _SplitTransactionSheetState();
}

class _SplitTransactionSheetState extends ConsumerState<SplitTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _totalCtrl = TextEditingController();

  late String _paymentMethod;
  late DateTime _selectedDate;

  // Split lines: each has a category + amount
  final List<_SplitLine> _splits = [
    _SplitLine(categoryId: 'food', amount: ''),
    _SplitLine(categoryId: 'transport', amount: ''),
  ];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _paymentMethod = 'Cash';
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    super.dispose();
  }

  double get _totalEntered => double.tryParse(_totalCtrl.text) ?? 0;

  /// Sum of all split amounts entered
  double get _splitSum => _splits
      .map((s) => double.tryParse(s.amount) ?? 0)
      .fold<double>(0, (a, b) => a + b);

  /// Running remainder to allocate
  double get _remainder => _totalEntered - _splitSum;

  bool get _isBalanced => _totalEntered > 0 && _remainder.abs() < 0.01;

  void _addSplitLine() {
    setState(() {
      _splits.add(_SplitLine(categoryId: 'other', amount: ''));
    });
  }

  void _removeSplitLine(int index) {
    if (_splits.length <= 2) return; // keep at least 2 lines
    setState(() => _splits.removeAt(index));
  }

  void _autoBalanceRemainder() {
    if (_splits.isEmpty || _totalEntered <= 0) return;
    // Put the remainder into the last non-empty split's amount
    final lastIdx = _splits.length - 1;
    final existing = double.tryParse(_splits[lastIdx].amount) ?? 0;
    final newAmount = existing + _remainder;
    setState(() => _splits[lastIdx].amount =
        newAmount > 0 ? newAmount.toStringAsFixed(0) : '');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final expenseCats = categories.where((c) => c.type == 'expense').toList();
    final isDark = colorScheme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
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
                'Split Transaction',
                style: AppTheme.displayStyle(
                  size: 20, weight: FontWeight.w600, color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Allocate a total amount across categories',
                style: AppTheme.bodyStyle(
                  size: 13, color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),

              // Total amount field
              TextFormField(
                controller: _totalCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: AppTheme.financialStyle(size: 24, weight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'Total Amount',
                  prefixText: '₹ ',
                  prefixStyle: AppTheme.financialStyle(size: 24, weight: FontWeight.w700),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter total amount';
                  final parsed = double.tryParse(v);
                  if (parsed == null || parsed <= 0) return 'Enter a valid amount > 0';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Split lines header
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text('Category', style: AppTheme.bodyStyle(
                      size: 12, weight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('Amount', textAlign: TextAlign.right, style: AppTheme.bodyStyle(
                      size: 12, weight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                  ),
                  const SizedBox(width: 32),
                ],
              ),
              const SizedBox(height: 8),

              // Split lines
              ..._splits.asMap().entries.map((entry) {
                final idx = entry.key;
                final split = entry.value;
                return _SplitLineRow(
                  split: split,
                  index: idx,
                  categories: expenseCats,
                  canRemove: _splits.length > 2,
                  onRemove: () => _removeSplitLine(idx),
                  onChanged: () => setState(() {}),
                  colorScheme: colorScheme,
                  isDark: isDark,
                );
              }),

              // Add line button
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: _addSplitLine,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: Text('Add category', style: AppTheme.bodyStyle(size: 13)),
                ),
              ),

              const SizedBox(height: 12),

              // Running remainder display
              if (_totalEntered > 0)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _isBalanced
                        ? AppColors.success.withValues(alpha: 0.08)
                        : AppColors.warning.withValues(alpha: 0.08),
                    border: Border.all(
                      color: _isBalanced
                          ? AppColors.success.withValues(alpha: 0.2)
                          : AppColors.warning.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isBalanced ? LucideIcons.checkCircle2 : LucideIcons.alertTriangle,
                        size: 18,
                        color: _isBalanced ? AppColors.success : AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isBalanced
                              ? 'All ₹${_totalEntered.toStringAsFixed(0)} allocated ✓'
                              : 'Remaining: ₹${_remainder.toStringAsFixed(0)}',
                          style: AppTheme.bodyStyle(
                            size: 13, weight: FontWeight.w600,
                            color: _isBalanced ? AppColors.success : AppColors.warning,
                          ),
                        ),
                      ),
                      if (!_isBalanced && _remainder > 0)
                        GestureDetector(
                          onTap: _autoBalanceRemainder,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: AppColors.warning.withValues(alpha: 0.2),
                            ),
                            child: Text('Auto-fill', style: AppTheme.bodyStyle(
                              size: 11, weight: FontWeight.w600, color: AppColors.warning)),
                          ),
                        ),
                    ],
                  ),
                ).animate().fadeIn(duration: 200.ms),

              const SizedBox(height: 16),

              // Date & Payment method row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) setState(() => _selectedDate = date);
                      },
                      icon: const Icon(LucideIcons.calendarDays, size: 16),
                      label: Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: AppTheme.bodyStyle(size: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: AppConstants.paymentMethods.map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m, style: AppTheme.bodyStyle(size: 13)),
                      )).toList(),
                      onChanged: (v) => setState(() => _paymentMethod = v ?? 'Cash'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit button
              FilledButton(
                onPressed: (_totalEntered > 0 && !_isSubmitting) ? _submit : null,
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.arrowLeftRight, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _isBalanced
                                ? 'Save ${_splits.length} Split Transactions'
                                : _totalEntered > 0
                                    ? 'Balance ₹${_remainder.toStringAsFixed(0)}'
                                    : 'Enter total amount',
                            style: AppTheme.bodyStyle(size: 15, weight: FontWeight.w600),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate splits are balanced
    if (!_isBalanced) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Split amounts must total ₹${_totalEntered.toStringAsFixed(0)}. '
              'Remaining: ₹${_remainder.toStringAsFixed(0)}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Validate each split has a positive amount
    for (final split in _splits) {
      final amt = double.tryParse(split.amount) ?? 0;
      if (amt <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Each split must have an amount > 0'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    final notifier = ref.read(transactionNotifierProvider.notifier);

    try {
      for (final split in _splits) {
        final amt = double.tryParse(split.amount) ?? 0;
        if (amt <= 0) continue;

        await notifier.addTransaction(
          amount: amt,
          categoryId: split.categoryId,
          note: 'Split: ${split.categoryId}',
          date: _selectedDate,
          paymentMethod: _paymentMethod,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_splits.length} split transactions saved ✓'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save splits: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _SplitLine {
  String categoryId;
  String amount;

  _SplitLine({required this.categoryId, this.amount = ''});
}

class _SplitLineRow extends StatelessWidget {
  final _SplitLine split;
  final int index;
  final List<Category> categories;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final ColorScheme colorScheme;
  final bool isDark;

  const _SplitLineRow({
    required this.split,
    required this.index,
    required this.categories,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
    required this.colorScheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = Color(
      categories.where((c) => c.id == split.categoryId).firstOrNull?.color ?? 0xFF6B7280,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Category dropdown
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: catColor.withValues(alpha: 0.08),
                border: Border.all(color: catColor.withValues(alpha: 0.2)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: categories.any((c) => c.id == split.categoryId)
                      ? split.categoryId
                      : categories.firstOrNull?.id ?? 'other',
                  isExpanded: true,
                  style: AppTheme.bodyStyle(size: 13, color: colorScheme.onSurface),
                  dropdownColor: isDark ? Color(0xFF1C2333) : Colors.white,
                  items: categories.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Row(
                      children: [
                        Icon(getCategoryIcon(c.icon), size: 14,
                            color: Color(c.color)),
                        const SizedBox(width: 6),
                        Text(c.name, style: AppTheme.bodyStyle(size: 12)),
                      ],
                    ),
                  )).toList(),
                  onChanged: (v) {
                    split.categoryId = v ?? 'other';
                    onChanged();
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Amount field
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: TextEditingController(text: split.amount),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTheme.financialStyle(size: 14, weight: FontWeight.w600),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: AppTheme.financialStyle(size: 12, weight: FontWeight.w600),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
                  ),
                  isDense: true,
                ),
                onChanged: (v) {
                  split.amount = v;
                  onChanged();
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Remove button
          if (canRemove)
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.error.withValues(alpha: 0.1),
                ),
                child: Icon(LucideIcons.x, size: 14, color: AppColors.error),
              ),
            )
          else
            const SizedBox(width: 26),
        ],
      ),
    );
  }
}
