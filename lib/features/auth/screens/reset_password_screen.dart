import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_actions.dart';
import '../theme/auth_tokens.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_components.dart';

/// RESET_PASSWORD has no Figma frame yet. It reuses SIGN_UP's header (back /
/// logo / 28px-inset title) and its two password fields, followed by
/// FIND_PASSWORD's 12px CTA gap and status slot.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final password = _passwordController.text;
    final error =
        AuthValidators.newPassword(password) ??
        AuthValidators.passwordConfirm(password, _confirmController.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authActionsProvider).updatePassword(newPassword: password);
      if (!mounted) return;
      showAuthMessage(context, '비밀번호를 변경했어요. 새 비밀번호로 로그인해주세요.');
      context.go('/login');
    } on AuthActionException catch (e) {
      if (mounted) setState(() => _error = e.message);
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
        const AuthTitle('새 비밀번호 설정', left: 28),
        const SizedBox(height: 16),
        AuthTextField(
          iconAsset: AuthAssets.iconLock,
          hintText: '새 비밀번호를 입력하세요',
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
          onSubmitted: (_) => _submit(),
          autofillHints: const [AutofillHints.newPassword],
        ),
        const SizedBox(height: 12),
        AuthPrimaryButton(
          label: '비밀번호 변경하기',
          onPressed: _submit,
          loading: _submitting,
        ),
        const SizedBox(height: 22),
        AuthStatusText(message: _error, isError: true),
        const Spacer(),
      ],
    );
  }
}
