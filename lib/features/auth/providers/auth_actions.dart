import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import 'auth_provider.dart';

/// A user-facing auth failure. [message] is shown on screen as-is.
class AuthActionException implements Exception {
  const AuthActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The auth operations the LOGIN / SIGN_UP / FIND_PASSWORD / VERIFY_EMAIL /
/// RESET_PASSWORD screens call. Screens depend only on this boundary, so the
/// real Supabase implementation can replace [MockAuthActions] without touching
/// the UI.
abstract class AuthActions {
  Future<void> signIn({
    required String email,
    required String password,
    required bool keepSignedIn,
  });

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<void> requestPasswordReset({required String email});

  Future<void> resendVerificationEmail({required String email});

  Future<void> updatePassword({required String newPassword});
}

/// Pre-Supabase implementation.
///
/// - [signIn] keeps the existing mock login (`AuthNotifier.login`): any
///   email/password is accepted, the password is discarded, and no token is
///   created. With [keepSignedIn] only the email is remembered (a dev-only
///   stand-in for a Supabase session) so it survives an app relaunch.
/// - Every other action has no backend yet and throws, so nothing pretends to
///   succeed. Passing `--dart-define=AUTH_UI_PREVIEW=true` to a debug build
///   lets them resolve for visual QA of the success states; release builds
///   never take that path.
class MockAuthActions implements AuthActions {
  MockAuthActions(this._ref);

  final Ref _ref;

  static const bool _uiPreview =
      kDebugMode && bool.fromEnvironment('AUTH_UI_PREVIEW');

  static const AuthActionException _notConnected = AuthActionException(
    '인증 서버 연동 전이라 아직 사용할 수 없어요.',
  );

  @override
  Future<void> signIn({
    required String email,
    required String password,
    required bool keepSignedIn,
  }) async {
    // A release build without SUPABASE_URL / SUPABASE_ANON_KEY must not
    // "sign in" without credentials: the backend would reject every call
    // anyway (DEV_AUTH_BYPASS is ignored in production).
    if (kReleaseMode) {
      throw const AuthActionException('인증 서버 설정이 없어 로그인할 수 없어요.');
    }
    _ref.read(authProvider.notifier).login(email, keepSignedIn: keepSignedIn);
  }

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) => _pending();

  @override
  Future<void> requestPasswordReset({required String email}) => _pending();

  @override
  Future<void> resendVerificationEmail({required String email}) => _pending();

  @override
  Future<void> updatePassword({required String newPassword}) => _pending();

  Future<void> _pending() async {
    if (!_uiPreview) throw _notConnected;
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }
}

/// Web demo (`DEMO_MODE=true`): there is no account to sign in to, so every
/// credential action explains that the demo is entered from LOGIN's
/// "데모로 둘러보기" instead ([AuthNotifier.startDemoSession]).
class DemoAuthActions implements AuthActions {
  const DemoAuthActions();

  static const AuthActionException _demoOnly = AuthActionException(
    '데모에서는 아래 \'데모로 둘러보기\'로 이용할 수 있어요.',
  );

  @override
  Future<void> signIn({
    required String email,
    required String password,
    required bool keepSignedIn,
  }) async => throw _demoOnly;

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async => throw _demoOnly;

  @override
  Future<void> requestPasswordReset({required String email}) async =>
      throw _demoOnly;

  @override
  Future<void> resendVerificationEmail({required String email}) async =>
      throw _demoOnly;

  @override
  Future<void> updatePassword({required String newPassword}) async =>
      throw _demoOnly;
}

/// Supabase Auth (email + password). The session it creates is what
/// [AuthNotifier] mirrors and what the API client sends as a Bearer token.
class SupabaseAuthActions implements AuthActions {
  SupabaseAuthActions(this._ref);

  final Ref _ref;

  GoTrueClient get _auth => Supabase.instance.client.auth;

  @override
  Future<void> signIn({
    required String email,
    required String password,
    required bool keepSignedIn,
  }) => _run(() async {
    await _auth.signInWithPassword(email: email, password: password);
    await _ref
        .read(sharedPreferencesProvider)
        ?.setBool(keepSignedInPreferenceKey, keepSignedIn);
  });

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) => _run(
    () => _auth.signUp(email: email, password: password, data: {'name': name}),
  );

  @override
  Future<void> requestPasswordReset({required String email}) =>
      _run(() => _auth.resetPasswordForEmail(email));

  @override
  Future<void> resendVerificationEmail({required String email}) =>
      _run(() => _auth.resend(type: OtpType.signup, email: email));

  @override
  Future<void> updatePassword({required String newPassword}) => _run(() async {
    if (_auth.currentSession == null) {
      throw const AuthActionException('재설정 메일의 링크로 다시 들어와 주세요.');
    }
    await _auth.updateUser(UserAttributes(password: newPassword));
  });

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on AuthActionException {
      rethrow;
    } on AuthException catch (e) {
      throw AuthActionException(authErrorMessage(e.code, e.message));
    }
  }
}

/// User-facing text for a Supabase Auth error. [code] is the server's error
/// code (see https://supabase.com/docs/guides/auth/debugging/error-codes);
/// unknown codes fall back to a generic message rather than the raw one.
@visibleForTesting
String authErrorMessage(String? code, String message) {
  switch (code) {
    case 'invalid_credentials':
      return '이메일 또는 비밀번호가 올바르지 않아요.';
    case 'email_not_confirmed':
      return '이메일 인증을 먼저 완료해주세요.';
    case 'user_already_exists':
    case 'email_exists':
      return '이미 가입된 이메일이에요.';
    case 'weak_password':
      return '더 안전한 비밀번호를 사용해주세요.';
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
      return '요청이 너무 많아요. 잠시 후 다시 시도해주세요.';
    case 'same_password':
      return '이전과 다른 비밀번호를 입력해주세요.';
    case 'user_not_found':
      return '등록되지 않은 이메일이에요.';
    default:
      return '요청을 처리하지 못했어요. 잠시 후 다시 시도해주세요.';
  }
}

final authActionsProvider = Provider<AuthActions>(
  (ref) => AppConfig.demoMode
      ? const DemoAuthActions()
      : AppConfig.authConfigured
      ? SupabaseAuthActions(ref)
      : MockAuthActions(ref),
);

/// Figma LOGIN shows social login and a guest entry, but neither is supported
/// yet. They stay visible by default (holding their Figma space) and can be
/// hidden without shifting the layout via
/// `--dart-define=AUTH_SOCIAL_LOGIN=false` / `AUTH_GUEST_ENTRY=false`.
class AuthFeatureFlags {
  AuthFeatureFlags._();

  static const bool socialLogin = bool.fromEnvironment(
    'AUTH_SOCIAL_LOGIN',
    defaultValue: true,
  );
  static const bool guestEntry = bool.fromEnvironment(
    'AUTH_GUEST_ENTRY',
    defaultValue: true,
  );
}
