import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budget_lite/app.dart';

void main() {
  testWidgets('App renders dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BudgetLiteApp()));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
