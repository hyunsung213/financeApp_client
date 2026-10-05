import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/wallet_glass.dart';

/// Which tier of the glass system a surface belongs to (see [WalletGlass]).
enum GlassLevel {
  /// Plain information area. Opaque, no border, no shadow.
  surface,

  /// Main information card. Translucent fill + hairline light border + soft
  /// ambient shadow, no blur.
  card,

  /// Floating interaction layer (nav, sheets). Strongest fill and the only
  /// level that blurs by default.
  floating,
}

/// The decoration of a [GlassLevel] surface, for call sites that already
/// draw their own `Container`/`Ink` and only need the look.
BoxDecoration glassDecoration(
  BuildContext context, {
  GlassLevel level = GlassLevel.card,
  double radius = AppRadii.lg,
  BorderRadius? borderRadius,
}) {
  final glass = context.glass;
  final shape = borderRadius ?? BorderRadius.circular(radius);
  return switch (level) {
    GlassLevel.surface => BoxDecoration(
      color: glass.surfaceFill,
      borderRadius: shape,
    ),
    GlassLevel.card => BoxDecoration(
      color: glass.cardFill,
      borderRadius: shape,
      border: Border.all(color: glass.cardBorder),
      boxShadow: glass.cardShadow,
    ),
    GlassLevel.floating => BoxDecoration(
      color: glass.floatingFill,
      borderRadius: shape,
      border: Border.all(color: glass.floatingBorder),
      boxShadow: glass.floatingShadow,
    ),
  };
}

/// A rounded glass panel. Use [GlassCard] for the common Level 2 case.
///
/// [blurSigma] adds a real backdrop blur (ClipRRect + BackdropFilter).
/// Leave it null inside scrolling lists - one blur per visible list row is
/// exactly the kind of cost the glass system avoids. The shadow is painted
/// outside the clip so the blur never cuts it off.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final GlassLevel level;
  final double radius;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? blurSigma;
  final VoidCallback? onTap;

  /// Overrides the level's fill (e.g. the hero card's on-gradient fill).
  final Color? fill;
  final Color? border;

  const GlassSurface({
    super.key,
    required this.child,
    this.level = GlassLevel.card,
    this.radius = AppRadii.lg,
    this.borderRadius,
    this.padding,
    this.blurSigma,
    this.onTap,
    this.fill,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final shape = borderRadius ?? BorderRadius.circular(radius);
    final base = glassDecoration(context, level: level, borderRadius: shape);
    final decoration = base.copyWith(
      color: fill,
      border: border == null ? null : Border.all(color: border!),
    );

    Widget content = padding == null
        ? child
        : Padding(padding: padding!, child: child);
    if (onTap != null) {
      // Transparent Material so the ripple paints above the fill.
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(borderRadius: shape, onTap: onTap, child: content),
      );
    }

    final sigma = blurSigma;
    if (sigma == null || sigma <= 0) {
      return DecoratedBox(decoration: decoration, child: content);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: decoration.boxShadow,
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: DecoratedBox(
            decoration: decoration.copyWith(boxShadow: const []),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Level 2 glass card - the default container for a screen's main
/// information blocks.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppRadii.lg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      level: GlassLevel.card,
      radius: radius,
      padding: padding,
      onTap: onTap,
      child: child,
    );
  }
}

/// Level 0 - the ambient page backdrop: a soft tonal gradient with two
/// faint brand-tinted glows. Painted once behind a whole screen (the tab
/// shell paints one for all five tabs), never per card.
class WalletBackground extends StatelessWidget {
  final Widget? child;

  const WalletBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [glass.backgroundTop, glass.backgroundBottom],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(1.1, -0.55),
                    radius: 0.9,
                    colors: [glass.glowPrimary, glass.glowPrimary.withAlpha(0)],
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-1.2, 0.75),
                      radius: 1.0,
                      colors: [
                        glass.glowSecondary,
                        glass.glowSecondary.withAlpha(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

/// Level 3 frame for a modal bottom sheet: blurred floating glass with the
/// app's sheet radius and drag handle. Open the sheet with
/// `backgroundColor: Colors.transparent` and put the content in [child].
class GlassSheet extends StatelessWidget {
  final Widget child;
  final bool showHandle;

  const GlassSheet({super.key, required this.child, this.showHandle = true});

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return GlassSurface(
      level: GlassLevel.floating,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadii.xl),
      ),
      blurSigma: GlassBlur.floating,
      // Sheets hold dense text, so they sit closer to opaque than the nav.
      fill: Color.alphaBlend(
        glass.surfaceFill.withValues(alpha: 0.55),
        glass.floatingFill,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle) const GlassSheetHandle(),
          Flexible(child: child),
        ],
      ),
    );
  }
}

class GlassSheetHandle extends StatelessWidget {
  const GlassSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: context.glass.textTertiary.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// A semi-transparent selectable pill (filters). Selected state is carried
/// by fill, border, weight and text color together, not color alone.
class GlassChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const GlassChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.fontSize = 13,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final fg = selected ? glass.chipSelectedText : glass.textPrimary;
    final radius = BorderRadius.circular(AppRadii.pill);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: padding,
            decoration: BoxDecoration(
              color: selected ? glass.chipSelectedFill : glass.chipFill,
              borderRadius: radius,
              border: Border.all(
                color: selected ? glass.chipSelectedBorder : glass.chipBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
