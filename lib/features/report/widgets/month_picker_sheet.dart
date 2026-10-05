import 'package:flutter/material.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/wallet_glass.dart';
import '../../../core/widgets/glass.dart';

/// 12-month grid picker (Figma node 397:6017), shown as a bottom sheet from
/// the "8월 ▾" dropdown on every Report screen that lets you change month.
class MonthPickerSheet extends StatefulWidget {
  final DateTime initialMonth;

  const MonthPickerSheet({super.key, required this.initialMonth});

  static Future<DateTime?> show(BuildContext context, DateTime initialMonth) {
    // Report lives inside a StatefulShellRoute branch Navigator, and the
    // floating bottom nav bar is painted as a Stack sibling *above* that
    // branch's Navigator in `ScaffoldWithNavBar` (core/router.dart) - a sheet
    // pushed on the branch Navigator renders underneath it. Pushing on the
    // root Navigator instead puts the sheet above the whole shell (nav bar
    // included) and also flips `isShellOnTop` false, sliding the nav bar away
    // - the same mechanism already used for AddTransactionModal's full-screen
    // push.
    return showModalBottomSheet<DateTime>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GlassSurface(
        level: GlassLevel.floating,
        radius: AppRadii.xl,
        blurSigma: GlassBlur.floating,
        fill: Color.alphaBlend(
          context.glass.surfaceFill.withValues(alpha: 0.55),
          context.glass.floatingFill,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: context.glass.textSecondary),
                  onPressed: () => setState(() => _selectedYear -= 1),
                ),
                Text('$_selectedYear년', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.glass.textPrimary)),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: context.glass.textSecondary),
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
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  onTap: () => Navigator.of(context).pop(DateTime(_selectedYear, monthNum, 1)),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? context.glass.accentSoft : context.glass.chipFill,
                      border: Border.all(color: isSelected ? context.glass.chipSelectedBorder : context.glass.chipBorder),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$monthNum월',
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? context.glass.chipSelectedText : context.glass.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        ),
      ),
    );
  }
}
