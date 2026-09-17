import 'package:flutter/material.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../theme/home_tokens.dart';
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
        decoration: BoxDecoration(
          color: HomeTokens.cardSurface,
          borderRadius: BorderRadius.circular(AppRadii.input),
          boxShadow: AppShadows.hairline,
        ),
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
                      Text(
                        merchant,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: HomeTokens.textDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 12,
                          color: HomeTokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    amountLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: HomeTokens.negative,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: HomeTokens.chipInactiveBg,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(color: HomeTokens.chipInactiveBorder),
                  ),
                  child: Text(
                    categoryPath,
                    style: const TextStyle(
                      fontSize: 12,
                      color: HomeTokens.textDark,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: HomeTokens.textMuted,
                ),
              ],
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
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '최근 소비 돌아보기',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: HomeTokens.accent,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "'아쉬운 소비'로 평가한 최근 거래를 보여드립니다.",
            style: TextStyle(fontSize: 16, color: HomeTokens.textDark),
          ),
          const SizedBox(height: 20),
          HomeSectionHeader(
            title: '아쉬운 소비',
            actionLabel: '총 ${data.length}건',
            titleColor: HomeTokens.textDark,
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
          const Text(
            '항목을 터치하면 공통 거래 상세 화면으로 이동합니다.',
            style: TextStyle(fontSize: 13, color: HomeTokens.textMuted),
          ),
        ],
      ),
    );
  }
}
