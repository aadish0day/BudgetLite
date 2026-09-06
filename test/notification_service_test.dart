import 'package:budget_lite/core/utils/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationService.calculateNextDueDate Tests', () {
    final baseDate = DateTime(2030, 7, 1, 10, 30);

    test('daily interval advances by 1 day', () {
      final now = DateTime.now();
      final next = NotificationService.calculateNextDueDate(
        lastDate: now,
        interval: 'daily',
      );
      expect(next!.difference(now).inHours, closeTo(24, 2));
    });

    test('weekly interval advances by 7 days', () {
      final now = DateTime.now();
      final next = NotificationService.calculateNextDueDate(
        lastDate: now,
        interval: 'weekly',
      );
      expect(next!.difference(now).inDays, 7);
    });

    test('biweekly interval advances by 14 days', () {
      final now = DateTime.now();
      final next = NotificationService.calculateNextDueDate(
        lastDate: now,
        interval: 'biweekly',
      );
      expect(next!.difference(now).inDays, 14);
    });

    test('monthly interval advances by 1 month', () {
      final next = NotificationService.calculateNextDueDate(
        lastDate: baseDate,
        interval: 'monthly',
      );
      expect(next, DateTime(2030, 8, 1, 10, 30));
    });

    test('quarterly interval advances by 3 months', () {
      final next = NotificationService.calculateNextDueDate(
        lastDate: baseDate,
        interval: 'quarterly',
      );
      expect(next, DateTime(2030, 10, 1, 10, 30));
    });

    test('yearly interval advances by 1 year', () {
      final next = NotificationService.calculateNextDueDate(
        lastDate: baseDate,
        interval: 'yearly',
      );
      expect(next, DateTime(2031, 7, 1, 10, 30));
    });

    test('null interval returns null', () {
      final next = NotificationService.calculateNextDueDate(
        lastDate: baseDate,
        interval: null,
      );
      expect(next, isNull);
    });
  });
}
