import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/database/database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/icon_helper.dart';
import '../../providers/budget_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  // 'expense' or 'income'

  const AddTransactionSheet({
    super.key,
    this.transaction,
    this.initialType = 'expense',
  });
  final Transaction? transaction; // null = add mode, non-null = edit mode
  final String initialType;

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _owedByCtrl = TextEditingController();

  late String _transactionType;
  late String _selectedCategory;
  late String _paymentMethod;
  late DateTime _selectedDate;
  late bool _isRecurring;
  late String? _recurringInterval;
  DateTime? _recurringEndDate;
  String? _receiptImagePath;
  bool _isReimbursementPending = false;
  int? _pressedCategoryIdx;
  bool get _isEditing => widget.transaction != null;

  bool get _hasData =>
      _amountCtrl.text.isNotEmpty ||
      _noteCtrl.text.isNotEmpty ||
      _tagsCtrl.text.isNotEmpty ||
      _receiptImagePath != null;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    if (t != null) {
      final isIncome = t.amount < 0;
      _transactionType = isIncome ? 'income' : 'expense';
      _selectedCategory = t.categoryId;
      _paymentMethod = t.paymentMethod;
      _selectedDate = t.date;
      _amountCtrl.text = t.amount.abs().toStringAsFixed(
        t.amount == t.amount.roundToDouble() ? 0 : 2,
      );
      _isRecurring = t.isRecurring;
      _recurringInterval = t.recurringInterval;
      _recurringEndDate = t.recurringEndDate;
      _receiptImagePath = t.receiptImagePath;
      final extracted = _extractTagsFromNote(t.note ?? '');
      _noteCtrl.text = extracted.cleanNote;
      if (extracted.tags.isNotEmpty) {
        _tagsCtrl.text = extracted.tags;
      }
    } else {
      _transactionType = widget.initialType;
      _selectedCategory = widget.initialType == 'income' ? 'income' : 'food';
      _paymentMethod = 'UPI';
      _selectedDate = DateTime.now();
      _isRecurring = false;
      _recurringInterval = null;
      _recurringEndDate = null;
      _receiptImagePath = null;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _tagsCtrl.dispose();
    _owedByCtrl.dispose();
    super.dispose();
  }

  static const List<String> _quickTags = [
    'Reimburse',
    'Parents',
    'Friends',
    'Urgent',
    'Subscription',
    'Office',
    'Travel',
    'Food',
    'Personal',
    'Bills',
    'Shopping',
  ];

  Set<String> _getSelectedTagsList() {
    return _tagsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  void _toggleTag(String tag) {
    final current = _getSelectedTagsList();
    final tagLower = tag.trim().toLowerCase();
    final existing = current.firstWhere(
      (e) => e.toLowerCase() == tagLower,
      orElse: () => '',
    );
    if (existing.isNotEmpty) {
      current.remove(existing);
    } else {
      current.add(tag);
    }
    _tagsCtrl.text = current.join(', ');
    setState(() {});
  }

  /// Uses the persisted auto-categorization rules from the provider.
  String? _detectCategory(String note) {
    return ref
        .read(autoCategorizationRulesProvider.notifier)
        .detectCategory(note);
  }

  void _setTransactionType(String type, List<Category> allCategories) {
    setState(() {
      _transactionType = type;
      final filtered = allCategories.where((c) => c.type == type).toList();
      if (filtered.isNotEmpty) {
        _selectedCategory = filtered.first.id;
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 70);
      if (!mounted) return;
      if (picked != null) {
        setState(() => _receiptImagePath = picked.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick photo: $e')));
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasData) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Discard changes?', style: AppTheme.displayStyle()),
        content: Text(
          'You have unsaved data. Are you sure you want to discard it?',
          style: AppTheme.bodyStyle(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
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
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allCategories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final categories = allCategories
        .where((c) => c.type == _transactionType)
        .toList();
    final isSubmitting = ref.watch(transactionNotifierProvider).isLoading;

    return PopScope(
      canPop: !_hasData,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title row with optional close button
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit Transaction' : 'Add Transaction',
                        style: AppTheme.displayStyle(
                          size: 20,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (_hasData)
                      GestureDetector(
                        onTap: () async {
                          final shouldPop = await _onWillPop();
                          if (shouldPop && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.surfaceContainerHighest,
                          ),
                          child: Icon(
                            LucideIcons.x,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Expense / Income toggle
                Row(
                  children: [
                    Expanded(
                      child: _TypeButton(
                        label: 'Expense',
                        selected: _transactionType == 'expense',
                        color: colorScheme.primary,
                        onTap: _isEditing
                            ? null
                            : () =>
                                  _setTransactionType('expense', allCategories),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TypeButton(
                        label: 'Income',
                        selected: _transactionType == 'income',
                        color: AppColors.success,
                        onTap: _isEditing
                            ? null
                            : () =>
                                  _setTransactionType('income', allCategories),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Amount field
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: !_isEditing,
                  style: AppTheme.financialStyle(size: 18),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                    prefixStyle: AppTheme.financialStyle(size: 18),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter an amount';
                    final parsed = double.tryParse(v);
                    if (parsed == null) return 'Enter a valid number';
                    if (parsed <= 0) return 'Amount must be greater than 0';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Category selector with validation
                Text(
                  'Category',
                  style: AppTheme.bodyStyle(
                    size: 13,
                    weight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                FormField<String>(
                  initialValue: _selectedCategory,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Select a category';
                    return null;
                  },
                  builder: (field) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...categories.map((cat) {
                              final selected = _selectedCategory == cat.id;
                              final catColor = Color(cat.color);
                              final idx = categories.indexOf(cat);
                              return GestureDetector(
                                onTapDown: (_) =>
                                    setState(() => _pressedCategoryIdx = idx),
                                onTapUp: (_) =>
                                    setState(() => _pressedCategoryIdx = null),
                                onTapCancel: () =>
                                    setState(() => _pressedCategoryIdx = null),
                                onTap: () {
                                  setState(() => _selectedCategory = cat.id);
                                  field.didChange(cat.id);
                                },
                                child: AnimatedScale(
                                  scale: _pressedCategoryIdx == idx
                                      ? 0.94
                                      : 1.0,
                                  duration: const Duration(milliseconds: 120),
                                  curve: Curves.easeOut,
                                  child: AnimatedContainer(
                                    duration: 200.ms,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: selected
                                          ? catColor.withValues(alpha: 0.15)
                                          : colorScheme.surfaceContainerHighest
                                                .withValues(alpha: 0.5),
                                      border: selected
                                          ? Border.all(
                                              color: catColor.withValues(
                                                alpha: 0.4,
                                              ),
                                              width: 1.5,
                                            )
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          getCategoryIcon(cat.icon),
                                          size: 18,
                                          color: selected
                                              ? catColor
                                              : colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          cat.name,
                                          style: AppTheme.bodyStyle(
                                            size: 13,
                                            weight: selected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: selected
                                                ? catColor
                                                : colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                        if (field.hasError)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Text(
                              field.errorText!,
                              style: AppTheme.bodyStyle(
                                size: 12,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // ── Tags Section with Selectable Chips ──
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.tag,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Select Tags',
                          style: AppTheme.bodyStyle(
                            size: 13,
                            weight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickTags.map((tag) {
                        final selected = _getSelectedTagsList().any(
                          (t) => t.toLowerCase() == tag.toLowerCase(),
                        );
                        return FilterChip(
                          label: Text(tag),
                          selected: selected,
                          onSelected: (_) => _toggleTag(tag),
                          showCheckmark: true,
                          checkmarkColor: colorScheme.onPrimary,
                          selectedColor: colorScheme.primary,
                          labelStyle: AppTheme.bodyStyle(
                            size: 12,
                            weight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: selected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                          ),
                          backgroundColor: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: selected
                                  ? colorScheme.primary
                                  : colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _tagsCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Custom Tags (or edit list)',
                        hintText: 'e.g. office, travel, urgent',
                        prefixIcon: const Icon(LucideIcons.tag, size: 16),
                        suffixIcon: _tagsCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(LucideIcons.x, size: 16),
                                onPressed: () {
                                  _tagsCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
                // ── Reimbursement / Owed to Me Section ──
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _isReimbursementPending
                        ? colorScheme.primary.withValues(alpha: 0.08)
                        : colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.3,
                          ),
                    border: Border.all(
                      color: _isReimbursementPending
                          ? colorScheme.primary.withValues(alpha: 0.3)
                          : colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Row(
                          children: [
                            Icon(
                              LucideIcons.handCoins,
                              size: 16,
                              color: _isReimbursementPending
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Paid for someone else (Reimbursement)',
                                style: AppTheme.bodyStyle(
                                  size: 13,
                                  weight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'Track money owed to you by parents/friends',
                          style: AppTheme.bodyStyle(
                            size: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        value: _isReimbursementPending,
                        onChanged: (val) =>
                            setState(() => _isReimbursementPending = val),
                      ),
                      if (_isReimbursementPending) ...[
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _owedByCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Owed By (e.g. Parents, Friends, Rahul)',
                            prefixIcon: Icon(LucideIcons.user, size: 16),
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: ['Parents', 'Friends', 'Roommate'].map((
                            name,
                          ) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                label: Text(name),
                                labelStyle: AppTheme.bodyStyle(
                                  size: 11,
                                  weight: FontWeight.w500,
                                ),
                                onPressed: () =>
                                    setState(() => _owedByCtrl.text = name),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Note
                TextFormField(
                  controller: _noteCtrl,
                  decoration: InputDecoration(
                    labelText: 'Note (optional)',
                    suffixIcon: _noteCtrl.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _noteCtrl.clear();
                              setState(() {});
                            },
                            child: const Icon(LucideIcons.x, size: 16),
                          )
                        : null,
                  ),
                  maxLines: 2,
                  onChanged: (value) {
                    setState(() {});
                    if (_isEditing) return;
                    final category = _detectCategory(value);
                    if (category != null) {
                      setState(() => _selectedCategory = category);
                    }
                  },
                ),
                if (widget.transaction?.payee != null &&
                    widget.transaction!.payee!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.6,
                        ),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _transactionType == 'income'
                                ? LucideIcons.userCheck
                                : LucideIcons.store,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_transactionType == "income" ? "Sender" : "Paid to"}: ',
                            style: AppTheme.bodyStyle(
                              size: 12,
                              weight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.transaction!.payee!,
                              style: AppTheme.bodyStyle(
                                size: 12,
                                weight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            LucideIcons.lock,
                            size: 12,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Date picker & Payment method row
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
                          if (!mounted) return;
                          if (date != null) {
                            setState(() => _selectedDate = date);
                          }
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
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: AppConstants.paymentMethods
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(
                                  m,
                                  style: AppTheme.bodyStyle(size: 13),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _paymentMethod = v ?? 'Cash'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Recurring toggle
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isRecurring
                          ? colorScheme.primary.withValues(alpha: 0.3)
                          : colorScheme.outline.withValues(alpha: 0.15),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            LucideIcons.rotateCw,
                            size: 18,
                            color: _isRecurring
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Recurring Transaction',
                              style: AppTheme.bodyStyle(
                                weight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: _isRecurring,
                            onChanged: (v) => setState(() {
                              _isRecurring = v;
                              if (!v) _recurringInterval = null;
                            }),
                          ),
                        ],
                      ),
                      if (_isRecurring) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: DropdownButtonFormField<String>(
                            initialValue: _recurringInterval,
                            decoration: InputDecoration(
                              labelText: 'Repeat every',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              isDense: true,
                            ),
                            items: AppConstants.recurringIntervals
                                .map(
                                  (interval) => DropdownMenuItem(
                                    value: interval,
                                    child: Text(
                                      interval[0].toUpperCase() +
                                          interval.substring(1),
                                      style: AppTheme.bodyStyle(size: 13),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _recurringInterval = v),
                            validator: (v) {
                              if (_isRecurring && v == null) {
                                return 'Select interval';
                              }
                              return null;
                            },
                          ),
                        ),
                        // Optional end date
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        _recurringEndDate ??
                                        _selectedDate.add(
                                          const Duration(days: 365),
                                        ),
                                    firstDate: _selectedDate,
                                    lastDate: DateTime(2035),
                                  );
                                  if (!mounted) return;
                                  if (date != null) {
                                    setState(() => _recurringEndDate = date);
                                  }
                                },
                                icon: Icon(
                                  LucideIcons.calendarX,
                                  size: 14,
                                  color: _recurringEndDate != null
                                      ? AppColors.error
                                      : colorScheme.onSurfaceVariant,
                                ),
                                label: Text(
                                  _recurringEndDate != null
                                      ? 'Ends ${_recurringEndDate!.day}/${_recurringEndDate!.month}/${_recurringEndDate!.year}'
                                      : 'No end date (optional)',
                                  style: AppTheme.bodyStyle(size: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  side: BorderSide(
                                    color: _recurringEndDate != null
                                        ? AppColors.error.withValues(alpha: 0.3)
                                        : colorScheme.outline.withValues(
                                            alpha: 0.2,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            if (_recurringEndDate != null)
                              IconButton(
                                icon: const Icon(
                                  LucideIcons.x,
                                  size: 16,
                                  color: AppColors.error,
                                ),
                                onPressed: () =>
                                    setState(() => _recurringEndDate = null),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Receipt photo
                Text(
                  'Attach Receipt Photo',
                  style: AppTheme.bodyStyle(
                    size: 13,
                    weight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                if (_receiptImagePath != null)
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _showReceiptViewer(context),
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colorScheme.outline.withValues(
                                alpha: 0.15,
                              ),
                            ),
                            image: DecorationImage(
                              image: FileImage(File(_receiptImagePath!)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _receiptImagePath = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black54,
                            ),
                            child: const Icon(
                              LucideIcons.x,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn()
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(LucideIcons.camera, size: 16),
                          label: Text(
                            'Take Photo',
                            style: AppTheme.bodyStyle(size: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(LucideIcons.image, size: 16),
                          label: Text(
                            'Choose Gallery',
                            style: AppTheme.bodyStyle(size: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),

                // Submit button
                FilledButton(
                  onPressed: isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _isEditing ? 'Update Transaction' : 'Add Transaction',
                          style: AppTheme.bodyStyle(
                            size: 15,
                            weight: FontWeight.w600,
                          ),
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showReceiptViewer(BuildContext context) async {
    if (_receiptImagePath == null) return;
    final deleteRequested = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _FullReceiptViewer(imagePath: _receiptImagePath!),
      ),
    );
    // The viewer's trash button pops with `true` — actually remove the
    // receipt instead of silently keeping it attached.
    if (deleteRequested == true && mounted) {
      setState(() => _receiptImagePath = null);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    unawaited(HapticFeedback.lightImpact());
    final amount = double.parse(_amountCtrl.text);
    if (amount <= 0) return;

    final notifier = ref.read(transactionNotifierProvider.notifier);
    final tagsText = _tagsCtrl.text.trim();
    final mergedNote = _buildMergedNote(_noteCtrl.text.trim(), tagsText);

    if (_isEditing) {
      final updated = Transaction(
        id: widget.transaction!.id,
        amount: _transactionType == 'income' ? -amount.abs() : amount.abs(),
        categoryId: _selectedCategory,
        accountId: 'default',
        note: mergedNote,
        date: _selectedDate,
        paymentMethod: _paymentMethod,
        isRecurring: _isRecurring,
        isRecurringInstance: widget.transaction!.isRecurringInstance,
        recurringInterval: _recurringInterval,
        recurringEndDate: _recurringEndDate,
        receiptImagePath: _receiptImagePath,
        createdAt: widget.transaction!.createdAt,
      );
      await notifier.updateTransaction(updated);
    } else {
      await notifier.addTransaction(
        amount: amount,
        categoryId: _selectedCategory,
        note: mergedNote,
        date: _selectedDate,
        paymentMethod: _paymentMethod,
        isRecurring: _isRecurring,
        recurringInterval: _recurringInterval,
        recurringEndDate: _recurringEndDate,
        receiptImagePath: _receiptImagePath,
        isIncome: _transactionType == 'income',
      );

      // Check budget thresholds after adding
      if (mounted) {
        final budgetNotif = ref.read(budgetNotifierProvider.notifier);
        await budgetNotif.checkBudgetThresholds(
          context: context,
          categoryId: _selectedCategory,
        );
      }
    }

    if (mounted) Navigator.pop(context);
  }

  _TagExtractionResult _extractTagsFromNote(String note) {
    final tagRegex = RegExp(r'\s*\[([^\]]+)\]\s*$');
    final match = tagRegex.firstMatch(note);
    if (match != null) {
      return _TagExtractionResult(
        cleanNote: note.substring(0, match.start).trimRight(),
        tags: match.group(1)?.trim() ?? '',
      );
    }
    return _TagExtractionResult(cleanNote: note, tags: '');
  }

  String? _buildMergedNote(String note, String tags) {
    var resultNote = note.trim();
    if (_isReimbursementPending) {
      final person = _owedByCtrl.text.trim().isEmpty
          ? 'Parents'
          : _owedByCtrl.text.trim();
      final tagStr = '[Owed by: $person]';
      if (!resultNote.contains('[Owed by:')) {
        resultNote = resultNote.isEmpty ? tagStr : '$resultNote $tagStr';
      }
    }
    if (resultNote.isEmpty && tags.isEmpty) return null;
    final buffer = StringBuffer();
    if (resultNote.isNotEmpty) buffer.write(resultNote);
    if (tags.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write('[$tags]');
    }
    final result = buffer.toString().trim();
    return result.isEmpty ? null : result;
  }
}

/// Full-screen receipt photo viewer with pinch-zoom
class _FullReceiptViewer extends StatelessWidget {
  const _FullReceiptViewer({required this.imagePath});
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Receipt'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.trash2),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.file(
            File(imagePath),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.imageOff,
                  size: 64,
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                const Text('Could not load image'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TagExtractionResult {
  const _TagExtractionResult({required this.cleanNote, required this.tags});
  final String cleanNote;
  final String tags;
}

class _TypeButton extends StatefulWidget {
  const _TypeButton({
    required this.label,
    required this.selected,
    required this.color,
    this.onTap,
  });
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  @override
  State<_TypeButton> createState() => _TypeButtonState();
}

class _TypeButtonState extends State<_TypeButton> {
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
        child: AnimatedContainer(
          duration: 200.ms,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: widget.selected
                ? widget.color.withValues(alpha: 0.15)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: widget.selected
                ? Border.all(color: widget.color, width: 1.5)
                : null,
          ),
          child: Text(
            widget.label,
            style: AppTheme.bodyStyle(
              size: 13,
              weight: widget.selected ? FontWeight.bold : FontWeight.w500,
              color: widget.selected
                  ? widget.color
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
