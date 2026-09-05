import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../tokens/motion.dart';
import '_engine.dart';

/// A per-letter slot roll for standalone text — the Flutter port of beUI's
/// `text-cascade`.
///
/// Changing [text] cascades the letters to the new value: the old letters roll
/// up and out (blurring) as the new ones roll up from below into place, staggered
/// left-to-right and clipped to one line. This is the same mechanic the source's
/// `ActionSwapText` drives with `animation="cascade"` (`CASCADE_LETTER_VARIANTS`)
/// — a text-first API over it, mirroring the source `TextCascade` wrapper.
///
/// Each entering letter rides the shared [beuiSpringSwap] token (stiffness 460 ·
/// damping 30 · mass 0.55), released at its `index × 25ms` stagger; the exit is
/// a 160ms [beuiEaseOut] tween at half that stagger. The slot's width eases to
/// the new label's width over 220ms [beuiEaseOut] (the source's inherited
/// `transition: width 220ms EASE_OUT`).
///
/// Reduced motion shows the text plainly with no per-letter roll or blur.
class BeuiTextCascade extends StatefulWidget {
  /// Creates a text cascade. Changing [text] triggers the roll.
  const BeuiTextCascade(this.text, {this.style, super.key});

  /// The current text. Changing it cascades to the new value.
  final String text;

  /// Text style. Falls back to the ambient [DefaultTextStyle].
  final TextStyle? style;

  @override
  State<BeuiTextCascade> createState() => _BeuiTextCascadeState();
}

class _BeuiTextCascadeState extends State<BeuiTextCascade>
    with SingleTickerProviderStateMixin {
  // Source CASCADE_STAGGER 0.025s; enter rides SPRING_SWAP (released per
  // letter), exit is 0.16s EASE_OUT at half the enter stagger; ROLL_BLUR is
  // blur(3px) → sigma 1.5; the slot width morphs over 220ms EASE_OUT.
  static const int _staggerMs = 25;
  static const int _enterMs = 360; // covers the SPRING_SWAP settle
  static const int _exitMs = 160; // source exit duration (0.16s)
  static const double _blur =
      1.5; // source ROLL_BLUR blur(3px) → sigma 3/2 = 1.5
  static const _widthDuration = Duration(milliseconds: 220);

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
  void didUpdateWidget(BeuiTextCascade old) {
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

  /// Measures [text] laid out on one line with [style] — used to drive the
  /// slot's width morph.
  Size _measure(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final size = painter.size;
    painter.dispose();
    return size;
  }

  /// The style [Text] will actually paint with — [BeuiTextCascade.style] merged
  /// over the ambient [DefaultTextStyle], exactly as [Text] resolves it.
  ///
  /// Resolving it here rather than using the raw prop is load-bearing: the
  /// rolling slot is sized from [_measure]'s [TextPainter], while the resting
  /// state is a plain [Text]. A caller that passes a partial style (say just a
  /// size and weight — the common case) inherits the ambient `height`, so
  /// measuring the raw style produced a slot several px shorter than the settled
  /// text and the whole line jumped every time the cascade rolled.
  TextStyle _effectiveStyle(BuildContext context) {
    final ambient = DefaultTextStyle.of(context).style;
    final style = widget.style;
    if (style == null) return ambient;
    return style.inherit ? ambient.merge(style) : style;
  }

  @override
  Widget build(BuildContext context) {
    final style = _effectiveStyle(context);
    final reduce = MediaQuery.disableAnimationsOf(context);

    // At rest (or reduced motion): plain crisp text, no per-letter overhead.
    if (reduce || _previous == null) {
      return Text(_current, style: style, maxLines: 1, softWrap: false);
    }

    final previous = _previous!;
    final fromSize = _measure(previous, style);
    final toSize = _measure(_current, style);
    final height = toSize.height > fromSize.height
        ? toSize.height
        : fromSize.height;

    return ClipRect(
      // The slot width eases old → new over 220ms EASE_OUT instead of snapping
      // (the source's inherited `transition: width 220ms EASE_OUT`).
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: fromSize.width, end: toSize.width),
        duration: _widthDuration,
        curve: beuiEaseOut,
        builder: (context, width, child) =>
            SizedBox(width: width, height: height, child: child),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final totalMs = _controller.duration!.inMilliseconds;
            final roll = (style.fontSize ?? 14) * 1.15; // ~105% of a line
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Exiting letters — the width morph, not this row, drives the
                // slot size; both rows overflow freely and clip at the edge.
                Positioned(
                  key: ValueKey('out-$_previous'),
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < previous.length; i++)
                        _exitLetter(previous[i], i, t, totalMs, roll, style),
                    ],
                  ),
                ),
                Positioned(
                  key: ValueKey('in-$_current'),
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < _current.length; i++)
                        _enterLetter(_current[i], i, t * totalMs, roll, style),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Exit: 160ms [beuiEaseOut] tween, staggered at half the enter stagger
  /// (source `delay * 0.5`) — rolls up and out, fading and blurring.
  Widget _exitLetter(
    String char,
    int i,
    double t,
    int totalMs,
    double roll,
    TextStyle style,
  ) {
    final start = (i * _staggerMs * 0.5) / totalMs;
    final p = ((t - start) / (_exitMs / totalMs)).clamp(0.0, 1.0);
    final e = beuiEaseOut.transform(p);
    return _glyph(
      char,
      style,
      dy: -e * roll, // roll up and out
      opacity: 1 - e,
      blur: e * _blur,
    );
  }

  /// Enter: the [beuiSpringSwap] token, released once the shared clock crosses
  /// the letter's `index × 25ms` stagger — opacity and blur ride the spring's
  /// own progress.
  Widget _enterLetter(
    String char,
    int i,
    double elapsedMs,
    double roll,
    TextStyle style,
  ) {
    final released = elapsedMs >= i * _staggerMs;
    return SingleMotionBuilder(
      value: released ? 0.0 : roll,
      from: roll,
      motion: beuiSpringSwap,
      builder: (context, dy, child) {
        final p = (1 - dy / roll).clamp(0.0, 1.0);
        Widget glyph = child!;
        final sigma = (1 - p) * _blur;
        if (sigma > 0.05) {
          glyph = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: sigma,
              sigmaY: sigma,
              tileMode: TileMode.decal,
            ),
            child: glyph,
          );
        }
        return Opacity(
          opacity: p,
          child: Transform.translate(offset: Offset(0, dy), child: glyph),
        );
      },
      child: Text(char, style: style, maxLines: 1, softWrap: false),
    );
  }

  Widget _glyph(
    String char,
    TextStyle style, {
    required double dy,
    required double opacity,
    required double blur,
  }) {
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
