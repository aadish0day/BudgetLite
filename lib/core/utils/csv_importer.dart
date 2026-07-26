import 'dart:io';
import 'package:csv/csv.dart';

/// A parsed row from a bank statement CSV.
class CsvTransactionRow {
  final DateTime date;
  final String description;
  final double amount;

  const CsvTransactionRow({
    required this.date,
    required this.description,
    required this.amount,
  });
}

/// Result of importing a CSV file.
class CsvImportResult {
  final List<CsvTransactionRow> transactions;
  final int totalRows;
  final int skippedRows;
  final List<String> errors;

  const CsvImportResult({
    required this.transactions,
    required this.totalRows,
    required this.skippedRows,
    required this.errors,
  });

  int get validCount => transactions.length;
}

/// Column mapping for detected CSV columns.
class CsvColumnMapping {
  final int? dateColumn;
  final int? descriptionColumn;
  final int? debitColumn;
  final int? creditColumn;
  final int? amountColumn; // For single-column amount

  const CsvColumnMapping({
    this.dateColumn,
    this.descriptionColumn,
    this.debitColumn,
    this.creditColumn,
    this.amountColumn,
  });

  bool get isValid =>
      dateColumn != null &&
      descriptionColumn != null &&
      (debitColumn != null || creditColumn != null || amountColumn != null);
}

/// Parses bank statement CSV files with automatic column detection.
///
/// Supports common Indian bank formats:
/// - Date, Narration, Withdrawal, Deposit, Balance
/// - Date, Description, Debit, Credit, Balance
/// - Date, Transaction Details, Amount, Balance
class CsvImporter {
  /// Parse a CSV file and auto-detect columns.
  static Future<CsvImportResult> importFile({
    required String filePath,
    String? dateFormat,
    CsvColumnMapping? forcedMapping,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return const CsvImportResult(
        transactions: [],
        totalRows: 0,
        skippedRows: 0,
        errors: ['File not found'],
      );
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return const CsvImportResult(
        transactions: [],
        totalRows: 0,
        skippedRows: 0,
        errors: ['Empty file'],
      );
    }

    // Parse CSV respecting quoted fields
    final parsedRows = const CsvToListConverter().convert(content);
    final parsedLines = parsedRows.map((r) => r.map((e) => e.toString()).toList()).toList();
    if (parsedLines.isEmpty) {
      return const CsvImportResult(
        transactions: [],
        totalRows: 0,
        skippedRows: 0,
        errors: ['Empty file'],
      );
    }
    final headerRow = parsedLines.first.map((c) => c.trim().toLowerCase()).toList();
    final dataRows = parsedLines.skip(1).toList();

    // Auto-detect or use forced mapping
    final mapping = forcedMapping ?? _detectMapping(headerRow);
    if (!mapping.isValid) {
      final sample = headerRow.join(', ');
      return CsvImportResult(
        transactions: [],
        totalRows: dataRows.length,
        skippedRows: dataRows.length,
        errors: [
          'Could not auto-detect CSV columns. '
          'Expected columns: Date, Description, and Amount (or Debit/Credit). '
          'Found: $sample',
        ],
      );
    }

    final transactions = <CsvTransactionRow>[];
    final errors = <String>[];

    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];

      try {
        // Parse date
        final dateStr = mapping.dateColumn! < row.length
            ? row[mapping.dateColumn!].trim()
            : '';
        if (dateStr.isEmpty) {
          errors.add('Row ${i + 2}: Empty date');
          continue;
        }

        final date = _parseDate(dateStr, dateFormat);
        if (date == null) {
          errors.add('Row ${i + 2}: Unparseable date "$dateStr"');
          continue;
        }

        // Parse description
        final desc = mapping.descriptionColumn! < row.length
            ? row[mapping.descriptionColumn!].trim()
            : 'Bank transaction';

        // Parse amount
        double? amount;
        if (mapping.debitColumn != null && mapping.debitColumn! < row.length) {
          final debitStr = row[mapping.debitColumn!].trim();
          final debitVal = _parseAmount(debitStr);
          if (debitVal != null && debitVal > 0) {
            amount = debitVal; // positive = expense
          }
        }
        if (amount == null &&
            mapping.creditColumn != null &&
            mapping.creditColumn! < row.length) {
          final creditStr = row[mapping.creditColumn!].trim();
          final creditVal = _parseAmount(creditStr);
          if (creditVal != null && creditVal > 0) {
            amount = -creditVal; // negative = income
          }
        }
        if (amount == null &&
            mapping.amountColumn != null &&
            mapping.amountColumn! < row.length) {
          final amtStr = row[mapping.amountColumn!].trim();
          final amtVal = _parseAmount(amtStr);
          if (amtVal != null) {
            amount = amtVal > 0 ? amtVal : -amtVal.abs();
          }
        }

        if (amount == null || amount == 0) {
          errors.add('Row ${i + 2}: Could not parse amount');
          continue;
        }

        transactions.add(CsvTransactionRow(
          date: date,
          description: desc.isNotEmpty ? desc : 'Bank transaction',
          amount: amount,
        ));
      } catch (e) {
        errors.add('Row ${i + 2}: $e');
      }
    }

    return CsvImportResult(
      transactions: transactions,
      totalRows: dataRows.length,
      skippedRows: dataRows.length - transactions.length,
      errors: errors,
    );
  }

  /// Auto-detect column indices from header names.
  static CsvColumnMapping _detectMapping(List<String> header) {
    int? dateCol, descCol, debitCol, creditCol, amountCol;

    for (int i = 0; i < header.length; i++) {
      final h = header[i];

      // Date column
      if (h == 'date' || h == 'transaction date' || h == 'txn date' ||
          h == 'value date' || h == 'posting date') {
        dateCol = i;
      }

      // Description
      if (h == 'description' || h == 'narration' || h == 'particulars' ||
          h == 'transaction details' || h == 'details' || h == 'remarks') {
        descCol = i;
      }

      // Debit
      if (h == 'debit' || h == 'debit amount' || h == 'withdrawal' ||
          h == 'withdrawals' || h == 'dr' || h == 'dr.' || h == 'withdrawn') {
        debitCol = i;
      }

      // Credit
      if (h == 'credit' || h == 'credit amount' || h == 'deposit' ||
          h == 'deposits' || h == 'cr' || h == 'cr.') {
        creditCol = i;
      }

      // Amount (single column, sign indicates direction)
      if (h == 'amount' || h == 'txn amount' || h == 'transaction amount' ||
          h == 'value') {
        amountCol = i;
      }
    }

    // Fallbacks
    if (descCol == null) {
      // Try common alternative names
      for (int i = 0; i < header.length; i++) {
        if (header[i] == 'transaction' || header[i] == 'name' ||
            header[i] == 'merchant' || header[i] == 'payee') {
          descCol = i;
          break;
        }
      }
    }

    return CsvColumnMapping(
      dateColumn: dateCol,
      descriptionColumn: descCol,
      debitColumn: debitCol,
      creditColumn: creditCol,
      amountColumn: amountCol,
    );
  }

  /// Parse a date string in various common formats.
  static DateTime? _parseDate(String input, String? dateFormat) {
    // Try DD/MM/YYYY
    final dmy = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(input);
    if (dmy != null) {
      return DateTime(
        int.parse(dmy.group(3)!),
        int.parse(dmy.group(2)!),
        int.parse(dmy.group(1)!),
      );
    }

    // Try YYYY-MM-DD
    final ymd = RegExp(r'^(\d{4})[/-](\d{1,2})[/-](\d{1,2})$').firstMatch(input);
    if (ymd != null) {
      return DateTime(
        int.parse(ymd.group(1)!),
        int.parse(ymd.group(2)!),
        int.parse(ymd.group(3)!),
      );
    }

    // Try MM/DD/YYYY (US format)
    final mdy = RegExp(r'^(\d{1,2})[/](\d{1,2})[/](\d{4})$').firstMatch(input);
    if (mdy != null) {
      final month = int.parse(mdy.group(1)!);
      final day = int.parse(mdy.group(2)!);
      if (month > 12) {
        // Day is in first position, swap
        return DateTime(int.parse(mdy.group(3)!), day, month);
      }
      return DateTime(int.parse(mdy.group(3)!), month, day);
    }

    // Try DD-Mon-YYYY (e.g., "22-Jan-2026")
    final dMonY = RegExp(
      r'^(\d{1,2})[-/](\w{3})[-/](\d{4})$',
      caseSensitive: false,
    ).firstMatch(input);
    if (dMonY != null) {
      final month = _monthAbbrToInt(dMonY.group(2)!);
      if (month != null) {
        return DateTime(int.parse(dMonY.group(3)!), month, int.parse(dMonY.group(1)!));
      }
    }

    return null;
  }

  /// Parse an amount string that may include commas, currency symbols, or parentheses (for negative).
  static double? _parseAmount(String input) {
    // Remove currency symbols, spaces, and commas (except decimal comma)
    var clean = input
        .replaceAll(RegExp(r'[₹$€£¥,,\s]'), '')
        .replaceAll('(', '-')
        .replaceAll(')', '');

    // Handle Indian number format: 1,23,456.78 → already stripped commas
    // Handle trailing CR/DR
    if (clean.endsWith('dr') || clean.endsWith('dr.')) {
      clean = clean.replaceAll(RegExp(r'dr\.?$', caseSensitive: false), '');
    } else if (clean.endsWith('cr') || clean.endsWith('cr.')) {
      clean = clean.replaceAll(RegExp(r'cr\.?$', caseSensitive: false), '');
      clean = '-$clean'; // credit = negative for our convention
    }

    return double.tryParse(clean);
  }


  static int? _monthAbbrToInt(String abbr) {
    const months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    return months[abbr.toLowerCase()];
  }
}
