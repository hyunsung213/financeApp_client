import 'package:flutter/material.dart';

import '../../../core/theme/wallet_glass.dart';

/// Live 배분 진행 상태 for the budget plan: how much of 100% is allocated,
/// how much is left, and a thin bar. Recomputed from [totalPercentage] on
/// every keystroke by the parent; the plan is saveable only at exactly 100.
class BudgetAllocationProgress extends StatelessWidget {
  final int totalPercentage;

  const BudgetAllocationProgress({super.key, required this.totalPercentage});

  static const double _barHeight = 6;

  @override
  Widget build(BuildContext context) {
    final total = totalPercentage;
    final isComplete = total == 100;
    final isOver = total > 100;
    final fillColor = isOver ? context.glass.negative : context.glass.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(context, total, isComplete: isComplete, isOver: isOver),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(_barHeight / 2),
          child: Container(
            height: _barHeight,
            color: context.glass.accentSoft,
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (total.clamp(0, 100)) / 100),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              builder: (context, fraction, _) => FractionallySizedBox(
                widthFactor: fraction,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(_barHeight / 2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(
    BuildContext context,
    int total, {
    required bool isComplete,
    required bool isOver,
  }) {
    const base = TextStyle(fontSize: 13, height: 1.4);
    const strong = TextStyle(fontWeight: FontWeight.w700);
    final muted = TextStyle(
      color: context.glass.textTertiary,
      fontWeight: FontWeight.w500,
    );

    final List<InlineSpan> spans;
    if (isOver) {
      spans = [
        TextSpan(text: '$total% 배분', style: muted),
        TextSpan(text: ' · ', style: muted),
        TextSpan(
          text: '${total - 100}% 초과',
          style: strong.copyWith(color: context.glass.negative),
        ),
      ];
    } else if (isComplete) {
      spans = [
        TextSpan(
          text: '배분 완료 100%',
          style: strong.copyWith(color: context.glass.accentText),
        ),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              Icons.check_circle_rounded,
              size: 15,
              color: context.glass.accentText,
            ),
          ),
        ),
      ];
    } else {
      spans = [
        TextSpan(
          text: '배분됨 $total%',
          style: strong.copyWith(color: context.glass.accentText),
        ),
        TextSpan(text: ' · ', style: muted),
        TextSpan(text: '남음 ${100 - total}%', style: muted),
      ];
    }
    return Text.rich(
      TextSpan(style: base, children: spans),
      key: const ValueKey('budget-allocation-label'),
    );
  }
}
