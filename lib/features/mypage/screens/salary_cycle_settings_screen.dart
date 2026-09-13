import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../home/providers/home_provider.dart';
import '../../../core/widgets/gradient_progress_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../providers/my_page_provider.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');

    final cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) return newValue.copyWith(text: '');

    final int value = int.parse(cleanText);
    final formatter = NumberFormat('#,###');
    final String newText = formatter.format(value);

    return TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}

class SalaryCycleSettingsScreen extends ConsumerStatefulWidget {
  const SalaryCycleSettingsScreen({super.key});

  @override
  ConsumerState<SalaryCycleSettingsScreen> createState() => _SalaryCycleSettingsScreenState();
}

class _SalaryCycleSettingsScreenState extends ConsumerState<SalaryCycleSettingsScreen> {
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
    '서울', '부산', '대구', '인천', '광주', '대전', '울산',
    '세종', '경기', '강원', '충북', '충남', '전북', '전남', '경북', '경남', '제주'
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
      _allocationControllers[name] = TextEditingController(text: percentage.toString());
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
    final cleanSalary = _salaryController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final salary = int.tryParse(cleanSalary);
    final totalPercentage = _calculateTotalPercentage();

    if (salary == null || salary <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('올바른 월급 금액을 입력해주세요.')));
      return;
    }
    if (totalPercentage != 100) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('예산 배분율의 합계는 100%여야 합니다. (현재: $totalPercentage%)')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updatedAllocations = _allocationsData.map((alloc) {
        final name = alloc['name'] as String? ?? '';
        final controller = _allocationControllers[name];
        final percentage = (controller != null ? double.tryParse(controller.text) : null) ?? 0.0;
        return {'id': alloc['id'], 'name': name, 'percentage': percentage, 'active': alloc['active'] ?? true};
      }).toList();

      final age = int.tryParse(_ageController.text);

      await ref.read(myPageActionsProvider.notifier).saveMyPageSettings(
            salaryAmount: salary,
            salaryDay: _salaryDay,
            reportingStartDay: _reportingStartDay,
            allocations: updatedAllocations,
            age: age,
            region: _selectedRegion,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장했어요.'), backgroundColor: AppColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myPageAsync = ref.watch(myPageDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('월급 주기 설정'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
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
                    _daySelector(label: '월급일', value: _salaryDay, onChanged: (v) => setState(() => _salaryDay = v)),
                    const SizedBox(height: 16),
                    const Align(alignment: Alignment.centerLeft, child: Text('월급 주기', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
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
                      child: Text('격주·주급 주기는 준비 중이에요. 지금은 매달 주기만 지원해요.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ),
                    const SizedBox(height: 16),
                    _daySelector(label: '월 시작일', value: _reportingStartDay, onChanged: (v) => setState(() => _reportingStartDay = v)),
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
                  decoration: InputDecoration(
                    labelText: '월급 금액',
                    suffixText: '원',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.monetization_on_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('예산 배분율 설정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isTotalValid ? AppColors.success.withValues(alpha: 0.1) : AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '합계: $totalPercentage% ${isTotalValid ? '✓' : '(100% 필요)'}',
                      style: TextStyle(color: isTotalValid ? AppColors.success : AppColors.danger, fontWeight: FontWeight.bold, fontSize: 12),
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
                          Expanded(flex: 2, child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.end,
                              decoration: InputDecoration(
                                suffixText: '%',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                      decoration: InputDecoration(
                        labelText: '만 나이',
                        suffixText: '세',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.cake_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRegion,
                      decoration: InputDecoration(
                        labelText: '거주 지역',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                      items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
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
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('저장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (home) {
        final cycleEnd = DateTime.now().add(Duration(days: home.daysUntilSalary));
        final cycleStart = DateTime(cycleEnd.year, cycleEnd.month - 1, cycleEnd.day);
        final dateFormat = DateFormat('M.d', 'ko_KR');
        final usagePercent = (home.flexibleUsageRatio * 100).round();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('다음 월급일까지 앞으로 D-${home.daysUntilSalary}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 4),
              Text('${dateFormat.format(cycleStart)} - ${dateFormat.format(cycleEnd)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${NumberFormat('#,###').format(home.remainingFlexibleAmount)}원 남았어요', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('$usagePercent% 사용', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              GradientProgressBar(
                value: home.flexibleUsageRatio,
                height: 6,
                backgroundColor: Colors.white,
                colors: const [Color(0xFF6EE7B7), AppColors.primary],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionCard({String? title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _daySelector({required String label, required int value, required ValueChanged<int> onChanged}) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        DropdownButton<int>(
          value: value,
          items: List.generate(31, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text('$d일'))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }

  Widget _cycleTab(String label, {bool selected = false, bool comingSoon = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 1.5),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary.withValues(alpha: comingSoon ? 0.5 : 1),
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
