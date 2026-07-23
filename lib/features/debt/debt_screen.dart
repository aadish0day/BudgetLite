import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/arc_progress.dart';

/// Simple in-memory debt model (stored in AppSettings as JSON for simplicity)
class DebtEntry {
  final String id;
  final String name;
  final double totalAmount;
  final double paidAmount;
  final double interestRate; // annual %
  final DateTime startDate;
  final String category; // 'loan', 'emi', 'credit_card', 'personal'

  DebtEntry({
    required this.id,
    required this.name,
    required this.totalAmount,
    this.paidAmount = 0,
    this.interestRate = 0,
    required this.startDate,
    this.category = 'personal',
  });

  double get remainingAmount => totalAmount - paidAmount;
  double get progress => totalAmount > 0 ? (paidAmount / totalAmount).clamp(0, 1) : 0.0;
  int get monthsElapsed {
    final now = DateTime.now();
    return ((now.year - startDate.year) * 12 + (now.month - startDate.month)).clamp(0, 999);
  }
  double get monthlyEmi {
    if (interestRate <= 0 || remainingAmount <= 0) return remainingAmount / max(1, (12 - monthsElapsed));
    final monthlyRate = (interestRate / 12 / 100).toDouble();
    final months = max(1, 12 - monthsElapsed);
    final numerator = (monthlyRate * pow(1 + monthlyRate, months)).toDouble();
    final denominator = (pow(1 + monthlyRate, months) - 1).toDouble();
    if (denominator <= 0) return remainingAmount / months;
    return remainingAmount * (numerator / denominator);
  }
  int get monthsToPayoff {
    if (monthlyEmi <= 0) return 999;
    return (remainingAmount / monthlyEmi).ceil();
  }
  DateTime get payoffDate => startDate.add(Duration(days: monthsToPayoff * 30));
}

/// Provider that holds debts in memory (persisted via settings JSON)
final debtsProvider = StateNotifierProvider<DebtNotifier, List<DebtEntry>>((ref) {
  return DebtNotifier(ref);
});

class DebtNotifier extends StateNotifier<List<DebtEntry>> {
  DebtNotifier(this.ref) : super([]);
  final Ref ref;

  void addDebt(DebtEntry debt) {
    state = [...state, debt];
  }

  void makePayment(String debtId, double amount) {
    state = state.map((d) {
      if (d.id == debtId) {
        return DebtEntry(
          id: d.id,
          name: d.name,
          totalAmount: d.totalAmount,
          paidAmount: d.paidAmount + amount,
          interestRate: d.interestRate,
          startDate: d.startDate,
          category: d.category,
        );
      }
      return d;
    }).toList();
  }

  void deleteDebt(String id) {
    state = state.where((d) => d.id != id).toList();
  }
}

class DebtScreen extends ConsumerWidget {
  const DebtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(debtsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Debt Tracker', style: AppTheme.displayStyle(size: 17, weight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus, size: 20),
            onPressed: () => _showAddDebtSheet(context, ref),
          ),
        ],
      ),
      body: debts.isEmpty
          ? _EmptyDebts()
          : ListView(
              padding: AppConstants.screenPadding,
              children: [
                // Summary card
                _DebtSummary(debts: debts),
                const SizedBox(height: 20),
                ...debts.map((debt) => _DebtCard(debt: debt, ref: ref)),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  void _showAddDebtSheet(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final interestCtrl = TextEditingController();
    String category = 'personal';
    DateTime startDate = DateTime.now().subtract(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final colorScheme = Theme.of(context).colorScheme;
        bool isAddingDebt = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24, right: 24, top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Add Debt / Loan', style: AppTheme.displayStyle(size: 20, weight: FontWeight.w600, color: colorScheme.onSurface)),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Debt Name', hintText: 'e.g. Car Loan, Credit Card'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total Amount', prefixText: '₹ '),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: interestCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Interest Rate % (optional)', hintText: 'e.g. 12'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: ['personal', 'loan', 'emi', 'credit_card'].map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.replaceAll('_', ' ').toUpperCase(), style: AppTheme.bodyStyle(size: 13)),
                  )).toList(),
                  onChanged: (v) => setSheetState(() => category = v ?? 'personal'),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setSheetState(() => startDate = date);
                  },
                  icon: const Icon(LucideIcons.calendarDays, size: 16),
                  label: Text('Started: ${Formatters.formatDate(startDate)}'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isAddingDebt
                      ? null
                      : () {
                          final name = nameCtrl.text.trim();
                          final amount = double.tryParse(amountCtrl.text);
                          if (name.isEmpty || amount == null || amount <= 0) return;
                          setSheetState(() => isAddingDebt = true);
                          ref.read(debtsProvider.notifier).addDebt(DebtEntry(
                            id: const Uuid().v4(),
                            name: name,
                            totalAmount: amount,
                            interestRate: double.tryParse(interestCtrl.text) ?? 0,
                            startDate: startDate,
                            category: category,
                          ));
                          Navigator.pop(ctx);
                        },
                  style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                  child: isAddingDebt
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Add Debt', style: AppTheme.bodyStyle(size: 15, weight: FontWeight.w600)),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DebtSummary extends StatelessWidget {
  final List<DebtEntry> debts;
  const _DebtSummary({required this.debts});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final totalRemaining = debts.fold<double>(0.0, (s, d) => s + d.remainingAmount);
    final totalOriginal = debts.fold<double>(0.0, (s, d) => s + d.totalAmount);
    final totalPaid = debts.fold<double>(0.0, (s, d) => s + d.paidAmount);
    final overallProgress = totalOriginal > 0 ? (totalPaid / totalOriginal).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.error.withValues(alpha: 0.15), AppColors.error.withValues(alpha: 0.05)]
              : [AppColors.error.withValues(alpha: 0.08), AppColors.error.withValues(alpha: 0.02)],
        ),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
      ),
      padding: AppConstants.cardPadding,
      child: Row(
        children: [
          ArcProgress(
            progress: overallProgress,
            color: AppColors.error,
            size: 64,
            strokeWidth: 6,
            center: Center(
              child: Text(
                '${(overallProgress * 100).toStringAsFixed(0)}%',
                style: AppTheme.financialStyle(size: 14, weight: FontWeight.w700, color: AppColors.error),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Outstanding', style: AppTheme.bodyStyle(size: 12, color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  Formatters.formatCurrency(totalRemaining),
                  style: AppTheme.financialStyle(size: 28, weight: FontWeight.w700, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  '${debts.length} debt${debts.length > 1 ? 's' : ''} • ${Formatters.formatCurrency(totalPaid)} paid off',
                  style: AppTheme.bodyStyle(size: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _DebtCard extends StatelessWidget {
  final DebtEntry debt;
  final WidgetRef ref;
  const _DebtCard({required this.debt, required this.ref});

  void _showPaymentSheet(BuildContext context) {
    final amountCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final colorScheme = Theme.of(context).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Make Payment — ${debt.name}', style: AppTheme.displayStyle(size: 18, weight: FontWeight.w600)),
              const SizedBox(height: 16),
              Text('Remaining: ${Formatters.formatCurrency(debt.remainingAmount)}', style: AppTheme.bodyStyle(size: 14, color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Payment Amount', prefixText: '₹ '),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  final amount = double.tryParse(amountCtrl.text);
                  if (amount == null || amount <= 0) return;
                  ref.read(debtsProvider.notifier).makePayment(debt.id, amount);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('₹${amount.toStringAsFixed(0)} paid towards ${debt.name}'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: const Text('Record Payment'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final catColor = AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
      ),
      padding: AppConstants.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppConstants.cardRadiusIcon),
                  color: catColor.withValues(alpha: 0.12),
                ),
                child: Icon(
                  debt.category == 'credit_card' ? LucideIcons.creditCard : LucideIcons.landmark,
                  size: 22, color: catColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(debt.name, style: AppTheme.bodyStyle(size: 16, weight: FontWeight.w600, color: colorScheme.onSurface)),
                    Text('${debt.category.replaceAll('_', ' ')} • ${debt.monthsElapsed}mo in', style: AppTheme.bodyStyle(size: 11, color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              ArcProgress(
                progress: debt.progress,
                color: catColor,
                size: 48,
                strokeWidth: 4,
                center: Center(
                  child: Text(
                    '${(debt.progress * 100).toStringAsFixed(0)}%',
                    style: AppTheme.financialStyle(size: 11, weight: FontWeight.w700, color: catColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: debt.progress > 1 ? 1.0 : debt.progress,
              minHeight: 5,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(catColor),
            ),
          ),
          const SizedBox(height: 10),
          // Details row
          Row(
            children: [
              Expanded(
                child: _DetailColumn(label: 'Remaining', value: Formatters.formatCurrency(debt.remainingAmount), color: colorScheme.onSurface),
              ),
              Expanded(
                child: _DetailColumn(label: 'Monthly EMI', value: Formatters.formatCurrency(debt.monthlyEmi), color: colorScheme.primary),
              ),
              Expanded(
                child: _DetailColumn(label: 'Payoff by', value: Formatters.formatDate(debt.payoffDate), color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _showPaymentSheet(context),
                  icon: const Icon(LucideIcons.wallet, size: 14),
                  label: Text('Pay', style: AppTheme.bodyStyle(size: 12, weight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: catColor.withValues(alpha: 0.12),
                    foregroundColor: catColor,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () => ref.read(debtsProvider.notifier).deleteDebt(debt.id),
                icon: Icon(LucideIcons.trash2, size: 18, color: colorScheme.onSurfaceVariant),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }
}

class _DetailColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _DetailColumn({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.bodyStyle(size: 10, color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: AppTheme.financialStyle(size: 13, weight: FontWeight.w600, color: color, letterSpacing: -0.3)),
      ],
    );
  }
}

class _EmptyDebts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.landmark, size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No debts tracked', style: AppTheme.displayStyle(size: 18, weight: FontWeight.w600, color: colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('Add your loans and EMIs to track payoff progress', style: AppTheme.bodyStyle(size: 14, color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
