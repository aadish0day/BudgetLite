import 'package:flutter_test/flutter_test.dart';
import 'package:budget_lite/core/utils/duplicate_detector.dart';
import 'package:budget_lite/core/database/database.dart';

void main() {
  group('DuplicateDetector Tests', () {
    final List<Transaction> existingTransactions = [
      Transaction(
        id: '1',
        accountId: 'default',
        amount: 50.0,
        categoryId: 'food',
        note: 'chaurasiayavijaykumar',
        date: DateTime(2026, 7, 8),
        paymentMethod: 'UPI',
        isRecurring: false,
        isRecurringInstance: false,
        createdAt: DateTime(2026, 7, 8),
      ),
      Transaction(
        id: '2',
        accountId: 'default',
        amount: -8000.0, // Income
        categoryId: 'income',
        note: 'PARENTS Pocket Money',
        date: DateTime(2026, 7, 10),
        paymentMethod: 'UPI',
        isRecurring: false,
        isRecurringInstance: false,
        createdAt: DateTime(2026, 7, 10),
      ),
    ];

    test('Detects exact duplicate debit transaction', () {
      final result = DuplicateDetector.findDuplicates(
        existingTransactions: existingTransactions,
        amount: 50.0,
        date: DateTime(2026, 7, 8),
        note: 'chaurasiayavijaykumar',
        isIncome: false,
      );

      expect(result.isNotEmpty, true);
      expect(result.first.id, '1');
    });

    test('Does not flag debit as duplicate of credit with same amount', () {
      final result = DuplicateDetector.findDuplicates(
        existingTransactions: existingTransactions,
        amount: 8000.0,
        date: DateTime(2026, 7, 10),
        note: 'PARENTS',
        isIncome: false, // Expense check vs Income existing
      );

      expect(result.isEmpty, true);
    });

    test('Detects duplicate credit/income transaction', () {
      final result = DuplicateDetector.findDuplicates(
        existingTransactions: existingTransactions,
        amount: 8000.0,
        date: DateTime(2026, 7, 10),
        note: 'PARENTS',
        isIncome: true, // Income check vs Income existing
      );

      expect(result.isNotEmpty, true);
      expect(result.first.id, '2');
    });
  });
}
