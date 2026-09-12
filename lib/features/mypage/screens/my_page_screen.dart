import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notification/providers/notification_provider.dart';
import '../../../core/services/notification_service.dart';
import '../providers/my_page_provider.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    
    final cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final int value = int.parse(cleanText);
    final formatter = NumberFormat('#,###');
    final String newText = formatter.format(value);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class MyPageScreen extends ConsumerStatefulWidget {
  const MyPageScreen({super.key});

  @override
  ConsumerState<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends ConsumerState<MyPageScreen> {
  final _salaryController = TextEditingController();
  final _salaryDayController = TextEditingController();
  final _ageController = TextEditingController();
  String? _selectedRegion;

  // Allocations mapping
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
    _salaryDayController.dispose();
    _ageController.dispose();
    for (var controller in _allocationControllers.values) {
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

    final salaryDay = _parseToInt(data.setting['salaryDay']) ?? 10;
    _salaryDayController.text = salaryDay.toString();

    final age = _parseToInt(data.profile['age']);
    if (age != null) {
      _ageController.text = age.toString();
    }

    final region = data.profile['region'] as String?;
    if (region != null && _regions.contains(region)) {
      _selectedRegion = region;
    }

    _allocationsData = List<Map<String, dynamic>>.from(data.allocations);
    
    // Default allocations if empty
    if (_allocationsData.isEmpty) {
      _allocationsData = [
        {'id': '1', 'name': '저축', 'percentage': 40.0, 'active': true},
        {'id': '2', 'name': '투자', 'percentage': 20.0, 'active': true},
        {'id': '3', 'name': '고정생활', 'percentage': 10.0, 'active': true},
        {'id': '4', 'name': '소비', 'percentage': 30.0, 'active': true},
      ];
    }

    for (final alloc in _allocationsData) {
      final name = alloc['name'] as String? ?? '항목';
      final percentage = _parseToInt(alloc['percentage']) ?? 0;
      _allocationControllers[name] = TextEditingController(text: percentage.toString());
      _allocationControllers[name]!.addListener(() {
        setState(() {});
      });
    }
  }

  int _calculateTotalPercentage() {
    int total = 0;
    for (var controller in _allocationControllers.values) {
      total += int.tryParse(controller.text) ?? 0;
    }
    return total;
  }

  Future<void> _saveSettings() async {
    final cleanSalary = _salaryController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final salary = int.tryParse(cleanSalary);
    final salaryDay = int.tryParse(_salaryDayController.text);
    final totalPercentage = _calculateTotalPercentage();

    if (salary == null || salary <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 월급 금액을 입력해주세요.')),
      );
      return;
    }

    if (salaryDay == null || salaryDay < 1 || salaryDay > 31) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('월급일은 1일~31일 사이여야 합니다.')),
      );
      return;
    }

    if (totalPercentage != 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('예산 배분율의 합계는 100%여야 합니다. (현재: $totalPercentage%)')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updatedAllocations = _allocationsData.map((alloc) {
        final name = alloc['name'] as String? ?? '';
        final controller = _allocationControllers[name];
        final percentage = (controller != null ? double.tryParse(controller.text) : null) ?? 0.0;
        return {
          'id': alloc['id'],
          'name': name,
          'percentage': percentage,
          'active': alloc['active'] ?? true,
        };
      }).toList();

      final age = int.tryParse(_ageController.text);

      await ref.read(myPageActionsProvider.notifier).saveMyPageSettings(
        salaryAmount: salary,
        salaryDay: salaryDay,
        reportingStartDay: 1,
        allocations: updatedAllocations,
        age: age,
        region: _selectedRegion,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('마이페이지 정보가 성공적으로 수정되었습니다! ✨'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            child: const Text('로그아웃', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myPageAsync = ref.watch(myPageDataProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('마이페이지', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textSecondary),
            tooltip: '로그아웃',
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: myPageAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('데이터를 불러오지 못했습니다: $error')),
        data: (data) {
          _initializeData(data);
          final totalPercentage = _calculateTotalPercentage();
          final isTotalValid = totalPercentage == 100;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Header Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: const Icon(Icons.person, size: 36, color: AppColors.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? '사용자',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? 'seed@example.local',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 1: 월급 및 재정 정보
                _buildSectionHeader(context, '월급 및 재정 설정', Icons.account_balance_wallet_outlined),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _salaryController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyInputFormatter()],
                        decoration: InputDecoration(
                          labelText: '월급 금액',
                          hintText: '예: 2,500,000',
                          suffixText: '원',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.monetization_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _salaryDayController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '월급일 (매월)',
                          hintText: '예: 10',
                          suffixText: '일',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.calendar_month_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 2: 예산 배분 비율
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader(context, '예산 배분율 설정', Icons.pie_chart_outline),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isTotalValid 
                            ? AppColors.success.withValues(alpha: 0.1) 
                            : AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '합계: $totalPercentage% ${isTotalValid ? '✓' : '(100% 필요)'}',
                        style: TextStyle(
                          color: isTotalValid ? AppColors.success : AppColors.danger,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
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
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _getAllocationColor(name),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
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

                // Section 3: 청년 정책 맞춤 프로필
                _buildSectionHeader(context, '맞춤 청년정책 프로필', Icons.shield_outlined),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '만 나이',
                          hintText: '예: 25',
                          suffixText: '세',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.cake_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedRegion,
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
                const SizedBox(height: 24),

                // Notification Access & Sync Section
                _buildSectionHeader(context, '금융 알림 자동 수집', Icons.notifications_active_outlined),
                const SizedBox(height: 12),
                _buildNotificationCard(context, ref),
                const SizedBox(height: 36),

                // Save Button
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          '수정 내용 저장하기',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 16),

                // Logout Button Text
                Center(
                  child: TextButton.icon(
                    onPressed: _showLogoutDialog,
                    icon: const Icon(Icons.logout, size: 18, color: AppColors.textSecondary),
                    label: const Text('로그아웃', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, WidgetRef ref) {
    final accessAsync = ref.watch(notificationAccessProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: accessAsync.when(
        loading: () => const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (e, st) => Text('권한 확인 오류: $e'),
        data: (status) {
          final statusText = switch (status) {
            NotificationAccessStatus.granted => '허용됨',
            NotificationAccessStatus.denied => '허용되지 않음',
            NotificationAccessStatus.unsupported => 'iOS에서 지원되지 않음',
          };

          final statusColor = switch (status) {
            NotificationAccessStatus.granted => const Color(0xFF10B981),
            NotificationAccessStatus.denied => const Color(0xFFF59E0B),
            NotificationAccessStatus.unsupported => const Color(0xFF9CA3AF),
          };

          final statusIcon = switch (status) {
            NotificationAccessStatus.granted => Icons.check_circle,
            NotificationAccessStatus.denied => Icons.warning_amber_rounded,
            NotificationAccessStatus.unsupported => Icons.info_outline,
          };

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('알림 접근 권한',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '앱이 종료되어 있어도 금융사 알림을 로컬 큐에 안전하게 수집하고 백엔드로 동기화합니다.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        ref.read(notificationAccessProvider.notifier).openSettings();
                      },
                      icon: const Icon(Icons.settings, size: 16, color: Color(0xFF374151)),
                      label: const Text('권한 설정', style: TextStyle(color: Color(0xFF374151), fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: Color(0xFF0066FF)),
                        foregroundColor: const Color(0xFF0066FF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showNotificationDebugSheet(context, ref),
                      icon: const Icon(Icons.list_alt, size: 16),
                      label: const Text('수집 내역 조회', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showNotificationDebugSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '수집된 금융 알림 큐',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: NotificationService.getRecentNotifications(limit: 50),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final notifications = snapshot.data ?? [];
                    if (notifications.isEmpty) {
                      return const Center(
                        child: Text(
                          '수집된 알림이 없습니다.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: notifications.length,
                      separatorBuilder: (context, index) => const Divider(height: 16),
                      itemBuilder: (context, index) {
                        final n = notifications[index];
                        final title = (n['title'] ?? '').toString();
                        final content = (n['content'] ?? '').toString();
                        final appName = (n['appName'] ?? n['packageName'] ?? '').toString();
                        final status = (n['status'] ?? 'PENDING').toString();
                        final timestamp = n['timestamp'] as int? ?? 0;
                        final dateStr = timestamp > 0
                            ? DateFormat('MM/dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(timestamp))
                            : '';

                        final statusBadgeColor = switch (status) {
                          'SENT' => const Color(0xFF10B981),
                          'SENDING' => const Color(0xFF3B82F6),
                          'FAILED' => const Color(0xFFEF4444),
                          _ => const Color(0xFFF59E0B),
                        };

                        final lastError = (n['lastError'] ?? '').toString();
                        final retryCount = n['retryCount'] as int? ?? 0;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        appName,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusBadgeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    retryCount > 0 ? '$status (재시도 $retryCount회)' : status,
                                    style: TextStyle(color: statusBadgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              content,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (lastError.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '원인: $lastError',
                                style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      await NotificationService.triggerManualSync();
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('동기화 작업을 요청했습니다.')),
                        );
                        Navigator.pop(ctx);
                      }
                    },
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('지금 즉시 동기화 실행'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
        ),
      ],
    );
  }

  Color _getAllocationColor(String name) {
    switch (name) {
      case '저축':
        return AppColors.primary;
      case '투자':
        return const Color(0xFF26A69A);
      case '고정생활':
        return const Color(0xFFFFA726);
      case '소비':
        return const Color(0xFFEF5350);
      default:
        return Colors.blueGrey;
    }
  }
}
