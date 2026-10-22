import 'dart:io';

import 'package:budget_lite/core/database/database.dart';
import 'package:budget_lite/core/utils/csv_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final transactions = [
    Transaction(
      id: 'txn_1',
      amount: 250,
      categoryId: 'food',
      accountId: 'default',
      date: DateTime(2026, 7, 22, 14, 30),
      paymentMethod: 'UPI',
      isRecurring: false,
      isRecurringInstance: false,
      createdAt: DateTime(2026, 7, 22, 14, 30),
      payee: 'Swiggy',
      note: 'Lunch order',
    ),
    Transaction(
      id: 'txn_2',
      amount: 50000,
      categoryId: 'income',
      accountId: 'default',
      date: DateTime(2026, 7, 1, 10),
      paymentMethod: 'Bank Transfer',
      isRecurring: true,
      isRecurringInstance: false,
      createdAt: DateTime(2026, 7, 1, 10),
      payee: 'Employer Corp',
      note: 'Monthly Salary',
    ),
  ];

  final Map<String, Category> categoryMap = {
    'food': const Category(
      id: 'food',
      name: 'Food & Dining',
      icon: 'restaurant',
      color: 0xFFEF4444,
      type: 'expense',
      sortOrder: 1,
    ),
    'income': const Category(
      id: 'income',
      name: 'Salary',
      icon: 'account_balance',
      color: 0xFF10B981,
      type: 'income',
      sortOrder: 2,
    ),
  };

  test('generateCsvString produces valid formatted CSV string', () {
    final csv = CsvExporter.generateCsvString(
      transactions: transactions,
      categoryMap: categoryMap,
    );

    expect(
      csv,
      contains(
        'Date,Time,Type,Category,Amount,Payee / Merchant,Payment Method,Notes,Recurring',
      ),
    );
    expect(
      csv,
      contains(
        '2026-07-22,14:30:00,Expense,Food & Dining,250.00,Swiggy,UPI,Lunch order,No',
      ),
    );
    expect(
      csv,
      contains(
        '2026-07-01,10:00:00,Income,Salary,50000.00,Employer Corp,Bank Transfer,Monthly Salary,Yes',
      ),
    );
  });

  test('exportTransactions writes CSV file to provided directory', () async {
    final tempDir = Directory.systemTemp.createTempSync('csv_export_test_');
    try {
      final path = await CsvExporter.exportTransactions(
        transactions: transactions,
        categoryMap: categoryMap,
        outputDir: tempDir,
      );

      final file = File(path);
      expect(file.existsSync(), isTrue);

      final content = await file.readAsString();
      expect(content, contains('Swiggy'));
      expect(content, contains('Employer Corp'));
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });
}
