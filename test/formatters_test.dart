import 'package:flutter_test/flutter_test.dart';
import 'package:budget_lite/core/utils/formatters.dart';

void main() {
  group('Formatters', () {
    test('formatMonthKey returns yyyy-MM', () {
      final date = DateTime(2026, 7, 15);
      expect(Formatters.formatMonthKey(date), '2026-07');
    });

    test('monthKey returns current month key', () {
      expect(Formatters.monthKey, matches(RegExp(r'^\d{4}-\d{2}$')));
    });

    test('previousMonthKey returns previous month', () {
      expect(Formatters.previousMonthKey, matches(RegExp(r'^\d{4}-\d{2}$')));
    });

    test('formatCurrency formats INR', () {
      expect(Formatters.formatCurrency(1234.5), '₹1,235');
    });

    test('formatCurrency handles zero', () {
      expect(Formatters.formatCurrency(0), '₹0');
    });

    test('formatCurrency hides when requested', () {
      expect(Formatters.formatCurrency(1000, hide: true), '••••');
    });

    test('formatDate formats correctly', () {
      final date = DateTime(2026, 7, 8);
      expect(Formatters.formatDate(date), 'Jul 08, 2026');
    });

    test('formatDateShort formats correctly', () {
      final date = DateTime(2026, 7, 8);
      expect(Formatters.formatDateShort(date), 'Jul 08');
    });

    test('formatMonth formats correctly', () {
      final date = DateTime(2026, 7, 8);
      expect(Formatters.formatMonth(date), 'July 2026');
    });

    test('formatPercentage formats correctly', () {
      expect(Formatters.formatPercentage(75.3), '75%');
      expect(Formatters.formatPercentage(100.0), '100%');
    });
  });
}
