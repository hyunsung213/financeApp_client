import 'package:flutter/foundation.dart';

/// Build-time settings, passed with `--dart-define`.
///
/// | Build                         | Flags                                   |
/// |-------------------------------|-----------------------------------------|
/// | Android emulator (dev)        | none → `http://10.0.2.2:4000`           |
/// | Web / desktop against a local | none → `http://localhost:4000`          |
/// | backend (dev)                 |                                         |
/// | Public web demo               | `DEMO_MODE=true` (no backend calls)     |
/// | Future production             | `API_BASE_URL=https://...`              |
/// | Real sign-in (any build)      | `SUPABASE_URL=https://<ref>.supabase.co`|
/// |                               | `SUPABASE_ANON_KEY=<anon key>`          |
///
/// Only the anon key is ever built into the app; the service role key stays
/// on the backend.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Real Supabase Auth: sign-in creates a session whose access token is sent
  /// to the backend as `Authorization: Bearer`. Without both values a debug
  /// build keeps the mock sign-in for a local backend running with
  /// `DEV_AUTH_BYPASS=true` (a release build refuses to sign in instead).
  static bool get authConfigured =>
      !demoMode && supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Serves every API call from an in-browser sample dataset instead of the
  /// backend (see `data/demo/`). Off unless explicitly enabled, so Android
  /// and local development builds keep talking to the real backend.
  static const bool demoMode = bool.fromEnvironment('DEMO_MODE');

  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  /// Backend origin. An explicit `API_BASE_URL` wins; otherwise the local
  /// development backend on port 4000, reached through `10.0.2.2` from the
  /// Android emulator and `localhost` everywhere else.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return isAndroid ? 'http://10.0.2.2:4000' : 'http://localhost:4000';
  }
}
