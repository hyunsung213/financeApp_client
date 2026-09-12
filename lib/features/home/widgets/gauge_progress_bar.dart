import 'package:flutter/material.dart';

/// Single continuous progress bar with tick marks at 25/50/75%, matching
/// Figma node 335:8091's D-Day card gauge (Group 11: Rectangle 25/26 fill +
/// Rectangle 86/87/88 ticks). Replaces the previous 4-segment row — the
/// underlying ratio (`flexibleUsageRatio`) is unchanged, only the rendering.
class GaugeProgressBar extends StatelessWidget {
  /// 0.0 - 1.0 usage ratio. Values outside that range are clamped.
  final double ratio;
  final double height;
  final Color backgroundColor;
  final List<Color> fillGradient;

  const GaugeProgressBar({
    super.key,
    required this.ratio,
    this.height = 10,
    this.backgroundColor = Colors.white,
    this.fillGradient = const [Color(0xFF00AE76), Color(0xFFA9E1CF)],
  });

  @override
  Widget build(BuildContext context) {
    final clamped = ratio.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(height / 2),
                child: Container(
                  width: double.infinity,
                  height: height,
                  color: backgroundColor,
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(height / 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: clamped,
                    child: Container(
                      height: height,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: fillGradient),
                      ),
                    ),
                  ),
                ),
              ),
              for (final fraction in const [0.25, 0.5, 0.75])
                Positioned(
                  left: constraints.maxWidth * fraction - 1,
                  child: Container(width: 2, height: height, color: Colors.white),
                ),
            ],
          ),
        );
      },
    );
  }
}
