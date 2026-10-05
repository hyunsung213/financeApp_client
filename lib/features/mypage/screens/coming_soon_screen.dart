import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/my_tokens.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/theme/wallet_glass.dart';

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
    return WalletBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.glass.textPrimary,
            ),
          ),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          foregroundColor: context.glass.textPrimary,
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
                  color: context.glass.insetFill,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Icon(
                  Icons.hourglass_empty,
                  size: 48,
                  color: context.glass.textTertiary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '아직 준비중이에요',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: context.glass.chipSelectedText,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.glass.textPrimary,
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
                    border: Border.all(color: context.glass.chipSelectedBorder),
                    borderRadius: BorderRadius.circular(AppRadii.md),
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
                        borderRadius: BorderRadius.circular(AppRadii.md),
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
                    backgroundColor: context.glass.cardFill,
                    foregroundColor: context.glass.chipSelectedText,
                    side: BorderSide(color: context.glass.chipSelectedBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
