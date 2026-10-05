import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money_format.dart';
import '../../../core/theme/app_palette.dart';
import '../widgets/app_settings_components.dart';

/// 앱 설정 > 화면 표시 > 금액 표시 형식. Changes how amounts are shown across
/// the app; amounts themselves (and amount inputs) are never changed.
class MoneyFormatSettingsScreen extends ConsumerWidget {
  const MoneyFormatSettingsScreen({super.key});

  static const int sampleAmount = 1234567;

  static const _labels = {
    MoneyDisplayFormat.exact: '정확하게 표시',
    MoneyDisplayFormat.compact: '간단하게 표시',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final selected = ref.watch(moneyDisplayFormatProvider);

    return AppSettingsScaffold(
      title: '금액 표시 형식',
      children: [
        Container(
          decoration: appSettingsCardDecoration(context),
          padding: const EdgeInsets.fromLTRB(12, 16, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('미리보기', style: appSettingsSubtitleStyle(palette)),
              const SizedBox(height: 6),
              Text(
                formatMoney(sampleAmount, selected),
                key: const ValueKey('money-format-preview'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  letterSpacing: -0.45,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final format in MoneyDisplayFormat.values) ...[
          AppSettingsChoiceCard(
            title: _labels[format]!,
            subtitle: formatMoney(sampleAmount, format),
            selected: format == selected,
            onTap: () =>
                ref.read(moneyDisplayFormatProvider.notifier).setFormat(format),
          ),
          const SizedBox(height: 12),
        ],
        const AppSettingsCaption(
          '보이는 방식만 바뀌고, 실제 금액과 입력은 그대로예요.\n'
          '1만원 미만은 간단하게 표시해도 그대로 보여요.',
        ),
      ],
    );
  }
}
