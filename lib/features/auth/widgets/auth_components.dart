import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/auth_tokens.dart';

/// Shared scaffold for every auth screen: white page with the Figma green
/// glows, SafeArea, and a scroll view whose content fills the viewport so
/// a `Spacer` can pin bottom elements exactly like the Figma frame while
/// still scrolling when the keyboard is up or the screen is short.
class AuthPage extends StatelessWidget {
  const AuthPage({super.key, required this.children, this.greenHero = false});

  final List<Widget> children;

  /// LOGIN has the large green glow behind the logo/Welcome block.
  final bool greenHero;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(child: _AuthBackground(greenHero: greenHero)),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground({required this.greenHero});

  final bool greenHero;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (greenHero)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 560,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.4),
                  radius: 0.72,
                  colors: [
                    Color(0xF000AE76),
                    Color(0xCC20B987),
                    Color(0x8C6DD9AB),
                    Color(0x33CDFFDA),
                    Color(0x00FFFFFF),
                  ],
                  stops: [0, 0.3, 0.55, 0.8, 1],
                  transform: _HorizontalStretch(2.3),
                ),
              ),
            ),
          ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 200,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, 1.25),
                radius: 1.1,
                colors: [
                  Color(0xCCA9E1CF),
                  Color(0x66D6F3E8),
                  Color(0x00FFFFFF),
                ],
                stops: [0, 0.55, 1],
                transform: _HorizontalStretch(1.9),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HorizontalStretch extends GradientTransform {
  const _HorizontalStretch(this.factor);

  final double factor;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final cx = bounds.center.dx;
    return Matrix4(
      factor,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      cx * (1 - factor),
      0,
      0,
      1,
    );
  }
}

/// Pops back to the previous auth screen, or goes to LOGIN when there is none.
void authPopOrGoLogin(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/login');
  }
}

void showAuthMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Figma back arrow: 24px icon at x 24 / y 78 (34px below the status bar).
/// The 10px padding only widens the tap target; the icon stays in place.
/// Occupies 68px of height in total.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 14, top: 24),
        child: Semantics(
          button: true,
          label: '뒤로가기',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                AuthAssets.iconArrowLeft,
                width: 24,
                height: 24,
                color: AuthTokens.textPrimary,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma "Group 1": wallet mark (24.47px) + "월릿" wordmark, 39px tall.
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key, this.onGreen = false});

  /// White logo for LOGIN's green hero, green everywhere else.
  final bool onGreen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 83,
        height: 39,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -0.27,
              top: 5.32,
              width: 25,
              height: 25,
              child: Image.asset(
                onGreen ? AuthAssets.logoMarkWhite : AuthAssets.logoMarkGreen,
                filterQuality: FilterQuality.high,
              ),
            ),
            Positioned(
              left: 32,
              top: 0,
              width: 51,
              height: 39,
              child: Image.asset(
                AuthAssets.logoWordmarkMask,
                color: onGreen ? Colors.white : AuthTokens.accent,
                colorBlendMode: BlendMode.srcIn,
                filterQuality: FilterQuality.high,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen title (SemiBold 20, accent). Figma left offset differs per screen:
/// SIGN_UP 28px, FIND_PASSWORD 24px.
class AuthTitle extends StatelessWidget {
  const AuthTitle(this.text, {super.key, required this.left});

  final String text;
  final double left;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: left),
      child: Text(
        text,
        style: AuthTokens.text(20, FontWeight.w600, AuthTokens.accent),
      ),
    );
  }
}

/// Figma input: 346 x 60, #FCFCFC, 0.5px accent border, radius 6, 13px side
/// padding, 20px leading icon + 6px gap, Medium 16 placeholder.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.iconAsset,
    required this.hintText,
    required this.controller,
    this.obscureText = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.readOnly = false,
  });

  final String iconAsset;
  final String hintText;
  final TextEditingController controller;
  final bool obscureText;

  /// When set, shows the trailing eye toggle (eye = hidden, eye-closed =
  /// visible).
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuthTokens.horizontalPadding,
      ),
      child: Container(
        height: AuthTokens.inputHeight,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: AuthTokens.inputFill,
          borderRadius: BorderRadius.circular(AuthTokens.inputRadius),
          border: Border.all(color: AuthTokens.accent, width: 0.5),
          boxShadow: AuthTokens.inputShadow,
        ),
        child: Row(
          children: [
            Image.asset(iconAsset, width: 20, height: 20),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscureText,
                enableSuggestions: !obscureText,
                autocorrect: false,
                readOnly: readOnly,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                onSubmitted: onSubmitted,
                autofillHints: autofillHints,
                cursorColor: AuthTokens.accent,
                style: AuthTokens.text(
                  16,
                  FontWeight.w500,
                  AuthTokens.textPrimary,
                ),
                // The app-wide inputDecorationTheme (filled, outlined) must not
                // leak into the Figma field, so every border is cleared here.
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  hintText: hintText,
                  hintStyle: AuthTokens.text(
                    16,
                    FontWeight.w500,
                    AuthTokens.textMuted,
                  ),
                ),
              ),
            ),
            if (onToggleObscure != null) ...[
              const SizedBox(width: 6),
              Semantics(
                button: true,
                label: obscureText ? '비밀번호 보기' : '비밀번호 숨기기',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggleObscure,
                  child: Image.asset(
                    obscureText ? AuthAssets.iconEye : AuthAssets.iconEyeClosed,
                    width: 20,
                    height: 20,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Figma primary CTA: 346 x 54, accent, radius 16, SemiBold 20 white.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Shows a spinner and ignores taps (prevents duplicate submits).
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuthTokens.horizontalPadding,
      ),
      child: Container(
        height: AuthTokens.primaryButtonHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AuthTokens.buttonRadius),
          boxShadow: AuthTokens.buttonShadow,
        ),
        child: Material(
          color: enabled || loading ? AuthTokens.accent : AuthTokens.disabled,
          borderRadius: BorderRadius.circular(AuthTokens.buttonRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: loading ? null : onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: AuthTokens.text(20, FontWeight.w600, Colors.white),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma secondary CTA (LOGIN "회원가입"): 346 x 55, white, 0.5px #ADADAD
/// border, radius 16, Medium 20.
class AuthSecondaryButton extends StatelessWidget {
  const AuthSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuthTokens.horizontalPadding,
      ),
      child: Container(
        height: AuthTokens.secondaryButtonHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AuthTokens.buttonRadius),
          boxShadow: AuthTokens.buttonShadow,
        ),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuthTokens.buttonRadius),
            side: const BorderSide(color: AuthTokens.textMuted, width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: Text(
                label,
                style: AuthTokens.text(
                  20,
                  FontWeight.w500,
                  AuthTokens.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Checkbox in the two Figma variants: LOGIN uses the 24px iconoir
/// check-square (19.5px square), SIGN_UP a 20px square with a 3px radius.
class AuthCheckbox extends StatelessWidget {
  const AuthCheckbox({
    super.key,
    required this.checked,
    required this.boxSize,
    required this.squareSize,
    required this.radius,
    required this.borderWidth,
  });

  const AuthCheckbox.login({super.key, required this.checked})
    : boxSize = 24,
      squareSize = 19.5,
      radius = 1.35,
      borderWidth = 1.5;

  const AuthCheckbox.agreement({super.key, required this.checked})
    : boxSize = 20,
      squareSize = 20,
      radius = 3,
      borderWidth = 1;

  final bool checked;
  final double boxSize;
  final double squareSize;
  final double radius;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    // The check-square asset draws its filled square at 19.5/24 of its size.
    final assetSize = squareSize * 24 / 19.5;
    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: checked
          ? OverflowBox(
              maxWidth: assetSize,
              maxHeight: assetSize,
              child: Image.asset(
                AuthAssets.iconCheckSquare,
                width: assetSize,
                height: assetSize,
              ),
            )
          : Center(
              child: Container(
                width: squareSize,
                height: squareSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: AuthTokens.textPrimary,
                    width: borderWidth,
                  ),
                ),
              ),
            ),
    );
  }
}

/// Underlined Regular 16 text link (Figma "비밀번호 찾기", "비회원으로 이용하기").
class AuthTextLink extends StatelessWidget {
  const AuthTextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.color = AuthTokens.accentDark,
    this.weight = FontWeight.w400,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(label, style: AuthTokens.link(16, weight, color)),
    );
  }
}

/// Figma bottom row: "이미 계정이 있나요?" + 6px + underlined SemiBold link.
class AuthBottomLinkRow extends StatelessWidget {
  const AuthBottomLinkRow({
    super.key,
    required this.prompt,
    required this.linkLabel,
    required this.onTap,
  });

  final String prompt;
  final String linkLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 21,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            prompt,
            style: AuthTokens.text(16, FontWeight.w400, AuthTokens.textPrimary),
          ),
          const SizedBox(width: 6),
          AuthTextLink(label: linkLabel, onTap: onTap, weight: FontWeight.w600),
        ],
      ),
    );
  }
}

/// Figma FIND_PASSWORD status line (Bold 16, centered). Always reserves its
/// 21px slot so showing a message never shifts the layout below it.
class AuthStatusText extends StatelessWidget {
  const AuthStatusText({super.key, this.message, this.isError = false});

  final String? message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 21,
      child: message == null
          ? null
          : Text(
              message!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AuthTokens.text(
                16,
                FontWeight.w700,
                isError ? AuthTokens.negative : AuthTokens.accent,
              ),
            ),
    );
  }
}

/// Figma FIND_PASSWORD info box: 347 x 97, #EFF8F2, radius 6, light-bulb icon.
class AuthInfoBox extends StatelessWidget {
  const AuthInfoBox({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        height: 97,
        padding: const EdgeInsets.fromLTRB(19, 16, 18, 0),
        decoration: BoxDecoration(
          color: AuthTokens.infoBoxFill,
          borderRadius: BorderRadius.circular(AuthTokens.inputRadius),
          boxShadow: AuthTokens.infoBoxShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(AuthAssets.iconLightBulb, width: 20, height: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: AuthTokens.text(
                  16,
                  FontWeight.w400,
                  AuthTokens.infoBoxText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
