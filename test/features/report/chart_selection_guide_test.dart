import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_client/features/report/widgets/chart_selection_guide.dart';

const _chartWidth = 300.0;
const _labelKey = Key('label');

Future<void> _pump(WidgetTester tester, {required double anchorX, bool clamp = false, double overhang = 0}) {
  return tester.pumpWidget(MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: _chartWidth,
        height: 100,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: AnchoredChartLabel(
              anchorX: anchorX,
              clampToChart: clamp,
              overhang: overhang,
              child: const SizedBox(key: _labelKey, width: 80, height: 20),
            ),
          ),
        ]),
      ),
    ),
  ));
}

void main() {
  test('chartDayX maps day 1..maxDay across the full width', () {
    expect(chartDayX(1, 30, _chartWidth), 0);
    expect(chartDayX(30, 30, _chartWidth), _chartWidth);
    expect(chartDayX(16, 31, _chartWidth), closeTo(_chartWidth / 2, 1e-9));
    expect(chartDayX(1, 1, _chartWidth), 0);
  });

  testWidgets('label center sits exactly on the anchor, not just at mid-chart', (tester) async {
    for (final x in [60.0, 150.0, 233.0]) {
      await _pump(tester, anchorX: x);
      expect(tester.getCenter(find.byKey(_labelKey)).dx, closeTo(x, 1e-6));
    }
  });

  testWidgets('clampToChart keeps a wide label inside the chart at both ends', (tester) async {
    await _pump(tester, anchorX: 0, clamp: true);
    expect(tester.getTopLeft(find.byKey(_labelKey)).dx, 0);

    await _pump(tester, anchorX: _chartWidth, clamp: true);
    expect(tester.getTopRight(find.byKey(_labelKey)).dx, _chartWidth);
  });

  testWidgets('without clamp the label stays centered on the anchor even at the edge', (tester) async {
    await _pump(tester, anchorX: 0);
    expect(tester.getCenter(find.byKey(_labelKey)).dx, closeTo(0, 1e-6));
  });

  testWidgets('overhang lets a clamped label stick out only that far', (tester) async {
    await _pump(tester, anchorX: 0, clamp: true, overhang: 8);
    expect(tester.getTopLeft(find.byKey(_labelKey)).dx, -8);

    await _pump(tester, anchorX: _chartWidth, clamp: true, overhang: 8);
    expect(tester.getTopRight(find.byKey(_labelKey)).dx, _chartWidth + 8);

    // Far enough from the edge that no clamping applies: still exactly centered.
    await _pump(tester, anchorX: 150, clamp: true, overhang: 8);
    expect(tester.getCenter(find.byKey(_labelKey)).dx, closeTo(150, 1e-6));
  });
}
