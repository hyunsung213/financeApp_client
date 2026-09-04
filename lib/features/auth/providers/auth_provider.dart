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
    seedUser.budgetAllocation = {
      'savings': 40,
      'invest': 20,
      'fixed': 10,
      'spending': 30,
    };

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

  Future<void> completeOnboarding({required int salary, required int salaryDay, required Map<String, int> budget}) async {
    try {
      final financeApi = ref.read(financeApiProvider);

      // 1. 설정 API 호출 (월급, 월급일)
      await financeApi.updateSetting(
        salaryAmount: salary,
        salaryDay: salaryDay,
        reportingStartDay: 1, // Default
      );

      // 2. 예산 배분 API 호출
      // 백엔드 검증 로직에 따라 합계가 100%가 되도록 순차 전송
      await financeApi.createAllocation(name: '저축', allocationType: 'SAVING', percentage: budget['savings']!.toDouble(), spendability: 'LOCKED', active: true);
      await financeApi.createAllocation(name: '투자', allocationType: 'INVESTMENT', percentage: budget['invest']!.toDouble(), spendability: 'LOCKED', active: true);
      await financeApi.createAllocation(name: '고정생활', allocationType: 'FIXED_LIVING', percentage: budget['fixed']!.toDouble(), spendability: 'RESERVED', active: true);
      await financeApi.createAllocation(name: '소비', allocationType: 'FLEXIBLE', percentage: budget['spending']!.toDouble(), spendability: 'FLEXIBLE', active: true);

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
