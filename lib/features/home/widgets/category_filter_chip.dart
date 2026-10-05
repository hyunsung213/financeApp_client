import 'package:flutter/material.dart';
import '../../../core/widgets/glass.dart';

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
    return GlassChip(
      label: label,
      icon: icon,
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
