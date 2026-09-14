/// Client-side input checks for the auth screens. They only guard obviously
/// invalid input; the auth server remains the source of truth.
class AuthValidators {
  AuthValidators._();

  /// Supabase Auth's default minimum password length.
  static const int minPasswordLength = 6;

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? name(String value) {
    return value.trim().isEmpty ? '이름을 입력해주세요.' : null;
  }

  static String? email(String value) {
    if (value.isEmpty) return '이메일을 입력해주세요.';
    if (!_emailPattern.hasMatch(value)) return '올바른 이메일 형식이 아니에요.';
    return null;
  }

  static String? loginPassword(String value) {
    return value.isEmpty ? '비밀번호를 입력해주세요.' : null;
  }

  static String? newPassword(String value) {
    if (value.isEmpty) return '비밀번호를 입력해주세요.';
    if (value.length < minPasswordLength) {
      return '비밀번호는 $minPasswordLength자 이상 입력해주세요.';
    }
    return null;
  }

  static String? passwordConfirm(String password, String confirm) {
    return password == confirm ? null : '비밀번호가 일치하지 않아요.';
  }
}
