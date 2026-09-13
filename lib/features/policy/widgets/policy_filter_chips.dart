import 'package:flutter/material.dart';
import '../../home/theme/home_tokens.dart';

/// Figma node 238:4953 (filter chip row: "전체" + category pills).
/// Category options come from whatever `Policy.category` values are already
/// present in the currently loaded list (no dedicated "list categories"
/// backend endpoint exists - see docs/backend/policy-backend-requirements.md
/// item 6). Filtering itself is client-side for now, per the approved scope.
class PolicyFilterChips extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const PolicyFilterChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          _chip(label: '전체', isSelected: selected == null, onTap: () => onSelected(null)),
          for (final category in categories) ...[
            const SizedBox(width: 6),
            _chip(label: category, isSelected: selected == category, onTap: () => onSelected(category)),
          ],
        ],
      ),
    );
  }

  Widget _chip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? HomeTokens.chipActiveBg : HomeTokens.chipInactiveBg,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: isSelected ? HomeTokens.chipActiveBorder : HomeTokens.chipInactiveBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: isSelected ? HomeTokens.accentDark : HomeTokens.textDark,
            ),
          ),
        ),
      ),
    );
  }
}
