import 'package:flutter/material.dart';

/// Box-shadow presets shared across features. Every entry here reproduces
/// exactly the shadow it consolidates - shared/duplicated definitions moved
/// to one place, not restyled.
///
/// `hairline`/`card`/`buttonElevated`/`fab` bake their color as a hex
/// literal (e.g. `Color(0x0D000000)`) rather than
/// `Colors.black.withValues(alpha: 0.05)`, so they can stay `const`
/// (matching how `AuthTokens`/`MyTokens` already expressed the identical
/// shadow) - the two forms render pixel-identical (0.05 * 255, rounded, is
/// exactly 0x0D). Shadows that were only ever expressed via
/// `.withValues(...)` stay non-const (`static final`) to avoid introducing
/// any rounding risk from hand-converting them to hex.
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> hairline = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 1, offset: Offset(0, 1)),
  ];

  /// The single most-repeated card shadow in the app.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// Figma button drop shadow: rgba(96,105,96) at 0.19 / 0.12 / 0.09 / 0.07.
  static const List<BoxShadow> buttonElevated = [
    BoxShadow(color: Color(0x30606960), blurRadius: 5, offset: Offset(0, 5.4)),
    BoxShadow(
      color: Color(0x1F606960),
      blurRadius: 1.229,
      offset: Offset(0, 1.224),
    ),
    BoxShadow(
      color: Color(0x17606960),
      blurRadius: 0.467,
      offset: Offset(0, 0.339),
    ),
    BoxShadow(
      color: Color(0x12606960),
      blurRadius: 0.204,
      offset: Offset(0, 0.06),
    ),
  ];

  /// Same `606960` shadow-color family as [buttonElevated] but a different
  /// alpha/blur/offset - confirmed distinct, kept as its own token rather
  /// than force-merged.
  static const List<BoxShadow> fab = [
    BoxShadow(color: Color(0x33606960), blurRadius: 5, offset: Offset(0, 5)),
  ];

  static final List<BoxShadow> elevatedSurface = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> elevatedStrong = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  /// The floating bottom-nav bar's glass shadow.
  static final List<BoxShadow> floatingNav = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
}
