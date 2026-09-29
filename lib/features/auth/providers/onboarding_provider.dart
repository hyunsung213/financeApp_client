import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/api/finance_api.dart';
import '../../../data/api/policy_api.dart';
import '../../home/providers/home_provider.dart';
import '../../mypage/providers/my_page_provider.dart';
import '../../policy/providers/policy_provider.dart';
import 'auth_provider.dart';

/// Which initial-setup step a signed-in user still needs.
enum OnboardingStep {
  /// No finance setting yet (`GET /api/finance/setting` data is null).
  profile,

  /// Setting saved, but the budget plan is still the backend default
  /// (`GET /api/finance/budget-plan` → `isConfigured: false`).
  budget,

  /// Both saved: the user goes straight to Home.
  done,
}

/// Initial-setup progress, read from the backend rather than a local flag, so
/// an existing account with a salary setting and a saved plan is treated as
/// done, and a setup interrupted by closing the app resumes at the right step.
/// Null while signed out.
final onboardingStepProvider = FutureProvider<OnboardingStep?>((ref) async {
  final signedIn = ref.watch(authProvider.select((s) => s.isAuthenticated));
  if (!signedIn) return null;

  final financeApi = ref.watch(financeApiProvider);
  final setting = await financeApi.getSettingOrNull();
  if (setting == null) return OnboardingStep.profile;

  final plan = await financeApi.getBudgetPlan();
  return plan['isConfigured'] == true
      ? OnboardingStep.done
      : OnboardingStep.budget;
});

/// Saved values used to pre-fill the 사용자 정보 step (empty for a new user,
/// filled when coming back from the budget step).
class OnboardingProfileDraft {
  final int? salaryAmount;
  final int? salaryDay;
  final int? reportingStartDay;
  final int? age;
  final String? region;

  const OnboardingProfileDraft({
    this.salaryAmount,
    this.salaryDay,
    this.reportingStartDay,
    this.age,
    this.region,
  });
}

final onboardingProfileDraftProvider =
    FutureProvider.autoDispose<OnboardingProfileDraft>((ref) async {
      final setting = await ref.watch(financeApiProvider).getSettingOrNull();
      Map<String, dynamic> profile = const {};
      try {
        profile = await ref.watch(policyApiProvider).getProfile();
      } catch (_) {
        // The profile fields are optional; a failed read just leaves them empty.
      }
      int? asInt(dynamic value) =>
          value is num ? value.toInt() : int.tryParse('${value ?? ''}');
      return OnboardingProfileDraft(
        salaryAmount: asInt(setting?['salaryAmount']),
        salaryDay: asInt(setting?['salaryDay']),
        reportingStartDay: asInt(setting?['reportingStartDay']),
        age: asInt(profile['age']),
        region: profile['region'] as String?,
      );
    });

class OnboardingActions extends Notifier<void> {
  @override
  void build() {}

  /// Saves the 사용자 정보 step. The optional policy-profile fields go first
  /// (`PUT /api/profile`) so that once the finance setting exists - which is
  /// what marks this step done - everything the user entered is saved.
  Future<void> saveProfileStep({
    required int salaryAmount,
    required int salaryDay,
    required int reportingStartDay,
    int? age,
    String? region,
  }) async {
    if (age != null || region != null) {
      await ref.read(policyApiProvider).updateProfile(age: age, region: region);
    }
    await ref
        .read(financeApiProvider)
        .updateSetting(
          salaryAmount: salaryAmount,
          salaryDay: salaryDay,
          reportingStartDay: reportingStartDay,
        );
    ref.invalidate(profileProvider);
    ref.invalidate(myPageDataProvider);
    ref.invalidate(homeDataProvider);
    await refreshStep();
  }

  /// Re-reads the setup progress; the router follows the new step.
  Future<void> refreshStep() async {
    ref.invalidate(onboardingStepProvider);
    await ref.read(onboardingStepProvider.future);
  }
}

final onboardingActionsProvider = NotifierProvider<OnboardingActions, void>(
  OnboardingActions.new,
);
