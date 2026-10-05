import 'package:dio/dio.dart';
import 'package:finance_client/data/api/finance_api.dart';
import 'package:finance_client/features/home/providers/home_provider.dart';
import 'package:finance_client/features/mypage/providers/my_page_provider.dart';
import 'package:finance_client/features/mypage/providers/salary_budget_preview.dart';
import 'package:finance_client/features/mypage/screens/salary_cycle_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// The seed account's plan: 저축 20 / 투자 10 / 고정지출 25, the other 45%
// spread over the 9 daily-spendable 지출 대분류.
const _plan = [
  {'categoryId': 'core.expense.food', 'percentage': 20},
  {'categoryId': 'core.expense.transport', 'percentage': 3},
  {'categoryId': 'core.expense.living', 'percentage': 8},
  {'categoryId': 'core.expense.fixed', 'percentage': 25},
  {'categoryId': 'core.expense.shopping', 'percentage': 4},
  {'categoryId': 'core.expense.leisure-culture', 'percentage': 4},
  {'categoryId': 'core.expense.health', 'percentage': 2},
  {'categoryId': 'core.expense.education', 'percentage': 1},
  {'categoryId': 'core.expense.relationship', 'percentage': 2},
  {'categoryId': 'core.expense.other', 'percentage': 1},
  {'categoryId': 'core.saving', 'percentage': 20},
  {'categoryId': 'core.investment', 'percentage': 10},
];

/// The `/api/home` the backend returns for a cycle re-budgeted from
/// [salary] + [additional], with 100,000 already spent on 식비.
Map<String, dynamic> _homeJson(
  int salary, {
  int? additional = 0,
  int spent = 100000,
}) {
  final total = salary + (additional ?? 0);
  final usable =
      total - (total * 20 ~/ 100) - (total * 10 ~/ 100) - (total * 25 ~/ 100);
  return {
    'daysUntilSalary': 27,
    'cycle': {'startDate': '2026-10-01', 'projectedEndDate': '2026-10-31'},
    'budget': {
      'salaryAmount': total,
      'additionalIncomeAmount': ?additional,
      'usableBudgetAmount': usable,
      'variableExpenseAmount': spent,
      'remainingUsableAmount': usable - spent,
    },
  };
}

class _FakeBackend extends FinanceApi {
  _FakeBackend(this.salary, {this.additional = 0, this.fail = false})
    : super(Dio());

  int salary;
  final int additional;
  final bool fail;
  final saved = <int>[];

  @override
  Future<void> updateSetting({
    required int salaryAmount,
    required int salaryDay,
    required int reportingStartDay,
  }) async {
    if (fail) throw DioException(requestOptions: RequestOptions());
    saved.add(salaryAmount);
    salary = salaryAmount;
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  group('previewSalaryChange', () {
    test('re-budgets the spendable pool from the new salary', () {
      final preview = previewSalaryChange(
        salaryAmount: 800000,
        home: HomeData.fromJson(_homeJson(2500000)),
        planAllocations: _plan,
      )!;
      expect(preview.cycleBudgetAmount, 800000);
      // 800,000 - 저축 160,000 - 투자 80,000 - 고정지출 200,000
      expect(preview.usableBudgetAmount, 360000);
      expect(preview.remainingUsableAmount, 260000);
    });

    test('keeps the additional income on top of the new salary', () {
      final preview = previewSalaryChange(
        salaryAmount: 800000,
        home: HomeData.fromJson(_homeJson(2500000, additional: 300000)),
        planAllocations: _plan,
      )!;
      expect(preview.cycleBudgetAmount, 1100000);
      expect(preview.usableBudgetAmount, 495000);
      expect(preview.remainingUsableAmount, 395000);
    });

    test('matches the backend numbers once that salary is saved', () {
      for (final salary in [800000, 1234567, 2500000, 3333333]) {
        final saved = HomeData.fromJson(_homeJson(salary, additional: 70001));
        final preview = previewSalaryChange(
          salaryAmount: salary,
          home: HomeData.fromJson(_homeJson(2500000, additional: 70001)),
          planAllocations: _plan,
        )!;
        expect(preview.usableBudgetAmount, saved.totalFlexibleAmount);
        expect(preview.remainingUsableAmount, saved.remainingFlexibleAmount);
      }
    });

    test('is unavailable without the additional income or a plan', () {
      expect(
        previewSalaryChange(
          salaryAmount: 800000,
          home: HomeData.fromJson(_homeJson(2500000, additional: null)),
          planAllocations: _plan,
        ),
        isNull,
      );
      expect(
        previewSalaryChange(
          salaryAmount: 800000,
          home: HomeData.fromJson(_homeJson(2500000)),
          planAllocations: const [],
        ),
        isNull,
      );
    });
  });

  group('정기 수입 설정 summary', () {
    Future<_FakeBackend> pump(WidgetTester tester, _FakeBackend api) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeApiProvider.overrideWithValue(api),
            myPageDataProvider.overrideWith(
              (ref) async => MyPageData(
                setting: {'salaryAmount': '${api.salary}', 'salaryDay': 1},
                allocations: _plan,
                profile: const {},
              ),
            ),
            homeDataProvider.overrideWith(
              (ref) async => HomeData.fromJson(
                _homeJson(api.salary, additional: api.additional),
              ),
            ),
          ],
          child: const MaterialApp(home: SalaryCycleSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    Future<void> typeSalary(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField).first, text);
      await tester.pump();
    }

    testWidgets('previews the typed salary instead of the saved budget', (
      tester,
    ) async {
      await pump(tester, _FakeBackend(2500000));
      expect(find.text('쓸 수 있는 예산 1,025,000원 남았어요'), findsOneWidget);
      expect(find.text('저장하면 현재 예산에 바로 반영돼요.'), findsNothing);

      await typeSalary(tester, '800000');
      expect(find.text('쓸 수 있는 예산 260,000원 남았어요'), findsOneWidget);
      expect(find.text('쓸 수 있는 예산 1,025,000원 남았어요'), findsNothing);
      expect(find.text('저장하면 현재 예산에 바로 반영돼요.'), findsOneWidget);

      // Typing the saved amount back shows the applied budget again.
      await typeSalary(tester, '2500000');
      expect(find.text('쓸 수 있는 예산 1,025,000원 남았어요'), findsOneWidget);
      expect(find.text('저장하면 현재 예산에 바로 반영돼요.'), findsNothing);
    });

    testWidgets('shows the re-budgeted cycle once the salary is saved', (
      tester,
    ) async {
      final api = await pump(tester, _FakeBackend(2500000));
      await typeSalary(tester, '800000');
      final save = find.text('저장');
      await tester.scrollUntilVisible(
        save,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(api.saved, [800000]);
      await tester.pump(const Duration(seconds: 2));
      await tester.scrollUntilVisible(
        find.textContaining('쓸 수 있는 예산'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('쓸 수 있는 예산 260,000원 남았어요'), findsOneWidget);
      expect(find.text('저장하면 현재 예산에 바로 반영돼요.'), findsNothing);
      expect(find.text('쓸 수 있는 예산 1,025,000원 남았어요'), findsNothing);
    });

    Future<void> tapSave(WidgetTester tester) async {
      final save = find.text('저장');
      await tester.scrollUntilVisible(
        save,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(save);
    }

    testWidgets('confirms a successful save with the success overlay', (
      tester,
    ) async {
      final api = await pump(tester, _FakeBackend(2500000));
      await typeSalary(tester, '800000');
      await tapSave(tester);
      // Not shown until the save and the refetch have both finished.
      expect(find.text('저장했어요!'), findsNothing);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(api.saved, [800000]);
      expect(find.text('저장했어요!'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      // Gone within 1.5s: held ~1s, then a short fade-out.
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('저장했어요!'), findsNothing);
    });

    testWidgets('a failed save shows the error and no success overlay', (
      tester,
    ) async {
      await pump(tester, _FakeBackend(2500000, fail: true));
      await typeSalary(tester, '800000');
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.text('저장했어요!'), findsNothing);
      expect(find.text('저장하지 못했어요. 다시 시도해주세요.'), findsOneWidget);
    });

    testWidgets('saving twice in a row keeps a single overlay', (tester) async {
      final api = await pump(tester, _FakeBackend(2500000));
      await tapSave(tester);
      await tester.pumpAndSettle();
      await tapSave(tester);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(api.saved, [2500000, 2500000]);
      expect(find.text('저장했어요!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('says when the budget includes additional income', (
      tester,
    ) async {
      await pump(tester, _FakeBackend(2500000, additional: 300000));
      expect(find.text('추가 수입 300,000원 포함'), findsOneWidget);

      await typeSalary(tester, '800000');
      expect(find.text('쓸 수 있는 예산 395,000원 남았어요'), findsOneWidget);
      expect(find.text('추가 수입 300,000원 포함'), findsOneWidget);
    });

    testWidgets('hides the additional income line when there is none', (
      tester,
    ) async {
      await pump(tester, _FakeBackend(2500000));
      expect(find.textContaining('추가 수입'), findsNothing);
    });
  });
}
