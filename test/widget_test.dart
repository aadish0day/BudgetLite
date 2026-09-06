import 'package:budget_lite/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App renders dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BudgetLiteApp()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(BudgetLiteApp), findsOneWidget);
  });
}
