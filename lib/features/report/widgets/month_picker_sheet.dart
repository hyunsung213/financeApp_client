import 'package:flutter/material.dart';
import '../../home/theme/home_tokens.dart';

/// 12-month grid picker (Figma node 397:6017), shown as a bottom sheet from
/// the "8월 ▾" dropdown on every Report screen that lets you change month.
class MonthPickerSheet extends StatefulWidget {
  final DateTime initialMonth;

  const MonthPickerSheet({super.key, required this.initialMonth});

  static Future<DateTime?> show(BuildContext context, DateTime initialMonth) {
    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MonthPickerSheet(initialMonth: initialMonth),
    );
  }

  @override
  State<MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<MonthPickerSheet> {
  late int _selectedYear = widget.initialMonth.year;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _selectedYear -= 1),
                ),
                Text('$_selectedYear년', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: HomeTokens.textDark)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _selectedYear += 1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 12,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.1,
              ),
              itemBuilder: (context, index) {
                final monthNum = index + 1;
                final isSelected = _selectedYear == widget.initialMonth.year && monthNum == widget.initialMonth.month;
                return InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => Navigator.of(context).pop(DateTime(_selectedYear, monthNum, 1)),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? HomeTokens.chipActiveBg : HomeTokens.chipInactiveBg,
                      border: Border.all(color: isSelected ? HomeTokens.chipActiveBorder : HomeTokens.chipInactiveBorder),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 1, offset: const Offset(0, 1))],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$monthNum월',
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? HomeTokens.accentDark : HomeTokens.textDark,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
