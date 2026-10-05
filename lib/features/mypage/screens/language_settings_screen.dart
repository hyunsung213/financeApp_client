import 'package:flutter/material.dart';

import '../widgets/app_settings_components.dart';

/// 앱 설정 > 언어 설정. The app ships Korean only (no localization set up),
/// so this states that instead of offering languages it can't show.
class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  static const String koreanOnlyMessage = '현재 한국어만 지원해요.';

  @override
  Widget build(BuildContext context) {
    return const AppSettingsScaffold(
      title: '언어 설정',
      children: [
        AppSettingsChoiceCard(title: '한국어', selected: true),
        AppSettingsCaption(koreanOnlyMessage),
      ],
    );
  }
}
