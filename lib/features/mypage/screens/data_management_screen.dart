import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_radii.dart';
import '../widgets/settings_form.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/theme/wallet_glass.dart';

/// When the user's data was last backed up. Backup has no backend yet (see
/// docs/backend/data-management-requirements.md), so this is always `null`;
/// once an API exists, only this provider needs to change.
final lastBackupAtProvider = Provider<DateTime?>((ref) => null);

/// 백업 및 데이터 관리 — Figma Frame 105 (176:5415).
///
/// Backup, restore, export and reset all lack backend support, so the full
/// UI is shown but every action only shows a short "준비 중" notice. Reset in
/// particular must get a confirm dialog before it is wired to a real API.
class DataManagementScreen extends ConsumerWidget {
  const DataManagementScreen({super.key});

  static const String comingSoonMessage = '아직 준비 중이에요.';
  static const String backupComingSoonMessage = '백업 기능은 준비 중이에요.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastBackupAt = ref.watch(lastBackupAtProvider);

    return WalletBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: settingsAppBar('백업 및 데이터 관리'),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
            children: [
              _BackupCard(
                lastBackupAt: lastBackupAt,
                onBackup: () => _showNotice(context, backupComingSoonMessage),
              ),
              const SizedBox(height: 6),
              _DataActionRow(
                title: '데이터 복원',
                subtitle: '이번에 백업한 데이터를 복원합니다.',
                onTap: () => _showNotice(context, comingSoonMessage),
              ),
              const SizedBox(height: 6),
              _DataActionRow(
                title: '데이터 내보내기',
                subtitle: '데이터를 파일로 내보냅니다.',
                onTap: () => _showNotice(context, comingSoonMessage),
              ),
              const SizedBox(height: 6),
              // No reset API exists, so this only shows the notice and never
              // touches data. Add a confirm dialog before wiring a real call.
              _DataActionRow(
                title: '데이터 초기화',
                subtitle: '모든 데이터가 삭제됩니다.',
                color: context.glass.negative,
                onTap: () => _showNotice(context, comingSoonMessage),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showNotice(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// `2026.8.25 21:30` — the Figma 최근 백업 format.
String formatBackupTimestamp(DateTime at) {
  final local = at.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.year}.${local.month}.${local.day} $hh:$mm';
}

TextStyle _titleStyle(BuildContext context) => TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  height: 1.3,
  letterSpacing: -0.45,
  color: context.glass.textPrimary,
);

TextStyle _bodyStyle(BuildContext context) => TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w400,
  height: 1.3,
  letterSpacing: -0.45,
  color: context.glass.textPrimary,
);

BoxDecoration _cardDecoration(BuildContext context) =>
    glassDecoration(context, radius: AppRadii.md);

class _BackupCard extends StatelessWidget {
  final DateTime? lastBackupAt;
  final VoidCallback onBackup;

  const _BackupCard({required this.lastBackupAt, required this.onBackup});

  @override
  Widget build(BuildContext context) {
    final at = lastBackupAt;
    return Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('데이터 백업', style: _titleStyle(context)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('현재 데이터를 안전하게 백업합니다.', style: _bodyStyle(context)),
                    const SizedBox(height: 2),
                    Text(
                      at == null
                          ? '최근 백업 기록이 없어요'
                          : '최근 백업: ${formatBackupTimestamp(at)}',
                      style: _bodyStyle(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 21),
              SizedBox(
                width: 105,
                child: OutlinedButton(
                  onPressed: onBackup,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: context.glass.accentText,
                    side: BorderSide(color: context.glass.accent, width: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    // Desktop browsers default to compact density, which
                    // would shave the Figma 8px vertical padding on web.
                    visualDensity: VisualDensity.standard,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                  ),
                  child: const Text(
                    '백업하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      letterSpacing: -0.45,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DataActionRow extends StatelessWidget {
  final String title;
  final String subtitle;

  /// Title/subtitle color; defaults to the theme's primary text color.
  final Color? color;
  final VoidCallback onTap;

  const _DataActionRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.glass.textPrimary;
    return Container(
      decoration: _cardDecoration(context),
      // Transparent Material so the InkWell ripple paints above the card
      // decoration instead of behind it.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 73),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 14, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: _titleStyle(context).copyWith(color: color),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: _bodyStyle(context).copyWith(color: color),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 24,
                    color: context.glass.textPrimary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
