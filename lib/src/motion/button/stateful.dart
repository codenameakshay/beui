import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../tokens/icons.dart';
import '../../tokens/motion.dart';
import 'base.dart';

/// Lifecycle state of a [BeuiStatefulButton].
enum BeuiButtonState {
  /// Resting; shows the label (and optional idle icon).
  idle,

  /// Busy; shows a spinner + loading text; input is locked.
  loading,

  /// Completed; shows a check + success text.
  success,

  /// Failed; shows an ✗ + error text.
  error,
}

/// A [BeuiButton] that morphs between idle / loading / success / error — the
/// Flutter port of beUI's `StatefulButton`.
///
/// Each state swaps a leading icon (spinner / check / ✗) and the label, and the
/// button width morphs to fit. While [BeuiButtonState.loading] the button is
/// disabled and announces busy state. Reduced motion crossfades icon and text
/// (no roll/blur).
class BeuiStatefulButton extends StatelessWidget {
  /// Creates a stateful button.
  const BeuiStatefulButton({
    required this.label,
    this.state = BeuiButtonState.idle,
    this.onPressed,
    this.loadingText = 'Loading',
    this.successText = 'Done',
    this.errorText = 'Try again',
    this.icon,
    this.variant = BeuiButtonVariant.primary,
    this.size = BeuiButtonSize.md,
    super.key,
  });

  /// The idle label.
  final String label;

  /// Current state.
  final BeuiButtonState state;

  /// Tap callback (ignored while loading).
  final VoidCallback? onPressed;

  /// Text shown while loading.
  final String loadingText;

  /// Text shown on success.
  final String successText;

  /// Text shown on error.
  final String errorText;

  /// Optional leading icon shown in the idle state.
  final IconData? icon;

  /// Visual style.
  final BeuiButtonVariant variant;

  /// Size.
  final BeuiButtonSize size;

  String get _text => switch (state) {
        BeuiButtonState.loading => loadingText,
        BeuiButtonState.success => successText,
        BeuiButtonState.error => errorText,
        BeuiButtonState.idle => label,
      };

  /// The leading status icon (spinner / check / ✗) — none while idle.
  IconData? get _leadingIcon => switch (state) {
        BeuiButtonState.loading => LucideIcons.loader_circle,
        BeuiButtonState.success => LucideIcons.check,
        BeuiButtonState.error => LucideIcons.x,
        BeuiButtonState.idle => null,
      };

  /// The trailing idle icon — only shown while idle (matching the source).
  IconData? get _trailingIcon =>
      state == BeuiButtonState.idle ? icon : null;

  Widget _iconSlot(IconData? data, {required bool leading, required bool reduce}) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      transitionBuilder: (child, animation) => _rollIn(child, animation, reduce),
      child: data == null
          ? SizedBox.shrink(key: ValueKey('none-${leading ? 'L' : 'T'}'))
          : Padding(
              key: ValueKey('${leading ? 'L' : 'T'}-$state'),
              padding: leading
                  ? const EdgeInsets.only(right: 8)
                  : const EdgeInsets.only(left: 8),
              child: leading && state == BeuiButtonState.loading
                  ? const _Spinner(size: 16)
                  : Icon(data, size: 16),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final isBusy = state == BeuiButtonState.loading;

    final textSlot = AnimatedSwitcher(
      duration: const Duration(milliseconds: 340),
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      transitionBuilder: (child, animation) => _rollIn(child, animation, reduce),
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previousChildren, ?currentChild],
      ),
      child: Text(_text, key: ValueKey(_text)),
    );

    return Semantics(
      liveRegion: true,
      child: BeuiButton(
        onPressed: isBusy ? null : onPressed,
        variant: variant,
        size: size,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: beuiEaseOut,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconSlot(_leadingIcon, leading: true, reduce: reduce),
              textSlot,
              _iconSlot(_trailingIcon, leading: false, reduce: reduce),
            ],
          ),
        ),
      ),
    );
  }
}

/// Roll-in transition: fade + rise + blur, the source's `blur(6px)` slot roll.
/// Driven by a *linear* animation (the AnimatedSwitcher curves are linear) so
/// the blur stays visible across the whole transition instead of being eased
/// away in the first frames; the fade and rise are eased internally. Reduced
/// motion collapses to a plain crossfade.
Widget _rollIn(Widget child, Animation<double> animation, bool reduce) {
  if (reduce) return FadeTransition(opacity: animation, child: child);
  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final t = animation.value; // linear progress
      final eased = beuiEaseOut.transform(t);
      final blur = (1 - t) * 8; // ~blur(6px) at the start, easing to 0
      return Opacity(
        opacity: eased,
        child: Transform.translate(
          offset: Offset(0, (1 - eased) * 14),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: blur,
              sigmaY: blur,
              tileMode: TileMode.decal,
            ),
            child: child,
          ),
        ),
      );
    },
  );
}

/// A continuously spinning loader icon.
class _Spinner extends StatefulWidget {
  const _Spinner({required this.size});
  final double size;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(LucideIcons.loader_circle, size: widget.size),
    );
  }
}
