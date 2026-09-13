import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../notification/providers/notification_provider.dart';
import '../../../core/services/notification_service.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('알림 설정'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('금융 알림 자동 수집', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _buildNotificationCard(context, ref),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: const Text(
              '알림 종류별 켜기/끄기, 알림 시간, 방해 금지 시간 설정은 준비 중이에요.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
          ),
        ],
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: accessAsync.when(
        loading: () => const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
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
                  const Text('알림 접근 권한', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 4),
                        Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
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
                      onPressed: () => ref.read(notificationAccessProvider.notifier).openSettings(),
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
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Column(
                  children: [
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('수집된 금융 알림 큐', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
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
                      return const Center(child: Text('수집된 알림이 없습니다.', style: TextStyle(color: Colors.grey)));
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
                        final dateStr = timestamp > 0 ? DateFormat('MM/dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(timestamp)) : '';

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
                                      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
                                      child: Text(appName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: statusBadgeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                                  child: Text(
                                    retryCount > 0 ? '$status (재시도 $retryCount회)' : status,
                                    style: TextStyle(color: statusBadgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(content, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)), maxLines: 2, overflow: TextOverflow.ellipsis),
                            if (lastError.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('원인: $lastError', style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626)), maxLines: 2, overflow: TextOverflow.ellipsis),
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
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('동기화 작업을 요청했습니다.')));
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
}
