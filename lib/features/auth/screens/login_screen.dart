import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_actions.dart';
import '../theme/auth_tokens.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_components.dart';

/// Figma LOGIN (683:1506). Vertical gaps are the Figma offsets measured from
/// the bottom of the 44px status bar.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _keepSignedIn = true;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final error =
        AuthValidators.email(email) ?? AuthValidators.loginPassword(password);
    if (error != null) {
      showAuthMessage(context, error);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await ref
          .read(authActionsProvider)
          .signIn(
            email: email,
            password: password,
            keepSignedIn: _keepSignedIn,
          );
    } on AuthActionException catch (e) {
      if (mounted) showAuthMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Drops field focus first so returning to LOGIN doesn't reopen the keyboard.
  void _open(String location) {
    FocusScope.of(context).unfocus();
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      greenHero: true,
      children: [
        const SizedBox(height: 56),
        const AuthLogo(onGreen: true),
        const SizedBox(height: 13),
        Text(
          'Welcome',
          textAlign: TextAlign.center,
          style: AuthTokens.text(36, FontWeight.w500, Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          '월급 주기에 맞춰\n소비를 관리해보세요',
          textAlign: TextAlign.center,
          style: AuthTokens.text(16, FontWeight.w500, Colors.white),
        ),
        const SizedBox(height: 47),
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
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          autofillHints: const [AutofillHints.password],
        ),
        const SizedBox(height: 12),
        AuthPrimaryButton(
          label: '로그인',
          onPressed: _submit,
          loading: _submitting,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(25, 0, 20, 0),
          child: SizedBox(
            height: 24,
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _keepSignedIn = !_keepSignedIn),
                  child: Row(
                    children: [
                      AuthCheckbox.login(checked: _keepSignedIn),
                      const SizedBox(width: 6),
                      Text(
                        '자동 로그인',
                        style: AuthTokens.text(
                          16,
                          FontWeight.w400,
                          AuthTokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                AuthTextLink(
                  label: '비밀번호 찾기',
                  onTap: () => _open('/find-password'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 39.66),
        Visibility(
          visible: AuthFeatureFlags.socialLogin,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: _SocialLoginSection(
            onTap: () => showAuthMessage(context, '소셜 로그인은 준비 중이에요.'),
          ),
        ),
        const SizedBox(height: 46.34),
        const Spacer(),
        AuthSecondaryButton(label: '회원가입', onPressed: () => _open('/signup')),
        const SizedBox(height: 13),
        Visibility(
          visible: AuthFeatureFlags.guestEntry,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: Center(
            child: AuthTextLink(
              label: '비회원으로 이용하기',
              onTap: () => showAuthMessage(context, '비회원 이용은 준비 중이에요.'),
            ),
          ),
        ),
      ],
    );
  }
}

/// "또는 다른 계정으로 로그인" divider (21px) + 18px + 42px social row.
/// Not wired to any OAuth provider yet.
class _SocialLoginSection extends StatelessWidget {
  const _SocialLoginSection({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 20, 0),
          child: SizedBox(
            height: 21,
            child: Row(
              children: [
                const Expanded(child: _DividerLine()),
                const SizedBox(width: 4),
                Text(
                  '또는 다른 계정으로 로그인',
                  style: AuthTokens.text(
                    16,
                    FontWeight.w400,
                    AuthTokens.textMuted,
                  ),
                ),
                const SizedBox(width: 4),
                const Expanded(child: _DividerLine()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SocialButton(
              label: '카카오로 로그인',
              onTap: onTap,
              child: Image.asset(AuthAssets.socialKakao, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            _SocialButton(
              label: '구글로 로그인',
              onTap: onTap,
              child: Image.asset(AuthAssets.socialGoogle, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            _SocialButton(
              label: '애플로 로그인',
              onTap: onTap,
              // Figma crops the Apple artwork at 126% x 121% of the circle.
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -5.5,
                    top: -4.5,
                    width: 53,
                    height: 51,
                    child: Image.asset(
                      AuthAssets.socialApple,
                      fit: BoxFit.fill,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: AuthTokens.socialBorder);
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AuthTokens.socialBorder, width: 0.618),
          ),
          child: ClipOval(child: child),
        ),
      ),
    );
  }
}
