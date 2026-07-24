import '../database/database.dart';

/// Result of a duplicate check.
class DuplicateCheckResult {
  final List<Transaction> potentialDuplicates;

  const DuplicateCheckResult({required this.potentialDuplicates});

  bool get hasDuplicates => potentialDuplicates.isNotEmpty;
}

/// Detects potential duplicate transactions before they are saved.
///
/// Matches on:
/// - Same amount (within a small tolerance of 0.01)
/// - Same category
/// - Date within 2 days
/// - Similar note text (optional, boosts confidence)
class DuplicateDetector {
  /// Check if a new transaction would be a duplicate of existing ones.
  static DuplicateCheckResult findDuplicates({
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

      // Check date proximity
      final daysDiff = t.date.difference(date).inDays.abs();
      if (daysDiff > maxDaysApart) continue;

      // Boost confidence with note similarity
      if (note != null && t.note != null && t.note!.isNotEmpty) {
        if (!_notesAreSimilar(note, t.note!)) continue;
      }

      matches.add(t);
    }

    return DuplicateCheckResult(potentialDuplicates: matches);
  }

  /// Simple note similarity check — case-insensitive partial word match.
  static bool _notesAreSimilar(String a, String b) {
    final aLower = a.toLowerCase().trim();
    final bLower = b.toLowerCase().trim();

    // Direct substring match
    if (aLower.contains(bLower) || bLower.contains(aLower)) return true;

    // Check if any significant word overlaps
    final wordsA = aLower.split(RegExp(r'[\s,._\-/]+')).where((w) => w.length > 2).toSet();
    final wordsB = bLower.split(RegExp(r'[\s,._\-/]+')).where((w) => w.length > 2).toSet();
    final overlap = wordsA.intersection(wordsB);

    // Require at least 2 common words or 50% overlap
    return overlap.length >= 2 ||
        (wordsA.isNotEmpty && wordsB.isNotEmpty &&
         overlap.length / (wordsA.length < wordsB.length ? wordsA.length : wordsB.length) >= 0.5);
  }
}
