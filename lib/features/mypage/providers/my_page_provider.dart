import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/api/finance_api.dart';
import '../../../data/api/policy_api.dart';
import '../../calendar/screens/calendar_screen.dart';
import '../../home/providers/home_provider.dart';
import '../../policy/providers/policy_provider.dart';
import '../../report/providers/report_provider.dart';

class MyPageData {
  final Map<String, dynamic> setting;

  /// Budget plan items `{categoryId, name, percentage}` from
  /// `GET /api/finance/budget-plan` (저축/투자 + 10 지출 대분류).
  final List<dynamic> allocations;
  final Map<String, dynamic> profile;

  MyPageData({
    required this.setting,
    required this.allocations,
    required this.profile,
  });
}

final myPageDataProvider = FutureProvider.autoDispose<MyPageData>((ref) async {
  final financeApi = ref.watch(financeApiProvider);
  final policyApi = ref.watch(policyApiProvider);

  Map<String, dynamic> setting = {};
  try {
    setting = await financeApi.getSetting();
  } catch (e) {
    setting = {
      'salaryAmount': 2500000,
      'salaryDay': 10,
      'reportingStartDay': 1,
    };
  }

  List<dynamic> allocations = [];
  try {
    final plan = await financeApi.getBudgetPlan();
    allocations = (plan['allocations'] as List<dynamic>?) ?? [];
  } catch (e) {
    allocations = [];
  }

  Map<String, dynamic> profile = {};
  try {
    profile = await policyApi.getProfile();
  } catch (e) {
    profile = {};
  }

  return MyPageData(
    setting: setting,
    allocations: allocations,
    profile: profile,
  );
});

class MyPageActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> saveMyPageSettings({
    required int salaryAmount,
    required int salaryDay,
    required int reportingStartDay,
    int? age,
    String? region,
  }) async {
    final financeApi = ref.read(financeApiProvider);
    final policyApi = ref.read(policyApiProvider);

    // 1. Update Finance Setting
    await financeApi.updateSetting(
      salaryAmount: salaryAmount,
      salaryDay: salaryDay,
      reportingStartDay: reportingStartDay,
    );

    // 2. Update Policy Profile
    if (age != null || region != null) {
      try {
        await policyApi.updateProfile(age: age, region: region);
      } catch (_) {}
    }

    // Invalidate caches
    ref.invalidate(myPageDataProvider);
    ref.invalidate(homeDataProvider);
    ref.invalidate(profileProvider);
    ref.invalidate(recommendedPoliciesProvider);
  }

  /// Saves the 계정 관리 profile fields through `PUT /api/profile`, which
  /// accepts `nickname`, `age` and `region` and only writes the ones sent.
  Future<void> updateProfile({
    String? nickname,
    int? age,
    String? region,
  }) async {
    await ref
        .read(policyApiProvider)
        .updateProfile(nickname: nickname, age: age, region: region);
    ref.invalidate(myPageDataProvider);
    ref.invalidate(profileProvider);
    ref.invalidate(recommendedPoliciesProvider);
  }

  /// Replaces the whole budget plan in one request - the backend only
  /// accepts a complete 12-item plan totalling 100%, so items can't be
  /// saved one at a time. [allocations] items are `{categoryId, percentage}`.
  Future<void> saveBudgetPlan(List<Map<String, dynamic>> allocations) async {
    final financeApi = ref.read(financeApiProvider);
    await financeApi.updateBudgetPlan([
      for (final alloc in allocations)
        {'categoryId': alloc['categoryId'], 'percentage': alloc['percentage']},
    ]);
    // The plan applies to the current cycle right away, so every screen that
    // shows its category limits or daily allowance refetches.
    ref.invalidate(myPageDataProvider);
    ref.invalidate(homeDataProvider);
    ref.invalidate(reportMainDataProvider);
    ref.invalidate(monthlyReportDataProvider);
    ref.invalidate(monthlyReportProvider);
  }
}

final myPageActionsProvider = NotifierProvider<MyPageActionsNotifier, void>(() {
  return MyPageActionsNotifier();
});
