import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/wallet_glass.dart';
import '../../../core/widgets/glass.dart';
import '../widgets/logout_dialog.dart';
import 'account_settings_screen.dart';
import 'app_info_screen.dart';
import 'app_settings_screen.dart';
import 'budget_plan_settings_screen.dart';
import 'category_management_screen.dart';
import 'coming_soon_screen.dart';
import 'data_management_screen.dart';
import 'notification_settings_screen.dart';
import 'salary_cycle_settings_screen.dart';

/// Height of the shell's floating nav pill (`ScaffoldWithNavBar` in
/// core/router.dart, ~86px including its 14px bottom gap) plus a small margin.
const double _floatingNavClearance = 96;

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    return Scaffold(
      // The tab shell paints the ambient background behind every tab.
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '설정',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: glass.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.notifications_none,
                      color: glass.textPrimary,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            Expanded(
              // End the list viewport above the shell's floating nav pill so
              // the last row and the logout button never sit behind it.
              child: Padding(
                padding: const EdgeInsets.only(bottom: _floatingNavClearance),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    // Rows are grouped into a few section surfaces (same
                    // order as before) instead of one card per row, so the
                    // menu doesn't read as a stack of boxes.
                    _MenuSection(
                      items: [
                        _MenuItem(
                          icon: Icons.person_outline,
                          title: '계정 관리',
                          subtitle: '이메일, 비밀번호, 프로필 관리',
                          onTap: () =>
                              _push(context, const AccountSettingsScreen()),
                        ),
                        _MenuItem(
                          icon: Icons.calendar_month_outlined,
                          title: '정기 수입 설정',
                          subtitle: '정기 수입 금액과 들어오는 날',
                          onTap: () =>
                              _push(context, const SalaryCycleSettingsScreen()),
                        ),
                        _MenuItem(
                          icon: Icons.pie_chart_outline,
                          title: '예산 배분 설정',
                          subtitle: '저축·투자·지출 예산 비율 설정',
                          onTap: () =>
                              _push(context, const BudgetPlanSettingsScreen()),
                        ),
                        _MenuItem(
                          icon: Icons.grid_view_outlined,
                          title: '카테고리 관리',
                          subtitle: '지출/수입 카테고리 관리',
                          onTap: () =>
                              _push(context, const CategoryManagementScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _MenuSection(
                      items: [
                        _MenuItem(
                          icon: Icons.notifications_none,
                          title: '알림 설정',
                          subtitle: '알림 항목 및 시간 설정',
                          onTap: () => _push(
                            context,
                            const NotificationSettingsScreen(),
                          ),
                        ),
                        _MenuItem(
                          icon: Icons.cloud_outlined,
                          title: '백업 및 데이터 관리',
                          subtitle: '데이터 백업, 복원, 내보내기 등',
                          onTap: () =>
                              _push(context, const DataManagementScreen()),
                        ),
                        _MenuItem(
                          icon: Icons.settings_outlined,
                          title: '앱 설정',
                          subtitle: '테마, 언어, 화면 등',
                          onTap: () =>
                              _push(context, const AppSettingsScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _MenuSection(
                      items: [
                        _MenuItem(
                          icon: Icons.auto_awesome_outlined,
                          title: 'AI 소비 분석',
                          subtitle: '소비 패턴 AI 분석',
                          onTap: () => _push(
                            context,
                            const ComingSoonScreen(title: 'AI 소비 분석'),
                          ),
                        ),
                        _MenuItem(
                          icon: Icons.info_outline,
                          title: '앱 정보',
                          subtitle: '버전, 이용약관, 개인정보 처리방침 등',
                          onTap: () => _push(context, const AppInfoScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => showLogoutDialog(context, ref),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          '로그아웃',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

/// One glass section holding several plain rows separated by hairlines.
class _MenuSection extends StatelessWidget {
  final List<_MenuItem> items;

  const _MenuSection({required this.items});

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return GlassSurface(
      radius: AppRadii.lg,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 68,
                endIndent: 16,
                color: glass.divider,
              ),
            _row(context, items[i], first: i == 0, last: i == items.length - 1),
          ],
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    _MenuItem item, {
    required bool first,
    required bool last,
  }) {
    final glass = context.glass;
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(first ? AppRadii.lg : 0),
            bottom: Radius.circular(last ? AppRadii.lg : 0),
          ),
        ),
        onTap: item.onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: glass.accentSoft,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Icon(item.icon, color: glass.accentText, size: 22),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: glass.textPrimary,
          ),
        ),
        subtitle: Text(
          item.subtitle,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: glass.textSecondary,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: glass.textTertiary),
      ),
    );
  }
}
