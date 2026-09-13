import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../home/theme/home_tokens.dart';
import '../utils/report_insight_utils.dart';

/// Per-category spent/budget progress bar (Figma frames 114:5192 / 397:5357
/// -- the "식비 초과 400,000원 / 200,000원" row).
///
/// Figma always paints the bar in the category's own donut color and signals
/// "over budget" only through the "초과" badge plus a warning-colored
/// "/ 예산" suffix -- never by recoloring the bar itself. Category color and
/// the over-budget warning are deliberately kept on separate visual layers.
///
/// The backend has no Category<->BudgetAllocation link today (see
/// docs/backend/report-backend-requirements.md item 1), so there is no real
/// `budgetAmount` to show in production. This component is built to full
/// Figma fidelity anyway per docs/development-work-policy.md 4 (backend
/// 미지원이라고 UI 자체를 생략하지 않는다): pass `budgetAmount: null` and it
/// renders an honest "예산 미설정" empty state instead of a fake bar. Once
/// the backend adds the mapping, pass the real amount and this component
/// starts rendering the real progress bar / "초과" badge with no UI changes.
class BudgetUsageBar extends StatelessWidget {
  final String categoryName;
  final Color categoryColor;
  final int spentAmount;
  final int? budgetAmount;
  final bool showCategoryName;

  const BudgetUsageBar({
    super.key,
    required this.categoryName,
    required this.categoryColor,
    required this.spentAmount,
    required this.budgetAmount,
    this.showCategoryName = true,
  });

  // Figma's progress-track gray (397:5689 etc.) -- not close enough to any
  // existing HomeTokens color to reuse one without drifting off-hex.
  static const _trackColor = Color(0xFFE9E9E9);

  /// kDebugMode-only sample so Figma visual QA (progress bar, "초과" badge,
  /// "예산 사용률" percentage) can be checked before the backend supports
  /// this -- never shown in a release build, never used as a real value.
  /// Shared by [BudgetUsageBar] and the Category Report detail's "예산
  /// 사용률" row so both spots preview the same number for a given category.
  static int? previewBudgetFor(int spentAmount, int? realBudget) {
    if (realBudget != null) return realBudget;
    if (!kDebugMode) return null;
    // Alternates over/under so QA can see both the normal progress-bar
    // state and the "초과" badge in the same list instead of every row
    // always landing on the same ratio.
    return (spentAmount ~/ 10000).isEven ? (spentAmount * 1.3).round() : (spentAmount * 0.7).round();
  }

  @override
  Widget build(BuildContext context) {
    final budget = previewBudgetFor(spentAmount, budgetAmount);

    if (budget == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: HomeTokens.chipInactiveBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: HomeTokens.textMuted),
            const SizedBox(width: 8),
            if (showCategoryName) ...[
              Text(categoryName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: HomeTokens.textDark)),
              const SizedBox(width: 8),
            ],
            const Expanded(
              child: Text('이 카테고리의 예산이 아직 설정되지 않았어요', style: TextStyle(fontSize: 12, color: HomeTokens.textMuted)),
            ),
          ],
        ),
      );
    }

    final isOver = spentAmount > budget;
    final ratio = budget == 0 ? 1.0 : (spentAmount / budget).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (showCategoryName) ...[
              Expanded(
                child: Text(categoryName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: HomeTokens.textDark)),
              ),
              const SizedBox(width: 6),
            ],
            if (isOver)
              Container(
                margin: showCategoryName ? EdgeInsets.zero : const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1E9),
                  border: Border.all(color: HomeTokens.negative),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text('초과', style: TextStyle(fontSize: 11, color: HomeTokens.negative)),
              ),
            if (!showCategoryName) const Spacer(),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: formatWon(spentAmount), style: TextStyle(fontWeight: FontWeight.bold, color: categoryColor)),
                TextSpan(text: ' / ${formatWon(budget)}', style: TextStyle(color: isOver ? HomeTokens.negative : HomeTokens.textMuted, fontSize: 13)),
              ]),
              textAlign: TextAlign.end,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            backgroundColor: _trackColor,
            valueColor: AlwaysStoppedAnimation(categoryColor),
          ),
        ),
      ],
    );
  }
}
