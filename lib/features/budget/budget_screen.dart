import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/icon_helper.dart';
import '../../core/utils/accessibility_utils.dart';
import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../core/database/database.dart';
import '../../providers/database_provider.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  String? _highlightTarget;
  Timer? _highlightTimer;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final budgets = ref.watch(thisMonthBudgetsProvider).valueOrNull ?? [];
    final spent = ref.watch(totalSpentThisMonthProvider).valueOrNull ?? 0;
    final income = ref.watch(totalIncomeThisMonthProvider).valueOrNull ?? 0;

    // Listen for budget highlight navigation (must be inside build)
    ref.listen<String?>(budgetHighlightProvider, (_, next) {
      if (next != null && mounted) {
        setState(() => _highlightTarget = next);
        _highlightTimer?.cancel();
        _highlightTimer = Timer(const Duration(milliseconds: 2500), () {
          if (mounted) {
            setState(() => _highlightTarget = null);
            ref.read(budgetHighlightProvider.notifier).state = null;
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Budget Setup',
          style: AppTheme.displayStyle(
            size: 17,
            weight: FontWeight.w600,
          ),
        ),
      ),
      body: categoriesAsync.when(
        loading: () => const _BudgetScreenSkeleton(),
        error: (_, _) => const Center(child: Text('Failed to load budget setup')),
        data: (categories) {
          final totalBudget = budgets.fold<double>(0, (sum, b) => sum + b.allocatedAmount);
          final remainingBudget = (totalBudget - spent);
          final overallRatio = totalBudget > 0 ? (spent / totalBudget).clamp(0.0, 1.0) : 0.0;

          return ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: AppConstants.screenPadding,
            children: [
              // ── Bento Hero Card: Monthly Budget & Spending Pacing ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [colorScheme.primaryContainer.withValues(alpha: 0.7), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                border: Border.all(
                  color: _highlightTarget != null
                      ? colorScheme.primary.withValues(alpha: 0.6)
                      : (isDark ? Colors.white.withValues(alpha: 0.1) : colorScheme.primary.withValues(alpha: 0.15)),
                  width: _highlightTarget != null ? 2 : 1,
                ),
                  boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(LucideIcons.pieChart, size: 18, color: colorScheme.primary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Monthly Budget Summary',
                                  style: AppTheme.displayStyle(size: 15, weight: FontWeight.w600, color: colorScheme.onSurface),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (remainingBudget >= 0 ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            remainingBudget >= 0 ? 'On Track' : 'Over Budget',
                            style: AppTheme.bodyStyle(
                              size: 11,
                              weight: FontWeight.w700,
                              color: remainingBudget >= 0 ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('MONTHLY INCOME', style: AppTheme.bodyStyle(size: 10, weight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                              const SizedBox(height: 2),
                              Text(
                                Formatters.formatCurrency(income),
                                style: AppTheme.financialStyle(size: 20, weight: FontWeight.w700, color: colorScheme.onSurface),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 36, color: colorScheme.outline.withValues(alpha: 0.15)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TOTAL ALLOCATED', style: AppTheme.bodyStyle(size: 10, weight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                              const SizedBox(height: 2),
                              Text(
                                Formatters.formatCurrency(totalBudget),
                                style: AppTheme.financialStyle(size: 20, weight: FontWeight.w700, color: colorScheme.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: overallRatio,
                        minHeight: 8,
                        backgroundColor: colorScheme.outline.withValues(alpha: 0.12),
                        color: remainingBudget >= 0 ? colorScheme.primary : AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Spent: ${Formatters.formatCurrency(spent)}',
                          style: AppTheme.bodyStyle(size: 12, color: colorScheme.onSurfaceVariant),
                        ),
                        Text(
                          remainingBudget >= 0
                              ? '${Formatters.formatCurrency(remainingBudget)} remaining'
                              : '${Formatters.formatCurrency(remainingBudget.abs())} over budget',
                          style: AppTheme.bodyStyle(
                            size: 12,
                            weight: FontWeight.w600,
                            color: remainingBudget >= 0 ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate(target: AccessibilityUtils.shouldAnimate(context) ? null : 1.0).fadeIn(duration: AppConstants.animNormal).slideY(begin: 0.05),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Category Allocation',
                    style: AppTheme.displayStyle(
                      size: 16,
                      weight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${categories.length} Categories',
                    style: AppTheme.bodyStyle(
                      size: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...categories.map((cat) {
                final budget = budgets.where((b) => b.categoryId == cat.id).firstOrNull;
                final allocated = budget?.allocatedAmount ?? 0;
                final hasRollover = budget?.rollover ?? false;

                return _BudgetSlot(
                  category: cat,
                  allocatedAmount: allocated,
                  rollover: hasRollover,
                  onSave: (amount, rollover) {
                    ref.read(budgetNotifierProvider.notifier).setBudget(
                      categoryId: cat.id,
                      amount: amount,
                      rollover: rollover,
                    );
                  },
                );
              }),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _showAddCategorySheet(context, ref),
                icon: const Icon(LucideIcons.plusCircle, size: 18),
                label: const Text('Add Custom Category', style: TextStyle(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  void _showAddCategorySheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => const _AddCategorySheet(),
    );
  }
}class _BudgetSlot extends StatefulWidget {
  final Category category;
  final double allocatedAmount;
  final bool rollover;
  final void Function(double amount, bool rollover) onSave;

  const _BudgetSlot({
    required this.category,
    required this.allocatedAmount,
    required this.rollover,
    required this.onSave,
  });

  @override
  State<_BudgetSlot> createState() => _BudgetSlotState();
}

class _BudgetSlotState extends State<_BudgetSlot> {
  late TextEditingController _ctrl;
  bool _rollover = false;
  bool _isRolloverPressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.allocatedAmount > 0 ? widget.allocatedAmount.toStringAsFixed(0) : '',
    );
    _rollover = widget.rollover;
  }

  @override
  void didUpdateWidget(_BudgetSlot old) {
    super.didUpdateWidget(old);
    if (widget.allocatedAmount != old.allocatedAmount && _ctrl.text.isEmpty) {
      _ctrl.text = widget.allocatedAmount > 0 ? widget.allocatedAmount.toStringAsFixed(0) : '';
    }
    // Sync rollover state from db updates
    if (widget.rollover != old.rollover) {
      setState(() => _rollover = widget.rollover);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final catColor = Color(widget.category.color);
    final isDark = colorScheme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.cardRadiusSmall),
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.cardRadiusIcon),
                color: catColor.withValues(alpha: 0.12),
              ),
              child: Icon(
                getCategoryIcon(widget.category.icon),
                size: 20,
                color: catColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.category.name,
                        style: AppTheme.bodyStyle(
                          size: 14,
                          weight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Consumer(
                        builder: (context, ref, _) {
                          final txns = ref.watch(thisMonthTransactionsProvider).valueOrNull ?? [];
                          final spentInCat = txns
                              .where((t) => t.categoryId == widget.category.id && t.amount > 0)
                              .fold<double>(0, (sum, t) => sum + t.amount);
                          final pct = widget.allocatedAmount > 0
                              ? (spentInCat / widget.allocatedAmount * 100).clamp(0, 100).toDouble()
                              : 0.0;
                          final isOver = widget.allocatedAmount > 0 && spentInCat > widget.allocatedAmount;

                          return Text(
                            widget.allocatedAmount > 0
                                ? '${Formatters.formatCurrency(spentInCat)} / ${Formatters.formatCurrency(widget.allocatedAmount)} (${pct.toStringAsFixed(0)}%)'
                                : '${Formatters.formatCurrency(spentInCat)} spent',
                            style: AppTheme.bodyStyle(
                              size: 11,
                              weight: FontWeight.w600,
                              color: isOver ? AppColors.error : colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Consumer(
                    builder: (context, ref, _) {
                      final txns = ref.watch(thisMonthTransactionsProvider).valueOrNull ?? [];
                      final spentInCat = txns
                          .where((t) => t.categoryId == widget.category.id && t.amount > 0)
                          .fold<double>(0, (sum, t) => sum + t.amount);
                      final ratio = widget.allocatedAmount > 0
                          ? (spentInCat / widget.allocatedAmount).clamp(0.0, 1.0)
                          : 0.0;
                      final pct = widget.allocatedAmount > 0 ? (spentInCat / widget.allocatedAmount * 100) : 0.0;

                      final Color progressColor;
                      if (pct <= 60) {
                        progressColor = AppColors.success;
                      } else if (pct <= 85) {
                        progressColor = AppColors.warning;
                      } else {
                        progressColor = AppColors.error;
                      }

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: widget.allocatedAmount > 0 ? ratio : 0.0,
                          minHeight: 5,
                          backgroundColor: colorScheme.outline.withValues(alpha: 0.1),
                          color: progressColor,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 100,
                        height: 36,
                        child: TextField(
                          controller: _ctrl,
                          keyboardType: TextInputType.number,
                          style: AppTheme.financialStyle(
                            size: 13,
                            weight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            prefixText: '₹ ',
                            prefixStyle: AppTheme.financialStyle(
                              size: 13,
                              weight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: colorScheme.outline.withValues(alpha: 0.2),
                              ),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _rollover = !_rollover),
                        onTapDown: (_) => setState(() => _isRolloverPressed = true),
                        onTapUp: (_) => setState(() => _isRolloverPressed = false),
                        onTapCancel: () => setState(() => _isRolloverPressed = false),
                        child: AnimatedScale(
                          scale: _isRolloverPressed ? 0.92 : 1.0,
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOut,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: _rollover
                                ? catColor.withValues(alpha: 0.12)
                                : Colors.transparent,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _rollover ? LucideIcons.rotateCw : LucideIcons.rotateCw,
                                size: 14,
                                color: _rollover ? catColor : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Rollover',
                                style: AppTheme.bodyStyle(
                                  size: 10,
                                  weight: FontWeight.w500,
                                  color: _rollover ? catColor : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                final text = _ctrl.text.trim();
                final amount = double.tryParse(text);
                // Reject empty/garbage/negative input instead of silently
                // saving 0 — a typo would wipe the category's allocation.
                if (text.isEmpty || amount == null || amount < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Enter a valid amount (0 or more)'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                widget.onSave(amount, _rollover);
              },
              icon: Icon(
                LucideIcons.circleCheckBig,
                color: colorScheme.primary,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCategorySheet extends ConsumerStatefulWidget {
  const _AddCategorySheet();

  @override
  ConsumerState<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends ConsumerState<_AddCategorySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _type = 'expense';
  Color _selectedColor = AppColors.categoryColors.first;
  String _selectedIcon = AppColors.categoryIcons.first;
  int? _pressedColorIdx;
  int? _pressedIconIdx;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
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
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            Text(
              'New Custom Category',
              style: AppTheme.displayStyle(
                size: 20,
                weight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _TypeButton(
                      label: 'Expense',
                      selected: _type == 'expense',
                      color: colorScheme.primary,
                      onTap: () => setState(() => _type = 'expense'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TypeButton(
                      label: 'Income',
                      selected: _type == 'income',
                      color: AppColors.success,
                      onTap: () => setState(() => _type = 'income'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nameCtrl,
                style: AppTheme.bodyStyle(size: 16),
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter name';
                  return null;
                },
              ),
              const SizedBox(height: 16),

            Text(
              'Select Color',
              style: AppTheme.bodyStyle(
                size: 13,
                weight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: AppColors.categoryColors.length,
                  itemBuilder: (ctx, idx) {
                    final color = AppColors.categoryColors[idx];
                    final isSelected = _selectedColor.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTapDown: (_) => setState(() => _pressedColorIdx = idx),
                      onTapUp: (_) => setState(() => _pressedColorIdx = null),
                      onTapCancel: () => setState(() => _pressedColorIdx = null),
                      onTap: () => setState(() => _selectedColor = color),
                      child: AnimatedScale(
                        scale: _pressedColorIdx == idx ? 0.88 : 1.0,
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.easeOut,
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: isSelected
                                ? Border.all(color: colorScheme.onSurface, width: 2)
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(LucideIcons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

            Text(
              'Select Icon',
              style: AppTheme.bodyStyle(
                size: 13,
                weight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: AppColors.categoryIcons.length,
                  itemBuilder: (ctx, idx) {
                    final iconName = AppColors.categoryIcons[idx];
                    final isSelected = _selectedIcon == iconName;
                    return GestureDetector(
                      onTapDown: (_) => setState(() => _pressedIconIdx = idx),
                      onTapUp: (_) => setState(() => _pressedIconIdx = null),
                      onTapCancel: () => setState(() => _pressedIconIdx = null),
                      onTap: () => setState(() => _selectedIcon = iconName),
                      child: AnimatedScale(
                        scale: _pressedIconIdx == idx ? 0.88 : 1.0,
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.easeOut,
                        child: AnimatedContainer(
                          duration: 150.ms,
                          margin: const EdgeInsets.only(right: 10),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: isSelected
                                ? _selectedColor.withValues(alpha: 0.15)
                                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            border: isSelected
                                ? Border.all(color: _selectedColor, width: 1.5)
                                : null,
                          ),
                          child: Icon(
                            getCategoryIcon(iconName),
                            size: 18,
                            color: isSelected ? _selectedColor : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),

              FilledButton(
                onPressed: _isSaving ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Add Category',
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
    );
  }

  bool _isSaving = false;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);
    try {
      final db = ref.read(databaseProvider);
      final uuid = const Uuid().v4();

      await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: uuid,
        name: _nameCtrl.text.trim(),
        icon: Value(_selectedIcon),
        color: Value(_selectedColor.toARGB32()),
        type: Value(_type),
      ));

      ref.invalidate(categoriesProvider);
      ref.invalidate(expenseCategoriesProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Custom category "${_nameCtrl.text.trim()}" added!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _TypeButton extends StatefulWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

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
            border: widget.selected ? Border.all(color: widget.color, width: 1.5) : null,
          ),
          child: Text(
            widget.label,
            style: AppTheme.bodyStyle(
              size: 13,
              weight: widget.selected ? FontWeight.bold : FontWeight.w500,
              color: widget.selected ? widget.color : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetScreenSkeleton extends StatelessWidget {
  const _BudgetScreenSkeleton();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: AppConstants.screenPadding,
      children: [
        // Income card skeleton
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          ),
        ).animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, color: colorScheme.primary.withValues(alpha: 0.08)),
        const SizedBox(height: 24),
        // Section header skeleton
        Container(
          width: 160, height: 18,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
        ).animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, delay: 200.ms, color: colorScheme.primary.withValues(alpha: 0.08)),
        const SizedBox(height: 16),
        // Budget slot skeletons
        ...List.generate(4, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppConstants.cardRadiusSmall),
            ),
          ).animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 1200.ms, delay: ((i + 2) * 150).ms, color: colorScheme.primary.withValues(alpha: 0.08)),
        )),
      ],
    );
  }
}
