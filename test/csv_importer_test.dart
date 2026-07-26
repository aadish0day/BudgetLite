import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_lite/core/utils/csv_importer.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('csv_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Import CSV with separate Debit and Credit columns', () async {
    final file = File('${tempDir.path}/statement.csv');
    await file.writeAsString([
      'Date,Description,Debit,Credit',
      '2026-07-01,Swiggy Order,250.00,',
      '2026-07-05,Salary Credit,,50000.00',
    ].join('\n'));

    final result = await CsvImporter.importFile(filePath: file.path);
    expect(result.validCount, 2);
    expect(result.transactions[0].amount, 250.0); // Expense = positive
    expect(result.transactions[1].amount, -50000.0); // Income = negative
  });

  test('Import CSV with single Amount column (Debit negative, Credit positive)', () async {
    final file = File('${tempDir.path}/single_amount.csv');
    await file.writeAsString([
      'Date,Description,Amount',
      '2026-07-01,Zomato,-350.00',
      '2026-07-05,Freelance Payment,12000.00',
    ].join('\n'));

    final result = await CsvImporter.importFile(filePath: file.path);
    expect(result.validCount, 2);
    expect(result.transactions[0].amount, 350.0); // -350 debit converted to +350 expense
    expect(result.transactions[1].amount, -12000.0); // +12000 credit converted to -12000 income
  });
}
