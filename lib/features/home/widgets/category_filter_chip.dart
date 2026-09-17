import 'package:flutter/material.dart';
import '../../../core/theme/app_radii.dart';
import '../theme/home_tokens.dart';

/// Pill-shaped category filter chip used in the Home "실시간 거래 내역" filter
/// row (Figma node 335:8091, Frame 156). Purely presentational — selection
/// state and the category list itself stay owned by the caller/provider.
class CategoryFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const CategoryFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? HomeTokens.chipActiveBg : HomeTokens.chipInactiveBg,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected ? HomeTokens.chipActiveBorder : HomeTokens.chipInactiveBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? HomeTokens.accentDark : HomeTokens.textDark),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? HomeTokens.accentDark : HomeTokens.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
