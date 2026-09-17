import 'package:flutter/material.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../home/theme/home_tokens.dart';
import '../utils/policy_category_visual.dart';
import '../utils/policy_dday.dart';

/// Figma node 238:4984/238:4909/238:4904 (Featured Policy Card). The photo
/// background in Figma has no backend data source (see
/// docs/backend/policy-backend-requirements.md item 2), so this uses a
/// category gradient plus a large faint category icon instead - the card's
/// size, radius, gradient overlay direction and text layout stay as Figma
/// specifies so swapping in a real image later is a drop-in change.
class PolicyFeaturedCard extends StatelessWidget {
  final Map<String, dynamic> policy;
  final VoidCallback onTap;

  const PolicyFeaturedCard({super.key, required this.policy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final category = (policy['category'] ?? '기타').toString();
    final title = (policy['title'] ?? '제목 없음').toString();
    final summary = (policy['summary'] ?? '').toString();
    final dDay = policyDDayLabel(policy['applicationEndDate']?.toString());
    final visual = PolicyCategoryVisual.forCategory(category);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.compactInput),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.compactInput),
        onTap: onTap,
        child: Container(
          height: 210,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.compactInput),
            gradient: LinearGradient(
              colors: visual.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: AppShadows.card,
          ),
          child: Stack(
            children: [
              Positioned(
                right: -16,
                bottom: -16,
                child: Icon(visual.icon, size: 120, color: Colors.white.withValues(alpha: 0.18)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.pill)),
                        child: Text(category, style: const TextStyle(fontSize: 13, color: HomeTokens.textDark, fontWeight: FontWeight.w600)),
                      ),
                      const Spacer(),
                      if (dDay != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(color: HomeTokens.negative, borderRadius: BorderRadius.circular(AppRadii.compactInput)),
                          child: Text(dDay, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      summary,
                      style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
