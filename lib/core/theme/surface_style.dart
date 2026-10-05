import 'package:flutter/material.dart';

import 'app_radii.dart';

/// A composable "surface" style - the color/border/shadow/radius (and,
/// optionally, a blur sigma for glass-style surfaces) that together make up
/// a card/panel's look. Centralizing these as data means a future full
/// restyle (e.g. Liquid Glass) can change a handful of [AppSurfaces]
/// definitions instead of every widget that draws a card.
///
/// Light-only and kept for the few remaining call sites (e.g. the on-hero
/// pills). New and restyled surfaces use the theme-aware glass system
/// instead: `WalletGlass` (core/theme/wallet_glass.dart) for values and
/// `GlassSurface`/`GlassCard`/`glassDecoration` (core/widgets/glass.dart).
class SurfaceStyle {
  final Color color;
  final double? colorOpacity;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? shadows;
  final double radius;
  final double? blurSigma;

  const SurfaceStyle({
    required this.color,
    this.colorOpacity,
    this.borderColor,
    this.borderWidth = 1,
    this.shadows,
    required this.radius,
    this.blurSigma,
  });

  BoxDecoration toBoxDecoration() {
    return BoxDecoration(
      color: colorOpacity == null
          ? color
          : color.withValues(alpha: colorOpacity!),
      borderRadius: BorderRadius.circular(radius),
      border: borderColor == null
          ? null
          : Border.all(color: borderColor!, width: borderWidth),
      boxShadow: shadows,
    );
  }
}

/// Named [SurfaceStyle] instances for the app's recurring surfaces.
/// Additive - most plain `Container(decoration: BoxDecoration(...))` call
/// sites are left as-is; only the two existing glass surfaces
/// (`heroCard`/`floatingNav`) plus generic `card`/`chip` are defined here in
/// this pass.
/// Named [SurfaceStyle] instances still in use. Cards, the bottom nav and
/// the Home hero card moved to the glass system (core/widgets/glass.dart).
class AppSurfaces {
  AppSurfaces._();

  /// Translucent pill that sits on a green header (Home's date pill,
  /// Calendar's cycle selector, Report's month selector).
  static final SurfaceStyle onHeroPill = SurfaceStyle(
    color: Colors.white,
    colorOpacity: 0.22,
    borderColor: Colors.white.withValues(alpha: 0.45),
    radius: AppRadii.pill,
  );
}
