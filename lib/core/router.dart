import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../features/auth/providers/auth_provider.dart';

// Screens placeholders
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/calendar/screens/calendar_screen.dart';
import '../features/report/screens/report_screen.dart';
import '../features/policy/screens/policy_screen.dart';
import '../features/policy/screens/policy_detail_screen.dart';
import '../features/mypage/screens/my_page_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggingIn = state.uri.toString() == '/login';
      final isAuth = authState.isAuthenticated;
      final hasOnboarded = authState.hasCompletedOnboarding;

      if (!isAuth && !isLoggingIn) return '/login';
      if (isAuth && !hasOnboarded && state.uri.toString() != '/onboarding') return '/onboarding';
      if (isAuth && hasOnboarded && (isLoggingIn || state.uri.toString() == '/onboarding')) return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Pushed as a full-screen route outside the shell (like the old /mypage
      // push) so the floating bottom nav pill doesn't overlap its own pinned
      // CTA button — a nested shell-branch route keeps that pill on screen.
      GoRoute(
        path: '/policy/:id',
        builder: (context, state) => PolicyDetailScreen(policyId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (context, state) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/calendar', builder: (context, state) => const CalendarScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/report', builder: (context, state) => const ReportScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/policy', builder: (context, state) => const PolicyScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/mypage', builder: (context, state) => const MyPageScreen())]),
        ],
      ),
    ],
  );
});

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(
                        index: 0,
                        label: '홈',
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home_rounded,
                      ),
                      _buildNavItem(
                        index: 1,
                        label: '캘린더',
                        icon: Icons.calendar_today_outlined,
                        activeIcon: Icons.calendar_month_rounded,
                      ),
                      _buildNavItem(
                        index: 2,
                        label: '리포트',
                        icon: Icons.bar_chart_outlined,
                        activeIcon: Icons.bar_chart_rounded,
                      ),
                      _buildNavItem(
                        index: 3,
                        label: '정책',
                        icon: Icons.shield_outlined,
                        activeIcon: Icons.shield_rounded,
                      ),
                      _buildNavItem(
                        index: 4,
                        label: '마이',
                        icon: Icons.person_outline_rounded,
                        activeIcon: Icons.person_rounded,
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
    required IconData activeIcon,
  }) {
    final isSelected = navigationShell.currentIndex == index;
    const activeColor = AppColors.primary;
    const inactiveColor = Color(0xFF9CA3AF);

    void go() {
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }

    return Expanded(
      // The whole cell stays tappable, but the ripple lives inside the small
      // icon pill below — a full-cell InkWell on an unclipped Material paints
      // its splash past its own bounds, which made neighbouring tabs flash.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: go,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Material(
                color: isSelected ? AppColors.primaryLight : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                animationDuration: const Duration(milliseconds: 180),
                child: InkWell(
                  onTap: go,
                  splashColor: activeColor.withValues(alpha: 0.16),
                  highlightColor: activeColor.withValues(alpha: 0.07),
                  child: SizedBox(
                    width: 40,
                    height: 26,
                    child: Center(
                      child: Icon(
                        isSelected ? activeIcon : icon,
                        size: 20,
                        color: isSelected ? activeColor : inactiveColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                  letterSpacing: -0.2,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
