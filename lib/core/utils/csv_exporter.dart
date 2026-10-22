import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database.dart';

/// Exports transaction records to standard CSV format.
abstract final class CsvExporter {
  /// Converts [transactions] into a CSV-formatted string.
  static String generateCsvString({
    required List<Transaction> transactions,
    required Map<String, Category> categoryMap,
  }) {
    final rows = <List<dynamic>>[
      [
        'Date',
        'Time',
        'Type',
        'Category',
        'Amount',
        'Payee / Merchant',
        'Payment Method',
        'Notes',
        'Recurring',
      ],
    ];

    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm:ss');

    for (final txn in transactions) {
      final category = categoryMap[txn.categoryId];
      final isExpense = category?.type != 'income';
      rows.add([
        dateFormat.format(txn.date),
        timeFormat.format(txn.date),
        if (isExpense) 'Expense' else 'Income',
        category?.name ?? txn.categoryId,
        txn.amount.toStringAsFixed(2),
        txn.payee ?? '',
        txn.paymentMethod,
        txn.note ?? '',
        if (txn.isRecurring) 'Yes' else 'No',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Converts [transactions] into CSV and writes to a temporary file.
  /// Returns the file path of the generated CSV file.
  static Future<String> exportTransactions({
    required List<Transaction> transactions,
    required Map<String, Category> categoryMap,
    Directory? outputDir,
  }) async {
    final csvString = generateCsvString(
      transactions: transactions,
      categoryMap: categoryMap,
    );

    final dir = outputDir ?? await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File(
      p.join(dir.path, 'budgetlite_transactions_$timestamp.csv'),
    );
    await file.writeAsString(csvString);
    return file.path;
  }
}
