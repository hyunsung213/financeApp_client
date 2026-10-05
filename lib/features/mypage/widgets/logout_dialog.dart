import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/wallet_glass.dart';

/// Logout confirmation shared by the 설정 main screen and 계정 관리.
void showLogoutDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.glass.surfaceFill,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      title: Text('로그아웃', style: TextStyle(color: context.glass.textPrimary)),
      content: Text(
        '정말 로그아웃 하시겠습니까?',
        style: TextStyle(color: context.glass.textPrimary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('취소', style: TextStyle(color: context.glass.textPrimary)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            ref.read(authProvider.notifier).logout();
            context.go('/login');
          },
          child: Text(
            '로그아웃',
            style: TextStyle(
              color: context.glass.negative,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}
