import 'package:flutter/material.dart';

/// Visual tokens for the auth flow, sourced from Figma section
/// FINAL_LOGIN_SCREENS (709:2298): LOGIN 683:1506, SIGN_UP 699:3240,
/// FIND_PASSWORD 701:3359.
///
/// Sizes, radii and shadows are the Figma values. Colors follow the app's
/// confirmed palette (Figma's #005D33 link green maps to [accentDark]).
class AuthTokens {
  AuthTokens._();

  static const Color accent = Color(0xFF00AE76);
  static const Color accentDark = Color(0xFF007C4F);
  static const Color textPrimary = Color(0xFF2F2F2F);
  static const Color textMuted = Color(0xFFADADAD);
  static const Color disabled = Color(0xFFA0AFA4);
  static const Color softGreen = Color(0xFFD6F3E8);
  static const Color softGreenBorder = Color(0xFFA9E1CF);
  static const Color negative = Color(0xFFEF6C4C);

  static const Color inputFill = Color(0xFFFCFCFC);
  static const Color socialBorder = Color(0xFFBDBDBD);
  static const Color infoBoxFill = Color(0xFFEFF8F2);
  static const Color infoBoxText = Color(0xFF8F8E8E);

  static const double horizontalPadding = 15;
  static const double inputHeight = 60;
  static const double inputGap = 6;
  static const double inputRadius = 6;
  static const double primaryButtonHeight = 54;
  static const double secondaryButtonHeight = 55;
  static const double buttonRadius = 16;

  /// Figma button drop shadow: rgba(96,105,96) at 0.19 / 0.12 / 0.09 / 0.07.
  static const List<BoxShadow> buttonShadow = [
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

  static const List<BoxShadow> inputShadow = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 1, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> infoBoxShadow = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// Figma text: line-height 1.3, letter-spacing -0.45.
  static TextStyle text(double size, FontWeight weight, Color color) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.3,
      letterSpacing: -0.45,
    );
  }

  static TextStyle link(double size, FontWeight weight, Color color) {
    return text(
      size,
      weight,
      color,
    ).copyWith(decoration: TextDecoration.underline, decorationColor: color);
  }
}

/// Asset paths for the auth flow (rendered from the Figma SVG/PNG exports).
class AuthAssets {
  AuthAssets._();

  static const String _dir = 'assets/auth';
  static const String iconMail = '$_dir/icon_mail.png';
  static const String iconLock = '$_dir/icon_lock.png';
  static const String iconEye = '$_dir/icon_eye.png';
  static const String iconEyeClosed = '$_dir/icon_eye_closed.png';
  static const String iconProfile = '$_dir/icon_profile.png';
  static const String iconLightBulb = '$_dir/icon_light_bulb.png';
  static const String iconCheckSquare = '$_dir/icon_check_square.png';
  static const String iconArrowLeft = '$_dir/icon_arrow_left.png';
  static const String logoMarkWhite = '$_dir/logo_mark_white.png';
  static const String logoMarkGreen = '$_dir/logo_mark_green.png';
  static const String logoWordmarkMask = '$_dir/logo_wordmark_mask.png';
  static const String socialKakao = '$_dir/social_kakao.png';
  static const String socialGoogle = '$_dir/social_google.png';
  static const String socialApple = '$_dir/social_apple.png';
}
