import 'package:flutter/material.dart';
import '../../../core/theme/app_radii.dart';
import '../../home/theme/home_tokens.dart';
import '../utils/policy_category_visual.dart';

/// Figma node 244:5045 (policy list row). Figma's list cards have no
/// bookmark icon or D-Day badge - only the Featured card and Detail screen
/// do - so `isBookmarked` is accepted for reuse by callers (e.g. the
/// bookmarks screen) but intentionally not rendered here to match Figma.
class PolicyListCard extends StatelessWidget {
  final Map<String, dynamic> policy;
  final bool isBookmarked;
  final VoidCallback onTap;

  const PolicyListCard({
    super.key,
    required this.policy,
    required this.onTap,
    this.isBookmarked = false,
  });

  @override
  Widget build(BuildContext context) {
    final category = (policy['category'] ?? '기타').toString();
    final title = (policy['title'] ?? '제목 없음').toString();
    final summary = (policy['summary'] ?? '').toString();
    final visual = PolicyCategoryVisual.forCategory(category);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadii.compactInput),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.compactInput),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.compactInput),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category, style: const TextStyle(fontSize: 12, color: HomeTokens.textDark)),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomeTokens.textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8F8E8E)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 81,
                height: 81,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.compactInput),
                  gradient: LinearGradient(colors: visual.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Icon(visual.icon, color: Colors.white, size: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
