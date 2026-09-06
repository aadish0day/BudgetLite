import 'package:budget_lite/core/database/database.dart';
import 'package:budget_lite/core/utils/duplicate_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DuplicateDetector Tests', () {
    final existingTransactions = [
      Transaction(
        id: '1',
        accountId: 'default',
        amount: 50,
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
        amount: -8000,
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
        amount: 50,
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
        amount: 8000,
        date: DateTime(2026, 7, 10),
        note: 'PARENTS',
        isIncome: false,
      );

      expect(result.isEmpty, true);
    });

    test('Detects duplicate credit/income transaction', () {
      final result = DuplicateDetector.findDuplicates(
        existingTransactions: existingTransactions,
        amount: 8000,
        date: DateTime(2026, 7, 10),
        note: 'PARENTS',
        isIncome: true,
      );

      expect(result.isNotEmpty, true);
      expect(result.first.id, '2');
    });

    test(
      'Detects duplicate transaction even if existing transaction has no note',
      () {
        final txnsWithEmptyNote = [
          Transaction(
            id: '3',
            accountId: 'default',
            amount: 250,
            categoryId: 'food',
            date: DateTime(2026, 7, 15),
            paymentMethod: 'UPI',
            isRecurring: false,
            isRecurringInstance: false,
            createdAt: DateTime(2026, 7, 15),
          ),
        ];

        final result = DuplicateDetector.findDuplicates(
          existingTransactions: txnsWithEmptyNote,
          amount: 250,
          categoryId: 'food',
          date: DateTime(2026, 7, 15),
          note: 'Swiggy order',
          isIncome: false,
        );

        expect(result.isNotEmpty, true);
        expect(result.first.id, '3');
      },
    );
  });
}
