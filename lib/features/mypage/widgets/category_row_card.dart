import 'package:flutter/material.dart';

import '../theme/my_tokens.dart';

/// Figma 카테고리 관리 row (Frame 108): a 57px white card with a 57px icon
/// cell, the name, and trailing actions. Also used, highlighted, as the
/// 카테고리 추가 preview (Frame 109).
class CategoryRowCard extends StatelessWidget {
  const CategoryRowCard({
    super.key,
    required this.icon,
    required this.name,
    this.iconColor = MyTokens.accentDark,
    this.trailing = const [],
    this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String name;
  final Color iconColor;
  final List<Widget> trailing;
  final VoidCallback? onTap;

  /// Preview style: mint fill, green border and green name.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(MyTokens.cardRadius);
    return Material(
      color: highlighted ? MyTokens.accentSoftBg : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: highlighted
            ? const BorderSide(color: MyTokens.accent)
            : BorderSide.none,
      ),
      shadowColor: Colors.black.withValues(alpha: 0.05),
      elevation: highlighted ? 0 : 1,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: SizedBox(
          height: 57,
          child: Row(
            children: [
              SizedBox.square(
                dimension: 57,
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.45,
                    color: highlighted
                        ? MyTokens.accentDark
                        : MyTokens.textPrimary,
                  ),
                ),
              ),
              for (final widget in trailing) ...[
                const SizedBox(width: 10),
                widget,
              ],
              const SizedBox(width: 15),
            ],
          ),
        ),
      ),
    );
  }
}
