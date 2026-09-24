import 'package:flutter/material.dart';
import '../../home/theme/home_tokens.dart';
import '../utils/report_insight_utils.dart';
import 'over_budget_badge.dart';

/// One category row of the Category Report (Figma frames 114:5192 / 397:5357):
/// name, spent amount, and that category's share of all spending, with a bar
/// showing the same share.
///
/// [sharePercent] is "categorySpent / totalExpense * 100" - the value the
/// donut legend shows for the same category, passed in as-is, never derived
/// here. The bar is painted in the category's own donut color.
///
/// [budgetAmount] is the future hook for a real category budget and is always
/// null today (the backend has no category budget). The budget period is the
/// salary-cycle BudgetCycle, not the calendar month this report screen is
/// scoped to, so only pass a value together with a [spentAmount] aggregated
/// over that same cycle. While it is null no budget-related UI is built,
/// including [OverBudgetBadge]; nothing is faked to exercise it.
class CategoryShareBar extends StatelessWidget {
  final String categoryName;
  final Color categoryColor;
  final int spentAmount;
  final double sharePercent;
  final int? budgetAmount;

  const CategoryShareBar({
    super.key,
    required this.categoryName,
    required this.categoryColor,
    required this.spentAmount,
    required this.sharePercent,
    this.budgetAmount,
  });

  // Figma's progress-track gray (397:5689 etc.) -- not close enough to any
  // existing HomeTokens color to reuse one without drifting off-hex.
  static const _trackColor = Color(0xFFE9E9E9);

  @override
  Widget build(BuildContext context) {
    final budget = budgetAmount;
    final isOverBudget = budget != null && spentAmount > budget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(categoryName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: HomeTokens.textDark)),
            ),
            const SizedBox(width: 6),
            if (isOverBudget) const OverBudgetBadge(),
            Text(formatWon(spentAmount), style: TextStyle(fontWeight: FontWeight.bold, color: categoryColor)),
            const SizedBox(width: 8),
            Text('${sharePercent.round()}%', style: const TextStyle(fontSize: 13, color: HomeTokens.textMuted)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (sharePercent / 100).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: _trackColor,
            valueColor: AlwaysStoppedAnimation(categoryColor),
          ),
        ),
      ],
    );
  }
}
