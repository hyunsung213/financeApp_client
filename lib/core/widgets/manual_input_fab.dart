import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which side of the screen the shared "수기 입력" FAB currently docks to.
/// Home and Calendar both watch [manualInputFabSideProvider] so a long-press
/// toggle on either screen is reflected on the other - the button is one
/// shared piece of UI state, not a per-screen preference.
enum ManualInputFabSide { left, right }

const _prefsKeyManualInputFabSide = 'manual_input_fab_side';

class ManualInputFabSideNotifier extends Notifier<ManualInputFabSide> {
  @override
  ManualInputFabSide build() {
    _restore();
    return ManualInputFabSide.right;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_prefsKeyManualInputFabSide) ==
        ManualInputFabSide.left.name) {
      state = ManualInputFabSide.left;
    }
  }

  Future<void> toggle() async {
    state = state == ManualInputFabSide.right
        ? ManualInputFabSide.left
        : ManualInputFabSide.right;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyManualInputFabSide, state.name);
  }
}

final manualInputFabSideProvider =
    NotifierProvider<ManualInputFabSideNotifier, ManualInputFabSide>(
      ManualInputFabSideNotifier.new,
    );

/// Long enough to be unmistakably distinct from a normal tap, short enough
/// not to feel unresponsive.
const _longPressDuration = Duration(milliseconds: 700);

/// The app-wide "수기 입력" (manual entry) floating action button. Originally
/// only Calendar's FAB looked like this (Home had its own green rounded-square
/// "+" button); this is now the single shared visual source of truth so Home
/// and Calendar render the exact same circle/gradient/icon/shadow instead of
/// two hand-maintained copies drifting apart.
///
/// Short tap -> [onPressed]. Long press (700ms) -> toggles which side of the
/// screen the button docks to instead, via [manualInputFabSideProvider]; it
/// does not also fire [onPressed]. A plain [GestureDetector.onLongPress] runs
/// on a fixed, non-configurable ~500ms deadline, so this uses a
/// [RawGestureDetector] with an explicit [LongPressGestureRecognizer.duration]
/// instead. The two gestures are mutually exclusive "for free": the
/// long-press recognizer only wins the gesture arena (and fires) once the
/// finger has stayed down past its deadline, and doing so defeats the child
/// [IconButton]'s own tap recognizer, so a short tap always reaches
/// [onPressed] and a long press never does.
class ManualInputFab extends ConsumerWidget {
  final VoidCallback onPressed;

  const ManualInputFab({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RawGestureDetector(
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(duration: _longPressDuration),
              (recognizer) {
                recognizer.onLongPress = () {
                  HapticFeedback.lightImpact();
                  ref.read(manualInputFabSideProvider.notifier).toggle();
                };
              },
            ),
      },
      child: Semantics(
        button: true,
        label: '수기 입력',
        hint: '탭하여 거래 입력, 길게 눌러 버튼 위치 변경',
        child: ExcludeSemantics(
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF00AF76), Color(0xFFBFEBDD)],
              ),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33606960),
                  blurRadius: 5,
                  offset: Offset(0, 5),
                ),
              ],
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

/// Positions a [ManualInputFab] at the bottom-left or bottom-right of
/// whichever [Stack] it's placed in (above the bottom navigation, via
/// [bottomPadding]), sliding smoothly between the two when
/// [manualInputFabSideProvider] changes. Meant to be used as a `Stack` child
/// alongside the screen's main content, replacing `Scaffold.floatingActionButton`
/// - that slot only supports Material's built-in scale/fade location
/// transitions, not the horizontal slide this cross-screen toggle needs.
class ManualInputFabOverlay extends ConsumerWidget {
  final VoidCallback onPressed;
  final double bottomPadding;

  const ManualInputFabOverlay({
    super.key,
    required this.onPressed,
    this.bottomPadding = 72,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final side = ref.watch(manualInputFabSideProvider);
    final isLeft = side == ManualInputFabSide.left;
    return Positioned.fill(
      child: SafeArea(
        top: false,
        bottom: false,
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: isLeft ? Alignment.bottomLeft : Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.only(
              left: isLeft ? 16 : 0,
              right: isLeft ? 0 : 16,
              bottom: bottomPadding,
            ),
            child: ManualInputFab(onPressed: onPressed),
          ),
        ),
      ),
    );
  }
}
