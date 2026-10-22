import 'package:budget_lite/core/database/database.dart';
import 'package:budget_lite/core/models/payee_tag_rule.dart';
import 'package:budget_lite/core/utils/sms_parser.dart';
import 'package:budget_lite/providers/database_provider.dart';
import 'package:budget_lite/providers/settings_provider.dart';
import 'package:budget_lite/providers/transaction_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PayeeTagRule Model Tests', () {
    test('matches performs case-insensitive and whitespace-tolerant matching', () {
      final rule = PayeeTagRule(
        payee: 'Satyanarayan Communi',
        tag: 'cig',
        categoryId: 'food',
      );

      expect(rule.matches('Satyanarayan Communi'), isTrue);
      expect(rule.matches('satyanarayan communi'), isTrue);
      expect(rule.matches('  SATYANARAYAN COMMUNI  '), isTrue);
      expect(rule.matches('Satyanarayan'), isTrue);
      expect(rule.matches('Other Merchant'), isFalse);
      expect(rule.matches(null), isFalse);
      expect(rule.matches(''), isFalse);
    });

    test('toJson and fromJson preserves all fields', () {
      final original = PayeeTagRule(
        id: 'test-rule-1',
        payee: 'Satyanarayan Communi',
        tag: 'cig',
        categoryId: 'food',
        note: 'Cigarettes at corner shop',
      );

      final json = original.toJson();
      final revived = PayeeTagRule.fromJson(json);

      expect(revived.id, equals(original.id));
      expect(revived.payee, equals('Satyanarayan Communi'));
      expect(revived.tag, equals('cig'));
      expect(revived.categoryId, equals('food'));
      expect(revived.note, equals('Cigarettes at corner shop'));
    });
  });

  group('Retroactive Transaction & Review Queue Integration Tests', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('updateTransactionsForPayee retroactively updates matching transactions with tag', () async {
      final notifier = container.read(transactionNotifierProvider.notifier);

      // 1. Add transactions for Satyanarayan Communi and another merchant
      await notifier.addTransaction(
        amount: 25.0,
        categoryId: 'other',
        note: null,
        date: DateTime(2026, 10, 21),
        payee: 'Satyanarayan Communi',
      );
      await notifier.addTransaction(
        amount: 60.0,
        categoryId: 'other',
        note: 'Morning stop',
        date: DateTime(2026, 10, 20),
        payee: 'Satyanarayan Communi',
      );
      await notifier.addTransaction(
        amount: 90.0,
        categoryId: 'food',
        note: 'Lunch diffin',
        date: DateTime(2026, 10, 19),
        payee: 'Baba diffin 2',
      );

      // 2. Perform retroactive update for Satyanarayan Communi
      final updatedCount = await notifier.updateTransactionsForPayee(
        payee: 'Satyanarayan Communi',
        tag: 'cig',
        categoryId: 'food',
      );

      expect(updatedCount, equals(2));

      // 3. Verify in database
      final allTxns = await db.select(db.transactions).get();
      final satya1 = allTxns.firstWhere((t) => t.amount == 25.0);
      final satya2 = allTxns.firstWhere((t) => t.amount == 60.0);
      final diffin = allTxns.firstWhere((t) => t.amount == 90.0);

      expect(satya1.note, equals('[cig]'));
      expect(satya1.categoryId, equals('food'));

      expect(satya2.note, equals('Morning stop [cig]'));
      expect(satya2.categoryId, equals('food'));

      // Untouched
      expect(diffin.note, equals('Lunch diffin'));
      expect(diffin.categoryId, equals('food'));
      expect(diffin.payee, equals('Baba diffin 2'));
    });

    test('Review Queue auto-tags incoming SMS matching existing PayeeTagRule', () async {
      final queueNotifier = container.read(smsReviewQueueProvider.notifier);
      final rulesNotifier = container.read(payeeTagRulesProvider.notifier);

      // Save rule
      await rulesNotifier.addOrUpdateRule(
        payee: 'Satyanarayan Communi',
        tag: 'cig',
        categoryId: 'food',
      );

      // Incoming SMS parsed
      final parsed = ParsedSmsTxn(
        id: 'sms_satya_1',
        amount: 25.0,
        note: '',
        categoryId: 'other',
        date: DateTime(2026, 10, 21),
        payee: 'Satyanarayan Communi',
      );

      await queueNotifier.addToQueue(parsed);

      final queueItems = container.read(smsReviewQueueProvider);
      expect(queueItems.length, equals(1));
      expect(queueItems.first.note, equals('[cig]'));
      expect(queueItems.first.categoryId, equals('food'));
    });

    test('Confirming item with applyRuleToAll updates past transactions and creates rule', () async {
      final txnNotifier = container.read(transactionNotifierProvider.notifier);
      final queueNotifier = container.read(smsReviewQueueProvider.notifier);

      // Past transaction without tag
      await txnNotifier.addTransaction(
        amount: 75.0,
        categoryId: 'other',
        note: null,
        date: DateTime(2026, 10, 18),
        payee: 'Satyanarayan Communi',
      );

      // Current pending item in queue
      final currentSms = ParsedSmsTxn(
        id: 'sms_satya_curr',
        amount: 25.0,
        note: '',
        categoryId: 'food',
        date: DateTime(2026, 10, 21),
        payee: 'Satyanarayan Communi',
      );
      await queueNotifier.addToQueue(currentSms);

      // Confirm with applyRuleToAll: true and tag: 'cig'
      final pastCount = await queueNotifier.confirmItem(
        'sms_satya_curr',
        overrideCategory: 'food',
        overrideNote: '[cig]',
        applyRuleToAll: true,
        tagToApply: 'cig',
      );

      expect(pastCount, equals(2)); // Both past transaction and newly confirmed transaction updated

      // Check rule saved
      final rule = container.read(payeeTagRulesProvider.notifier).findRuleForPayee('Satyanarayan Communi');
      expect(rule, isNotNull);
      expect(rule!.tag, equals('cig'));

      // Check past transaction updated
      final allTxns = await db.select(db.transactions).get();
      final pastTxn = allTxns.firstWhere((t) => t.amount == 75.0);
      expect(pastTxn.note, equals('[cig]'));
      expect(pastTxn.categoryId, equals('food'));
    });
  });
}
