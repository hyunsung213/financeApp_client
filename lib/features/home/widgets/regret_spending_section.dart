import 'package:flutter/material.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/wallet_glass.dart';
import '../../../core/widgets/glass.dart';
import 'home_section_header.dart';

/// One row in the "아쉬운 소비" list (Figma Group 141/142): merchant, time,
/// amount, category breadcrumb, and a tap affordance into the common
/// transaction detail screen.
class RegretTransactionRow extends StatelessWidget {
  final String merchant;
  final String time;
  final String amountLabel;
  final String categoryPath;
  final VoidCallback? onTap;

  const RegretTransactionRow({
    super.key,
    required this.merchant,
    required this.time,
    required this.amountLabel,
    required this.categoryPath,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: onTap,
        radius: AppRadii.md,
        padding: const EdgeInsets.all(AppSpacing.itemPadding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          merchant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: glass.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12,
                          color: glass.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    amountLabel,
                    style: AppTextStyles.amountMedium.copyWith(
                      color: glass.negative,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: glass.insetFill,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        categoryPath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: glass.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: glass.textTertiary,
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

/// "최근 소비 돌아보기" section (Figma Rectangle 105 / node 335:8358 and
/// below, originally labeled "어제 소비 돌아보기"). Renamed from "어제" to
/// "최근" because the underlying data is no longer scoped to a single
/// calendar day - see home_provider.dart's recentRegrettableTransactionsProvider
/// for why ("어제" went empty whenever yesterday specifically had no
/// REGRETTABLE/BAD-evaluated transaction, even if older ones existed).
/// `items` stays nullable and the section renders nothing when there is
/// truly no evaluated transaction to show - do not populate it with mock or
/// hardcoded data.
class RegretSpendingSection extends StatelessWidget {
  final List<Map<String, dynamic>>? items;
  final void Function(Map<String, dynamic> item)? onItemTap;

  const RegretSpendingSection({super.key, required this.items, this.onItemTap});

  @override
  Widget build(BuildContext context) {
    final data = items;
    if (data == null || data.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 28, AppSpacing.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '최근 소비 돌아보기',
            style: AppTextStyles.sectionTitle.copyWith(
              color: context.glass.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "'아쉬운 소비'로 평가한 최근 거래를 보여드립니다.",
            style: AppTextStyles.secondary.copyWith(
              color: context.glass.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          HomeSectionHeader(
            title: '아쉬운 소비',
            actionLabel: '총 ${data.length}건',
            titleStyle: AppTextStyles.cardTitle,
          ),
          const SizedBox(height: 12),
          ...data.map(
            (item) => RegretTransactionRow(
              merchant: (item['merchantOrTitle'] ?? '내역').toString(),
              time: (item['time'] ?? '').toString(),
              amountLabel: (item['amountLabel'] ?? '').toString(),
              categoryPath: (item['categoryPath'] ?? '').toString(),
              onTap: onItemTap == null ? null : () => onItemTap!(item),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '항목을 터치하면 공통 거래 상세 화면으로 이동합니다.',
            style: AppTextStyles.caption.copyWith(
              color: context.glass.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
