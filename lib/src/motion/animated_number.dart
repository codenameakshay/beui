import 'package:flutter/widgets.dart';

import '../tokens/motion.dart';
import '_engine.dart';

/// An in-view count-up number — the Flutter port of beUI's `animated-number`.
///
/// Unlike [BeuiNumberTicker] (a per-digit odometer roll), this animates a single
/// scalar from its previous value to [value] and re-formats every frame —
/// `animate(from, value)` in the source. It is a **tween**, not a spring: the
/// source drives it with `{ duration, ease: EASE_OUT }`, which maps to
/// [CurvedMotion] over [beuiEaseOut] (PORTING_SPEC §number — explicitly *not* a
/// `SpringMotion`).
///
/// The count starts from `0` on first build (matching the source's
/// `display = 0` / `fromRef = 0` seed) and counts up to [value]; subsequent
/// [value] changes count from the previous value.
///
/// Reduced motion snaps straight to the formatted [value] with no count-up.
class BeuiAnimatedNumber extends StatefulWidget {
  /// Creates an animated number that counts up to [value].
  const BeuiAnimatedNumber({
    required this.value,
    this.duration = const Duration(milliseconds: 1200),
    this.format,
    this.style,
    super.key,
  });

  /// The target value. The display counts from the previous value to this.
  final num value;

  /// Count-up duration (source default `1.2s`).
  final Duration duration;

  /// Formats the interpolated value to a string. Defaults to a rounded,
  /// thousands-grouped integer (the source's `Math.round(n).toLocaleString()`).
  final String Function(num value)? format;

  /// Text style. Falls back to the ambient [DefaultTextStyle].
  final TextStyle? style;

  @override
  State<BeuiAnimatedNumber> createState() => _BeuiAnimatedNumberState();
}

class _BeuiAnimatedNumberState extends State<BeuiAnimatedNumber> {
  // Where the current count-up starts (source `fromRef`). Seeded at 0.
  double _from = 0;

  @override
  void didUpdateWidget(BeuiAnimatedNumber old) {
    super.didUpdateWidget(old);
    // Next animation counts from the previous target.
    if (old.value != widget.value) _from = old.value.toDouble();
  }

  String _format(num v) {
    if (widget.format != null) return widget.format!(v);
    return _grouped(v.round());
  }

  // Locale-free thousands grouping, matching the source's default formatter.
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
    final target = widget.value.toDouble();

    // Reduced motion: no count-up — render the final value directly.
    if (reduce) {
      return Text(_format(widget.value), style: style, maxLines: 1);
    }

    return SingleMotionBuilder(
      value: target,
      from: _from,
      motion: CurvedMotion(widget.duration, beuiEaseOut),
      builder: (context, v, _) =>
          Text(_format(v), style: style, maxLines: 1, softWrap: false),
    );
  }
}
