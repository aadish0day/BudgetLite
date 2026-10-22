import 'package:budget_lite/core/utils/sms_parser.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime calculateCutoff(int months, {DateTime? from}) {
  final now = from ?? DateTime.now();
  var y = now.year;
  var m = now.month - months;
  while (m <= 0) {
    m += 12;
    y -= 1;
  }
  return DateTime(y, m, now.day.clamp(1, 28));
}

List<ParsedSmsTxn> filterQueue(List<ParsedSmsTxn> queue, int? filterMonths, {DateTime? now}) {
  if (filterMonths == null) return queue;
  final cutoff = calculateCutoff(filterMonths, from: now);
  return queue
      .where(
        (t) =>
            t.date.isAfter(cutoff) || t.date.isAtSameMomentAs(cutoff),
      )
      .toList();
}

void main() {
  group('SMS Review Queue Timeframe Filtering', () {
    final fixedNow = DateTime(2026, 10, 22);

    test('calculateCutoff properly subtracts months across year boundaries', () {
      // 1 month back from Oct 2026 -> Sept 2026
      expect(calculateCutoff(1, from: fixedNow), DateTime(2026, 9, 22));

      // 3 months back from Oct 2026 -> July 2026
      expect(calculateCutoff(3, from: fixedNow), DateTime(2026, 7, 22));

      // 12 months back from Oct 2026 -> Oct 2025 (last year)
      expect(calculateCutoff(12, from: fixedNow), DateTime(2025, 10, 22));

      // 15 months back from Oct 2026 -> July 2025
      expect(calculateCutoff(15, from: fixedNow), DateTime(2025, 7, 22));
    });

    test('filterQueue accurately isolates 1, 2, 3, 6, 9, and 12 month items', () {
      final txns = [
        ParsedSmsTxn(
          id: 'sms_today',
          amount: 150,
          note: 'Food Cafe',
          categoryId: 'food',
          date: DateTime(2026, 10, 20),
        ),
        ParsedSmsTxn(
          id: 'sms_1m',
          amount: 250,
          note: 'Groceries',
          categoryId: 'food',
          date: DateTime(2026, 9, 10), // ~1.5 months ago
        ),
        ParsedSmsTxn(
          id: 'sms_2m',
          amount: 400,
          note: 'Stationery',
          categoryId: 'shopping',
          date: DateTime(2026, 8, 15), // ~2.2 months ago
        ),
        ParsedSmsTxn(
          id: 'sms_5m',
          amount: 900,
          note: 'Clothing',
          categoryId: 'shopping',
          date: DateTime(2026, 5), // ~5.5 months ago
        ),
        ParsedSmsTxn(
          id: 'sms_8m',
          amount: 1200,
          note: 'Phone recharge',
          categoryId: 'bills',
          date: DateTime(2026, 2, 10), // ~8.5 months ago
        ),
        ParsedSmsTxn(
          id: 'sms_last_year',
          amount: 5000,
          note: 'College books',
          categoryId: 'other',
          date: DateTime(2025, 11, 15), // 11 months ago (last year)
        ),
        ParsedSmsTxn(
          id: 'sms_ancient',
          amount: 300,
          note: 'Old transaction',
          categoryId: 'other',
          date: DateTime(2024, 5), // > 2 years ago
        ),
      ];

      // All filter
      expect(filterQueue(txns, null, now: fixedNow).length, 7);

      // 1 Month filter (after Sept 22, 2026) -> only sms_today
      final q1m = filterQueue(txns, 1, now: fixedNow);
      expect(q1m.map((t) => t.id), ['sms_today']);

      // 2 Months filter (after Aug 22, 2026) -> sms_today, sms_1m
      final q2m = filterQueue(txns, 2, now: fixedNow);
      expect(q2m.map((t) => t.id), ['sms_today', 'sms_1m']);

      // 3 Months filter (after July 22, 2026) -> sms_today, sms_1m, sms_2m
      final q3m = filterQueue(txns, 3, now: fixedNow);
      expect(q3m.map((t) => t.id), ['sms_today', 'sms_1m', 'sms_2m']);

      // 6 Months filter (after April 22, 2026) -> sms_today, sms_1m, sms_2m, sms_5m
      final q6m = filterQueue(txns, 6, now: fixedNow);
      expect(q6m.map((t) => t.id), ['sms_today', 'sms_1m', 'sms_2m', 'sms_5m']);

      // 9 Months filter (after Jan 22, 2026) -> includes sms_8m
      final q9m = filterQueue(txns, 9, now: fixedNow);
      expect(q9m.map((t) => t.id), ['sms_today', 'sms_1m', 'sms_2m', 'sms_5m', 'sms_8m']);

      // 1 Year filter (after Oct 22, 2025) -> includes sms_last_year from Nov 2025!
      final q1y = filterQueue(txns, 12, now: fixedNow);
      expect(q1y.map((t) => t.id), [
        'sms_today',
        'sms_1m',
        'sms_2m',
        'sms_5m',
        'sms_8m',
        'sms_last_year',
      ]);
      expect(q1y.any((t) => t.id == 'sms_ancient'), isFalse);
    });
  });
}
