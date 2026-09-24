import 'package:flutter/material.dart';

import '../theme/app_gradients.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Title row every tab opens with (Home/Calendar/Report): white title,
/// optional white subtitle, trailing white icon actions.
class TabHeaderTitleRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const TabHeaderTitleRow({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.headerTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: AppTextStyles.headerSubtitle),
              ],
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// White icon button for [TabHeaderTitleRow.actions].
class TabHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const TabHeaderIconButton({super.key, required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 26),
      onPressed: onPressed,
    );
  }
}

/// Full-bleed green header band with rounded bottom corners, used by the
/// Calendar and Report tabs. Home keeps its own taller panel that fades into
/// the page, but uses the same colors and [TabHeaderTitleRow].
class TabHeaderBand extends StatelessWidget {
  final Widget child;

  const TabHeaderBand({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppGradients.tabHeader,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppSpacing.headerBandRadius),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            12,
            AppSpacing.gutter,
            AppSpacing.gutter,
          ),
          child: child,
        ),
      ),
    );
  }
}
