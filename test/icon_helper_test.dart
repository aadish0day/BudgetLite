import 'package:budget_lite/core/utils/icon_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getCategoryIcon', () {
    test('returns known icons', () {
      expect(getCategoryIcon('restaurant'), isNotNull);
      expect(getCategoryIcon('home'), isNotNull);
      expect(getCategoryIcon('shopping'), isNotNull);
    });

    test('returns question mark for unknown icon', () {
      expect(getCategoryIcon('non_existent_icon'), isNotNull);
    });

    test('is case insensitive', () {
      final upper = getCategoryIcon('RESTAURANT');
      final lower = getCategoryIcon('restaurant');
      expect(upper, lower);
    });

    test('handles edge case empty string', () {
      expect(getCategoryIcon(''), isNotNull);
    });
  });
}
