import 'package:budget_lite/core/utils/categorization_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CategorizationRule', () {
    test('defaults contains predefined rules', () {
      final rules = CategorizationRule.defaults();
      expect(rules.isNotEmpty, true);
      expect(rules.any((r) => r.categoryId == 'food'), true);
      expect(rules.any((r) => r.categoryId == 'transport'), true);
      expect(rules.any((r) => r.categoryId == 'rent'), false);
    });

    test('toRegExp matches keywords from comma-separated string', () {
      final rule = CategorizationRule(
        keyword: 'swiggy, zomato, restaurant',
        categoryId: 'food',
      );
      expect(rule.toRegExp().hasMatch('Swiggy order #123'), true);
      expect(rule.toRegExp().hasMatch('ZOMATO PAYMENT'), true);
      expect(rule.toRegExp().hasMatch('uber ride'), false);
    });

    test('toRegExp matches any keyword', () {
      final rule = CategorizationRule(
        keyword: 'netflix, prime, hotstar, spotify',
        categoryId: 'entertainment',
      );
      expect(rule.toRegExp().hasMatch('Netflix subscription'), true);
      expect(rule.toRegExp().hasMatch('Spotify premium'), true);
    });

    test('toJson and fromJson roundtrip', () {
      final rule = CategorizationRule(
        keyword: 'netflix, prime video, youtube',
        categoryId: 'entertainment',
      );
      final json = rule.toJson();
      final restored = CategorizationRule.fromJson(json);
      expect(restored.categoryId, rule.categoryId);
      expect(restored.keyword, rule.keyword);
    });

    test('single keyword matches correctly', () {
      final rule = CategorizationRule(keyword: 'uber', categoryId: 'transport');
      expect(rule.toRegExp().hasMatch('Uber ride today'), true);
      expect(rule.toRegExp().hasMatch('netflix'), false);
    });
  });
}
