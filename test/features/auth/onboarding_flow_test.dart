import 'package:dio/dio.dart';
import 'package:finance_client/data/api/finance_api.dart';
import 'package:finance_client/data/api/policy_api.dart';
import 'package:finance_client/features/auth/providers/auth_provider.dart';
import 'package:finance_client/features/auth/providers/onboarding_provider.dart';
import 'package:finance_client/features/auth/screens/onboarding_screen.dart';
import 'package:finance_client/features/mypage/utils/budget_plan_items.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A brand-new user on the backend: no finance setting, default plan.
class _NewUserFinanceApi extends FinanceApi {
  _NewUserFinanceApi() : super(Dio());

  Map<String, dynamic>? setting;
  List<Map<String, dynamic>>? savedPlan;

  @override
  Future<Map<String, dynamic>?> getSettingOrNull() async => setting;

  @override
  Future<void> updateSetting({
    required int salaryAmount,
    required int salaryDay,
    required int reportingStartDay,
  }) async {
    setting = {
      'salaryAmount': '$salaryAmount',
      'salaryDay': salaryDay,
      'reportingStartDay': reportingStartDay,
    };
  }

  @override
  Future<Map<String, dynamic>> getBudgetPlan() async => {
    'isConfigured': savedPlan != null,
    'allocations': [
      for (final (id, name) in budgetPlanItems)
        {
          'categoryId': id,
          'name': name,
          'percentage': id == 'core.saving' ? 100 : 0,
        },
    ],
  };

  @override
  Future<Map<String, dynamic>> updateBudgetPlan(
    List<Map<String, dynamic>> allocations,
  ) async {
    savedPlan = allocations;
    return {'allocations': allocations};
  }
}

class _FakePolicyApi extends PolicyApi {
  _FakePolicyApi() : super(Dio());

  final List<Map<String, dynamic>> profileUpdates = [];

  @override
  Future<Map<String, dynamic>> getProfile() async => {};

  @override
  Future<void> updateProfile({
    String? nickname,
    int? age,
    String? region,
  }) async {
    profileUpdates.add({'age': age, 'region': region});
  }
}

void main() {
  testWidgets('new user: 사용자 정보 → 예산 배분 → done', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final finance = _NewUserFinanceApi();
    final policy = _FakePolicyApi();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        financeApiProvider.overrideWithValue(finance),
        policyApiProvider.overrideWithValue(policy),
      ],
    );
    addTearDown(container.dispose);
    container.read(authProvider.notifier).login('new@user.dev');
    expect(
      await container.read(onboardingStepProvider.future),
      OnboardingStep.profile,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('기본 정보를 알려주세요'), findsOneWidget);

    // Required salary info missing: nothing is saved.
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('월급 금액을 입력해주세요.'), findsOneWidget);
    expect(finance.setting, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-salary')),
      '3000000',
    );
    await tester.tap(find.byKey(const ValueKey('onboarding-salary-day')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('매월 5일').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(finance.setting?['salaryAmount'], '3000000');
    expect(finance.setting?['salaryDay'], 5);
    expect(policy.profileUpdates, isEmpty); // optional fields left empty
    expect(container.read(onboardingStepProvider).value, OnboardingStep.budget);
    expect(find.text('월급을 어떻게 나눠 쓸까요?'), findsOneWidget);
    expect(find.text('3,000,000원'), findsOneWidget); // 저축 100% preview

    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();
    expect(finance.savedPlan, hasLength(12));
    expect(container.read(onboardingStepProvider).value, OnboardingStep.done);
  });
}
