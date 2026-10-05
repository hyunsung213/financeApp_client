import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';

/// The user's 테마 설정 choice (앱 설정), kept on the device only. It is a
/// local preference, so it never goes to the backend.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const storageKey = 'settings.themeMode';

  @override
  ThemeMode build() {
    final saved = ref.read(sharedPreferencesProvider)?.getString(storageKey);
    // Light until chosen otherwise: most screens are not dark-ready yet, so
    // following a dark OS setting by default would surprise existing users.
    return ThemeMode.values.asNameMap()[saved] ?? ThemeMode.light;
  }

  void setMode(ThemeMode mode) {
    state = mode;
    ref.read(sharedPreferencesProvider)?.setString(storageKey, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
