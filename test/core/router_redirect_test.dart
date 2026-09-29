import 'package:finance_client/core/router.dart';
import 'package:finance_client/features/auth/providers/onboarding_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? redirect(
    String path, {
    bool signedIn = true,
    AsyncValue<OnboardingStep?> step = const AsyncData(OnboardingStep.done),
  }) => resolveAppRedirect(
    path: path,
    isAuthenticated: signedIn,
    onboardingStep: step,
  );

  test('signed out: app start and Home go to LOGIN, auth screens stay', () {
    expect(redirect(startupPath, signedIn: false), '/login');
    expect(redirect('/home', signedIn: false), '/login');
    expect(redirect('/onboarding', signedIn: false), '/login');
    expect(redirect('/login', signedIn: false), isNull);
    expect(redirect('/signup', signedIn: false), isNull);
  });

  test('signed in, progress unknown or failed: wait on the startup gate', () {
    for (final step in <AsyncValue<OnboardingStep?>>[
      const AsyncLoading(),
      const AsyncData(null),
      AsyncError(Exception('down'), StackTrace.empty),
    ]) {
      expect(redirect('/login', step: step), startupPath);
      expect(redirect(startupPath, step: step), isNull);
    }
  });

  test('setup not finished: always the onboarding route', () {
    for (final step in [OnboardingStep.profile, OnboardingStep.budget]) {
      expect(redirect(startupPath, step: AsyncData(step)), '/onboarding');
      expect(redirect('/home', step: AsyncData(step)), '/onboarding');
      expect(redirect('/login', step: AsyncData(step)), '/onboarding');
      expect(redirect('/onboarding', step: AsyncData(step)), isNull);
    }
  });

  test('setup done: Home instead of LOGIN/onboarding, other routes stay', () {
    expect(redirect(startupPath), '/home');
    expect(redirect('/login'), '/home');
    expect(redirect('/onboarding'), '/home');
    expect(redirect('/home'), isNull);
    expect(redirect('/mypage'), isNull);
  });
}
