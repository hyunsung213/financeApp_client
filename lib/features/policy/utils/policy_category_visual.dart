import 'package:flutter/material.dart';

/// Visual stand-in for a policy's missing photo/thumbnail.
///
/// Neither this backend nor the upstream 온통청년 Open API it syncs from
/// expose an image/thumbnail field for a policy (confirmed by reading
/// `youthPolicyApiService.ts` and the `Policy` model - see
/// docs/backend/policy-backend-requirements.md). Rather than drop Figma's
/// large visual area (Featured Card / list thumbnail), each category gets a
/// gradient + a Material icon - consistent with this project's existing
/// convention of using Material Icons instead of Figma's Iconoir assets
/// (see lib/features/home/utils/category_icons.dart). `category` matching is
/// substring-based since `/api/policies` returns whatever free-text label
/// the sync job mapped from the source category name.
///
/// If a real `imageUrl` field is added later, callers can swap this for the
/// actual image without changing where PolicyCategoryVisual is invoked -
/// see docs/backend/policy-backend-requirements.md item 2.
class PolicyCategoryVisual {
  final IconData icon;
  final List<Color> gradient;

  const PolicyCategoryVisual({required this.icon, required this.gradient});

  factory PolicyCategoryVisual.forCategory(String? category) {
    final name = (category ?? '').trim();

    if (name.contains('주거')) {
      return const PolicyCategoryVisual(icon: Icons.home_rounded, gradient: [Color(0xFF00AF76), Color(0xFF6DD9AB)]);
    }
    if (name.contains('일자리') || name.contains('취업') || name.contains('창업')) {
      return const PolicyCategoryVisual(icon: Icons.work_rounded, gradient: [Color(0xFF007C4F), Color(0xFF00AE76)]);
    }
    if (name.contains('금융') || name.contains('자산')) {
      return const PolicyCategoryVisual(icon: Icons.savings_rounded, gradient: [Color(0xFF00AE76), Color(0xFF80D7BA)]);
    }
    if (name.contains('교육') || name.contains('훈련')) {
      return const PolicyCategoryVisual(icon: Icons.school_rounded, gradient: [Color(0xFF10B981), Color(0xFF6EE7B7)]);
    }
    if (name.contains('복지') || name.contains('문화')) {
      return const PolicyCategoryVisual(icon: Icons.diversity_3_rounded, gradient: [Color(0xFF059669), Color(0xFF6DD9AB)]);
    }
    if (name.contains('참여') || name.contains('권리')) {
      return const PolicyCategoryVisual(icon: Icons.campaign_rounded, gradient: [Color(0xFF00AF76), Color(0xFF34D399)]);
    }

    return const PolicyCategoryVisual(icon: Icons.stars_rounded, gradient: [Color(0xFF00AF76), Color(0xFF6DD9AB)]);
  }
}
