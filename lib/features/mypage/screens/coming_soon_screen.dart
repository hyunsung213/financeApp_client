import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/my_tokens.dart';

/// Shared "coming soon" placeholder for settings rows that don't have a real
/// screen yet (backend support is missing — see aiProgress.md API 요구사항).
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final String message;

  const ComingSoonScreen({
    super.key,
    required this.title,
    this.message = '더 나은 기능을 제공하기 위해 준비하고 있습니다.\n추후 업데이트에서 만나볼 수 있어요.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyTokens.pageBackground,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: MyTokens.textPrimary,
          ),
        ),
        backgroundColor: MyTokens.pageBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: MyTokens.textPrimary,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: MyTokens.illustrationPlaceholder,
                borderRadius: BorderRadius.circular(MyTokens.buttonRadius),
              ),
              child: const Icon(
                Icons.hourglass_empty,
                size: 48,
                color: MyTokens.placeholder,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '아직 준비중이에요',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: MyTokens.accentDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MyTokens.textPrimary,
                fontSize: 16,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: MyTokens.primaryGradient,
                  border: Border.all(color: MyTokens.accentSoftBorder),
                  borderRadius: BorderRadius.circular(MyTokens.buttonRadius),
                ),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text(
                    '이전화면으로 돌아가기',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: Colors.white,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        MyTokens.buttonRadius,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.home_outlined, size: 18),
                label: const Text(
                  '홈으로 이동',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: MyTokens.accentDark,
                  side: const BorderSide(color: MyTokens.accentSoftBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MyTokens.buttonRadius),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
