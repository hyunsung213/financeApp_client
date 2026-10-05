import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/wallet_glass.dart';
import 'glass.dart';

/// The overlay currently on screen, so a second save replaces it instead of
/// stacking another one on top.
_SuccessOverlayHandle? _current;

/// Shows a compact "✓ [message]" toast a little above the screen center,
/// then fades it out on its own. Unlike a SnackBar it never sits behind the
/// bottom navigation, system navigation bar or keyboard.
///
/// Only call this once the save has actually succeeded.
void showSuccessOverlay(
  BuildContext context,
  String message, {
  Duration visibleFor = const Duration(milliseconds: 1000),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _current?.remove();
  final handle = _SuccessOverlayHandle();
  handle.entry = OverlayEntry(
    builder: (_) => _SuccessOverlay(
      message: message,
      visibleFor: visibleFor,
      onDismissed: handle.remove,
    ),
  );
  _current = handle;
  overlay.insert(handle.entry);
}

class _SuccessOverlayHandle {
  late final OverlayEntry entry;
  bool _removed = false;

  void remove() {
    if (_removed) return;
    _removed = true;
    entry.remove();
    if (identical(_current, this)) _current = null;
  }
}

class _SuccessOverlay extends StatefulWidget {
  const _SuccessOverlay({
    required this.message,
    required this.visibleFor,
    required this.onDismissed,
  });

  final String message;
  final Duration visibleFor;
  final VoidCallback onDismissed;

  @override
  State<_SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<_SuccessOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _controller.forward().then((_) {
      if (!mounted) return;
      _holdTimer = Timer(widget.visibleFor, () {
        if (!mounted) return;
        _controller.reverse().then((_) {
          if (mounted) widget.onDismissed();
        });
      });
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Center within the area the keyboard leaves visible.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Align(
          alignment: const Alignment(0, -0.15),
          child: FadeTransition(
            opacity: _curve,
            child: ScaleTransition(
              scale: Tween(begin: 0.95, end: 1.0).animate(_curve),
              child: Semantics(
                liveRegion: true,
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    // Level 3 floating toast, opaque enough to read over
                    // whatever screen it lands on.
                    decoration: glassDecoration(
                      context,
                      level: GlassLevel.floating,
                      radius: AppRadii.md,
                    ).copyWith(color: context.glass.surfaceFill),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 22,
                          color: context.glass.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.message,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.glass.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
