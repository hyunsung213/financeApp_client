import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../theme/my_tokens.dart';

/// Logout confirmation shared by the 설정 main screen and 계정 관리.
void showLogoutDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('로그아웃', style: TextStyle(color: MyTokens.textPrimary)),
      content: const Text(
        '정말 로그아웃 하시겠습니까?',
        style: TextStyle(color: MyTokens.textPrimary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            '취소',
            style: TextStyle(color: MyTokens.textPrimary),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            ref.read(authProvider.notifier).logout();
            context.go('/login');
          },
          child: const Text(
            '로그아웃',
            style: TextStyle(
              color: MyTokens.negative,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}
