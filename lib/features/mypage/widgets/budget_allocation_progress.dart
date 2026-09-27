import 'package:flutter/material.dart';

import '../theme/my_tokens.dart';

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
    final fillColor = isOver ? MyTokens.negative : MyTokens.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(total, isComplete: isComplete, isOver: isOver),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(_barHeight / 2),
          child: Container(
            height: _barHeight,
            color: MyTokens.accentSoftBg,
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

  Widget _label(int total, {required bool isComplete, required bool isOver}) {
    const base = TextStyle(fontSize: 13, height: 1.4);
    const strong = TextStyle(fontWeight: FontWeight.w700);
    const muted = TextStyle(
      color: MyTokens.placeholder,
      fontWeight: FontWeight.w500,
    );

    final List<InlineSpan> spans;
    if (isOver) {
      spans = [
        TextSpan(text: '$total% 배분', style: muted),
        const TextSpan(text: ' · ', style: muted),
        TextSpan(
          text: '${total - 100}% 초과',
          style: strong.copyWith(color: MyTokens.negative),
        ),
      ];
    } else if (isComplete) {
      spans = [
        TextSpan(
          text: '배분 완료 100%',
          style: strong.copyWith(color: MyTokens.accent),
        ),
        const WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(
              Icons.check_circle_rounded,
              size: 15,
              color: MyTokens.accent,
            ),
          ),
        ),
      ];
    } else {
      spans = [
        TextSpan(
          text: '배분됨 $total%',
          style: strong.copyWith(color: MyTokens.accent),
        ),
        const TextSpan(text: ' · ', style: muted),
        TextSpan(text: '남음 ${100 - total}%', style: muted),
      ];
    }
    return Text.rich(
      TextSpan(style: base, children: spans),
      key: const ValueKey('budget-allocation-label'),
    );
  }
}
