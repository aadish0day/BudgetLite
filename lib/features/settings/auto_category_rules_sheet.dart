import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/categorization_rule.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';

/// Bottom sheet for viewing/editing keyword-to-category auto-categorization rules.
/// Rules are persisted to AppSettings via [autoCategorizationRulesProvider].
class AutoCategoryRulesSheet extends ConsumerStatefulWidget {
  const AutoCategoryRulesSheet({super.key});

  @override
  ConsumerState<AutoCategoryRulesSheet> createState() =>
      _AutoCategoryRulesSheetState();
}

class _AutoCategoryRulesSheetState
    extends ConsumerState<AutoCategoryRulesSheet> {
  bool _showAddForm = false;
  String _newKeyword = '';
  String _newCategoryId = 'food';

  void _addRule() {
    if (_newKeyword.trim().isEmpty) return;
    final notifier = ref.read(autoCategorizationRulesProvider.notifier);
    final current = [...ref.read(autoCategorizationRulesProvider)];
    current.add(
      CategorizationRule(
        keyword: _newKeyword.trim(),
        categoryId: _newCategoryId,
      ),
    );
    notifier.setRules(current);
    setState(() {
      _showAddForm = false;
      _newKeyword = '';
    });
  }

  void _removeRule(int index) {
    final notifier = ref.read(autoCategorizationRulesProvider.notifier);
    final current = [...ref.read(autoCategorizationRulesProvider)];
    current.removeAt(index);
    notifier.setRules(current);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final allCats = categories.toList();
    final rules = ref.watch(autoCategorizationRulesProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
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
                Icon(
                  LucideIcons.brainCircuit,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Auto-Categorization Rules',
                    style: AppTheme.displayStyle(color: colorScheme.onSurface),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.plus, size: 18),
                  onPressed: () => setState(() => _showAddForm = !_showAddForm),
                ),
              ],
            ),
          ),

          // Add form
          if (_showAddForm)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Rule',
                    style: AppTheme.bodyStyle(
                      size: 12,
                      weight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Keywords (comma-separated)',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (v) => _newKeyword = v,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: colorScheme.surface,
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: allCats.any((c) => c.id == _newCategoryId)
                                  ? _newCategoryId
                                  : (allCats.isNotEmpty
                                        ? allCats.first.id
                                        : 'food'),
                              isExpanded: true,
                              style: AppTheme.bodyStyle(size: 13),
                              items: allCats
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(
                                        c.name,
                                        style: AppTheme.bodyStyle(size: 13),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _newCategoryId = v ?? 'food'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _newKeyword.trim().isEmpty ? null : _addRule,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.1),

          if (_showAddForm) const SizedBox(height: 12),

          // Rules list
          if (rules.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.listRestart,
                      size: 48,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No custom rules',
                      style: AppTheme.bodyStyle(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: rules.length,
                itemBuilder: (context, index) {
                  final rule = rules[index];
                  final cat = allCats
                      .where((c) => c.id == rule.categoryId)
                      .firstOrNull;
                  final catColor = Color(cat?.color ?? 0xFF6B7280);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.3,
                        ),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: catColor.withValues(alpha: 0.15),
                            ),
                            child: Text(
                              cat?.name ?? 'Unknown',
                              style: AppTheme.bodyStyle(
                                size: 11,
                                weight: FontWeight.w600,
                                color: catColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              rule.keyword,
                              style: AppTheme.bodyStyle(
                                size: 11,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _removeRule(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.error.withValues(alpha: 0.1),
                              ),
                              child: const Icon(
                                LucideIcons.trash2,
                                size: 14,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Info text
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Text(
              'Changes are saved automatically. When adding a transaction, '
              'the note text is checked against these keywords.',
              style: AppTheme.bodyStyle(
                size: 11,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
