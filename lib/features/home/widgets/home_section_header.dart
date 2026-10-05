import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/wallet_glass.dart';

/// Section title + optional trailing action ("더보기"), reused across Home
/// sections (실시간 거래 내역 등).
class HomeSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  /// Defaults to the theme's primary text color.
  final Color? titleColor;
  final TextStyle titleStyle;

  const HomeSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionTap,
    this.titleColor,
    this.titleStyle = AppTextStyles.sectionTitle,
  });

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: titleStyle.copyWith(color: titleColor ?? glass.textPrimary),
        ),
        if (actionLabel != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onActionTap,
            // Padded out to a comfortable tap target.
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                actionLabel!,
                style: AppTextStyles.sectionAction.copyWith(
                  color: glass.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
