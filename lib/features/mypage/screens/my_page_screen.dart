import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../auth/providers/auth_provider.dart';
import 'app_info_screen.dart';
import 'coming_soon_screen.dart';
import 'notification_settings_screen.dart';
import 'salary_cycle_settings_screen.dart';

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            child: const Text('로그아웃', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('설정', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                children: [
                  _menuRow(
                    context,
                    icon: Icons.person_outline,
                    title: '계정 관리',
                    subtitle: '이메일, 비밀번호, 프로필 관리',
                    onTap: () => _push(context, const ComingSoonScreen(title: '계정 관리')),
                  ),
                  _menuRow(
                    context,
                    icon: Icons.calendar_month_outlined,
                    title: '월급 주기 설정',
                    subtitle: '월급일, 주기 설정',
                    onTap: () => _push(context, const SalaryCycleSettingsScreen()),
                  ),
                  _menuRow(
                    context,
                    icon: Icons.grid_view_outlined,
                    title: '카테고리 관리',
                    subtitle: '지출/수입 카테고리 관리',
                    onTap: () => _push(context, const ComingSoonScreen(title: '카테고리 관리')),
                  ),
                  _menuRow(
                    context,
                    icon: Icons.notifications_none,
                    title: '알림 설정',
                    subtitle: '알림 항목 및 시간 설정',
                    onTap: () => _push(context, const NotificationSettingsScreen()),
                  ),
                  _menuRow(
                    context,
                    icon: Icons.cloud_outlined,
                    title: '백업 및 데이터 관리',
                    subtitle: '데이터 백업, 복원, 내보내기 등',
                    onTap: () => _push(context, const ComingSoonScreen(title: '백업 및 데이터 관리')),
                  ),
                  _menuRow(
                    context,
                    icon: Icons.settings_outlined,
                    title: '앱 설정',
                    subtitle: '테마, 언어, 화면 등',
                    onTap: () => _push(context, const ComingSoonScreen(title: '앱 설정')),
                  ),
                  _menuRow(
                    context,
                    icon: Icons.auto_awesome_outlined,
                    title: 'AI 소비 분석',
                    subtitle: '소비 패턴 AI 분석',
                    onTap: () => _push(context, const ComingSoonScreen(title: 'AI 소비 분석')),
                  ),
                  _menuRow(
                    context,
                    icon: Icons.info_outline,
                    title: '앱 정보',
                    subtitle: '버전, 이용약관, 개인정보 처리방침 등',
                    onTap: () => _push(context, const AppInfoScreen()),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showLogoutDialog(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('로그아웃', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ),
    );
  }
}
