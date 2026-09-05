/// Per-letter slot cascade shared by the action-swap `cascade` variant and
/// `StatefulButton`'s label roll (source `CASCADE_LETTER_VARIANTS`).
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../tokens/motion.dart';
import '_engine.dart';

/// Cascades [text] letter-by-letter on change: the old letters roll up and
/// out (blurring) while the new letters roll up from below into place,
/// staggered left-to-right and clipped to one line.
///
/// The enter rides the [beuiSpringSwap] token (source `SPRING_SWAP`),
/// released staggered left-to-right; the exit is a ~160ms [beuiEaseOut]
/// tween at half the stagger (source `delay * 0.5`). Reduced motion drops to
/// plain crisp text.
class BeuiCascadeText extends StatefulWidget {
  /// Creates a cascade text.
  const BeuiCascadeText(this.text, {this.style, super.key});

  /// The text to show.
  final String text;

  /// Text style; null uses the ambient [DefaultTextStyle].
  final TextStyle? style;

  @override
  State<BeuiCascadeText> createState() => _BeuiCascadeTextState();
}

class _BeuiCascadeTextState extends State<BeuiCascadeText>
    with SingleTickerProviderStateMixin {
  static const int _staggerMs = 25; // source CASCADE_STAGGER 0.025s
  static const int _enterMs = 360; // covers the SPRING_SWAP settle
  static const int _exitMs = 160; // source exit 0.16s
  static const double _blur = 3; // source ROLL_BLUR blur(6px) → sigma 3

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
  void didUpdateWidget(BeuiCascadeText old) {
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
    final style = widget.style ?? DefaultTextStyle.of(context).style;
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
    if (exiting) {
      // Exit: 160ms EASE_OUT tween at half the enter stagger (source
      // `delay * 0.5`) — rolls up and out, fading and blurring.
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

    // Enter: the SPRING_SWAP token (source CASCADE_LETTER_VARIANTS), released
    // once the shared clock crosses the letter's `index × 25ms` stagger —
    // opacity and blur ride the spring's own progress.
    final released = t * totalMs >= i * _staggerMs;
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
