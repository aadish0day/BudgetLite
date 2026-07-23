import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static String formatCurrency(double amount, {String? currency}) {
    switch (currency ?? 'INR') {
      case 'USD':
        return NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount);
      case 'EUR':
        return NumberFormat.currency(symbol: '€', decimalDigits: 2).format(amount);
      case 'GBP':
        return NumberFormat.currency(symbol: '£', decimalDigits: 2).format(amount);
      case 'JPY':
        return NumberFormat.currency(symbol: '¥', decimalDigits: 0).format(amount);
      default:
        return NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(amount);
    }
  }

  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static String formatDateShort(DateTime date) {
    return DateFormat('MMM dd').format(date);
  }

  static String formatMonth(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  static String formatMonthKey(DateTime date) {
    return DateFormat('yyyy-MM').format(date);
  }

  static String formatPercentage(double value) {
    return '${value.toStringAsFixed(0)}%';
  }

  static String get monthKey {
    return formatMonthKey(DateTime.now());
  }

  static String monthKeyFor(DateTime date) {
    return formatMonthKey(date);
  }
}
