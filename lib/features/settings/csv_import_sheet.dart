import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/csv_importer.dart';
import '../../core/utils/duplicate_detector.dart';
import '../../core/database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/transaction_provider.dart';

/// Bottom sheet for importing transactions from a bank statement CSV.
class CsvImportSheet extends ConsumerStatefulWidget {
  const CsvImportSheet({super.key});

  @override
  ConsumerState<CsvImportSheet> createState() => _CsvImportSheetState();
}

class _CsvImportSheetState extends ConsumerState<CsvImportSheet> {
  CsvImportResult? _result;
  bool _loading = false;
  bool _importing = false;
  List<int> _selectedRows = [];
  String _categoryName = 'other';
  String _accountId = 'default';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final accounts = ref.watch(accountsListProvider).valueOrNull ?? [];

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
              width: 40, height: 4,
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
                Icon(LucideIcons.fileSpreadsheet, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _result != null ? 'Review Import' : 'Import Bank Statement',
                    style: AppTheme.displayStyle(
                      size: 18, weight: FontWeight.w600, color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (!_loading)
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            )
          else if (_result == null)
            _buildPickFileView(colorScheme, isDark)
          else
            _buildPreviewView(colorScheme, isDark, categories, accounts),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPickFileView(ColorScheme colorScheme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.08),
            ),
            child: Icon(
              LucideIcons.fileUp,
              size: 36,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a bank statement CSV file',
            style: AppTheme.displayStyle(
              size: 16, weight: FontWeight.w600, color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Supports most Indian bank formats.\nColumns will be auto-detected.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyStyle(
              size: 13, color: colorScheme.onSurfaceVariant, height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _pickFile,
            icon: const Icon(LucideIcons.folderOpen, size: 18),
            label: const Text('Choose CSV File'),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _loadSampleData(),
            icon: const Icon(LucideIcons.flaskConical, size: 16),
            label: const Text('Try with sample CSV'),
          ),
          // Sample format preview
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expected format:',
                  style: AppTheme.bodyStyle(
                    size: 10, weight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Date, Narration, Withdrawal, Deposit, Balance\n'
                  '01/01/2026, Swiggy order, 450.00, , 5000.00\n'
                  '02/01/2026, Salary credit, , 50000.00, 55000.00',                    style: AppTheme.bodyStyle(
                      size: 10, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewView(ColorScheme colorScheme, bool isDark,
      List<Category> categories, List<Account> accounts) {
    if (_result == null) return const SizedBox.shrink();

    return Flexible(
      child: Column(
        children: [
          // Summary bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _result!.skippedRows > 0
                  ? AppColors.warning.withValues(alpha: 0.1)
                  : AppColors.success.withValues(alpha: 0.1),
              border: Border.all(
                color: _result!.skippedRows > 0
                    ? AppColors.warning.withValues(alpha: 0.2)
                    : AppColors.success.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _result!.skippedRows > 0
                      ? LucideIcons.alertTriangle
                      : LucideIcons.checkCircle2,
                  size: 16,
                  color: _result!.skippedRows > 0
                      ? AppColors.warning
                      : AppColors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_result!.validCount} valid transaction${_result!.validCount != 1 ? 's' : ''}'
                    '${_result!.skippedRows > 0 ? ', ${_result!.skippedRows} skipped' : ''}',
                    style: AppTheme.bodyStyle(
                      size: 12, weight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Category & Account selectors
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildDropdown<String>(
                    value: _categoryName,
                    items: [
                      ...categories.where((c) => c.type == 'expense').map((c) =>
                        DropdownMenuItem(value: c.id, child: Text(c.name, style: AppTheme.bodyStyle(size: 13))),
                      ),
                    ],
                    hint: 'Category',
                    onChanged: (v) => setState(() => _categoryName = v ?? 'other'),
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDropdown<String>(
                    value: _accountId,
                    items: accounts.map((a) =>
                      DropdownMenuItem(value: a.id, child: Text(a.name, style: AppTheme.bodyStyle(size: 13))),
                    ).toList(),
                    hint: 'Account',
                    onChanged: (v) => setState(() => _accountId = v ?? 'default'),
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            ),
          ),

          // Preview table header
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 24),
                Expanded(flex: 2,
                  child: Text('Date', style: AppTheme.bodyStyle(
                      size: 10, weight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                ),
                Expanded(flex: 3,
                  child: Text('Description', style: AppTheme.bodyStyle(
                      size: 10, weight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                ),
                Expanded(flex: 2,
                  child: Text('Amount', textAlign: TextAlign.right, style: AppTheme.bodyStyle(
                      size: 10, weight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),

          // Transaction list (scrollable)
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _result!.transactions.length,
              itemBuilder: (context, index) {
                final t = _result!.transactions[index];
                final isSelected = _selectedRows.contains(index);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (isSelected) {
                      _selectedRows.remove(index);
                    } else {
                      _selectedRows.add(index);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: 100.ms,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.05),
                        ),
                      ),
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.05)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? LucideIcons.checkCircle : LucideIcons.circle,
                          size: 16,
                          color: isSelected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 6),
                        Expanded(flex: 2,
                          child: Text(
                            Formatters.formatDateShort(t.date),
                            style: AppTheme.bodyStyle(size: 11, color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                        Expanded(flex: 3,
                          child: Text(
                            t.description.length > 20
                                ? '${t.description.substring(0, 20)}…'
                                : t.description,
                            style: AppTheme.bodyStyle(size: 11, color: colorScheme.onSurface),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(flex: 2,
                          child: Text(
                            t.amount > 0
                                ? '-${Formatters.formatCurrency(t.amount)}'
                                : '+${Formatters.formatCurrency(t.amount.abs())}',
                            textAlign: TextAlign.right,
                            style: AppTheme.financialStyle(
                              size: 11, weight: FontWeight.w600,
                              color: t.amount > 0 ? AppColors.error : AppColors.success,
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

          // Error log (if any)
          if (_result!.errors.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.error.withValues(alpha: 0.05),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_result!.errors.length} error${_result!.errors.length != 1 ? 's' : ''}:',
                    style: AppTheme.bodyStyle(
                      size: 10, weight: FontWeight.w600, color: AppColors.error,
                    ),
                  ),
                  ..._result!.errors.take(3).map((e) => Text(
                    e,
                    style: AppTheme.bodyStyle(size: 9, color: AppColors.error.withValues(alpha: 0.8)),
                  )),
                ],
              ),
            ),

          // Import button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_selectedRows.isNotEmpty && !_importing)
                    ? _importSelected
                    : null,
                icon: _importing
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.import, size: 18),
                label: Text(
                  _importing
                      ? 'Importing...'
                      : 'Import ${_selectedRows.length} transaction${_selectedRows.length != 1 ? 's' : ''}',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required String hint,
    required ValueChanged<T?> onChanged,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          style: AppTheme.bodyStyle(size: 13, color: colorScheme.onSurface),
          dropdownColor: colorScheme.surface,
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    setState(() => _loading = true);

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'CSV'],
      );

      if (result != null && result.files.single.path != null) {
        final importResult = await CsvImporter.importFile(
          filePath: result.files.single.path!,
        );
        if (mounted) {
          setState(() {
            _result = importResult;
            _loading = false;
            // Pre-select all valid rows
            _selectedRows = List.generate(
              importResult.transactions.length, (i) => i,
            );
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read file: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadSampleData() async {
    setState(() => _loading = true);

    // Simulate parsing by creating a sample result inline
    final now = DateTime.now();
    final sampleTransactions = [
      CsvTransactionRow(
        date: DateTime(now.year, now.month, 1),
        description: 'Swiggy order',
        amount: 450,
      ),
      CsvTransactionRow(
        date: DateTime(now.year, now.month, 3),
        description: 'Uber ride',
        amount: 320,
      ),
      CsvTransactionRow(
        date: DateTime(now.year, now.month, 5),
        description: 'Groceries at FreshMart',
        amount: 1250,
      ),
      CsvTransactionRow(
        date: DateTime(now.year, now.month, 7),
        description: 'Electricity bill',
        amount: 2400,
      ),
      CsvTransactionRow(
        date: DateTime(now.year, now.month, 10),
        description: 'Netflix subscription',
        amount: 499,
      ),
      CsvTransactionRow(
        date: DateTime(now.year, now.month, 12),
        description: 'Zara clothing',
        amount: 3200,
      ),
      CsvTransactionRow(
        date: DateTime(now.year, now.month, 15),
        description: 'Monthly rent',
        amount: 15000,
      ),
      CsvTransactionRow(
        date: DateTime(now.year, now.month, 18),
        description: 'Petrol',
        amount: 1200,
      ),
      CsvTransactionRow(
        date: DateTime(now.year, now.month, 20),
        description: 'Salary credit',
        amount: -60000,
      ),
    ];

    // Simulate a small delay for realism
    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) {
      setState(() {
        _result = CsvImportResult(
          transactions: sampleTransactions,
          totalRows: sampleTransactions.length,
          skippedRows: 0,
          errors: [],
        );
        _loading = false;
        _selectedRows = List.generate(
          sampleTransactions.length, (i) => i,
        );
      });
    }
  }

  Future<void> _importSelected() async {
    if (_result == null || _selectedRows.isEmpty) return;

    setState(() => _importing = true);
    final db = ref.read(databaseProvider);
    final existingTxns = ref.read(transactionsProvider).valueOrNull ?? [];
    int imported = 0;
    int skipped = 0;

    for (final idx in _selectedRows) {
      final row = _result!.transactions[idx];

      // Map description to category using keyword matching (similar to SmsParser)
      String categoryId = _categoryName; // default to user-selected
      final desc = row.description.toLowerCase();

      if (desc.contains('swiggy') || desc.contains('zomato') ||
          desc.contains('food') || desc.contains('restaurant') ||
          desc.contains('cafe') || desc.contains('mcdonald') ||
          desc.contains('kfc') || desc.contains('pizza') ||
          desc.contains('groceri') || desc.contains('fresh') ||
          desc.contains('supermarket')) {
        categoryId = 'food';
      } else if (desc.contains('uber') || desc.contains('ola') ||
          desc.contains('metro') || desc.contains('petrol') ||
          desc.contains('fuel') || desc.contains('taxi') ||
          desc.contains('railway') || desc.contains('cab')) {
        categoryId = 'transport';
      } else if (desc.contains('rent') || desc.contains('housing') ||
          desc.contains('pg ')) {
        categoryId = 'rent';
      } else if (desc.contains('amazon') || desc.contains('flipkart') ||
          desc.contains('myntra') || desc.contains('zara') ||
          desc.contains('cloth') || desc.contains('shoe') ||
          desc.contains('shopping') || desc.contains('store') ||
          desc.contains('mart')) {
        categoryId = 'shopping';
      } else if (desc.contains('bill') || desc.contains('electricity') ||
          desc.contains('broadband') || desc.contains('recharge') ||
          desc.contains('water') || desc.contains('gas') ||
          desc.contains('insurance') || desc.contains('netflix') ||
          desc.contains('subscription') || desc.contains('phone') ||
          desc.contains('jio') || desc.contains('airtel')) {
        categoryId = 'bills';
      } else if (desc.contains('salary') || desc.contains('credit')) {
        categoryId = 'income';
      }

      // Check for duplicates
      final dupCheck = DuplicateDetector.findDuplicates(
        existingTransactions: existingTxns,
        amount: row.amount.abs(),
        categoryId: categoryId,
        date: row.date,
        note: row.description,
      );

      if (dupCheck.hasDuplicates) {
        skipped++;
        continue;
      }

      // Import the transaction
      try {
        final uuid = const Uuid().v4();
        final finalAmount = categoryId == 'income'
            ? -row.amount.abs()
            : row.amount.abs();

        await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: uuid,
          amount: finalAmount,
          categoryId: categoryId,
          accountId: _accountId,
          note: Value(row.description),
          date: row.date,
          paymentMethod: const Value('bank'),
        ));

        // Update account balance
        final account = await (db.select(db.accounts)
          ..where((a) => a.id.equals(_accountId))).getSingleOrNull();
        if (account != null) {
          await (db.update(db.accounts)..where((a) => a.id.equals(_accountId)))
              .write(AccountsCompanion(
                balance: Value(account.balance - finalAmount),
              ));
        }

        imported++;
      } catch (e) {
        skipped++;
      }
    }

    // Invalidate providers
    ref.invalidate(transactionsProvider);
    ref.invalidate(thisMonthTransactionsProvider);
    ref.invalidate(totalSpentThisMonthProvider);
    ref.invalidate(totalIncomeThisMonthProvider);
    ref.invalidate(accountsListProvider);

    setState(() => _importing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported $imported transaction${imported != 1 ? 's' : ''}'
            '${skipped > 0 ? ', $skipped skipped (duplicates)' : ''}',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    }
  }
}
