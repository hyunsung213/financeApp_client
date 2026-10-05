import 'package:flutter/material.dart';
import '../../../core/widgets/glass.dart';

/// Figma node 238:4953 (filter chip row: "전체" + category pills).
/// Category options come from whatever `Policy.category` values are already
/// present in the currently loaded list (no dedicated "list categories"
/// backend endpoint exists - see docs/backend/policy-backend-requirements.md
/// item 6). Filtering itself is client-side for now, per the approved scope.
///
/// "북마크" is a filter of a different kind - it isn't a `Policy.category`
/// value, it means "the policies I bookmarked" - so it is selected with the
/// [kPolicyBookmarkFilter] sentinel rather than a category string, which
/// can't collide with a real category name coming from the backend.
const String kPolicyBookmarkFilter = '__policy_bookmark_filter__';

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
          const SizedBox(width: 6),
          _chip(
            label: '북마크',
            isSelected: selected == kPolicyBookmarkFilter,
            onTap: () => onSelected(kPolicyBookmarkFilter),
          ),
          for (final category in categories) ...[
            const SizedBox(width: 6),
            _chip(label: category, isSelected: selected == category, onTap: () => onSelected(category)),
          ],
        ],
      ),
    );
  }

  Widget _chip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GlassChip(
      label: label,
      selected: isSelected,
      onTap: onTap,
      fontSize: 15,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    );
  }
}
