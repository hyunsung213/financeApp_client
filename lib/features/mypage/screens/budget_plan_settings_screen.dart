import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/category/category_appearance.dart';
import '../../../core/widgets/skeleton.dart';
import '../providers/my_page_provider.dart';
import '../theme/my_tokens.dart';
import '../utils/budget_plan_items.dart';
import '../widgets/budget_allocation_progress.dart';
import '../widgets/settings_form.dart';

/// 예산 배분 설정: the 12-item budget plan (저축/투자 + 10 지출 대분류), saved
/// as a whole through `PUT /api/finance/budget-plan`. Saving also re-budgets
/// the current salary cycle right away (existing transactions are untouched).
///
/// [BudgetPlanSettingsScreen.onboarding] is the same screen as the last
/// initial-setup step: only the copy, the back action and what happens after
/// a successful save differ.
class BudgetPlanSettingsScreen extends ConsumerStatefulWidget {
  const BudgetPlanSettingsScreen({super.key})
    : onOnboardingBack = null,
      onOnboardingComplete = null;

  const BudgetPlanSettingsScreen.onboarding({
    super.key,
    required VoidCallback onBack,
    required Future<void> Function() onComplete,
  }) : onOnboardingBack = onBack,
       onOnboardingComplete = onComplete;

  final VoidCallback? onOnboardingBack;

  /// Called after the plan is saved; takes the user on to Home.
  final Future<void> Function()? onOnboardingComplete;

  bool get isOnboarding => onOnboardingComplete != null;

  @override
  ConsumerState<BudgetPlanSettingsScreen> createState() =>
      _BudgetPlanSettingsScreenState();
}

class _BudgetPlanSettingsScreenState
    extends ConsumerState<BudgetPlanSettingsScreen> {
  // Keyed by budget-plan categoryId.
  final Map<String, TextEditingController> _allocationControllers = {};
  int? _salaryAmount;
  bool _isInitialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    for (final controller in _allocationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _parseToInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is String) {
      final clean = value.replaceAll(RegExp(r'[^0-9.-]'), '');
      return double.tryParse(clean)?.toInt();
    }
    return null;
  }

  void _initializeData(MyPageData data) {
    if (_isInitialized) return;
    _isInitialized = true;

    _salaryAmount = _parseToInt(data.setting['salaryAmount']);

    final percentageByCategory = <String, int>{
      for (final alloc in data.allocations.whereType<Map>())
        (alloc['categoryId'] ?? '').toString():
            _parseToInt(alloc['percentage']) ?? 0,
    };
    for (final (categoryId, _) in budgetPlanItems) {
      _allocationControllers[categoryId] = TextEditingController(
        text: (percentageByCategory[categoryId] ?? 0).toString(),
      )..addListener(() => setState(() {}));
    }
  }

  int _calculateTotalPercentage() {
    int total = 0;
    for (final controller in _allocationControllers.values) {
      total += int.tryParse(controller.text) ?? 0;
    }
    return total;
  }

  Future<void> _save() async {
    final totalPercentage = _calculateTotalPercentage();
    if (totalPercentage != 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('예산 배분율의 합계는 100%여야 합니다. (현재: $totalPercentage%)'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(myPageActionsProvider.notifier).saveBudgetPlan([
        for (final entry in _allocationControllers.entries)
          {
            'categoryId': entry.key,
            'percentage': int.tryParse(entry.value.text) ?? 0,
          },
      ]);

      final onComplete = widget.onOnboardingComplete;
      if (onComplete != null) {
        await onComplete();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('저장했어요. 현재 예산에 바로 반영됐어요.'),
            backgroundColor: MyTokens.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myPageAsync = ref.watch(myPageDataProvider);

    return Scaffold(
      backgroundColor: MyTokens.pageBackground,
      appBar: widget.isOnboarding
          ? settingsAppBar(
              '예산 배분',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onOnboardingBack,
              ),
            )
          : settingsAppBar('예산 배분 설정'),
      body: myPageAsync.when(
        loading: () => const FormSkeleton(),
        error: (error, stack) => Center(child: Text('데이터를 불러오지 못했습니다: $error')),
        data: (data) {
          _initializeData(data);
          final totalPercentage = _calculateTotalPercentage();
          final isTotalValid = totalPercentage == 100;

          // The list scrolls; the 배분 진행 상태 + 저장 panel stays pinned below
          // it, so the running total is visible at any scroll position. The
          // Scaffold resizes the body for the keyboard, which keeps the panel
          // above it and lets the list scroll the focused field into view.
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  children: [
                    if (widget.isOnboarding) ...[
                      const Text(
                        '월급을 어떻게 나눠 쓸까요?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: MyTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '저축·투자·지출 비율을 정해보세요.\n총 100%가 되도록 나눠주세요.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: MyTokens.placeholder,
                        ),
                      ),
                    ] else
                      const Text(
                        '월급을 저축·투자·지출로 나눠 배분해요. 저장하면 현재 예산에 바로 반영돼요.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: MyTokens.placeholder,
                        ),
                      ),
                    const SizedBox(height: 20),
                    const Text(
                      '예산 배분율 설정',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: MyTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Three top-level groups - 저축, 투자, 지출 예산 - each its own card
                    // with an icon, spaced further apart than the 지출 rows, so
                    // 저축/투자 never read as siblings of 식비/교통.
                    SettingsSectionCard(
                      child: _topLevelRow(
                        'core.saving',
                        '저축',
                        Icons.savings_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SettingsSectionCard(
                      child: _topLevelRow(
                        'core.investment',
                        '투자',
                        Icons.trending_up,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SettingsSectionCard(
                      child: Column(
                        children: [
                          _sectionHeader(
                            Icons.account_balance_wallet_outlined,
                            '지출 예산',
                          ),
                          const SizedBox(height: 16),
                          for (final (categoryId, name)
                              in budgetPlanExpenseItems)
                            _allocationRow(categoryId, name),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _bottomPanel(totalPercentage, isTotalValid),
            ],
          );
        },
      ),
    );
  }

  /// Pinned footer: live allocation status (recomputed on every keystroke)
  /// and the 저장 button, which is enabled only at exactly 100%.
  Widget _bottomPanel(int totalPercentage, bool isTotalValid) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: MyTokens.pageBackground,
        border: Border(top: BorderSide(color: MyTokens.borderNeutral)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BudgetAllocationProgress(totalPercentage: totalPercentage),
              const SizedBox(height: 12),
              SettingsSaveButton(
                isSaving: _isSaving,
                onPressed: isTotalValid ? _save : null,
                label: widget.isOnboarding ? '완료' : '저장',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionIcon(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: MyTokens.accentSoftBg,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: MyTokens.accent),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        _sectionIcon(icon),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: MyTokens.textPrimary,
          ),
        ),
      ],
    );
  }

  /// 저축/투자: a top-level item is its own group, so its icon + name act as
  /// the group header and sit on the same line as its input.
  Widget _topLevelRow(String categoryId, String name, IconData icon) {
    return Row(
      children: [
        _sectionIcon(icon),
        const SizedBox(width: 10),
        Expanded(
          child: _allocationRow(
            categoryId,
            name,
            nameStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: MyTokens.textPrimary,
            ),
            bottomPadding: 0,
          ),
        ),
      ],
    );
  }

  /// One plan row; under the name, the amount this percentage would be of the
  /// current salary (a preview only - it doesn't change the running cycle).
  Widget _allocationRow(
    String categoryId,
    String name, {
    TextStyle nameStyle = const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 15,
      color: MyTokens.textPrimary,
    ),
    double bottomPadding = 12,
  }) {
    final controller = _allocationControllers[categoryId];
    final salary = _salaryAmount;
    final percentage = int.tryParse(controller?.text ?? '') ?? 0;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The user's name for the 대분류; the plan stays keyed by id.
                Text(
                  ref.watch(categoryDirectoryProvider).nameOf(categoryId, name)!,
                  style: nameStyle,
                ),
                if (salary != null && salary > 0)
                  Text(
                    '${NumberFormat('#,###').format(salary * percentage ~/ 100)}원',
                    style: const TextStyle(
                      fontSize: 12,
                      color: MyTokens.placeholder,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                PercentInputFormatter(),
              ],
              decoration: settingsInputDecoration(
                suffixText: '%',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
