import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_actions.dart';
import '../theme/auth_tokens.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_components.dart';

/// Figma SIGN_UP (699:3240). Vertical gaps are the Figma offsets measured
/// from the bottom of the 44px status bar.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final error =
        AuthValidators.name(name) ??
        AuthValidators.email(email) ??
        AuthValidators.newPassword(password) ??
        AuthValidators.passwordConfirm(password, _confirmController.text) ??
        (_agreeTerms && _agreePrivacy ? null : '필수 약관에 모두 동의해주세요.');
    if (error != null) {
      showAuthMessage(context, error);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await ref
          .read(authActionsProvider)
          .signUp(name: name, email: email, password: password);
      if (mounted) context.pushReplacement('/verify-email', extra: email);
    } on AuthActionException catch (e) {
      if (mounted) showAuthMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      children: [
        AuthBackButton(onTap: () => authPopOrGoLogin(context)),
        const SizedBox(height: 6),
        const AuthLogo(),
        const SizedBox(height: 29),
        const AuthTitle('회원가입', left: 28),
        const SizedBox(height: 16),
        AuthTextField(
          iconAsset: AuthAssets.iconProfile,
          hintText: '이름을 입력하세요',
          controller: _nameController,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
        ),
        const SizedBox(height: AuthTokens.inputGap),
        AuthTextField(
          iconAsset: AuthAssets.iconMail,
          hintText: '이메일을 입력하세요',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: AuthTokens.inputGap),
        AuthTextField(
          iconAsset: AuthAssets.iconLock,
          hintText: '비밀번호를 입력하세요',
          controller: _passwordController,
          obscureText: _obscurePassword,
          onToggleObscure: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
        ),
        const SizedBox(height: AuthTokens.inputGap),
        AuthTextField(
          iconAsset: AuthAssets.iconLock,
          hintText: '비밀번호를 한 번 더 입력하세요',
          controller: _confirmController,
          obscureText: _obscureConfirm,
          onToggleObscure: () =>
              setState(() => _obscureConfirm = !_obscureConfirm),
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
        ),
        const SizedBox(height: 29),
        _AgreementRow(
          label: '이용약관 동의',
          checked: _agreeTerms,
          onToggle: () => setState(() => _agreeTerms = !_agreeTerms),
          onView: () => showAuthMessage(context, '이용약관은 준비 중이에요.'),
        ),
        const SizedBox(height: 16),
        _AgreementRow(
          label: '개인정보 처리방침 동의',
          checked: _agreePrivacy,
          onToggle: () => setState(() => _agreePrivacy = !_agreePrivacy),
          onView: () => showAuthMessage(context, '개인정보 처리방침은 준비 중이에요.'),
        ),
        const SizedBox(height: 31),
        AuthPrimaryButton(
          label: '가입하기',
          onPressed: _submit,
          loading: _submitting,
        ),
        const SizedBox(height: 99),
        const Spacer(),
        AuthBottomLinkRow(
          prompt: '이미 계정이 있나요?',
          linkLabel: '로그인',
          onTap: () => authPopOrGoLogin(context),
        ),
      ],
    );
  }
}

/// Figma agreement row: 20px checkbox + label + "(필수)", "보기" link on the
/// right. 330px wide starting at x 25.
class _AgreementRow extends StatelessWidget {
  const _AgreementRow({
    required this.label,
    required this.checked,
    required this.onToggle,
    required this.onView,
  });

  final String label;
  final bool checked;
  final VoidCallback onToggle;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 0, 20, 0),
      child: SizedBox(
        height: 21,
        child: Row(
          children: [
            Semantics(
              checked: checked,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: Row(
                  children: [
                    AuthCheckbox.agreement(checked: checked),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: AuthTokens.text(
                        16,
                        FontWeight.w400,
                        AuthTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(필수)',
                      style: AuthTokens.text(
                        16,
                        FontWeight.w400,
                        AuthTokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            AuthTextLink(
              label: '보기',
              onTap: onView,
              color: AuthTokens.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
