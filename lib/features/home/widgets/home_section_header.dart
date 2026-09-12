import 'package:flutter/material.dart';
import '../theme/home_tokens.dart';

/// Section title + optional trailing action ("더보기"), reused across Home
/// sections (실시간 거래 내역 등).
class HomeSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final Color titleColor;

  const HomeSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionTap,
    this.titleColor = HomeTokens.textDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              actionLabel!,
              style: const TextStyle(fontSize: 14, color: HomeTokens.textFaint),
            ),
          ),
      ],
    );
  }
}
