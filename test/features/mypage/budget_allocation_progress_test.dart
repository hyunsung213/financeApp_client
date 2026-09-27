import 'package:finance_client/features/mypage/widgets/budget_allocation_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<String> labelFor(WidgetTester tester, int total) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BudgetAllocationProgress(totalPercentage: total)),
      ),
    );
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(
      find.byKey(const ValueKey('budget-allocation-label')),
    );
    return text.textSpan!.toPlainText(includePlaceholders: false);
  }

  testWidgets('under 100 shows allocated and remaining', (tester) async {
    expect(await labelFor(tester, 0), '배분됨 0% · 남음 100%');
    expect(await labelFor(tester, 20), '배분됨 20% · 남음 80%');
    expect(await labelFor(tester, 65), '배분됨 65% · 남음 35%');
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });

  testWidgets('exactly 100 shows completion with a check', (tester) async {
    expect(await labelFor(tester, 100), '배분 완료 100%');
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('over 100 shows how much is exceeded', (tester) async {
    expect(await labelFor(tester, 105), '105% 배분 · 5% 초과');
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });
}
