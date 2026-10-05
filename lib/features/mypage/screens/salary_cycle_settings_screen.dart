import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../home/providers/home_provider.dart';
import '../../../core/widgets/gradient_progress_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/success_overlay.dart';
import '../providers/my_page_provider.dart';
import '../providers/salary_budget_preview.dart';
import '../theme/my_tokens.dart';
import '../utils/currency_input_formatter.dart';
import '../utils/profile_regions.dart';
import '../widgets/settings_form.dart';
import 'budget_plan_settings_screen.dart';

class SalaryCycleSettingsScreen extends ConsumerStatefulWidget {
  const SalaryCycleSettingsScreen({super.key});

  @override
  ConsumerState<SalaryCycleSettingsScreen> createState() =>
      _SalaryCycleSettingsScreenState();
}

class _SalaryCycleSettingsScreenState
    extends ConsumerState<SalaryCycleSettingsScreen> {
  final _salaryController = TextEditingController();
  final _ageController = TextEditingController();
  String? _selectedRegion;
  int _salaryDay = 25;
  int _reportingStartDay = 1;

  bool _isInitialized = false;
  bool _isSaving = false;

  final List<String> _regions = profileRegions;

  @override
  void dispose() {
    _salaryController.dispose();
    _ageController.dispose();
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

  /// The 정기 수입 typed in the field, or null while it isn't a valid amount.
  int? get _draftSalary {
    final salary = int.tryParse(
      _salaryController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    return salary != null && salary > 0 ? salary : null;
  }

  void _initializeData(MyPageData data) {
    if (_isInitialized) return;
    _isInitialized = true;

    final salary = _parseToInt(data.setting['salaryAmount']) ?? 2500000;
    _salaryController.text = NumberFormat('#,###').format(salary);
    _salaryDay = _parseToInt(data.setting['salaryDay']) ?? 25;
    _reportingStartDay = _parseToInt(data.setting['reportingStartDay']) ?? 1;

    final age = _parseToInt(data.profile['age']);
    if (age != null) _ageController.text = age.toString();

    final region = data.profile['region'] as String?;
    if (region != null && _regions.contains(region)) _selectedRegion = region;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final cleanSalary = _salaryController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final salary = int.tryParse(cleanSalary);

    if (salary == null || salary <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('올바른 수입 금액을 입력해주세요.')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final age = int.tryParse(_ageController.text);

      await ref
          .read(myPageActionsProvider.notifier)
          .saveMyPageSettings(
            salaryAmount: salary,
            salaryDay: _salaryDay,
            reportingStartDay: _reportingStartDay,
            age: age,
            region: _selectedRegion,
          );

      // Wait for the re-budgeted cycle so the summary never pairs the new
      // salary with the previous cycle's numbers.
      try {
        await Future.wait([
          ref.read(myPageDataProvider.future),
          ref.read(homeDataProvider.future),
        ]);
      } catch (_) {}

      if (mounted) showSuccessOverlay(context, '저장했어요!');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('저장하지 못했어요. 다시 시도해주세요.')));
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
      appBar: settingsAppBar('정기 수입 설정'),
      body: myPageAsync.when(
        loading: () => const FormSkeleton(),
        error: (error, stack) => Center(child: Text('데이터를 불러오지 못했습니다: $error')),
        data: (data) {
          _initializeData(data);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SettingsSectionCard(
                title: '들어오는 날',
                child: Column(
                  children: [
                    _daySelector(
                      label: '들어오는 날',
                      value: _salaryDay,
                      onChanged: (v) => setState(() => _salaryDay = v),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '수입 주기',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: MyTokens.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _cycleTab('매달', selected: true),
                        _cycleTab('2주', comingSoon: true),
                        _cycleTab('1주', comingSoon: true),
                        _cycleTab('기타', comingSoon: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '격주·주급 주기는 준비 중이에요. 지금은 매달 주기만 지원해요.',
                        style: TextStyle(
                          fontSize: 11,
                          color: MyTokens.placeholder,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _daySelector(
                      label: '월 시작일',
                      value: _reportingStartDay,
                      onChanged: (v) => setState(() => _reportingStartDay = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildPreviewCard(context, ref, data),
              const SizedBox(height: 24),

              SettingsSectionCard(
                title: '정기 수입 금액',
                child: TextField(
                  controller: _salaryController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  // The summary card previews the typed amount.
                  onChanged: (_) => setState(() {}),
                  decoration: settingsInputDecoration(
                    labelText: '한 번에 들어오는 금액',
                    suffixText: '원',
                    prefixIcon: const Icon(Icons.monetization_on_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _buildBudgetPlanLink(context),
              const SizedBox(height: 24),

              SettingsSectionCard(
                title: '맞춤 청년정책 프로필',
                child: Column(
                  children: [
                    TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: settingsInputDecoration(
                        labelText: '만 나이',
                        suffixText: '세',
                        prefixIcon: const Icon(Icons.cake_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRegion,
                      decoration: settingsInputDecoration(
                        labelText: '거주 지역',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                      items: _regions
                          .map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _selectedRegion = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SettingsSaveButton(isSaving: _isSaving, onPressed: _save),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  /// Small pointer to the separate 예산 배분 설정 screen.
  Widget _buildBudgetPlanLink(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(MyTokens.cardRadius),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BudgetPlanSettingsScreen()),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                '정기 수입을 기준으로 예산을 나눠 설정할 수 있어요.',
                style: TextStyle(fontSize: 13, color: MyTokens.placeholder),
              ),
            ),
            const Text(
              '예산 배분 설정',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MyTokens.accent,
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: MyTokens.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(
    BuildContext context,
    WidgetRef ref,
    MyPageData myPage,
  ) {
    final homeAsync = ref.watch(homeDataProvider);
    return homeAsync.when(
      // Keep the preview card's slot while home data is loading or
      // unavailable, without inventing any numbers.
      loading: () => _previewShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _previewSkeletonLine(width: 170, height: 15),
            const SizedBox(height: 8),
            _previewSkeletonLine(width: 90, height: 11),
            const SizedBox(height: 12),
            _previewSkeletonLine(width: 150, height: 15),
            const SizedBox(height: 12),
            _previewSkeletonLine(height: 6),
          ],
        ),
      ),
      error: (e, st) => _previewShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '다음 수입까지 앞으로',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: MyTokens.accent,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '미리보기 정보를 불러오지 못했어요.',
              style: TextStyle(color: MyTokens.placeholder, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
      data: (home) {
        // The ACTIVE cycle's real dates from the API, shown as-is.
        final dateFormat = DateFormat('M.d', 'ko_KR');
        final cycleStart = home.cycleStartDate;
        final cycleEnd = home.cycleProjectedEndDate;
        final cycleRange = cycleStart != null && cycleEnd != null
            ? '${dateFormat.format(cycleStart)} - ${dateFormat.format(cycleEnd)}'
            : '';
        // While the typed 정기 수입 differs from the saved one, show what the
        // current cycle becomes once it's saved rather than pairing the new
        // amount with the budget built from the old one.
        final draft = _draftSalary;
        final isDraft =
            draft != null &&
            draft != _parseToInt(myPage.setting['salaryAmount']);
        final preview = isDraft
            ? previewSalaryChange(
                salaryAmount: draft,
                home: home,
                planAllocations: myPage.allocations,
              )
            : null;
        final remaining =
            preview?.remainingUsableAmount ?? home.remainingFlexibleAmount;
        final usageRatio = preview?.usageRatio ?? home.flexibleUsageRatio;
        final usagePercent = (usageRatio * 100).round();
        final additionalIncome = home.additionalIncomeAmount ?? 0;
        final won = NumberFormat('#,###');

        return _previewShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                home.awaitingSalary
                    ? home.salaryCountdownLabel
                    : '다음 수입까지 앞으로 ${home.salaryCountdownLabel}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: MyTokens.accent,
                ),
              ),
              const SizedBox(height: 4),
              // Once the expected payday has passed the projected end is
              // behind us - show the state instead of a range (as Home does).
              Text(
                home.awaitingSalary ? '예정 수입일이 지났어요' : cycleRange,
                style: const TextStyle(
                  color: MyTokens.textPrimary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // The daily-spendable pool (저축/투자/고정지출 excluded),
                  // the same remaining budget Home's daily allowance uses.
                  Flexible(
                    child: Text(
                      remaining < 0
                          ? '쓸 수 있는 예산을 ${won.format(-remaining)}원 넘었어요'
                          : '쓸 수 있는 예산 ${won.format(remaining)}원 남았어요',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: MyTokens.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$usagePercent% 사용',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: MyTokens.accent,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GradientProgressBar(
                value: usageRatio,
                height: 6,
                backgroundColor: Colors.white,
                colors: MyTokens.progressGradient,
              ),
              if (additionalIncome > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '추가 수입 ${won.format(additionalIncome)}원 포함',
                  style: const TextStyle(
                    color: MyTokens.placeholder,
                    fontSize: 11,
                  ),
                ),
              ],
              if (isDraft) ...[
                SizedBox(height: additionalIncome > 0 ? 2 : 8),
                Text(
                  preview != null
                      ? '저장하면 현재 예산에 바로 반영돼요.'
                      : '아직 저장되지 않은 변경사항이에요. 위 금액은 현재 적용 중인 예산이에요.',
                  style: const TextStyle(
                    color: MyTokens.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _previewShell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyTokens.accentSoftBg,
        border: Border.all(color: MyTokens.accent),
        borderRadius: BorderRadius.circular(MyTokens.cardRadius),
        boxShadow: MyTokens.cardShadow,
      ),
      child: child,
    );
  }

  Widget _previewSkeletonLine({double? width, required double height}) {
    return SkeletonBox(
      width: width ?? double.infinity,
      height: height,
      borderRadius: BorderRadius.circular(height / 2),
      baseColor: Colors.white.withValues(alpha: 0.55),
      highlightColor: Colors.white,
    );
  }

  Widget _daySelector({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    final days = List.generate(31, (i) => i + 1);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: MyTokens.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: MyTokens.borderNeutral),
            borderRadius: BorderRadius.circular(MyTokens.inputRadius),
            boxShadow: MyTokens.cardShadow,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              style: const TextStyle(fontSize: 16, color: MyTokens.textPrimary),
              iconEnabledColor: MyTokens.textPrimary,
              borderRadius: BorderRadius.circular(MyTokens.inputRadius),
              selectedItemBuilder: (context) => days
                  .map(
                    (d) => Center(
                      child: Text(
                        '$d일',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: MyTokens.accent,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              items: days
                  .map((d) => DropdownMenuItem(value: d, child: Text('$d일')))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _cycleTab(
    String label, {
    bool selected = false,
    bool comingSoon = false,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? MyTokens.accentSoftBg : MyTokens.cardSurface,
            borderRadius: BorderRadius.circular(MyTokens.chipRadius),
            border: Border.all(
              color: selected ? MyTokens.accent : MyTokens.borderNeutral,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? MyTokens.accent
                    : (comingSoon
                          ? MyTokens.placeholder
                          : MyTokens.textPrimary),
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
