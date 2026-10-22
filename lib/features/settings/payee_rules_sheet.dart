import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/payee_tag_rule.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';

/// Bottom sheet for viewing, adding, editing, and reapplying Person & Merchant Tag Rules.
class PayeeRulesSheet extends ConsumerStatefulWidget {
  const PayeeRulesSheet({super.key});

  @override
  ConsumerState<PayeeRulesSheet> createState() => _PayeeRulesSheetState();
}

class _PayeeRulesSheetState extends ConsumerState<PayeeRulesSheet> {
  bool _showAddForm = false;
  String _newPayee = '';
  String _newTag = '';
  String _newCategoryId = 'food';
  bool _applyToPast = true;

  static const List<String> _quickTags = [
    'Cig',
    'Chai',
    'Food',
    'Snacks',
    'Grocery',
    'Travel',
    'Bills',
    'Personal',
    'Medicine',
  ];

  Future<void> _addRule() async {
    if (_newPayee.trim().isEmpty || _newTag.trim().isEmpty) return;
    final payee = _newPayee.trim();
    final tag = _newTag.trim();
    final notifier = ref.read(payeeTagRulesProvider.notifier);

    await notifier.addOrUpdateRule(
      payee: payee,
      tag: tag,
      categoryId: _newCategoryId,
    );

    int updated = 0;
    if (_applyToPast) {
      updated = await ref
          .read(transactionNotifierProvider.notifier)
          .updateTransactionsForPayee(
            payee: payee,
            tag: tag,
            categoryId: _newCategoryId,
          );
    }

    if (mounted) {
      final msg = updated > 0
          ? 'Rule saved & updated $updated past transaction${updated != 1 ? "s" : ""}!'
          : 'Rule saved successfully!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _showAddForm = false;
        _newPayee = '';
        _newTag = '';
      });
    }
  }

  Future<void> _reapplyRule(PayeeTagRule rule) async {
    final updated = await ref
        .read(transactionNotifierProvider.notifier)
        .updateTransactionsForPayee(
          payee: rule.payee,
          tag: rule.tag,
          categoryId: rule.categoryId,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated > 0
                ? 'Updated $updated transaction${updated != 1 ? "s" : ""} for "${rule.payee}"'
                : 'No past transactions found for "${rule.payee}"',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeRule(String id) async {
    await ref.read(payeeTagRulesProvider.notifier).deleteRule(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rule removed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final rules = ref.watch(payeeTagRulesProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: colorScheme.primary.withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    LucideIcons.tags,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Merchant & Payee Rules',
                        style: AppTheme.displayStyle(),
                      ),
                      Text(
                        'Auto-tag & categorize transactions by person or shop',
                        style: AppTheme.bodyStyle(
                          size: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _showAddForm = !_showAddForm),
                  icon: Icon(
                    _showAddForm ? LucideIcons.x : LucideIcons.plus,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          // Add form
          if (_showAddForm)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Person / Merchant Rule',
                    style: AppTheme.bodyStyle(weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Person / Shop name (e.g. Satyanarayan Communi)',
                      prefixIcon: const Icon(LucideIcons.store, size: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      isDense: true,
                    ),
                    style: AppTheme.bodyStyle(size: 13),
                    onChanged: (v) => _newPayee = v,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Tag to assign (e.g. cig)',
                      prefixIcon: const Icon(LucideIcons.tag, size: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      isDense: true,
                    ),
                    style: AppTheme.bodyStyle(size: 13),
                    onChanged: (v) => _newTag = v,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _quickTags.map((t) {
                      return GestureDetector(
                        onTap: () => setState(() => _newTag = t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            t,
                            style: AppTheme.bodyStyle(size: 11),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _newCategoryId,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      isDense: true,
                    ),
                    items: categories.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, style: AppTheme.bodyStyle(size: 13)),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _newCategoryId = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _applyToPast,
                          onChanged: (val) =>
                              setState(() => _applyToPast = val ?? true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Update all existing past transactions now',
                          style: AppTheme.bodyStyle(size: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _addRule,
                      icon: const Icon(LucideIcons.check, size: 16),
                      label: const Text('Save Rule'),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 200.ms),

          // Rules list
          Expanded(
            child: rules.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.tag,
                            size: 40,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No rules yet',
                            style: AppTheme.displayStyle(size: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tag a person when reviewing SMS (e.g. Satyanarayan Communi -> cig) and choose "Apply to all past & future" to add rules automatically!',
                            style: AppTheme.bodyStyle(
                              size: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: rules.length,
                    itemBuilder: (context, index) {
                      final rule = rules[index];
                      final category = categories
                          .where((c) => c.id == rule.categoryId)
                          .firstOrNull;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.25,
                          ),
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                              child: Icon(
                                LucideIcons.store,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rule.payee,
                                    style: AppTheme.bodyStyle(
                                      weight: FontWeight.w700,
                                      size: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.secondaryContainer
                                              .withValues(alpha: 0.4),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '🏷️ [${rule.tag}]',
                                          style: AppTheme.bodyStyle(
                                            size: 11,
                                            weight: FontWeight.w600,
                                            color: colorScheme.secondary,
                                          ),
                                        ),
                                      ),
                                      if (category != null) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '· ${category.name}',
                                          style: AppTheme.bodyStyle(
                                            size: 11,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(LucideIcons.refreshCw, size: 16),
                              tooltip: 'Re-apply to past transactions',
                              onPressed: () => _reapplyRule(rule),
                            ),
                            IconButton(
                              icon: const Icon(
                                LucideIcons.trash2,
                                size: 16,
                                color: AppColors.error,
                              ),
                              tooltip: 'Delete rule',
                              onPressed: () => _removeRule(rule.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
