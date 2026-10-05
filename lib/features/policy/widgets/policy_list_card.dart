import 'package:flutter/material.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/wallet_glass.dart';
import '../../../core/widgets/glass.dart';
import '../utils/policy_category_visual.dart';

/// Figma node 244:5045 (policy list row). Figma's list cards have no
/// bookmark icon or D-Day badge; the bookmark toggle is an intentional
/// addition (the "북마크" filter needs a way to bookmark from the list), kept
/// as a small badge on the thumbnail's corner so the text layout that
/// matches Figma doesn't move. It only renders when [onBookmarkTap] is
/// given, so callers that don't want it get the plain Figma card.
class PolicyListCard extends StatelessWidget {
  final Map<String, dynamic> policy;
  final bool isBookmarked;
  final VoidCallback onTap;
  final VoidCallback? onBookmarkTap;

  const PolicyListCard({
    super.key,
    required this.policy,
    required this.onTap,
    this.isBookmarked = false,
    this.onBookmarkTap,
  });

  // `GET /api/policies/bookmarks` returns a slimmer policy object than the
  // list endpoints: no top-level `summary`, only `presentation.summary`.
  String _summary() {
    final summary = (policy['summary'] ?? '').toString();
    if (summary.isNotEmpty) return summary;
    final presentation = policy['presentation'];
    return presentation is Map ? (presentation['summary'] ?? '').toString() : '';
  }

  @override
  Widget build(BuildContext context) {
    final category = (policy['category'] ?? '기타').toString();
    final title = (policy['title'] ?? '제목 없음').toString();
    final summary = _summary();
    final visual = PolicyCategoryVisual.forCategory(category);

    final glass = context.glass;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        radius: AppRadii.md,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category reads as a label, not a second title.
                  Text(
                    category,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: glass.accentText),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: glass.textPrimary, height: 1.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      style: TextStyle(fontSize: 12, color: glass.textSecondary, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 81,
              height: 81,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        gradient: LinearGradient(colors: visual.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                      child: Icon(visual.icon, color: Colors.white, size: 32),
                    ),
                  ),
                  if (onBookmarkTap != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _BookmarkBadge(isBookmarked: isBookmarked, onTap: onBookmarkTap!),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White disc on the thumbnail corner: outline icon when not bookmarked,
/// filled primary-green icon when bookmarked. The visible disc is 26px but
/// the tap target is padded out to 40px so it's easy to hit without also
/// triggering the card's own onTap.
class _BookmarkBadge extends StatelessWidget {
  final bool isBookmarked;
  final VoidCallback onTap;

  const _BookmarkBadge({required this.isBookmarked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isBookmarked ? '북마크 해제' : '북마크',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), shape: BoxShape.circle),
            child: Icon(
              isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              size: 18,
              // The disc is always white, so these stay light-theme colors.
              color: isBookmarked ? WalletGlass.light.accentText : WalletGlass.light.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
