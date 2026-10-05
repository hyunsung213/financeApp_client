import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../home/providers/home_section_visibility_provider.dart';
import '../widgets/app_settings_components.dart';

/// 앱 설정 > 홈 화면 설정. Shows or hides Home's optional sections; the
/// spendable amount and budget card at the top are always shown.
class HomeDisplaySettingsScreen extends ConsumerWidget {
  const HomeDisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final visibility = ref.watch(homeSectionVisibilityProvider);
    final notifier = ref.read(homeSectionVisibilityProvider.notifier);

    return AppSettingsScaffold(
      title: '홈 화면 설정',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            '홈 화면에 표시할 항목',
            style: appSettingsTitleStyle(palette),
          ),
        ),
        AppSettingsRow(
          title: '실시간 거래 내역',
          subtitle: '오늘 거래와 카테고리별 거래',
          trailing: WalletToggle(
            value: visibility.showRecentTransactions,
            onChanged: notifier.setRecentTransactions,
          ),
          onTap: () => notifier.setRecentTransactions(
            !visibility.showRecentTransactions,
          ),
        ),
        const SizedBox(height: 12),
        AppSettingsRow(
          title: '최근 소비 돌아보기',
          subtitle: "'아쉬운 소비'로 평가한 최근 거래",
          trailing: WalletToggle(
            value: visibility.showRegretReview,
            onChanged: notifier.setRegretReview,
          ),
          onTap: () => notifier.setRegretReview(!visibility.showRegretReview),
        ),
        const AppSettingsCaption(
          '오늘 쓸 수 있는 금액과 다음 수입까지 남은 예산은 항상 표시돼요.',
        ),
      ],
    );
  }
}
