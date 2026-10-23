import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '_scramble.dart';

/// Default glyph set sampled while unresolved positions scramble.
///
/// Source `DEFAULT_GLYPHS` — omits I/O so random draws stay unambiguous.
const beuiTextScrambleGlyphs = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789#%&@\$?/';

/// A controlled character scramble that resolves to [text] — the Flutter port
/// of beUI's `text-scramble`.
///
/// Changing [text] after the first frame samples [glyphs] into unresolved
/// positions (~every 40ms) until the new string settles left to right. The
/// first mount shows [text] immediately (no scramble). Reduced motion (and an
/// empty [glyphs] string) skip the scramble and show the final text.
///
/// Screen readers always hear [text], never the in-flight glyphs.
class BeuiTextScramble extends StatefulWidget {
  /// Creates a scramble that resolves to [text].
  const BeuiTextScramble(
    this.text, {
    this.duration,
    this.glyphs = beuiTextScrambleGlyphs,
    this.style,
    this.textAlign,
    super.key,
  });

  /// Final text revealed by the scramble.
  final String text;

  /// Maximum animation duration. When null, the source formula
  /// `min(760, max(420, length × 32))` milliseconds is used.
  final Duration? duration;

  /// Characters sampled while unresolved positions scramble.
  final String glyphs;

  /// Text style. Falls back to the ambient [DefaultTextStyle].
  final TextStyle? style;

  /// Horizontal alignment of the visible glyphs.
  final TextAlign? textAlign;

  @override
  State<BeuiTextScramble> createState() => _BeuiTextScrambleState();
}

class _BeuiTextScrambleState extends State<BeuiTextScramble>
    with SingleTickerProviderStateMixin {
  static const _tick = Duration(milliseconds: 40);

  late String _display = widget.text;
  bool _mountedOnce = false;
  Ticker? _ticker;
  Duration _lastUpdate = Duration.zero;
  Duration _window = Duration.zero;
  final _random = math.Random();

  Duration get _animationDuration =>
      widget.duration ??
      Duration(
        milliseconds: math.min(760, math.max(420, widget.text.length * 32)),
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_mountedOnce) {
      _mountedOnce = true;
      _display = widget.text;
    }
  }

  @override
  void didUpdateWidget(BeuiTextScramble old) {
    super.didUpdateWidget(old);
    if (old.text == widget.text &&
        old.duration == widget.duration &&
        old.glyphs == widget.glyphs) {
      return;
    }
    _run();
  }

  void _run() {
    _ticker?.dispose();
    _ticker = null;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce ||
        widget.glyphs.isEmpty ||
        _animationDuration <= Duration.zero) {
      setState(() => _display = widget.text);
      return;
    }
    _window = _animationDuration;
    _lastUpdate = Duration.zero;
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (elapsed - _lastUpdate < _tick && elapsed < _window) return;
    _lastUpdate = elapsed;
    final progress = (elapsed.inMicroseconds / _window.inMicroseconds).clamp(
      0.0,
      1.0,
    );
    final settled = (progress * widget.text.length).floor();
    final next = beuiScramble(widget.text, settled, _random, widget.glyphs);
    if (elapsed >= _window) {
      _ticker?.dispose();
      _ticker = null;
      setState(() => _display = widget.text);
      return;
    }
    if (next != _display) setState(() => _display = next);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final shown = reduce ? widget.text : _display;
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    return Semantics(
      label: widget.text,
      excludeSemantics: true,
      child: Text(
        shown,
        style: style,
        textAlign: widget.textAlign,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}
