import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_shadows.dart';

/// A composable "surface" style - the color/border/shadow/radius (and,
/// optionally, a blur sigma for glass-style surfaces) that together make up
/// a card/panel's look. Centralizing these as data means a future full
/// restyle (e.g. Liquid Glass) can change a handful of [AppSurfaces]
/// definitions instead of every widget that draws a card.
///
/// This does not manage blur itself - [blurSigma] is exposed as plain data
/// only. A caller that needs the blur applies its own `ClipRRect` +
/// `BackdropFilter` around this surface's decoration (see
/// `core/router.dart`'s nav bar and `home_screen.dart`'s D-Day card for the
/// existing pattern), since blur requires a widget in the tree, not just a
/// `BoxDecoration` value.
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
class AppSurfaces {
  AppSurfaces._();

  static const SurfaceStyle card = SurfaceStyle(
    color: AppColorTokens.surfaceOffWhite,
    radius: AppRadii.compactInput,
    shadows: AppShadows.card,
  );

  /// Radius only - fill/border vary by active/inactive state, so those stay
  /// caller-supplied rather than baked in here.
  static const SurfaceStyle chip = SurfaceStyle(
    color: Colors.transparent,
    radius: AppRadii.pill,
  );

  /// Top-level white card on the tab screens (Home/Calendar/Report): white,
  /// no border, one soft shadow. Content padding is
  /// `AppSpacing.cardPadding` for section cards, `AppSpacing.itemPadding`
  /// for list/grid item cards.
  static const SurfaceStyle contentCard = SurfaceStyle(
    color: Colors.white,
    radius: AppRadii.button,
    shadows: AppShadows.content,
  );

  /// A tile nested inside a [contentCard] - tinted with the page background
  /// instead of a second border/shadow, so cards never stack shadows.
  static const SurfaceStyle insetTile = SurfaceStyle(
    color: AppColorTokens.pageBackgroundHome,
    radius: AppRadii.input,
  );

  /// Translucent pill that sits on a green header (Home's date pill,
  /// Calendar's cycle selector, Report's month selector).
  static final SurfaceStyle onHeroPill = SurfaceStyle(
    color: Colors.white,
    colorOpacity: 0.22,
    borderColor: Colors.white.withValues(alpha: 0.45),
    radius: AppRadii.pill,
  );

  /// Home's D-Day hero card. Mirrors `HomeTokens.heroCardSurface` /
  /// `heroCardSurfaceOpacity` / `heroCardBorder` as literals (not an import)
  /// so `core/theme` doesn't depend on a feature folder. Must render
  /// pixel-identical to today's inline `home_screen.dart` decoration,
  /// including the existing `blurSigma: 12` `BackdropFilter`, left untouched
  /// at its call site.
  static const SurfaceStyle heroCard = SurfaceStyle(
    color: Color(0xFFFFFFFF),
    colorOpacity: 0.94,
    borderColor: Color(0xFFFFFFFF),
    radius: AppRadii.hero,
    blurSigma: 12,
  );

  /// The floating bottom-nav bar. Mirrors `router.dart`'s current values
  /// exactly, including the existing `blurSigma: 18` `BackdropFilter`, left
  /// untouched at its call site.
  static final SurfaceStyle floatingNav = SurfaceStyle(
    color: Colors.white,
    colorOpacity: 0.88,
    borderColor: Colors.white.withValues(alpha: 0.95),
    borderWidth: 1.2,
    radius: 32,
    shadows: AppShadows.floatingNav,
    blurSigma: 18,
  );
}
