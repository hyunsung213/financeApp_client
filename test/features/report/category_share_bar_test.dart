import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_client/features/report/widgets/category_share_bar.dart';
import 'package:finance_client/features/report/widgets/over_budget_badge.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('shows amount and share only, with the bar at the share ratio', (tester) async {
    await tester.pumpWidget(_host(const CategoryShareBar(
      categoryName: '식비',
      categoryColor: Colors.green,
      spentAmount: 64000,
      sharePercent: 36,
    )));

    expect(find.text('식비'), findsOneWidget);
    expect(find.text('64,000원'), findsOneWidget);
    expect(find.text('36%'), findsOneWidget);
    expect(find.text('초과'), findsNothing);
    expect(find.textContaining('/'), findsNothing);
    expect(find.textContaining('예산'), findsNothing);
    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, closeTo(0.36, 1e-9));
  });

  testWidgets('never shows the over-budget badge without a real budget', (tester) async {
    // Even a category that is 100% of spending is not "over" anything.
    await tester.pumpWidget(_host(const CategoryShareBar(
      categoryName: '식비',
      categoryColor: Colors.green,
      spentAmount: 500000,
      sharePercent: 100,
    )));

    expect(find.byType(OverBudgetBadge), findsNothing);
  });

  testWidgets('re-attaches the badge once a real budget is passed and exceeded', (tester) async {
    await tester.pumpWidget(_host(const CategoryShareBar(
      categoryName: '식비',
      categoryColor: Colors.green,
      spentAmount: 64000,
      sharePercent: 36,
      budgetAmount: 50000,
    )));
    expect(find.byType(OverBudgetBadge), findsOneWidget);

    await tester.pumpWidget(_host(const CategoryShareBar(
      categoryName: '식비',
      categoryColor: Colors.green,
      spentAmount: 64000,
      sharePercent: 36,
      budgetAmount: 80000,
    )));
    expect(find.byType(OverBudgetBadge), findsNothing);
  });
}
