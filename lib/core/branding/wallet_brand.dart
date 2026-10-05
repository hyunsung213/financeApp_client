import 'package:flutter/material.dart';

/// User-facing 월릿 brand values. The package/application id stays
/// `finance_client` - only what the user sees is branded.
class WalletBrand {
  WalletBrand._();

  static const String name = '월릿';

  /// Brand green of the final logo (Figma Frame 15, 789:2449).
  static const Color green = Color(0xFF005731);

  /// Symbol + "월릿" wordmark lockups from Figma Frame 15 (789:2449).
  /// SVG sources live in `assets/branding/source/`; the PNGs (1x/2x/3x) are
  /// rendered from them since the app has no SVG renderer.
  static const String logoGreenAsset = 'assets/branding/wallet_logo_green.png';
  static const String logoWhiteAsset = 'assets/branding/wallet_logo_white.png';

  /// Lockup size in Figma.
  static const double logoWidth = 90.25;
  static const double logoHeight = 26.31;
}

enum WalletLogoTone {
  /// Green on light backgrounds, white on dark ones (follows the theme).
  auto,

  /// For light backgrounds.
  green,

  /// For green/dark backgrounds (e.g. LOGIN's green hero).
  white,
}

/// The final 월릿 lockup (symbol + wordmark). Since it already spells the
/// app name, callers should not repeat "월릿" as text next to it.
class WalletLogo extends StatelessWidget {
  const WalletLogo({
    super.key,
    this.tone = WalletLogoTone.auto,
    this.height = WalletBrand.logoHeight,
  });

  final WalletLogoTone tone;
  final double height;

  @override
  Widget build(BuildContext context) {
    final white = switch (tone) {
      WalletLogoTone.green => false,
      WalletLogoTone.white => true,
      WalletLogoTone.auto => Theme.of(context).brightness == Brightness.dark,
    };
    return Image.asset(
      white ? WalletBrand.logoWhiteAsset : WalletBrand.logoGreenAsset,
      height: height,
      width: height * WalletBrand.logoWidth / WalletBrand.logoHeight,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: WalletBrand.name,
    );
  }
}
