import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../tokens/motion.dart';
import '_engine.dart';

/// A slot-machine number — the Flutter port of beUI's `number-ticker`.
///
/// Each digit is its own column holding the glyphs 0–9 stacked vertically and
/// clipped to one digit's height; the column rolls vertically to the target
/// digit like an odometer. The clip/slot mechanic mirrors
/// `lib/src/motion/text_cascade.dart`.
///
/// The roll rides an [EASE_OUT][beuiEaseOut] curve over [duration] (source
/// default `0.9s`), driven through `motor` — matching the source's
/// `transition: { duration, ease: EASE_OUT }` exactly, not a spring overshoot
/// (an odometer must never bounce past its number). On the entrance the digits
/// roll in staggered left-to-right by [stagger]; once that reveal has played,
/// live value changes roll every digit immediately (a per-digit delay on live
/// updates reads as lag — the source's `entered` gate).
///
/// With [blur] true a short blur rides each roll (the source's
/// `blur(10px) → blur(0px)`), capped at 10px per the library's blur budget.
///
/// Reduced motion snaps every digit straight to its target with no roll or
/// blur.
class BeuiNumberTicker extends StatefulWidget {
  /// Creates a number ticker. Changing [value] rolls the affected digits.
  const BeuiNumberTicker({
    required this.value,
    this.pad,
    this.duration = const Duration(milliseconds: 900),
    this.stagger = const Duration(milliseconds: 40),
    this.prefix,
    this.suffix,
    this.blur = false,
    this.locale = false,
    this.format,
    this.style,
    super.key,
  });

  /// The current value. Rounded to the nearest integer before display.
  final num value;

  /// Left-pad the formatted digits to this width with leading zeros.
  final int? pad;

  /// Per-digit roll duration (source `duration`, default `0.9s`).
  final Duration duration;

  /// Entrance stagger between digits (source `stagger`, default `0.04s`).
  final Duration stagger;

  /// Optional leading text (e.g. a currency symbol). Not animated.
  final String? prefix;

  /// Optional trailing text. Not animated.
  final String? suffix;

  /// Add a small blur during digit rolls (source `blur`).
  final bool blur;

  /// Insert locale group separators (thousands commas).
  final bool locale;

  /// Custom formatter. Takes precedence over [locale]. Receives the rounded int.
  final String Function(int value)? format;

  /// Text style. Falls back to the ambient [DefaultTextStyle].
  final TextStyle? style;

  @override
  State<BeuiNumberTicker> createState() => _BeuiNumberTickerState();
}

class _BeuiNumberTickerState extends State<BeuiNumberTicker> {
  // Whether the staggered entrance reveal has already played. After it has,
  // live value changes roll every digit with no per-digit delay (source).
  bool _entered = false;
  Timer? _enterTimer;

  @override
  void initState() {
    super.initState();
    // The stagger is a one-shot entrance flourish; arm a single timer to drop
    // the per-digit delay once the reveal window has passed. Scheduling it here
    // (not in build) keeps it cancellable and timer-leak free.
    final text = _format();
    final total = widget.duration + widget.stagger * (text.length - 1);
    _enterTimer = Timer(total, () {
      if (mounted) setState(() => _entered = true);
    });
  }

  @override
  void dispose() {
    _enterTimer?.cancel();
    super.dispose();
  }

  String _format() {
    final rounded = widget.value.round();
    final String s;
    if (widget.format != null) {
      s = widget.format!(rounded);
    } else if (widget.locale) {
      s = _grouped(rounded);
    } else {
      s = rounded.toString();
    }
    final pad = widget.pad;
    return pad != null ? s.padLeft(pad, '0') : s;
  }

  // Minimal, locale-free thousands grouping (server-safe, like the source's
  // `toLocaleString()` default): groups of three with a comma separator.
  static String _grouped(int value) {
    final neg = value < 0;
    final digits = value.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return neg ? '-${buf.toString()}' : buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final text = _format();

    final children = <Widget>[];
    if (widget.prefix != null) {
      children.add(Text(widget.prefix!, style: style));
    }

    // Key each digit slot by place value (position from the right) so a
    // changing digit keeps its identity and rolls to the new value instead of
    // remounting from 0 — the source's `g-${len-1-i}` keying.
    final chars = text.split('');
    for (var i = 0; i < chars.length; i++) {
      final char = chars[i];
      final place = chars.length - 1 - i;
      final digit = int.tryParse(char);
      if (digit == null) {
        // Non-digit (comma, sign, decimal): render statically.
        children.add(
          Text(char, key: ValueKey('sep-$place-$char'), style: style),
        );
      } else {
        children.add(
          _Digit(
            key: ValueKey('d-$place'),
            digit: digit,
            delay: (reduce || _entered) ? Duration.zero : widget.stagger * i,
            duration: widget.duration,
            blur: widget.blur,
            reduce: reduce,
            style: style,
          ),
        );
      }
    }

    if (widget.suffix != null) {
      children.add(Text(widget.suffix!, style: style));
    }

    return Semantics(
      label: '${widget.prefix ?? ''}$text${widget.suffix ?? ''}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        ),
      ),
    );
  }
}

/// One digit column: glyphs 0–9 stacked vertically, clipped to a single digit's
/// height, translated to bring the target digit into the window.
class _Digit extends StatelessWidget {
  const _Digit({
    required this.digit,
    required this.delay,
    required this.duration,
    required this.blur,
    required this.reduce,
    required this.style,
    super.key,
  });

  final int digit;
  final Duration delay;
  final Duration duration;
  final bool blur;
  final bool reduce;
  final TextStyle style;

  // Source DIGIT_HEIGHT_EM 1.1 — the slot is 1.1× the font size tall.
  static const double _heightEm = 1.1;
  // Source blur(10px); the library blur budget caps at 10px.
  static const double _maxBlurSigma = 5.0; // ~10px CSS blur

  @override
  Widget build(BuildContext context) {
    final fontSize = style.fontSize ?? 14;
    final slot = fontSize * _heightEm;
    final width = fontSize * 0.62; // ~1ch for tabular figures

    Widget column(double y, {double blurSigma = 0}) {
      Widget col = Transform.translate(
        offset: Offset(0, -y * slot),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var n = 0; n < 10; n++)
              SizedBox(
                height: slot,
                child: Center(
                  child: Text('$n', style: style, maxLines: 1, softWrap: false),
                ),
              ),
          ],
        ),
      );
      if (blurSigma > 0.05) {
        col = ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: blurSigma,
            sigmaY: blurSigma,
            tileMode: TileMode.decal,
          ),
          child: col,
        );
      }
      return col;
    }

    Widget slotBox(Widget child) => ClipRect(
      child: SizedBox(
        width: width,
        height: slot,
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: double.infinity,
          child: Align(alignment: Alignment.topCenter, child: child),
        ),
      ),
    );

    // Reduced motion: jump straight to the target digit, no roll, no blur.
    if (reduce) {
      return slotBox(column(digit.toDouble()));
    }

    // The roll: an EASE_OUT curve over `duration`, driven through motor. Spring
    // tokens would overshoot — an odometer must settle exactly on its number —
    // so this mirrors the source's `{ duration, ease: EASE_OUT }` tween.
    return SingleMotionBuilder(
      value: digit.toDouble(),
      motion: motionFor(
        context,
        CurvedMotion(duration, beuiEaseOut),
        isMovement: true,
      ),
      builder: (context, y, _) {
        double blurSigma = 0;
        if (blur) {
          // Blur tracks how far the column still is from its target, scaled to
          // the source window (`min(duration*0.75, 0.32)`), capped at the budget.
          final dist = (y - digit).abs();
          blurSigma = (dist * _maxBlurSigma).clamp(0.0, _maxBlurSigma);
        }
        return slotBox(column(y, blurSigma: blurSigma));
      },
    );
  }
}
