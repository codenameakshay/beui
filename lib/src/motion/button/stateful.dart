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
  IconData? get _trailingIcon => state == BeuiButtonState.idle ? icon : null;

  Widget _iconSlot(
    IconData? data, {
    required bool leading,
    required bool reduce,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      transitionBuilder: (child, animation) =>
          _rollIn(child, animation, reduce),
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

    final textSlot = _CascadeText(_text);

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
      final blur = (1 - t) * 4; // gentle blur on the small icon glyphs
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

/// Per-letter slot cascade with blur — the Flutter port of the source's
/// StatefulButton text roll (`CASCADE_LETTER_VARIANTS`). On a text change the
/// old letters roll up and out (blurring) while the new letters roll up from
/// below into place, staggered left-to-right and clipped to one line.
///
/// Replaces a naive whole-text crossfade, which overlapped both strings and
/// produced a muddy double-image.
class _CascadeText extends StatefulWidget {
  const _CascadeText(this.text);

  final String text;

  @override
  State<_CascadeText> createState() => _CascadeTextState();
}

class _CascadeTextState extends State<_CascadeText>
    with SingleTickerProviderStateMixin {
  static const int _staggerMs = 30; // source CASCADE_STAGGER (0.025s), eased up
  static const int _enterMs = 360; // per-letter spring-in window
  static const int _exitMs = 160; // source exit duration
  static const double _blur = 3.5; // source ROLL_BLUR blur(6px) ≈ sigma 3.5

  late final AnimationController _controller;
  late String _current = widget.text;
  String? _previous;

  int _durationMs(String t) =>
      _enterMs + _staggerMs * (t.length - 1).clamp(0, 80);

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: Duration(milliseconds: _durationMs(_current)),
          value: 1,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && _previous != null) {
            setState(() => _previous = null);
          }
        });
  }

  @override
  void didUpdateWidget(_CascadeText old) {
    super.didUpdateWidget(old);
    if (widget.text != _current) {
      _previous = _current;
      _current = widget.text;
      _controller
        ..duration = Duration(milliseconds: _durationMs(_current))
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    final reduce = MediaQuery.disableAnimationsOf(context);

    // At rest (or reduced motion): plain crisp text, no per-letter overhead.
    if (reduce || _previous == null) {
      return Text(_current, style: style, maxLines: 1, softWrap: false);
    }

    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final totalMs = _controller.duration!.inMilliseconds;
          final roll = (style.fontSize ?? 14) * 1.15; // ~105% of a line
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              // Exiting text — positioned, so it doesn't drive the slot width.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: _letters(
                  _previous!,
                  t,
                  totalMs,
                  roll,
                  style,
                  exiting: true,
                ),
              ),
              // Entering text — sizes the slot to the new label immediately.
              _letters(_current, t, totalMs, roll, style, exiting: false),
            ],
          );
        },
      ),
    );
  }

  Widget _letters(
    String text,
    double t,
    int totalMs,
    double roll,
    TextStyle style, {
    required bool exiting,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < text.length; i++)
          _letter(text[i], i, t, totalMs, roll, style, exiting: exiting),
      ],
    );
  }

  Widget _letter(
    String char,
    int i,
    double t,
    int totalMs,
    double roll,
    TextStyle style, {
    required bool exiting,
  }) {
    final double dy;
    final double opacity;
    final double blur;
    if (exiting) {
      final start = (i * _staggerMs * 0.5) / totalMs;
      final p = ((t - start) / (_exitMs / totalMs)).clamp(0.0, 1.0);
      final e = Curves.easeOut.transform(p);
      dy = -e * roll; // roll up and out
      opacity = 1 - e;
      blur = e * _blur;
    } else {
      final start = (i * _staggerMs) / totalMs;
      final p = ((t - start) / (_enterMs / totalMs)).clamp(0.0, 1.0);
      final e = Curves.easeOutCubic.transform(p);
      dy = (1 - e) * roll; // roll up from below
      opacity = e;
      blur = (1 - e) * _blur;
    }

    Widget glyph = Text(char, style: style, maxLines: 1, softWrap: false);
    if (blur > 0.05) {
      glyph = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
          tileMode: TileMode.decal,
        ),
        child: glyph,
      );
    }
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(offset: Offset(0, dy), child: glyph),
    );
  }
}

/// A continuously spinning loader icon.
class _Spinner extends StatefulWidget {
  const _Spinner({required this.size});
  final double size;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
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
