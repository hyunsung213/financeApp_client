import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
/// - [signIn] keeps the existing mock login (`AuthNotifier.login`) so the
///   current app flow is unchanged.
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
    _ref.read(authProvider.notifier).login(email);
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

final authActionsProvider = Provider<AuthActions>(
  (ref) => MockAuthActions(ref),
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
