import 'package:flutter/material.dart';

import '../../../core/theme/app_radii.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/theme/wallet_glass.dart';

/// Figma 카테고리 관리 row (Frame 108): a 57px glass card with a 57px icon
/// cell, the name, and trailing actions. Also used, highlighted, as the
/// 카테고리 추가 preview (Frame 109).
class CategoryRowCard extends StatelessWidget {
  const CategoryRowCard({
    super.key,
    required this.icon,
    required this.name,
    this.iconColor,
    this.trailing = const [],
    this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String name;

  /// Defaults to the theme's dark-green chip text color.
  final Color? iconColor;
  final List<Widget> trailing;
  final VoidCallback? onTap;

  /// Preview style: mint fill, green border and green name.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final radius = BorderRadius.circular(AppRadii.md);
    // Level 2 glass card; the highlighted (preview) variant swaps in the
    // soft green fill and a green border.
    final decoration = highlighted
        ? BoxDecoration(
            color: glass.accentSoft,
            borderRadius: radius,
            border: Border.all(color: glass.accent),
          )
        : glassDecoration(context, borderRadius: radius);
    return DecoratedBox(
      decoration: decoration,
      // Transparent Material so the InkWell ripple paints above the fill.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox(
            height: 57,
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 57,
                  child: Icon(
                    icon,
                    size: 28,
                    color: iconColor ?? glass.chipSelectedText,
                  ),
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
                          ? glass.chipSelectedText
                          : glass.textPrimary,
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
      ),
    );
  }
}
