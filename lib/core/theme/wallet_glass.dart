import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 월릿's glass design system, one set of values per brightness. Registered
/// on both `appTheme` and `appDarkTheme` (core/theme.dart) and read through
/// `context.glass`.
///
/// Surfaces come in four levels, each with its own fill/border/shadow so a
/// screen never invents its own card look:
///
/// - Level 0 `background*` / `glow*` - the ambient page backdrop
///   ([WalletBackground] in core/widgets/glass.dart).
/// - Level 1 [surfaceFill] - plain information areas, no glass.
/// - Level 2 [cardFill] - main information cards. Translucent, but drawn
///   without a BackdropFilter: over the smooth ambient backdrop a blur is
///   invisible and only costs frames (most of these cards scroll).
/// - Level 3 [floatingFill] - things floating above content (bottom nav,
///   sheets, the FAB). The only level that really blurs what is behind it.
///
/// Light and dark use different opacities on purpose: a dark translucent
/// fill over a dark backdrop needs less alpha and a faint light border to
/// stay distinguishable without turning muddy.
@immutable
class WalletGlass extends ThemeExtension<WalletGlass> {
  // Level 0 - background.
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color glowPrimary;
  final Color glowSecondary;

  // Level 1 - normal surface.
  final Color surfaceFill;

  // Level 2 - glass card.
  final Color cardFill;
  final Color cardBorder;
  final List<BoxShadow> cardShadow;

  /// Tile nested inside a card: a tint, never a second border/shadow.
  final Color insetFill;

  // Level 3 - floating glass.
  final Color floatingFill;
  final Color floatingBorder;
  final List<BoxShadow> floatingShadow;

  /// The hero panel at the top of Home/Calendar/Report.
  final List<Color> heroGradient;

  /// Glass laid directly on the hero panel (Home's main card).
  final Color heroCardFill;
  final Color heroCardBorder;

  // Text, all checked against [cardFill] for contrast: primary/secondary
  // pass 4.5:1, tertiary is for >=12px captions only.
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  final Color divider;
  final Color track;

  // Chips.
  final Color chipFill;
  final Color chipBorder;
  final Color chipSelectedFill;
  final Color chipSelectedBorder;
  final Color chipSelectedText;

  /// Brand green for fills/icons/strokes.
  final Color accent;

  /// Brand green dark enough (light) / bright enough (dark) for small text.
  final Color accentText;
  final Color accentSoft;

  // Semantic.
  final Color positive;
  final Color negative;
  final Color negativeSoft;
  final Color warning;

  /// Saturday labels, informational accents.
  final Color info;

  // Bottom navigation.
  final Color navActiveFill;
  final Color navActiveContent;
  final Color navInactiveContent;

  const WalletGlass({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.glowPrimary,
    required this.glowSecondary,
    required this.surfaceFill,
    required this.cardFill,
    required this.cardBorder,
    required this.cardShadow,
    required this.insetFill,
    required this.floatingFill,
    required this.floatingBorder,
    required this.floatingShadow,
    required this.heroGradient,
    required this.heroCardFill,
    required this.heroCardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
    required this.track,
    required this.chipFill,
    required this.chipBorder,
    required this.chipSelectedFill,
    required this.chipSelectedBorder,
    required this.chipSelectedText,
    required this.accent,
    required this.accentText,
    required this.accentSoft,
    required this.positive,
    required this.negative,
    required this.negativeSoft,
    required this.warning,
    required this.info,
    required this.navActiveFill,
    required this.navActiveContent,
    required this.navInactiveContent,
  });

  /// Warm white -> very light grey with a faint brand tint.
  static const WalletGlass light = WalletGlass(
    backgroundTop: Color(0xFFF1F7F4),
    backgroundBottom: Color(0xFFF6F7F8),
    glowPrimary: Color(0x2400C875),
    glowSecondary: Color(0x1A7FD8C0),
    surfaceFill: Color(0xFFFFFFFF),
    cardFill: Color(0xC7FFFFFF),
    cardBorder: Color(0xE6FFFFFF),
    cardShadow: [
      BoxShadow(color: Color(0x0D0F2A1F), blurRadius: 24, offset: Offset(0, 8)),
      BoxShadow(color: Color(0x080F2A1F), blurRadius: 3, offset: Offset(0, 1)),
    ],
    insetFill: Color(0xFFF2F6F4),
    floatingFill: Color(0xD1FFFFFF),
    floatingBorder: Color(0xF2FFFFFF),
    floatingShadow: [
      BoxShadow(
        color: Color(0x140F2A1F),
        blurRadius: 28,
        offset: Offset(0, 10),
      ),
      BoxShadow(color: Color(0x080F2A1F), blurRadius: 6, offset: Offset(0, 2)),
    ],
    heroGradient: [
      Color(0xFF009E6B),
      Color(0xFF00AE76),
      Color(0xFF4FCB9B),
      Color(0xFFB9EDD3),
    ],
    heroCardFill: Color(0xB8FFFFFF),
    heroCardBorder: Color(0xB3FFFFFF),
    textPrimary: Color(0xFF17201C),
    textSecondary: Color(0xFF55605B),
    textTertiary: Color(0xFF737D78),
    divider: Color(0xFFE4E9E6),
    track: Color(0xFFE1EEE7),
    chipFill: Color(0x99FFFFFF),
    chipBorder: Color(0xFFE1E6E3),
    chipSelectedFill: AppColorTokens.softGreenTint,
    chipSelectedBorder: Color(0xFF9CD1A9),
    chipSelectedText: AppColorTokens.accentDark,
    accent: AppColorTokens.accent,
    accentText: Color(0xFF00875A),
    accentSoft: AppColorTokens.softGreenTint,
    positive: Color(0xFF00875A),
    negative: Color(0xFFE0553A),
    negativeSoft: AppColorTokens.negativeSoftBg,
    warning: Color(0xFFB7791F),
    info: Color(0xFF2F6FDB),
    navActiveFill: AppColorTokens.softGreenTint,
    navActiveContent: AppColorTokens.accentDark,
    navInactiveContent: Color(0xFF85928A),
  );

  /// Deep charcoal -> navy-black with a faint brand tint.
  static const WalletGlass dark = WalletGlass(
    backgroundTop: Color(0xFF0F1714),
    backgroundBottom: Color(0xFF0B0F12),
    glowPrimary: Color(0x2200C875),
    glowSecondary: Color(0x1F2B4C7E),
    surfaceFill: Color(0xFF161C1A),
    cardFill: Color(0xB81C2422),
    cardBorder: Color(0x14FFFFFF),
    cardShadow: [
      BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 8)),
    ],
    insetFill: Color(0x0FFFFFFF),
    floatingFill: Color(0xD91A2120),
    floatingBorder: Color(0x1FFFFFFF),
    floatingShadow: [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 28,
        offset: Offset(0, 10),
      ),
    ],
    heroGradient: [
      Color(0xFF0B4D36),
      Color(0xFF0C3F2E),
      Color(0xFF0E2A21),
      Color(0xFF0F1714),
    ],
    heroCardFill: Color(0x9E1C2624),
    heroCardBorder: Color(0x1FFFFFFF),
    textPrimary: Color(0xFFEDF2EF),
    textSecondary: Color(0xFFAAB5AF),
    textTertiary: Color(0xFF85908A),
    divider: Color(0x1AFFFFFF),
    track: Color(0x1FFFFFFF),
    chipFill: Color(0x0FFFFFFF),
    chipBorder: Color(0x1FFFFFFF),
    chipSelectedFill: Color(0x2E00C875),
    chipSelectedBorder: Color(0x6600C875),
    chipSelectedText: Color(0xFF5BE3A8),
    accent: Color(0xFF1FCB8A),
    accentText: Color(0xFF4FDDA0),
    accentSoft: Color(0x2600C875),
    positive: Color(0xFF4FDDA0),
    negative: Color(0xFFFF8A70),
    negativeSoft: Color(0x26FF8A70),
    warning: Color(0xFFF2B85B),
    info: Color(0xFF8AB4FF),
    navActiveFill: Color(0x2E00C875),
    navActiveContent: Color(0xFF5BE3A8),
    navInactiveContent: Color(0xFF8D9893),
  );

  @override
  WalletGlass copyWith() => this;

  @override
  WalletGlass lerp(WalletGlass? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return WalletGlass(
      backgroundTop: c(backgroundTop, other.backgroundTop),
      backgroundBottom: c(backgroundBottom, other.backgroundBottom),
      glowPrimary: c(glowPrimary, other.glowPrimary),
      glowSecondary: c(glowSecondary, other.glowSecondary),
      surfaceFill: c(surfaceFill, other.surfaceFill),
      cardFill: c(cardFill, other.cardFill),
      cardBorder: c(cardBorder, other.cardBorder),
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t)!,
      insetFill: c(insetFill, other.insetFill),
      floatingFill: c(floatingFill, other.floatingFill),
      floatingBorder: c(floatingBorder, other.floatingBorder),
      floatingShadow: BoxShadow.lerpList(
        floatingShadow,
        other.floatingShadow,
        t,
      )!,
      heroGradient: [
        for (var i = 0; i < heroGradient.length; i++)
          c(heroGradient[i], other.heroGradient[i]),
      ],
      heroCardFill: c(heroCardFill, other.heroCardFill),
      heroCardBorder: c(heroCardBorder, other.heroCardBorder),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      divider: c(divider, other.divider),
      track: c(track, other.track),
      chipFill: c(chipFill, other.chipFill),
      chipBorder: c(chipBorder, other.chipBorder),
      chipSelectedFill: c(chipSelectedFill, other.chipSelectedFill),
      chipSelectedBorder: c(chipSelectedBorder, other.chipSelectedBorder),
      chipSelectedText: c(chipSelectedText, other.chipSelectedText),
      accent: c(accent, other.accent),
      accentText: c(accentText, other.accentText),
      accentSoft: c(accentSoft, other.accentSoft),
      positive: c(positive, other.positive),
      negative: c(negative, other.negative),
      negativeSoft: c(negativeSoft, other.negativeSoft),
      warning: c(warning, other.warning),
      info: c(info, other.info),
      navActiveFill: c(navActiveFill, other.navActiveFill),
      navActiveContent: c(navActiveContent, other.navActiveContent),
      navInactiveContent: c(navInactiveContent, other.navInactiveContent),
    );
  }
}

/// Blur strengths (BackdropFilter sigma) for the levels that blur.
class GlassBlur {
  GlassBlur._();

  /// Home's main card, laid on the hero panel.
  static const double card = 16;

  /// Bottom nav, sheets.
  static const double floating = 22;
}

extension WalletGlassContext on BuildContext {
  /// Falls back to [WalletGlass.light] when a test pumps a bare
  /// `MaterialApp` without the app themes.
  WalletGlass get glass =>
      Theme.of(this).extension<WalletGlass>() ?? WalletGlass.light;
}
