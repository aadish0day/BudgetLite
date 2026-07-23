import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/database_provider.dart';

/// A bottom sheet for transferring funds between accounts
class TransferSheet extends ConsumerStatefulWidget {
  const TransferSheet({super.key});

  @override
  ConsumerState<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<TransferSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _fromAccountId;
  String? _toAccountId;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accounts = ref.watch(accountsListProvider).valueOrNull ?? [];

    // Auto-select first two accounts if available
    if (_fromAccountId == null && accounts.length >= 2) {
      _fromAccountId = accounts[0].id;
      _toAccountId = accounts[1].id;
    } else if (_fromAccountId == null && accounts.length == 1) {
      _fromAccountId = accounts[0].id;
    }

    final fromAccount = accounts.where((a) => a.id == _fromAccountId).firstOrNull;
    final toAccount = accounts.where((a) => a.id == _toAccountId).firstOrNull;

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
              // Drag handle
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
                'Transfer Funds',
                style: AppTheme.displayStyle(
                  size: 20,
                  weight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),

              // Amount field
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTheme.financialStyle(size: 18, weight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  prefixStyle: AppTheme.financialStyle(size: 18, weight: FontWeight.w600),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter amount';
                  if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // From Account
              Text(
                'From Account',
                style: AppTheme.bodyStyle(
                  size: 13,
                  weight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _fromAccountId != null && accounts.any((a) => a.id == _fromAccountId)
                    ? _fromAccountId
                    : null,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: accounts.where((a) => a.id != _toAccountId).map((a) => DropdownMenuItem(
                  value: a.id,
                  child: Text('${a.name} (₹${a.balance.toStringAsFixed(0)})', style: AppTheme.bodyStyle(size: 14)),
                )).toList(),
                onChanged: (v) => setState(() => _fromAccountId = v),
              ),
              const SizedBox(height: 16),

              // Arrow down icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary.withValues(alpha: 0.1),
                  ),
                  child: Icon(LucideIcons.arrowDown, size: 20, color: colorScheme.primary),
                ),
              ),
              const SizedBox(height: 16),

              // To Account
              Text(
                'To Account',
                style: AppTheme.bodyStyle(
                  size: 13,
                  weight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _toAccountId != null && accounts.any((a) => a.id == _toAccountId)
                    ? _toAccountId
                    : null,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: accounts.where((a) => a.id != _fromAccountId).map((a) => DropdownMenuItem(
                  value: a.id,
                  child: Text('${a.name} (₹${a.balance.toStringAsFixed(0)})', style: AppTheme.bodyStyle(size: 14)),
                )).toList(),
                onChanged: (v) => setState(() => _toAccountId = v),
              ),
              const SizedBox(height: 16),

              // Note (optional)
              TextFormField(
                controller: _noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Transfer to savings',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Transfer summary
              if (fromAccount != null && toAccount != null && _amountCtrl.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    boxShadow: colorScheme.brightness == Brightness.dark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.info, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '₹${_amountCtrl.text} will be transferred from ${fromAccount.name} to ${toAccount.name}',
                          style: AppTheme.bodyStyle(size: 12, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(),
              const SizedBox(height: 20),

              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Transfer Funds',
                        style: AppTheme.bodyStyle(size: 15, weight: FontWeight.w600),
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
    if (_fromAccountId == null || _toAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both accounts'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (_fromAccountId == _toAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot transfer to the same account'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final amount = double.parse(_amountCtrl.text);

    try {
      await ref.read(transactionNotifierProvider.notifier).transferFunds(
        amount: amount,
        fromAccountId: _fromAccountId!,
        toAccountId: _toAccountId!,
        note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
        date: DateTime.now(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('₹${amount.toStringAsFixed(0)} transferred successfully ✓'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transfer failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}
