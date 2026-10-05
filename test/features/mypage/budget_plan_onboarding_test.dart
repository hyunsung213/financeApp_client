import 'package:dio/dio.dart';
import 'package:finance_client/data/api/finance_api.dart';
import 'package:finance_client/features/mypage/providers/my_page_provider.dart';
import 'package:finance_client/features/mypage/screens/budget_plan_settings_screen.dart';
import 'package:finance_client/features/mypage/utils/budget_plan_items.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFinanceApi extends FinanceApi {
  _FakeFinanceApi() : super(Dio());

  final List<List<Map<String, dynamic>>> savedPlans = [];

  @override
  Future<Map<String, dynamic>> updateBudgetPlan(
    List<Map<String, dynamic>> allocations,
  ) async {
    savedPlans.add(allocations);
    return {'allocations': allocations};
  }
}

void main() {
  // The backend's default plan (isConfigured: false) that a new user starts
  // from: 저축 20 + 투자 10 + 지출 70 = 100.
  final defaultPlan = [
    for (final (id, name) in budgetPlanItems)
      {
        'categoryId': id,
        'name': name,
        'percentage': switch (id) {
          'core.saving' => 20,
          'core.investment' => 10,
          'core.expense.food' => 70,
          _ => 0,
        },
      },
  ];

  Future<(_FakeFinanceApi, List<String>)> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final api = _FakeFinanceApi();
    final events = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeApiProvider.overrideWithValue(api),
          myPageDataProvider.overrideWith(
            (ref) async => MyPageData(
              setting: {'salaryAmount': 3000000},
              allocations: defaultPlan,
              profile: const {},
            ),
          ),
        ],
        child: MaterialApp(
          home: BudgetPlanSettingsScreen.onboarding(
            onBack: () => events.add('back'),
            onComplete: () async => events.add('complete'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (api, events);
  }

  ElevatedButton completeButton(WidgetTester tester) => tester.widget(
    find.ancestor(of: find.text('완료'), matching: find.byType(ElevatedButton)),
  );

  testWidgets('shows the onboarding copy on the shared budget screen', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('수입을 어떻게 나눠 쓸까요?'), findsOneWidget);
    expect(find.text('예산 배분'), findsOneWidget);
    final label = tester.widget<Text>(
      find.byKey(const ValueKey('budget-allocation-label')),
    );
    expect(
      label.textSpan!.toPlainText(includePlaceholders: false),
      '배분 완료 100%',
    );
  });

  testWidgets('완료 is disabled until the plan totals 100%', (tester) async {
    final (api, events) = await pump(tester);

    await tester.enterText(find.widgetWithText(TextField, '70'), '60');
    await tester.pump();
    expect(completeButton(tester).onPressed, isNull);
    expect(find.text('배분됨 90% · 남음 10%'), findsOneWidget);

    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();
    expect(api.savedPlans, isEmpty);
    expect(events, isEmpty);
  });

  testWidgets('saving at 100% stores the whole plan, then completes', (
    tester,
  ) async {
    final (api, events) = await pump(tester);

    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    expect(api.savedPlans, hasLength(1));
    expect(api.savedPlans.single, hasLength(12));
    expect(events, ['complete']);
  });

  testWidgets('back returns to the 사용자 정보 step', (tester) async {
    final (_, events) = await pump(tester);
    await tester.tap(find.byIcon(Icons.arrow_back));
    expect(events, ['back']);
  });
}
