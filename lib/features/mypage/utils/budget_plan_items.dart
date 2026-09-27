import 'package:flutter/services.dart';

/// The 12 budget-plan items in display order: 저축/투자, then the 지출 대분류.
/// Each maps to the backend budget-plan `categoryId` (the 대분류 category id),
/// so a 지출 percentage is always tied to its real major category. Shared by
/// the salary-cycle settings screen and onboarding.
const List<(String categoryId, String name)> budgetPlanSavingItems = [
  ('core.saving', '저축'),
  ('core.investment', '투자'),
];
const List<(String categoryId, String name)> budgetPlanExpenseItems = [
  ('core.expense.food', '식비'),
  ('core.expense.transport', '교통'),
  ('core.expense.living', '생활'),
  ('core.expense.fixed', '고정지출'),
  ('core.expense.shopping', '쇼핑'),
  ('core.expense.leisure-culture', '여가·문화'),
  ('core.expense.health', '건강'),
  ('core.expense.education', '교육·자기계발'),
  ('core.expense.relationship', '모임·관계'),
  ('core.expense.other', '기타'),
];
const List<(String categoryId, String name)> budgetPlanItems = [
  ...budgetPlanSavingItems,
  ...budgetPlanExpenseItems,
];

/// Rejects any edit that would make a percentage field exceed 100. Pair with
/// `FilteringTextInputFormatter.digitsOnly` so negatives can't be typed.
class PercentInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final value = int.tryParse(newValue.text);
    if (value == null || value > 100) return oldValue;
    return newValue;
  }
}
