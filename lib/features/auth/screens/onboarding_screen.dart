import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/skeleton.dart';
import '../../mypage/screens/budget_plan_settings_screen.dart';
import '../../mypage/theme/my_tokens.dart';
import '../../mypage/utils/currency_input_formatter.dart';
import '../../mypage/utils/profile_regions.dart';
import '../../mypage/widgets/settings_form.dart';
import '../providers/onboarding_provider.dart';

/// Initial setup after sign-in: 사용자 정보 → 예산 배분 → Home.
///
/// The step comes from [onboardingStepProvider] (backend data), so a setup
/// interrupted by closing the app resumes where it stopped. The only local
/// state is "went back from 예산 배분 to edit 사용자 정보".
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _editingProfile = false;

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(onboardingStepProvider).value;

    if (_editingProfile || step == OnboardingStep.profile) {
      return _ProfileStep(
        onSaved: () => setState(() => _editingProfile = false),
      );
    }
    return BudgetPlanSettingsScreen.onboarding(
      onBack: () => setState(() => _editingProfile = true),
      onComplete: () =>
          ref.read(onboardingActionsProvider.notifier).refreshStep(),
    );
  }
}

/// 사용자 정보: the salary setting the budget is calculated from (required)
/// plus the policy-profile fields already used by 월급 설정/계정 관리
/// (optional).
class _ProfileStep extends ConsumerStatefulWidget {
  final VoidCallback onSaved;

  const _ProfileStep({required this.onSaved});

  @override
  ConsumerState<_ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends ConsumerState<_ProfileStep> {
  final _salaryController = TextEditingController();
  final _ageController = TextEditingController();
  int? _salaryDay;
  String? _region;
  int _reportingStartDay = 1;
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _salaryController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _initialize(OnboardingProfileDraft draft) {
    if (_initialized) return;
    _initialized = true;
    final salary = draft.salaryAmount;
    if (salary != null && salary > 0) {
      _salaryController.text = NumberFormat('#,###').format(salary);
    }
    _salaryDay = draft.salaryDay;
    _reportingStartDay = draft.reportingStartDay ?? 1;
    if (draft.age != null) _ageController.text = '${draft.age}';
    if (profileRegions.contains(draft.region)) _region = draft.region;
  }

  Future<void> _next() async {
    final salary = int.tryParse(
      _salaryController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    final ageText = _ageController.text.trim();
    final age = int.tryParse(ageText);
    final String? error;
    if (salary == null || salary <= 0) {
      error = '월급 금액을 입력해주세요.';
    } else if (_salaryDay == null) {
      error = '월급일을 선택해주세요.';
    } else if (ageText.isNotEmpty && (age == null || age > 120)) {
      error = '만 나이를 0~120 사이로 입력해주세요.';
    } else {
      error = null;
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(onboardingActionsProvider.notifier)
          .saveProfileStep(
            salaryAmount: salary!,
            salaryDay: _salaryDay!,
            reportingStartDay: _reportingStartDay,
            age: age,
            region: _region,
          );
      if (mounted) widget.onSaved();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '저장하지 못했어요. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final draftAsync = ref.watch(onboardingProfileDraftProvider);

    return Scaffold(
      backgroundColor: MyTokens.pageBackground,
      appBar: settingsAppBar('사용자 정보', leading: const SizedBox.shrink()),
      body: draftAsync.when(
        loading: () => const FormSkeleton(),
        // Nothing to pre-fill is not a reason to block setup.
        error: (_, _) => _form(const OnboardingProfileDraft()),
        data: _form,
      ),
    );
  }

  Widget _form(OnboardingProfileDraft draft) {
    _initialize(draft);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              const Text(
                '기본 정보를 알려주세요',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: MyTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '월급과 월급일로 매일 쓸 수 있는 예산을 계산해요.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: MyTokens.placeholder,
                ),
              ),
              const SizedBox(height: 24),
              SettingsSectionCard(
                title: '월급',
                child: Column(
                  children: [
                    TextField(
                      key: const ValueKey('onboarding-salary'),
                      controller: _salaryController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      decoration: settingsInputDecoration(
                        labelText: '월급 금액',
                        suffixText: '원',
                        prefixIcon: const Icon(Icons.monetization_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      key: const ValueKey('onboarding-salary-day'),
                      initialValue: _salaryDay,
                      decoration: settingsInputDecoration(
                        labelText: '월급일',
                        prefixIcon: const Icon(Icons.calendar_month_outlined),
                      ),
                      items: [
                        for (var day = 1; day <= 31; day++)
                          DropdownMenuItem(value: day, child: Text('매월 $day일')),
                      ],
                      onChanged: (value) => setState(() => _salaryDay = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SettingsSectionCard(
                title: '맞춤 청년정책 프로필 (선택)',
                child: Column(
                  children: [
                    TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: settingsInputDecoration(
                        labelText: '만 나이',
                        suffixText: '세',
                        prefixIcon: const Icon(Icons.cake_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _region,
                      decoration: settingsInputDecoration(
                        labelText: '거주 지역',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                      items: profileRegions
                          .map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _region = value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        DecoratedBox(
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
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: MyTokens.negative,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SettingsSaveButton(
                    isSaving: _saving,
                    onPressed: _next,
                    label: '다음',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
