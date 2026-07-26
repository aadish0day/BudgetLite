import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../database/database.dart' show Transaction;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  NotificationService._();

  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _timezoneInitialized = false;

  final Set<String> _firedAlerts = {};

  Future<void> initialize({void Function(String? payload)? onNotificationTap}) async {
    if (_initialized) return;

    _initTimezones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
    );
    _initialized = true;
  }

  /// Check budget thresholds (80% and 100%) for a category in a given month.
  /// Fires notification once per threshold when crossed, and RESETS flag if spending drops back below threshold.
  Future<void> checkBudgetThreshold({
    required String categoryId,
    required String categoryName,
    required String month,
    required double spent,
    required double allocatedAmount,
  }) async {
    if (allocatedAmount <= 0) return;

    final ratio = spent / allocatedAmount;
    final flag80 = 'budget_alert_${categoryId}_${month}_80';
    final flag100 = 'budget_alert_${categoryId}_${month}_100';

    // 80% Threshold Alert & Reset Logic
    if (ratio >= 0.8) {
      if (!_firedAlerts.contains(flag80)) {
        _firedAlerts.add(flag80);
        await showNotification(
          id: ('80_${categoryId}_$month'.hashCode).abs() % 100000,
          title: 'Budget Alert: $categoryName',
          body: 'You have used ${(ratio * 100).toStringAsFixed(0)}% of your $categoryName budget.',
          payload: 'budget:$categoryId',
        );
      }
    } else {
      // RESET: Spending dropped back below 80% (e.g. transaction edited or deleted)
      _firedAlerts.remove(flag80);
    }

    // 100% Threshold Alert & Reset Logic
    if (ratio >= 1.0) {
      if (!_firedAlerts.contains(flag100)) {
        _firedAlerts.add(flag100);
        await showNotification(
          id: ('100_${categoryId}_$month'.hashCode).abs() % 100000,
          title: 'Budget Exceeded: $categoryName',
          body: 'You have exceeded your $categoryName budget!',
          payload: 'budget:$categoryId',
        );
      }
    } else {
      // RESET: Spending dropped back below 100% (e.g. transaction edited or deleted)
      _firedAlerts.remove(flag100);
    }
  }

  void _initTimezones() {
    if (!_timezoneInitialized) {
      tz_data.initializeTimeZones();
      _timezoneInitialized = true;
    }
  }

  Future<void> showNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _initializeIfNeeded();

    const androidDetails = AndroidNotificationDetails(
      'payment_reminders',
      'Payment Reminders',
      channelDescription: 'Notifications for upcoming recurring payments',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// Schedule a one-time notification for a specific date/time
  Future<void> scheduleNotification({
    int id = 0,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    await _initializeIfNeeded();

    final now = DateTime.now();
    if (scheduledDate.isBefore(now)) return;

    _initTimezones();
    final location = tz.local;
    final tzDate = tz.TZDateTime.from(scheduledDate, location);

    final androidDetails = AndroidNotificationDetails(
      'payment_reminders',
      'Payment Reminders',
      channelDescription: 'Notifications for upcoming recurring payments',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: null,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Schedule a recurring notification for a transaction based on its interval
  Future<void> scheduleForTransaction({
    required Transaction transaction,
    required int notificationId,
    required DateTime nextDueDate,
  }) async {
    await _initializeIfNeeded();
    _initTimezones();

    final location = tz.local;
    final tzDate = tz.TZDateTime.from(nextDueDate, location);

    final androidDetails = AndroidNotificationDetails(
      'payment_reminders',
      'Payment Reminders',
      channelDescription: 'Notifications for upcoming recurring payments',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final note = transaction.note ?? 'Payment';
    final amount = '₹${transaction.amount.abs().toStringAsFixed(0)}';

    // One-time notification for the next due date
    if (nextDueDate.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        notificationId,
        'Upcoming Payment: $note',
        '$amount due ${nextDueDate.day}/${nextDueDate.month}',
        tzDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: _matchComponentForInterval(transaction.recurringInterval),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: transaction.id,
      );
    }
  }

  DateTimeComponents? _matchComponentForInterval(String? interval) {
    switch (interval) {
      case 'daily':
        return DateTimeComponents.time;
      case 'weekly':
        return DateTimeComponents.dayOfWeekAndTime;
      case 'biweekly':
        return null; // No built-in biweekly, will be handled by separate scheduling
      case 'monthly':
        return DateTimeComponents.dayOfMonthAndTime;
      case 'quarterly':
        return null; // Scheduled manually
      case 'yearly':
        return null; // No built-in yearly repeat in flutter_local_notifications; rescheduleAll handles re-scheduling
      default:
        return null;
    }
  }

  /// Cancel all existing notifications and re-schedule for active recurring transactions
  Future<void> rescheduleAll(List<Transaction> transactions) async {
    await _initializeIfNeeded();
    await _plugin.cancelAll();

    int id = 100;
    for (final t in transactions.where((t) => t.isRecurring)) {
      final nextDate = calculateNextDueDate(
        lastDate: t.date,
        interval: t.recurringInterval,
      );
      if (nextDate != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final nextDay = DateTime(nextDate.year, nextDate.month, nextDate.day);
        if (nextDay.difference(today).inDays <= 30) {
          await scheduleForTransaction(
            transaction: t,
            notificationId: id++,
            nextDueDate: nextDate,
          );
        }
      }
    }
  }

  Future<void> cancelNotification(int id) async {
    await _initializeIfNeeded();
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _initializeIfNeeded();
    await _plugin.cancelAll();
  }

  Future<void> _initializeIfNeeded() async {
    if (!_initialized) await initialize();
  }

  /// Calculate the next due date for a recurring transaction
  static DateTime? calculateNextDueDate({
    required DateTime lastDate,
    required String? interval,
  }) {
    if (interval == null) return null;

    final now = DateTime.now();
    DateTime next = lastDate;

    switch (interval) {
      case 'daily':
        next = lastDate.add(const Duration(days: 1));
        break;
      case 'weekly':
        next = lastDate.add(const Duration(days: 7));
        break;
      case 'biweekly':
        next = lastDate.add(const Duration(days: 14));
        break;
      case 'monthly':
        next = _safeAddMonths(lastDate, 1);
        break;
      case 'quarterly':
        next = _safeAddMonths(lastDate, 3);
        break;
      case 'yearly':
        next = _safeAddMonths(lastDate, 12);
        break;
      default:
        return null;
    }

    // If the calculated next date is in the past, keep advancing
    while (next.isBefore(now)) {
      switch (interval) {
        case 'daily':
          next = next.add(const Duration(days: 1));
          break;
        case 'weekly':
          next = next.add(const Duration(days: 7));
          break;
        case 'biweekly':
          next = next.add(const Duration(days: 14));
          break;
        case 'monthly':
          next = _safeAddMonths(next, 1);
          break;
        case 'quarterly':
          next = _safeAddMonths(next, 3);
          break;
        case 'yearly':
          next = _safeAddMonths(next, 12);
          break;
      }
    }

    return next;
  }

  static DateTime _safeAddMonths(DateTime date, int monthsToAdd) {
    final newMonth = date.month + monthsToAdd;
    final yearOffset = (newMonth - 1) ~/ 12;
    final targetYear = date.year + yearOffset;
    final targetMonth = ((newMonth - 1) % 12) + 1;
    final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final targetDay = date.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : date.day;
    return DateTime(targetYear, targetMonth, targetDay, date.hour, date.minute, date.second);
  }
}
