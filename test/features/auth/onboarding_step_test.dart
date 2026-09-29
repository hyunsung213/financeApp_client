import 'package:dio/dio.dart';
import 'package:finance_client/data/api/finance_api.dart';
import 'package:finance_client/features/auth/providers/auth_provider.dart';
import 'package:finance_client/features/auth/providers/onboarding_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFinanceApi extends FinanceApi {
  _FakeFinanceApi({this.setting, this.isConfigured = false}) : super(Dio());

  final Map<String, dynamic>? setting;
  final bool isConfigured;

  @override
  Future<Map<String, dynamic>?> getSettingOrNull() async => setting;

  @override
  Future<Map<String, dynamic>> getBudgetPlan() async => {
    'isConfigured': isConfigured,
    'allocations': [],
  };
}

void main() {
  Future<ProviderContainer> signedInContainer(FinanceApi api) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        financeApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    container.read(authProvider.notifier).login('a@b.c');
    return container;
  }

  test('signed out has no step', () async {
    final container = ProviderContainer(
      overrides: [financeApiProvider.overrideWithValue(_FakeFinanceApi())],
    );
    addTearDown(container.dispose);
    expect(await container.read(onboardingStepProvider.future), isNull);
  });

  test('no finance setting yet → 사용자 정보', () async {
    final container = await signedInContainer(_FakeFinanceApi());
    expect(
      await container.read(onboardingStepProvider.future),
      OnboardingStep.profile,
    );
  });

  test('setting saved but default plan → 예산 배분', () async {
    final container = await signedInContainer(
      _FakeFinanceApi(setting: {'salaryAmount': '2500000', 'salaryDay': 25}),
    );
    expect(
      await container.read(onboardingStepProvider.future),
      OnboardingStep.budget,
    );
  });

  test('setting and configured plan (existing account) → done', () async {
    final container = await signedInContainer(
      _FakeFinanceApi(
        setting: {'salaryAmount': '2500000', 'salaryDay': 1},
        isConfigured: true,
      ),
    );
    expect(
      await container.read(onboardingStepProvider.future),
      OnboardingStep.done,
    );
  });
}
