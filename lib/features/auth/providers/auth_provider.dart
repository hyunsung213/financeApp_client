import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/api/finance_api.dart';
import '../../../data/mocks/db.dart'; // Keeping for User model

class AuthState {
  final bool isAuthenticated;
  final MockUser? user;
  final bool hasCompletedOnboarding;

  AuthState({
    this.isAuthenticated = false,
    this.user,
    this.hasCompletedOnboarding = false,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    MockUser? user,
    bool? hasCompletedOnboarding,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // 자동 로그인 및 온보딩 패스 (개발용)
    final seedUser = MockUser(
      id: 'auth-user-uuid', 
      email: 'seed@example.local', 
      name: 'seed'
    );
    seedUser.salary = 2500000;
    seedUser.salaryDay = 10;

    return AuthState(
      isAuthenticated: true,
      user: seedUser,
      hasCompletedOnboarding: true,
    );
  }

  void login(String email) {
    // For MVP without real Supabase UI, we mock the user state 
    // but the API calls in completeOnboarding will actually hit the backend.
    final user = MockUser(id: 'auth-user-uuid', email: email, name: email.split('@')[0]);
    
    state = state.copyWith(
      isAuthenticated: true,
      user: user,
      hasCompletedOnboarding: false,
    );
  }

  void logout() {
    state = AuthState();
  }

  /// Saves the salary/payday entered so far and returns the budget plan to
  /// pre-fill onboarding's budget step. `GET /api/finance/budget-plan`
  /// requires a finance setting to exist, and for a user with no saved plan
  /// it returns the backend's default plan (`isConfigured: false`) - so the
  /// initial ratios come from the backend, not from the app.
  Future<List<dynamic>> loadOnboardingBudgetPlan({required int salary, required int salaryDay}) async {
    final financeApi = ref.read(financeApiProvider);
    await financeApi.updateSetting(
      salaryAmount: salary,
      salaryDay: salaryDay,
      reportingStartDay: 1, // Default
    );
    final plan = await financeApi.getBudgetPlan();
    return (plan['allocations'] as List<dynamic>?) ?? [];
  }

  /// [allocations] is the complete 12-item plan (`{categoryId, percentage}`,
  /// see budget_plan_items.dart), saved in one request - the same shape the
  /// salary-cycle settings screen saves.
  Future<void> completeOnboarding({required int salary, required int salaryDay, required List<Map<String, dynamic>> allocations}) async {
    try {
      final financeApi = ref.read(financeApiProvider);

      // 1. 설정 API 호출 (월급, 월급일)
      await financeApi.updateSetting(
        salaryAmount: salary,
        salaryDay: salaryDay,
        reportingStartDay: 1, // Default
      );

      // 2. 예산 배분 12개 항목을 한 번에 저장
      await financeApi.updateBudgetPlan(allocations);

      state = state.copyWith(hasCompletedOnboarding: true);
    } catch (e) {
      print('Onboarding Error: $e');
      // If error occurs, we could show a dialog, but for now we'll just print and still proceed to unblock MVP.
      state = state.copyWith(hasCompletedOnboarding: true);
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
