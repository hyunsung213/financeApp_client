import 'package:finance_client/core/config/app_config.dart';
import 'package:finance_client/features/auth/providers/auth_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('without SUPABASE_URL / SUPABASE_ANON_KEY the app is not auth-configured and keeps the dev mock', () {
    expect(AppConfig.authConfigured, isFalse);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(authActionsProvider), isA<MockAuthActions>());
  });

  test('Supabase auth errors are shown as Korean messages, never the raw server text', () {
    expect(authErrorMessage('invalid_credentials', 'Invalid login credentials'), '이메일 또는 비밀번호가 올바르지 않아요.');
    expect(authErrorMessage('email_not_confirmed', 'Email not confirmed'), '이메일 인증을 먼저 완료해주세요.');
    expect(authErrorMessage('user_already_exists', 'User already registered'), '이미 가입된 이메일이에요.');
    expect(authErrorMessage('over_email_send_rate_limit', 'rate limit'), contains('잠시 후'));
    expect(authErrorMessage(null, 'Some internal detail'), isNot(contains('internal')));
    expect(authErrorMessage('unexpected_code', 'raw'), isNot('raw'));
  });
}
