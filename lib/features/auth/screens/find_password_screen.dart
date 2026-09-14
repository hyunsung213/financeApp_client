import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_actions.dart';
import '../theme/auth_tokens.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_components.dart';

/// Figma FIND_PASSWORD (701:3359). Vertical gaps are the Figma offsets
/// measured from the bottom of the 44px status bar.
class FindPasswordScreen extends ConsumerStatefulWidget {
  const FindPasswordScreen({super.key});

  @override
  ConsumerState<FindPasswordScreen> createState() => _FindPasswordScreenState();
}

class _FindPasswordScreenState extends ConsumerState<FindPasswordScreen> {
  final _emailController = TextEditingController();
  bool _submitting = false;
  String? _status;
  bool _statusIsError = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _setStatus(String? message, {bool isError = false}) {
    setState(() {
      _status = message;
      _statusIsError = isError;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final email = _emailController.text.trim();
    final error = AuthValidators.email(email);
    if (error != null) {
      _setStatus(error, isError: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _status = null;
    });
    try {
      await ref.read(authActionsProvider).requestPasswordReset(email: email);
      if (mounted) _setStatus('재설정 메일을 발송했습니다.');
    } on AuthActionException catch (e) {
      if (mounted) _setStatus(e.message, isError: true);
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
        const AuthTitle('비밀번호 찾기', left: 24),
        const SizedBox(height: 16),
        AuthTextField(
          iconAsset: AuthAssets.iconMail,
          hintText: '이메일을 입력하세요',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 12),
        AuthPrimaryButton(
          label: '인증 메일 보내기',
          onPressed: _submit,
          loading: _submitting,
        ),
        const SizedBox(height: 22),
        AuthStatusText(message: _status, isError: _statusIsError),
        const SizedBox(height: 164),
        const AuthInfoBox(
          text: '가입한 이메일로 비밀번호\n재설정 링크를 보내드립니다.\n메일 수신까지 최대 몇 분이 소요될 수 있습니다.',
        ),
        const Spacer(),
      ],
    );
  }
}
