import 'package:flutter/material.dart';
import '../theme.dart';

/// A shimmering placeholder block. Page-level skeletons below compose these
/// into the actual card/row shapes of each screen so loading looks like the
/// real layout instead of a spinner or a big gray slab.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final Color baseColor;
  final Color highlightColor;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius,
    this.baseColor = const Color(0xFFE9EBEE),
    this.highlightColor = const Color(0xFFF6F7F8),
  });

  /// Thin rounded bar used for text placeholders.
  const SkeletonBox.line({
    super.key,
    this.width,
    this.height = 13,
    this.baseColor = const Color(0xFFE9EBEE),
    this.highlightColor = const Color(0xFFF6F7F8),
  }) : borderRadius = const BorderRadius.all(Radius.circular(7));

  /// Line variant for dark/green backgrounds.
  factory SkeletonBox.lightLine({double? width, double height = 13}) {
    return SkeletonBox.line(
      width: width,
      height: height,
      baseColor: Colors.white.withValues(alpha: 0.28),
      highlightColor: Colors.white.withValues(alpha: 0.5),
    );
  }

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(widget.baseColor, widget.highlightColor, _controller.value),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          ),
        );
      },
    );
  }
}

/// White rounded card matching the app's card styling, for skeleton contents.
class SkeletonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const SkeletonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}

/// Home hero: big amount + the frosted budget card. Sits on the green
/// gradient, so it uses translucent white tones.
class HomeHeroSkeleton extends StatelessWidget {
  const HomeHeroSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Center(child: SkeletonBox.lightLine(width: 200, height: 42)),
        const SizedBox(height: 30),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox.lightLine(width: 180, height: 14),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonBox.lightLine(width: 150, height: 20),
                  SkeletonBox.lightLine(width: 60, height: 14),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: List.generate(
                  4,
                  (i) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == 3 ? 0 : 4),
                      child: SkeletonBox.lightLine(height: 6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Home's 2-up transaction cards.
class TransactionCardsSkeleton extends StatelessWidget {
  const TransactionCardsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _card()),
        const SizedBox(width: 12),
        Expanded(child: _card()),
      ],
    );
  }

  Widget _card() {
    return SkeletonCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SkeletonBox.line(height: 12)),
              const SizedBox(width: 6),
              const SkeletonBox(width: 30, height: 14, borderRadius: BorderRadius.all(Radius.circular(6))),
            ],
          ),
          const SizedBox(height: 10),
          const SkeletonBox.line(width: 80, height: 16),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              SkeletonBox.line(width: 34, height: 11),
              SkeletonBox(width: 30, height: 30, borderRadius: BorderRadius.all(Radius.circular(15))),
            ],
          ),
        ],
      ),
    );
  }
}

/// Calendar's month summary row (무지출 N일 / 수입 / 지출).
class CalendarSummarySkeleton extends StatelessWidget {
  const CalendarSummarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SkeletonBox.line(width: 130, height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: const [
            SkeletonBox.line(width: 110, height: 12),
            SizedBox(height: 8),
            SkeletonBox.line(width: 96, height: 12),
          ],
        ),
      ],
    );
  }
}

/// Report page: green hero, daily chart card, donut card, insight rows.
class ReportSkeleton extends StatelessWidget {
  const ReportSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF00C875), Color(0xFF10B981)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox.lightLine(width: 190, height: 22),
                  const SizedBox(height: 10),
                  SkeletonBox.lightLine(width: 240, height: 22),
                  const SizedBox(height: 22),
                  Center(child: SkeletonBox.lightLine(width: 230, height: 16)),
                  const SizedBox(height: 10),
                  Center(child: SkeletonBox.lightLine(width: 200, height: 14)),
                  const SizedBox(height: 22),
                  SkeletonBox.lightLine(height: 44),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
            children: [
              _sectionHeader(),
              const SizedBox(height: 24),
              const SkeletonBox(height: 170, borderRadius: BorderRadius.all(Radius.circular(12))),
              const SizedBox(height: 32),
              _sectionHeader(),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Center(
                      child: SkeletonBox(width: 150, height: 150, borderRadius: BorderRadius.all(Radius.circular(75))),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: List.generate(
                        3,
                        (i) => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              SkeletonBox(width: 8, height: 8, borderRadius: BorderRadius.all(Radius.circular(4))),
                              SizedBox(width: 8),
                              Expanded(child: SkeletonBox.line(height: 12)),
                              SizedBox(width: 8),
                              SkeletonBox.line(width: 30, height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _sectionHeader(),
              const SizedBox(height: 16),
              ...List.generate(
                3,
                (i) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: SkeletonBox(height: 48, borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        SkeletonBox.line(width: 150, height: 17),
        SkeletonBox.line(width: 44, height: 13),
      ],
    );
  }
}

/// Policy list: filter chips, a hero card with image block, then compact rows.
class PolicyListSkeleton extends StatelessWidget {
  const PolicyListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children: [
        SizedBox(
          height: 38,
          child: Row(
            children: const [
              SkeletonBox(width: 72, height: 34, borderRadius: BorderRadius.all(Radius.circular(18))),
              SizedBox(width: 8),
              SkeletonBox(width: 92, height: 34, borderRadius: BorderRadius.all(Radius.circular(18))),
              SizedBox(width: 8),
              SkeletonBox(width: 116, height: 34, borderRadius: BorderRadius.all(Radius.circular(18))),
              SizedBox(width: 8),
              Expanded(child: SkeletonBox(height: 34, borderRadius: BorderRadius.all(Radius.circular(18)))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletonBox(height: 140, borderRadius: BorderRadius.zero),
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox.line(height: 17),
                    SizedBox(height: 10),
                    SkeletonBox.line(width: 220, height: 13),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SkeletonCard(
              padding: const EdgeInsets.all(12),
              radius: 14,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(width: 48, height: 18, borderRadius: BorderRadius.all(Radius.circular(4))),
                        SizedBox(height: 10),
                        SkeletonBox.line(height: 14),
                        SizedBox(height: 8),
                        SkeletonBox.line(width: 170, height: 12),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const SkeletonBox(width: 64, height: 64, borderRadius: BorderRadius.all(Radius.circular(10))),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Settings-style form (mypage sub-screens): section titles, label/value rows,
/// and a highlighted preview card.
class FormSkeleton extends StatelessWidget {
  const FormSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SkeletonBox.line(width: 90, height: 17),
        const SizedBox(height: 12),
        SkeletonCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _labelRow(),
              const SizedBox(height: 20),
              _labelRow(),
              const SizedBox(height: 20),
              const SkeletonBox(height: 40, borderRadius: BorderRadius.all(Radius.circular(10))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletonBox.line(width: 190, height: 14),
              SizedBox(height: 10),
              SkeletonBox.line(width: 110, height: 11),
              SizedBox(height: 14),
              SkeletonBox.line(height: 6),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SkeletonBox.line(width: 110, height: 17),
        const SizedBox(height: 12),
        SkeletonCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _labelRow(),
              const SizedBox(height: 20),
              _labelRow(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _labelRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        SkeletonBox.line(width: 76, height: 14),
        SkeletonBox.line(width: 56, height: 14),
      ],
    );
  }
}

/// Transaction rows for the day-detail sheet.
class TransactionRowsSkeleton extends StatelessWidget {
  final int count;
  const TransactionRowsSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: const [
              SkeletonBox(width: 20, height: 20, borderRadius: BorderRadius.all(Radius.circular(6))),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox.line(height: 14)),
              SizedBox(width: 10),
              SkeletonBox.line(width: 70, height: 14),
            ],
          ),
        ),
      ),
    );
  }
}
