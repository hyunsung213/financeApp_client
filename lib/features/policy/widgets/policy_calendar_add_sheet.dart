import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../home/theme/home_tokens.dart';

/// Figma node 248:6033 ("내 캘린더에 추가하시겠습니까?"): confirms adding a
/// policy's application window to the user's Calendar.
///
/// The backend has no API for this yet - `PolicyCalendarEvent` is a defined
/// table with zero controller/service/route wired to it (see
/// docs/backend/policy-backend-requirements.md item 1). So this dialog is
/// built to full Figma fidelity, but tapping "추가" only shows a
/// non-destructive "준비 중" message instead of writing anything. When the
/// backend API exists, only the body of `_confirm` below needs to change to
/// a real API call - the dialog widget itself does not need to be rebuilt.
class PolicyCalendarAddSheet extends StatelessWidget {
  final String title;
  final String? applicationStartDate;
  final String? applicationEndDate;

  const PolicyCalendarAddSheet({
    super.key,
    required this.title,
    this.applicationStartDate,
    this.applicationEndDate,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? applicationStartDate,
    String? applicationEndDate,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => PolicyCalendarAddSheet(
        title: title,
        applicationStartDate: applicationStartDate,
        applicationEndDate: applicationEndDate,
      ),
    );
  }

  void _confirm(BuildContext context) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('캘린더 추가 기능은 준비 중이에요.')),
    );
  }

  String? _formatDay(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return null;
    final date = DateTime.tryParse(isoDate);
    if (date == null) return null;
    return DateFormat('M월 d일', 'ko_KR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final startLabel = _formatDay(applicationStartDate);
    final endLabel = _formatDay(applicationEndDate);
    final rangeLabel = [startLabel, endLabel].whereType<String>().join(' - ');

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '내 캘린더에 추가하시겠습니까?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black),
            ),
            if (startLabel != null || endLabel != null) ...[
              const SizedBox(height: 16),
              _buildRangePreview(),
              if (rangeLabel.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(rangeLabel, style: const TextStyle(fontSize: 12, color: HomeTokens.accentDark)),
              ],
            ],
            const SizedBox(height: 12),
            Text(
              '$title 내 캘린더에 추가하기',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: HomeTokens.accentDark),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HomeTokens.accentDark,
                      side: const BorderSide(color: Color(0xFFA9E1CF)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('취소', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HomeTokens.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () => _confirm(context),
                    child: const Text('추가', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangePreview() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _rangeDot(filled: false),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: DottedLine(),
          ),
        ),
        _rangeDot(filled: true),
      ],
    );
  }

  Widget _rangeDot({required bool filled}) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? HomeTokens.accent : Colors.white,
        border: Border.all(color: HomeTokens.accent, width: 1.5),
      ),
    );
  }
}

class DottedLine extends StatelessWidget {
  const DottedLine({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 4.0;
        const dashSpace = 4.0;
        final dashCount = (constraints.maxWidth / (dashWidth + dashSpace)).floor().clamp(1, 1000);
        return SizedBox(
          height: 2,
          child: Row(
            children: List.generate(
              dashCount,
              (_) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: dashSpace / 2),
                child: SizedBox(width: dashWidth, height: 2, child: DecoratedBox(decoration: BoxDecoration(color: HomeTokens.accent))),
              ),
            ),
          ),
        );
      },
    );
  }
}
