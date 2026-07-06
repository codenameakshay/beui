import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../tokens/motion.dart';

/// A per-letter slot roll for standalone text — the Flutter port of beUI's
/// `text-cascade`.
///
/// Changing [text] cascades the letters to the new value: the old letters roll
/// up and out (blurring) as the new ones roll up from below into place, staggered
/// left-to-right and clipped to one line. This is the same mechanic the source's
/// `ActionSwapText` drives with `animation="cascade"` (`CASCADE_LETTER_VARIANTS`)
/// — a text-first API over it, mirroring the source `TextCascade` wrapper.
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
  // Source CASCADE_STAGGER 0.025s; enter rides SPRING_SWAP, exit is 0.16s
  // EASE_OUT at half the enter stagger; ROLL_BLUR is blur(6px) ≈ sigma 3.5.
  static const int _staggerMs = 25;
  static const int _enterMs = 360; // SPRING_SWAP settle window
  static const int _exitMs = 160; // source exit duration (0.16s)
  static const double _blur = 3.5;

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
    final double dy;
    final double opacity;
    final double blur;
    if (exiting) {
      // Exit cascades at half the enter stagger (source `delay * 0.5`).
      final start = (i * _staggerMs * 0.5) / totalMs;
      final p = ((t - start) / (_exitMs / totalMs)).clamp(0.0, 1.0);
      final e = beuiEaseOut.transform(p);
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
