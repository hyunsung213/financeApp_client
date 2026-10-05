import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/wallet_glass.dart';
import '../core/widgets/glass.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/providers/onboarding_provider.dart';

// Screens placeholders
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/find_password_screen.dart';
import '../features/auth/screens/verify_email_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/auth/screens/startup_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/calendar/screens/calendar_screen.dart';
import '../features/report/screens/report_screen.dart';
import '../features/policy/screens/policy_screen.dart';
import '../features/policy/screens/policy_detail_screen.dart';
import '../features/policy/screens/policy_bookmarks_screen.dart';
import '../features/mypage/screens/my_page_screen.dart';

/// Auth screens reachable while signed out.
const Set<String> _authFlowPaths = {
  '/login',
  '/signup',
  '/find-password',
  '/verify-email',
  '/reset-password',
};

/// Start-up gate shown while the setup progress is being read.
const String startupPath = '/startup';

/// Where a user at [path] belongs:
///
/// - signed out → LOGIN (or the other auth screens)
/// - signed in, setup progress not known yet (or failed to load) → [startupPath]
/// - 사용자 정보 or 예산 배분 still missing → `/onboarding`
/// - setup done → the requested screen, or Home instead of LOGIN/onboarding
///
/// Returns null to stay on [path].
String? resolveAppRedirect({
  required String path,
  required bool isAuthenticated,
  required AsyncValue<OnboardingStep?> onboardingStep,
}) {
  final isAuthFlow = _authFlowPaths.contains(path);
  if (!isAuthenticated) return isAuthFlow ? null : '/login';

  // A reload after sign-in still carries the signed-out null, so null means
  // "not known yet" here.
  final step = onboardingStep.hasError ? null : onboardingStep.value;
  if (step == null) return path == startupPath ? null : startupPath;

  if (step != OnboardingStep.done) {
    return path == '/onboarding' ? null : '/onboarding';
  }
  if (isAuthFlow || path == '/onboarding' || path == startupPath) {
    return '/home';
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  // One router for the app's lifetime; auth and setup-progress changes only
  // re-run the redirect. Moving to LOGIN on logout replaces the whole page
  // stack, so back can't return to Home.
  final refresh = ValueNotifier<int>(0);
  void bump(_, _) => refresh.value++;
  ref.listen(authProvider, bump);
  ref.listen(onboardingStepProvider, bump);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: startupPath,
    refreshListenable: refresh,
    redirect: (context, state) => resolveAppRedirect(
      path: state.uri.path,
      isAuthenticated: ref.read(authProvider).isAuthenticated,
      onboardingStep: ref.read(onboardingStepProvider),
    ),
    routes: [
      GoRoute(
        path: startupPath,
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/find-password',
        builder: (context, state) => const FindPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) =>
            VerifyEmailScreen(email: state.extra as String?),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      // Five-tab bottom navigation (Figma node 335:8091 "Bottom Navigation
      // Component"): 홈 / 캘린더 / 리포트 / 뉴스 / 마이. Each tab is a real
      // StatefulShellBranch so navigation state (scroll position, provider
      // caches, etc.) is preserved when switching tabs, matching go_router's
      // IndexedStack semantics. "뉴스" reuses PolicyScreen/policy routes
      // unchanged - only the nav label/icon differ from before. MyPage was
      // previously a standalone push route reached from Home's avatar; it is
      // now branch #4 (index 4) so it participates in the shell like the
      // other tabs. Policy Detail/Bookmarks stay nested *inside* the
      // '/policy' branch (below) rather than pushed as a root-level route,
      // so the floating nav pill stays visible on them - only truly
      // full-screen flows (Add/Edit Transaction, pushed with
      // `Navigator.of(context, rootNavigator: true)`) hide it, via
      // `isShellOnTop` in `ScaffoldWithNavBar` below.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/report',
                builder: (context, state) => const ReportScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/policy',
                builder: (context, state) => const PolicyScreen(),
                routes: [
                  // Registered before ':id' so '/policy/bookmarks' resolves as
                  // the literal bookmarks route, not id == "bookmarks" (same
                  // ordering concern the backend's own API_SPEC.md calls out
                  // for '/api/policies/bookmarks' vs '/api/policies/:id').
                  GoRoute(
                    path: 'bookmarks',
                    builder: (context, state) => const PolicyBookmarksScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => PolicyDetailScreen(
                      policyId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mypage',
                builder: (context, state) => const MyPageScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (label: '홈', icon: Icons.home_rounded),
    (label: '캘린더', icon: Icons.calendar_month_rounded),
    (label: '리포트', icon: Icons.pie_chart_rounded),
    (label: '뉴스', icon: Icons.article_rounded),
    (label: '마이', icon: Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    // False while anything sits above the shell (a bottom sheet, dialog, or a
    // pushed full-screen route), so the floating pill slides away instead of
    // hovering over modals.
    final isShellOnTop = ModalRoute.of(context)?.isCurrent ?? true;
    final glass = context.glass;

    return Scaffold(
      backgroundColor: glass.backgroundBottom,
      body: Stack(
        children: [
          // Level 0: one ambient backdrop shared by all five tabs (their own
          // Scaffolds are transparent), so it is painted once, not per tab.
          const Positioned.fill(child: WalletBackground()),

          // Main screen content
          navigationShell,

          // Content scrolling under the pill fades into the page color, so
          // the nav reads as floating above it rather than cutting it off.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 120,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      glass.backgroundBottom.withValues(alpha: 0),
                      glass.backgroundBottom.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Level 3: floating glass bottom navigation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !isShellOnTop,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                offset: isShellOnTop ? Offset.zero : const Offset(0, 1.4),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: isShellOnTop ? 1 : 0,
                  child: _buildNavBar(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: GlassSurface(
              level: GlassLevel.floating,
              radius: 32,
              blurSigma: GlassBlur.floating,
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    _buildNavItem(
                      context,
                      index: i,
                      label: _tabs[i].label,
                      icon: _tabs[i].icon,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required String label,
    required IconData icon,
  }) {
    final glass = context.glass;
    final isSelected = navigationShell.currentIndex == index;
    final color = isSelected
        ? glass.navActiveContent
        : glass.navInactiveContent;

    // Active tab gets a pill background (Figma: #D6F3E8 fill, #007C4F
    // content) plus a heavier label, not just a color swap.
    return Expanded(
      child: Semantics(
        selected: isSelected,
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? glass.navActiveFill
                    : glass.navActiveFill.withValues(alpha: 0),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Center(child: Icon(icon, size: 22, color: color)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: color,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
