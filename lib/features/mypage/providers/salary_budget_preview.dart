import '../../home/providers/home_provider.dart';

/// Budget items left out of the daily-spendable pool (저축/투자/고정지출),
/// matching the backend's `isDailySpendableBudgetCategory`.
const _nonSpendableCategoryIds = {
  'core.saving',
  'core.investment',
  'core.expense.fixed',
};

/// What the ACTIVE cycle's spendable budget becomes once an edited 정기 수입
/// is saved. Saving a new salary re-budgets the current cycle from
/// `salary + additional income` with the same plan percentages, and spending
/// already recorded stays, so the result can be shown before saving.
class SalaryBudgetPreview {
  final int cycleBudgetAmount;
  final int usableBudgetAmount;
  final int remainingUsableAmount;

  const SalaryBudgetPreview({
    required this.cycleBudgetAmount,
    required this.usableBudgetAmount,
    required this.remainingUsableAmount,
  });

  int get usedUsableAmount => usableBudgetAmount - remainingUsableAmount;

  double get usageRatio => usableBudgetAmount > 0
      ? (usedUsableAmount / usableBudgetAmount).clamp(0.0, 1.0)
      : 0.0;
}

/// Mirrors the backend's cycle re-budget (`amountsFor`): every item is
/// `floor(total * percentage / 100)` and the rounding remainder goes to 기타,
/// which is spendable - so the spendable pool is the total minus the floored
/// 저축/투자/고정지출 amounts. Returns null when the inputs can't reproduce it
/// (an older backend without `additionalIncomeAmount`, or no saved plan).
SalaryBudgetPreview? previewSalaryChange({
  required int salaryAmount,
  required HomeData home,
  required List<dynamic> planAllocations,
}) {
  final additional = home.additionalIncomeAmount;
  if (additional == null || planAllocations.isEmpty) return null;

  final percentages = <String, num>{
    for (final item in planAllocations)
      if (item is Map && item['categoryId'] is String)
        item['categoryId'] as String:
            num.tryParse('${item['percentage']}') ?? 0,
  };
  if (!_nonSpendableCategoryIds.every(percentages.containsKey)) return null;

  final total = salaryAmount + additional;
  final reserved = _nonSpendableCategoryIds.fold<int>(
    0,
    (sum, id) => sum + (total * percentages[id]! / 100).floor(),
  );
  final usable = total - reserved;
  return SalaryBudgetPreview(
    cycleBudgetAmount: total,
    usableBudgetAmount: usable,
    remainingUsableAmount: usable - home.usedFlexibleAmount,
  );
}
