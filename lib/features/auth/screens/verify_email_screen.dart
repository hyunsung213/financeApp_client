import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_actions.dart';
import '../theme/auth_tokens.dart';
import '../widgets/auth_components.dart';

/// VERIFY_EMAIL has no Figma frame yet. It is assembled from FIND_PASSWORD
/// (back / logo / title / 60px field / 12px / CTA / 22px / status slot) and
/// SIGN_UP's bottom "이미 계정이 있나요? 로그인" row, reusing their geometry.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.email});

  /// The address the verification mail was sent to (passed from SIGN_UP).
  final String? email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  late final TextEditingController _emailController = TextEditingController(
    text: widget.email ?? '',
  );
  bool _submitting = false;
  String? _status;
  bool _statusIsError = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    final email = widget.email;
    if (_submitting || email == null) return;
    setState(() {
      _submitting = true;
      _status = null;
    });
    try {
      await ref.read(authActionsProvider).resendVerificationEmail(email: email);
      if (mounted) {
        setState(() {
          _status = '인증 메일을 다시 보냈습니다.';
          _statusIsError = false;
        });
      }
    } on AuthActionException catch (e) {
      if (mounted) {
        setState(() {
          _status = e.message;
          _statusIsError = true;
        });
      }
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
        const AuthTitle('이메일을 확인해주세요', left: 24),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 20, 0),
          child: Text(
            '가입한 이메일로 인증 메일을 보냈어요.\n메일의 링크를 눌러 인증을 완료해주세요.',
            style: AuthTokens.text(16, FontWeight.w400, AuthTokens.textPrimary),
          ),
        ),
        const SizedBox(height: 12),
        AuthTextField(
          iconAsset: AuthAssets.iconMail,
          hintText: '이메일',
          controller: _emailController,
          readOnly: true,
        ),
        const SizedBox(height: 12),
        AuthPrimaryButton(
          label: '인증 메일 다시 보내기',
          onPressed: widget.email == null ? null : _resend,
          loading: _submitting,
        ),
        const SizedBox(height: 22),
        AuthStatusText(message: _status, isError: _statusIsError),
        const SizedBox(height: 24),
        const Spacer(),
        AuthBottomLinkRow(
          prompt: '이미 인증하셨나요?',
          linkLabel: '로그인',
          onTap: () => context.go('/login'),
        ),
      ],
    );
  }
}
