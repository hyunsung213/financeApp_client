import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../../notification/providers/notification_provider.dart';
import '../../../core/services/notification_service.dart';

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

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with WidgetsBindingObserver {
  int step = 1;
  final _salaryController = TextEditingController();
  final _salaryDayController = TextEditingController();

  final _savingsController = TextEditingController(text: '50');
  final _investController = TextEditingController(text: '10');
  final _fixedController = TextEditingController(text: '10');
  final _spendingController = TextEditingController(text: '30');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _salaryController.dispose();
    _salaryDayController.dispose();
    _savingsController.dispose();
    _investController.dispose();
    _fixedController.dispose();
    _spendingController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && step == 4) {
      ref.read(notificationAccessProvider.notifier).checkStatus();
    }
  }

  void next() {
    if (step < 4) {
      setState(() => step++);
    } else {
      // Complete onboarding
      final salaryText = _salaryController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final salary = int.tryParse(salaryText) ?? 3000000;
      
      final salaryDay = int.tryParse(_salaryDayController.text) ?? 25;
      
      final savings = int.tryParse(_savingsController.text) ?? 50;
      final invest = int.tryParse(_investController.text) ?? 10;
      final fixed = int.tryParse(_fixedController.text) ?? 10;
      final spending = int.tryParse(_spendingController.text) ?? 30;

      ref.read(authProvider.notifier).completeOnboarding(
        salary: salary,
        salaryDay: salaryDay,
        budget: {
          'savings': savings,
          'invest': invest,
          'fixed': fixed,
          'spending': spending,
        },
      );
    }
  }

  void previous() {
    if (step > 1) {
      setState(() => step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: step > 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: previous,
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: step == 1
                        ? _buildStep1()
                        : step == 2
                            ? _buildStep2()
                            : step == 3
                                ? _buildStep3()
                                : _buildStep4(),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: next,
                child: Text(step == 4 ? '완료하기' : '다음'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('월급은 얼마인가요?', style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 24),
        TextField(
          controller: _salaryController, 
          keyboardType: TextInputType.number, 
          inputFormatters: [CurrencyInputFormatter()],
          decoration: const InputDecoration(
            hintText: '예: 3,000,000',
            suffixText: '원',
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('월급은 언제 들어오나요?', style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 24),
        TextField(
          controller: _salaryDayController, 
          keyboardType: TextInputType.number, 
          decoration: const InputDecoration(
            hintText: '매월 며칠 (예: 25)',
            suffixText: '일',
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('예산을 어떻게 나눌까요?', style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 8),
        Text('총합이 100%가 되어야 합니다.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        _buildRow('저축', _savingsController),
        const SizedBox(height: 8),
        _buildRow('투자', _investController),
        const SizedBox(height: 8),
        _buildRow('고정생활', _fixedController),
        const SizedBox(height: 8),
        _buildRow('소비', _spendingController),
      ],
    );
  }

  Widget _buildStep4() {
    final accessAsync = ref.watch(notificationAccessProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.notifications_active_outlined, size: 56, color: Color(0xFF0066FF)),
        const SizedBox(height: 16),
        Text('금융 알림 자동 수집',
            style: Theme.of(context).textTheme.displayMedium, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        const Text(
          '은행 및 카드사의 결제·입출금 알림을 자동으로 수집하여 가계부에 기록합니다.\n앱이 꺼져 있어도 안전하게 수집됩니다.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, height: 1.5, fontSize: 14),
        ),
        const SizedBox(height: 28),

        // Status Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: accessAsync.when(
            loading: () => const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, st) => Text('상태 확인 오류: $e'),
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
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('알림 접근 권한 상태',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: statusColor, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (status == NotificationAccessStatus.denied) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0066FF),
                        side: const BorderSide(color: Color(0xFF0066FF)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                      onPressed: () {
                        ref.read(notificationAccessProvider.notifier).openSettings();
                      },
                      icon: const Icon(Icons.settings, size: 18),
                      label: const Text('설정에서 알림 접근 허용하기'),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRow(String label, TextEditingController controller) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Expanded(
          child: TextField(
            controller: controller, 
            keyboardType: TextInputType.number, 
            decoration: const InputDecoration(suffixText: '%'),
          ),
        ),
      ],
    );
  }
}
