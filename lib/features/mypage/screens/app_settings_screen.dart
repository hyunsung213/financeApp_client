import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_lock/app_lock.dart';
import '../../../core/format/money_format.dart';
import '../../../core/providers/theme_mode_provider.dart';
import '../../../core/theme/app_palette.dart';
import '../theme/my_tokens.dart';
import '../widgets/app_settings_components.dart';
import 'home_display_settings_screen.dart';
import 'language_settings_screen.dart';
import 'money_format_settings_screen.dart';

/// 앱 설정 — Figma Frame 106 (176:5580).
///
/// Every setting here is a local, on-device preference (no backend):
/// 테마 ([themeModeProvider]), 금액 표시 형식 ([moneyDisplayFormatProvider]),
/// 홈 화면 항목 (`homeSectionVisibilityProvider`) and 앱 잠금
/// ([appLockEnabledProvider], OS biometrics). 언어 only states that the app
/// is Korean-only.
///
/// Colors come from `context.palette` so this screen follows dark mode.
class AppSettingsScreen extends ConsumerStatefulWidget {
  const AppSettingsScreen({super.key});

  static const String webAppLockMessage = '앱 잠금은 Android/iOS 앱에서 사용할 수 있어요.';
  static const String noBiometricsMessage = '이 기기에서는 생체인증을 사용할 수 없어요.';
  static const String appLockFailedMessage = '본인 인증을 완료하지 않아 앱 잠금을 켜지 않았어요.';
  static const String appLockOnMessage = '앱 잠금을 켰어요.';
  static const String appLockOffMessage = '앱 잠금을 껐어요.';

  /// Sample shown on the 금액 표시 형식 row, in the chosen format.
  static const int amountPreviewSample = 123456;

  /// The app is Korean-only.
  static const String currentLanguageLabel = '한국어';

  @override
  ConsumerState<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends ConsumerState<AppSettingsScreen> {
  bool _appLockBusy = false;

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _setAppLock(bool turnOn) async {
    if (_appLockBusy) return;
    final notifier = ref.read(appLockEnabledProvider.notifier);
    if (!turnOn) {
      notifier.disable();
      showAppSettingsNotice(context, AppSettingsScreen.appLockOffMessage);
      return;
    }
    setState(() => _appLockBusy = true);
    final result = await notifier.enable();
    if (!mounted) return;
    setState(() => _appLockBusy = false);
    showAppSettingsNotice(context, switch (result) {
      AppLockEnableResult.enabled => AppSettingsScreen.appLockOnMessage,
      AppLockEnableResult.unsupportedPlatform =>
        AppSettingsScreen.webAppLockMessage,
      AppLockEnableResult.noBiometrics => AppSettingsScreen.noBiometricsMessage,
      AppLockEnableResult.failed => AppSettingsScreen.appLockFailedMessage,
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final moneyFormat = ref.watch(moneyDisplayFormatProvider);
    final appLockEnabled = ref.watch(appLockEnabledProvider);
    final appLockSupported = ref
        .watch(appLockAuthenticatorProvider)
        .isPlatformSupported;

    return AppSettingsScaffold(
      title: '앱 설정',
      children: [
        _ThemeCard(
          selected: themeMode,
          onSelected: ref.read(themeModeProvider.notifier).setMode,
        ),
        const SizedBox(height: 12),
        AppSettingsRow(
          title: '화면 표시',
          subtitle: '금액 표시 형식',
          value: formatMoney(AppSettingsScreen.amountPreviewSample, moneyFormat),
          onTap: () => _push(const MoneyFormatSettingsScreen()),
        ),
        const SizedBox(height: 12),
        AppSettingsRow(
          title: '언어 설정',
          value: AppSettingsScreen.currentLanguageLabel,
          onTap: () => _push(const LanguageSettingsScreen()),
        ),
        const SizedBox(height: 12),
        AppSettingsRow(
          title: '홈 화면 설정',
          subtitle: '홈 첫 화면 관리',
          onTap: () => _push(const HomeDisplaySettingsScreen()),
        ),
        const SizedBox(height: 12),
        AppSettingsRow(
          title: '기타',
          subtitle: '앱 잠금',
          minHeight: 68,
          trailing: WalletToggle(
            value: appLockEnabled,
            onChanged: appLockSupported && !_appLockBusy ? _setAppLock : null,
          ),
          onTap: appLockSupported
              ? () => _setAppLock(!appLockEnabled)
              : () => showAppSettingsNotice(
                  context,
                  AppSettingsScreen.webAppLockMessage,
                ),
        ),
      ],
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final ThemeMode selected;
  final ValueChanged<ThemeMode> onSelected;

  const _ThemeCard({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: appSettingsCardDecoration(context),
      padding: const EdgeInsets.fromLTRB(12, 16, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('테마 설정', style: appSettingsTitleStyle(palette)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final option in _ThemeOption.values) ...[
                if (option != _ThemeOption.values.first)
                  const SizedBox(width: 9),
                Expanded(
                  child: _ThemeButton(
                    option: option,
                    selected: option.mode == selected,
                    onTap: () => onSelected(option.mode),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Each Figma button is a small swatch of the theme it picks, so its fill
/// and label color stay fixed; the selected one gets the green outline.
enum _ThemeOption {
  light('라이트', ThemeMode.light, Colors.white, MyTokens.accent),
  dark('다크', ThemeMode.dark, Color(0xFF2D2D2D), MyTokens.accent),
  system('시스템', ThemeMode.system, Color(0xFF575E5C), MyTokens.accentSoftBorder);

  final String label;
  final ThemeMode mode;
  final Color background;
  final Color foreground;

  const _ThemeOption(this.label, this.mode, this.background, this.foreground);
}

class _ThemeButton extends StatelessWidget {
  final _ThemeOption option;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeButton({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(MyTokens.cardRadius);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: option.background,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? MyTokens.accent : Colors.transparent,
            width: 2,
          ),
        ),
        shadowColor: Colors.black.withValues(alpha: 0.05),
        elevation: 1,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox(
            height: 37,
            child: Center(
              child: Text(
                option.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  letterSpacing: -0.45,
                  color: option.foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
