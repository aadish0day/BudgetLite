import '../database/database.dart';

/// Detects potential duplicate transactions before they are saved.
///
/// Matches on:
/// - Same amount (within a small tolerance of 0.01)
/// - Same category
/// - Date within 2 days
/// Note text is not compared — bank narrations differ from user notes.
class DuplicateDetector {
  /// Check if a new transaction would be a duplicate of existing ones.
  static List<Transaction> findDuplicates({
    required List<Transaction> existingTransactions,
    required double amount,
    String? categoryId,
    required DateTime date,
    String? note,
    bool? isIncome,
    double amountTolerance = 0.01,
    int maxDaysApart = 2,
  }) {
    final matches = <Transaction>[];

    for (final t in existingTransactions) {
      // Check direction if specified
      if (isIncome != null) {
        final existingIsIncome = t.amount < 0;
        if (existingIsIncome != isIncome) continue;
      }

      // Skip if category specified and doesn't match
      if (categoryId != null && categoryId.isNotEmpty && t.categoryId != categoryId) {
        continue;
      }

      // Check amount within tolerance
      if ((t.amount.abs() - amount.abs()).abs() > amountTolerance) continue;

      // Check calendar-day proximity (not .inHours ~/ 24, which truncates
      // and lets e.g. Jan 1 08:00 → Jan 4 07:00 pass as "2 days apart")
      final dayA = DateTime(t.date.year, t.date.month, t.date.day);
      final dayB = DateTime(date.year, date.month, date.day);
      final daysDiff = dayA.difference(dayB).inDays.abs();
      if (daysDiff > maxDaysApart) continue;

      // Note text is intentionally NOT a hard criterion: bank narrations
      // routinely differ from user-entered notes on genuinely identical
      // transactions, so requiring similarity here caused false negatives.
      // Amount + category + direction + date-window are the real signals.

      matches.add(t);
    }

    return matches;
  }
}
