import 'package:flutter/material.dart';

/// Colors shared across 2+ features, consolidating what used to be
/// independently copy-pasted into `HomeTokens`/`AuthTokens`/`MyTokens` (and
/// occasionally hand-typed raw hex) under different names. Every value here
/// is unchanged from whichever token/file it was consolidated from - this is
/// a "give the duplicate one name" pass, not a restyle.
///
/// Feature-specific colors with no proven duplicate elsewhere stay in their
/// own `HomeTokens`/`AuthTokens`/`MyTokens`, or in `AppColors`
/// (core/theme.dart).
class AppColorTokens {
  AppColorTokens._();

  static const Color primary = Color(0xFF00C875);

  /// Flat "app green" used for text/icons/flat fills. Intentionally distinct
  /// from [accentGradientEnd] (0xFF00AF76) - audited, not a typo: this is
  /// the solid-color shade, that one is the gradient-endpoint shade.
  static const Color accent = Color(0xFF00AE76);

  /// Gradient-stop green used as an endpoint in Home's hero gradient,
  /// Calendar/Report's shared header gradient, the manual-input FAB's
  /// gradient, and MyPage's primary gradient.
  static const Color accentGradientEnd = Color(0xFF00AF76);

  static const Color accentDark = Color(0xFF007C4F);

  /// Consolidates `HomeTokens.chipActiveBg`/`textOnHero`/`navActiveBg`,
  /// `AuthTokens.softGreen`, `MyTokens.accentSoftBg`.
  static const Color softGreenTint = Color(0xFFD6F3E8);

  /// Consolidates `AuthTokens.softGreenBorder`/`MyTokens.accentSoftBorder`.
  static const Color softGreenBorder = Color(0xFFA9E1CF);

  /// Consolidates `HomeTokens.negative`/`AuthTokens.negative`/
  /// `MyTokens.negative`. Deliberately NOT merged with `AppColors.danger`/
  /// `dangerSoft` in core/theme.dart - confirmed a different, unreconciled
  /// color family, out of scope for this structural pass.
  static const Color negativeAccent = Color(0xFFEF6C4C);

  /// Soft-orange "초과"/over-budget badge fill. Report previously defined
  /// this independently in two places with a 1-value drift
  /// (`budget_usage_bar.dart`'s 0xFFFFF1E9 vs `report_screen.dart`'s
  /// 0xFFFFF1E8) - converged to this one canonical value.
  static const Color negativeSoftBg = Color(0xFFFFF1E9);

  /// Consolidates `HomeTokens.cardSurface`/`chipInactiveBg`,
  /// `AuthTokens.inputFill`, `MyTokens.cardSurface`.
  static const Color surfaceOffWhite = Color(0xFFFCFCFC);

  /// Consolidates `HomeTokens.chipInactiveBorder`/`MyTokens.borderNeutral`.
  static const Color borderNeutral = Color(0xFFE4E4E4);

  /// A light divider/track grey, previously hand-typed as a raw literal in
  /// several unrelated files with no token backing it.
  static const Color dividerTrack = Color(0xFFE5E7EB);

  // Four near-identical off-white page backgrounds sourced from different
  // Figma exports, confirmed NOT byte-identical - kept as distinct named
  // constants for this structural pass rather than silently shifting a
  // pixel. A future visual-QA'd pass may reconcile these to one value.
  static const Color pageBackgroundCore = Color(0xFFF7F8FA);
  static const Color pageBackgroundHome = Color(0xFFF8FAF9);
  static const Color pageBackgroundMy = Color(0xFFF7F7F7);
  static const Color skeletonShimmerHighlight = Color(0xFFF6F7F8);
}
