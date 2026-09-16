import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../features/home/theme/home_tokens.dart';
import '../features/auth/providers/auth_provider.dart';

// Screens placeholders
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/find_password_screen.dart';
import '../features/auth/screens/verify_email_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
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

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggingIn = state.uri.toString() == '/login';
      final isAuthFlow = _authFlowPaths.contains(state.uri.path);
      final isAuth = authState.isAuthenticated;
      final hasOnboarded = authState.hasCompletedOnboarding;

      if (!isAuth && !isAuthFlow) return '/login';
      if (isAuth && !hasOnboarded && state.uri.toString() != '/onboarding')
        return '/onboarding';
      if (isAuth &&
          hasOnboarded &&
          (isLoggingIn || state.uri.toString() == '/onboarding'))
        return '/home';

      return null;
    },
    routes: [
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

  @override
  Widget build(BuildContext context) {
    // False while anything sits above the shell (a bottom sheet, dialog, or a
    // pushed full-screen route), so the floating pill slides away instead of
    // hovering over modals.
    final isShellOnTop = ModalRoute.of(context)?.isCurrent ?? true;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main screen content
          navigationShell,

          // Soft color backdrop behind the floating nav bar, so the mostly
          // white/gray page content isn't colorless right at the bottom edge.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 130,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      HomeTokens.navActiveBg.withValues(alpha: 0),
                      HomeTokens.navActiveBg.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Floating translucent bottom navigation bar
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
                  child: _buildNavBar(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 14),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.95),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(
                        index: 0,
                        label: '홈',
                        icon: Icons.home_rounded,
                      ),
                      _buildNavItem(
                        index: 1,
                        label: '캘린더',
                        icon: Icons.calendar_month_rounded,
                      ),
                      _buildNavItem(
                        index: 2,
                        label: '리포트',
                        icon: Icons.pie_chart_rounded,
                      ),
                      _buildNavItem(
                        index: 3,
                        label: '뉴스',
                        icon: Icons.article_rounded,
                      ),
                      _buildNavItem(
                        index: 4,
                        label: '마이',
                        icon: Icons.person_rounded,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = navigationShell.currentIndex == index;

    // Active tab gets a pill background (Figma: #D6F3E8 fill, #007C4F
    // content) instead of just a color swap, matching node 335:8091's
    // Bottom Navigation Component.
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected ? HomeTokens.navActiveBg : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: Icon(
                      icon,
                      size: 22,
                      color: isSelected
                          ? HomeTokens.navActiveText
                          : HomeTokens.navInactive,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? HomeTokens.navActiveText
                        : HomeTokens.navInactive,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
