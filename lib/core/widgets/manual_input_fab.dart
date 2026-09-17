import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_gradients.dart';
import '../theme/app_shadows.dart';

/// Where the shared "수기 입력" FAB currently sits, as its top-left offset in
/// the enclosing [Stack]'s local coordinate space. `null` means "no drag yet
/// this session" - the overlay falls back to its default bottom-right spot.
/// Home and Calendar both watch this provider so dragging the FAB on either
/// screen is reflected on the other - the button is one shared piece of UI
/// state, not a per-screen preference. Deliberately in-memory only (not
/// persisted to disk): the position should survive switching bottom-nav tabs
/// within a session, but does not need to survive an app restart.
class ManualInputFabOffsetNotifier extends Notifier<Offset?> {
  @override
  Offset? build() => null;

  void set(Offset offset) => state = offset;
}

final manualInputFabOffsetProvider =
    NotifierProvider<ManualInputFabOffsetNotifier, Offset?>(
      ManualInputFabOffsetNotifier.new,
    );

/// Total footprint the floating bottom navigation pill reserves at the
/// bottom of the screen, *not* counting the device's bottom safe-area inset
/// (that's added separately via `MediaQuery.paddingOf(context).bottom`
/// wherever this constant is used). Derived from the pill's Figma spec
/// (`docs/figma/report-spec.md` C.8: `347 × 66`) plus the `14`px gap below
/// it that `ScaffoldWithNavBar._buildNavBar` in `lib/core/router.dart` pads
/// with (`EdgeInsets.fromLTRB(28, 0, 28, 14)`). Kept as a single named
/// constant here - rather than re-deriving/hardcoding it again - so the
/// draggable FAB never lands on top of or inside the nav bar.
const double kBottomNavBarHeight = 66 + 14;

/// The app-wide "수기 입력" (manual entry) floating action button. Originally
/// only Calendar's FAB looked like this (Home had its own green rounded-square
/// "+" button); this is now the single shared visual source of truth so Home
/// and Calendar render the exact same circle/gradient/icon/shadow instead of
/// two hand-maintained copies drifting apart.
///
/// Short tap -> [onPressed]. Press-and-drag -> [onPanStart]/[onPanUpdate]/
/// [onPanEnd], which [ManualInputFabOverlay] uses to move the button. A
/// plain [GestureDetector] carrying both a tap and a pan recognizer resolves
/// the two via Flutter's normal gesture arena: the pan recognizer only wins
/// once the pointer has actually moved past the touch slop, so a stationary
/// press (however long) and a quick tap both still reach [onPressed], and a
/// press that moves goes to the pan callbacks instead - long-press-without-
/// moving does not change position, and a drag does not also open the input
/// screen.
class ManualInputFab extends StatelessWidget {
  /// Diameter of the circular button. Exposed so [ManualInputFabOverlay] can
  /// size its draggable bounds off the same number instead of a second copy.
  static const double diameter = 48;

  final VoidCallback onPressed;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  const ManualInputFab({
    super.key,
    required this.onPressed,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
      child: Semantics(
        button: true,
        label: '수기 입력',
        hint: '탭하여 거래 입력, 눌러서 드래그하면 위치 이동',
        child: ExcludeSemantics(
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.fab,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: AppShadows.fab,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: Colors.white,
                size: 22,
              ),
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
  }
}

/// Positions a [ManualInputFab] inside whichever [Stack] it's placed in and
/// lets the user drag it anywhere within bounds that keep it clear of the
/// status bar and the floating bottom navigation pill. Meant to be used as a
/// `Stack` child alongside the screen's main content, replacing
/// `Scaffold.floatingActionButton` - that slot doesn't support free-form
/// dragging at all.
///
/// Position state: the *committed* (drag-released) offset lives in
/// [manualInputFabOffsetProvider], shared app-wide so it survives switching
/// bottom-nav tabs. The offset *while actively dragging* lives in this
/// widget's own [State] so only the instance the user is actually touching
/// re-renders every pointer-move frame, instead of every offstage branch
/// that also watches the shared provider.
class ManualInputFabOverlay extends ConsumerStatefulWidget {
  final VoidCallback onPressed;

  const ManualInputFabOverlay({super.key, required this.onPressed});

  @override
  ConsumerState<ManualInputFabOverlay> createState() =>
      _ManualInputFabOverlayState();
}

class _ManualInputFabOverlayState extends ConsumerState<ManualInputFabOverlay> {
  /// Live position while a drag is in progress; `null` when not dragging.
  Offset? _liveOffset;

  /// Margins/gaps around the draggable area. See docs/figma comment on
  /// [kBottomNavBarHeight] for where the bottom nav number comes from.
  static const double _edgeMargin = 16;
  static const double _topMargin = 16;
  static const double _bottomGap = 20;

  Rect _draggableBounds(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final viewPadding = MediaQuery.paddingOf(context);

    final minX = _edgeMargin;
    final maxX = size.width - ManualInputFab.diameter - _edgeMargin;
    final minY = viewPadding.top + _topMargin;
    final maxY =
        size.height -
        viewPadding.bottom -
        kBottomNavBarHeight -
        ManualInputFab.diameter -
        _bottomGap;

    // Guard tiny/unusual viewports where the reserved margins would
    // otherwise invert the range and make Offset.clamp throw.
    return Rect.fromLTRB(
      minX,
      minY,
      maxX < minX ? minX : maxX,
      maxY < minY ? minY : maxY,
    );
  }

  Offset _clampToBounds(Offset offset, Rect bounds) {
    return Offset(
      offset.dx.clamp(bounds.left, bounds.right),
      offset.dy.clamp(bounds.top, bounds.bottom),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _draggableBounds(context);
    final committed = ref.watch(manualInputFabOffsetProvider);
    final defaultOffset = Offset(bounds.right, bounds.bottom);
    final base = _clampToBounds(committed ?? defaultOffset, bounds);
    final current = _liveOffset ?? base;

    return Positioned(
      left: current.dx,
      top: current.dy,
      child: ManualInputFab(
        onPressed: widget.onPressed,
        onPanStart: (_) => setState(() => _liveOffset = current),
        onPanUpdate: (details) {
          setState(() {
            _liveOffset = _clampToBounds(
              (_liveOffset ?? current) + details.delta,
              bounds,
            );
          });
        },
        onPanEnd: (_) {
          final released = _liveOffset;
          setState(() => _liveOffset = null);
          if (released != null) {
            ref.read(manualInputFabOffsetProvider.notifier).set(released);
          }
        },
      ),
    );
  }
}
