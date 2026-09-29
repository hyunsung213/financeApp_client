import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import '../theme/auth_tokens.dart';
import '../widgets/auth_components.dart';

/// Shown to a signed-in user while the initial-setup progress is read from
/// the backend; the router then moves on to onboarding or Home. If the read
/// fails (e.g. the backend is down) it offers a retry or a way back to LOGIN
/// instead of guessing a step.
class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(onboardingStepProvider);
    final failed = step.hasError && !step.isLoading;

    return AuthPage(
      greenHero: true,
      children: [
        const SizedBox(height: 56),
        const AuthLogo(onGreen: true),
        const Spacer(),
        if (failed) ...[
          Text(
            '정보를 불러오지 못했어요.\n잠시 후 다시 시도해주세요.',
            textAlign: TextAlign.center,
            style: AuthTokens.text(16, FontWeight.w500, AuthTokens.textPrimary),
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: '다시 시도',
            onPressed: () => ref.invalidate(onboardingStepProvider),
          ),
          const SizedBox(height: 16),
          Center(
            child: AuthTextLink(
              label: '로그인 화면으로',
              onTap: () => ref.read(authProvider.notifier).logout(),
            ),
          ),
        ] else
          const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AuthTokens.accent,
              ),
            ),
          ),
        const Spacer(),
      ],
    );
  }
}
