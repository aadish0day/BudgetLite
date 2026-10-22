import 'package:budget_lite/core/database/database.dart';
import 'package:budget_lite/core/utils/accessibility_utils.dart';
import 'package:budget_lite/providers/database_provider.dart';
import 'package:budget_lite/providers/settings_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccessibilityUtils & Animation Performance Mode', () {
    setUp(() {
      AccessibilityUtils.animationsEnabled = true;
    });

    tearDown(() {
      AccessibilityUtils.animationsEnabled = true;
    });

    test('animationsEnabled defaults to true and can be toggled', () {
      expect(AccessibilityUtils.animationsEnabled, isTrue);

      AccessibilityUtils.animationsEnabled = false;
      expect(AccessibilityUtils.animationsEnabled, isFalse);

      AccessibilityUtils.animationsEnabled = true;
      expect(AccessibilityUtils.animationsEnabled, isTrue);
    });

    testWidgets('shouldAnimate respects animationsEnabled and MediaQuery', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(AccessibilityUtils.shouldAnimate(context), isTrue);

              AccessibilityUtils.animationsEnabled = false;
              expect(AccessibilityUtils.shouldAnimate(context), isFalse);

              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('animateFadeSlide returns identical child when animations disabled', (
      tester,
    ) async {
      AccessibilityUtils.animationsEnabled = false;

      const testKey = Key('child-widget');
      const childWidget = SizedBox(key: testKey, width: 50, height: 50);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final result = childWidget.animateFadeSlide(context, index: 1);
              expect(identical(result, childWidget), isTrue);
              return result;
            },
          ),
        ),
      );

      expect(find.byKey(testKey), findsOneWidget);
    });

    testWidgets('animateShimmer returns identical child when animations disabled', (
      tester,
    ) async {
      AccessibilityUtils.animationsEnabled = false;

      const testKey = Key('shimmer-child');
      const childWidget = SizedBox(key: testKey, width: 100, height: 20);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final result = childWidget.animateShimmer(context);
              expect(identical(result, childWidget), isTrue);
              return result;
            },
          ),
        ),
      );

      expect(find.byKey(testKey), findsOneWidget);
    });

    testWidgets('animateScalePop returns identical child when animations disabled', (
      tester,
    ) async {
      AccessibilityUtils.animationsEnabled = false;

      const testKey = Key('fab-child');
      const childWidget = SizedBox(key: testKey, width: 40, height: 40);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final result = childWidget.animateScalePop(context);
              expect(identical(result, childWidget), isTrue);
              return result;
            },
          ),
        ),
      );

      expect(find.byKey(testKey), findsOneWidget);
    });
  });

  group('SettingsNotifier animations setting', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      AccessibilityUtils.animationsEnabled = true;
    });

    tearDown(() async {
      container.dispose();
      await db.close();
      AccessibilityUtils.animationsEnabled = true;
    });

    test('getAnimationsEnabled returns true by default and persists updates', () async {
      final notifier = container.read(settingsNotifierProvider.notifier);

      final initial = await notifier.getAnimationsEnabled();
      expect(initial, isTrue);
      expect(AccessibilityUtils.animationsEnabled, isTrue);

      await notifier.setAnimationsEnabled(false);
      final disabled = await notifier.getAnimationsEnabled();
      expect(disabled, isFalse);
      expect(AccessibilityUtils.animationsEnabled, isFalse);

      await notifier.setAnimationsEnabled(true);
      final enabledAgain = await notifier.getAnimationsEnabled();
      expect(enabledAgain, isTrue);
      expect(AccessibilityUtils.animationsEnabled, isTrue);
    });
  });
}
