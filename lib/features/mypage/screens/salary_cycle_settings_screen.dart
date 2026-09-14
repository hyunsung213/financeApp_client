import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../home/providers/home_provider.dart';
import '../../../core/widgets/gradient_progress_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../providers/my_page_provider.dart';
import '../theme/my_tokens.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');

    final cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) return newValue.copyWith(text: '');

    final int value = int.parse(cleanText);
    final formatter = NumberFormat('#,###');
    final String newText = formatter.format(value);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

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

  final Map<String, TextEditingController> _allocationControllers = {};
  List<Map<String, dynamic>> _allocationsData = [];
  bool _isInitialized = false;
  bool _isSaving = false;

  final List<String> _regions = [
    '서울',
    '부산',
    '대구',
    '인천',
    '광주',
    '대전',
    '울산',
    '세종',
    '경기',
    '강원',
    '충북',
    '충남',
    '전북',
    '전남',
    '경북',
    '경남',
    '제주',
  ];

  @override
  void dispose() {
    _salaryController.dispose();
    _ageController.dispose();
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

    final salary = _parseToInt(data.setting['salaryAmount']) ?? 2500000;
    _salaryController.text = NumberFormat('#,###').format(salary);
    _salaryDay = _parseToInt(data.setting['salaryDay']) ?? 25;
    _reportingStartDay = _parseToInt(data.setting['reportingStartDay']) ?? 1;

    final age = _parseToInt(data.profile['age']);
    if (age != null) _ageController.text = age.toString();

    final region = data.profile['region'] as String?;
    if (region != null && _regions.contains(region)) _selectedRegion = region;

    _allocationsData = List<Map<String, dynamic>>.from(data.allocations);
    if (_allocationsData.isEmpty) {
      // No id yet — these don't exist on the backend, so saving must create
      // them (see _allocationTypeFor in my_page_provider.dart), not PATCH a
      // made-up id.
      _allocationsData = [
        {'id': null, 'name': '저축', 'percentage': 40.0, 'active': true},
        {'id': null, 'name': '투자', 'percentage': 20.0, 'active': true},
        {'id': null, 'name': '고정생활', 'percentage': 10.0, 'active': true},
        {'id': null, 'name': '소비', 'percentage': 30.0, 'active': true},
      ];
    }

    for (final alloc in _allocationsData) {
      final name = alloc['name'] as String? ?? '항목';
      final percentage = _parseToInt(alloc['percentage']) ?? 0;
      _allocationControllers[name] = TextEditingController(
        text: percentage.toString(),
      );
      _allocationControllers[name]!.addListener(() => setState(() {}));
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
    final cleanSalary = _salaryController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final salary = int.tryParse(cleanSalary);
    final totalPercentage = _calculateTotalPercentage();

    if (salary == null || salary <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('올바른 월급 금액을 입력해주세요.')));
      return;
    }
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
      final updatedAllocations = _allocationsData.map((alloc) {
        final name = alloc['name'] as String? ?? '';
        final controller = _allocationControllers[name];
        final percentage =
            (controller != null ? double.tryParse(controller.text) : null) ??
            0.0;
        return {
          'id': alloc['id'],
          'name': name,
          'percentage': percentage,
          'active': alloc['active'] ?? true,
        };
      }).toList();

      final age = int.tryParse(_ageController.text);

      await ref
          .read(myPageActionsProvider.notifier)
          .saveMyPageSettings(
            salaryAmount: salary,
            salaryDay: _salaryDay,
            reportingStartDay: _reportingStartDay,
            allocations: updatedAllocations,
            age: age,
            region: _selectedRegion,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('저장했어요.'),
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
      appBar: AppBar(
        title: const Text(
          '월급 주기 설정',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: MyTokens.textPrimary,
          ),
        ),
        backgroundColor: MyTokens.pageBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: MyTokens.textPrimary,
        elevation: 0,
      ),
      body: myPageAsync.when(
        loading: () => const FormSkeleton(),
        error: (error, stack) => Center(child: Text('데이터를 불러오지 못했습니다: $error')),
        data: (data) {
          _initializeData(data);
          final totalPercentage = _calculateTotalPercentage();
          final isTotalValid = totalPercentage == 100;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _sectionCard(
                title: '월급일',
                child: Column(
                  children: [
                    _daySelector(
                      label: '월급일',
                      value: _salaryDay,
                      onChanged: (v) => setState(() => _salaryDay = v),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '월급 주기',
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
              _buildPreviewCard(context, ref),
              const SizedBox(height: 24),

              _sectionCard(
                title: '월급 금액',
                child: TextField(
                  controller: _salaryController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  decoration: _inputDecoration(
                    labelText: '월급 금액',
                    suffixText: '원',
                    prefixIcon: const Icon(Icons.monetization_on_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '예산 배분율 설정',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: MyTokens.textPrimary,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      '합계: $totalPercentage% ${isTotalValid ? '✓' : '(100% 필요)'}',
                      style: TextStyle(
                        color: isTotalValid
                            ? MyTokens.accent
                            : MyTokens.negative,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _sectionCard(
                child: Column(
                  children: _allocationsData.map((alloc) {
                    final name = alloc['name'] as String? ?? '항목';
                    final controller = _allocationControllers[name];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: MyTokens.textPrimary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.end,
                              decoration: _inputDecoration(
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
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              _sectionCard(
                title: '맞춤 청년정책 프로필',
                child: Column(
                  children: [
                    TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        labelText: '만 나이',
                        suffixText: '세',
                        prefixIcon: const Icon(Icons.cake_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRegion,
                      decoration: _inputDecoration(
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

              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: MyTokens.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: MyTokens.placeholder,
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MyTokens.buttonRadius),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '저장',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context, WidgetRef ref) {
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
              '다음 월급일까지 앞으로',
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
        final cycleEnd = DateTime.now().add(
          Duration(days: home.daysUntilSalary),
        );
        final cycleStart = DateTime(
          cycleEnd.year,
          cycleEnd.month - 1,
          cycleEnd.day,
        );
        final dateFormat = DateFormat('M.d', 'ko_KR');
        final usagePercent = (home.flexibleUsageRatio * 100).round();

        return _previewShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '다음 월급일까지 앞으로 D-${home.daysUntilSalary}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: MyTokens.accent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${dateFormat.format(cycleStart)} - ${dateFormat.format(cycleEnd)}',
                style: const TextStyle(
                  color: MyTokens.textPrimary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${NumberFormat('#,###').format(home.remainingFlexibleAmount)}원 남았어요',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: MyTokens.textPrimary,
                    ),
                  ),
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
                value: home.flexibleUsageRatio,
                height: 6,
                backgroundColor: Colors.white,
                colors: MyTokens.progressGradient,
              ),
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

  Widget _sectionCard({String? title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: MyTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: MyTokens.cardSurface,
            borderRadius: BorderRadius.circular(MyTokens.cardRadius),
            boxShadow: MyTokens.cardShadow,
          ),
          child: child,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    String? labelText,
    String? suffixText,
    Widget? prefixIcon,
    bool? isDense,
    EdgeInsetsGeometry? contentPadding,
  }) {
    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(MyTokens.inputRadius),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: labelText,
      suffixText: suffixText,
      prefixIcon: prefixIcon,
      isDense: isDense,
      contentPadding: contentPadding,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: MyTokens.placeholder),
      floatingLabelStyle: const TextStyle(color: MyTokens.accent),
      hintStyle: const TextStyle(color: MyTokens.placeholder),
      suffixStyle: const TextStyle(color: MyTokens.textPrimary),
      prefixIconColor: MyTokens.placeholder,
      border: outline(MyTokens.borderNeutral),
      enabledBorder: outline(MyTokens.borderNeutral),
      focusedBorder: outline(MyTokens.accent, 1.5),
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
