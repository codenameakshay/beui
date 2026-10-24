import 'package:flutter/widgets.dart';

import '../tokens/motion.dart';
import '_engine.dart';
import '_scroll_geometry.dart';

/// An in-view count-up number — the Flutter port of beUI's `animated-number`.
///
/// Unlike [BeuiNumberTicker] (a per-digit odometer roll), this animates a single
/// scalar from its previous value to [value] and re-formats every frame —
/// `animate(from, value)` in the source. It is a **tween**, not a spring: the
/// source drives it with `{ duration, ease: EASE_OUT }`, which maps to
/// [CurvedMotion] over [beuiEaseOut] (PORTING_SPEC §number — explicitly *not* a
/// `SpringMotion`).
///
/// The count starts from `0` (matching the source's `display = 0` / `fromRef =
/// 0` seed) and counts up to [value]; subsequent [value] changes count from the
/// previous value. With [startOnView] (the source default) the count holds at
/// its seed until 60% of the widget is visible in the nearest enclosing
/// scrollable, then plays once — the source's `useInView(ref, { once: true,
/// amount: 0.6 })` gate.
///
/// Reduced motion snaps straight to the formatted [value] with no count-up.
class BeuiAnimatedNumber extends StatefulWidget {
  /// Creates an animated number that counts up to [value].
  const BeuiAnimatedNumber({
    required this.value,
    this.duration = const Duration(milliseconds: 1200),
    this.startOnView = true,
    this.format,
    this.style,
    super.key,
  });

  /// The target value. The display counts from the previous value to this.
  final num value;

  /// Count-up duration (source default `1.2s`).
  final Duration duration;

  /// Hold the count-up until 60% of the widget is visible in the nearest
  /// enclosing scrollable (source `startOnView`, default true; `amount: 0.6`,
  /// once only). Without an enclosing scrollable the widget counts as visible
  /// and plays on the first layout.
  final bool startOnView;

  /// Formats the interpolated value to a string. Defaults to a rounded,
  /// thousands-grouped integer (the source's `Math.round(n).toLocaleString()`).
  final String Function(num value)? format;

  /// Text style. Falls back to the ambient [DefaultTextStyle].
  final TextStyle? style;

  @override
  State<BeuiAnimatedNumber> createState() => _BeuiAnimatedNumberState();
}

class _BeuiAnimatedNumberState extends State<BeuiAnimatedNumber>
    with ScrollGeometryMixin {
  // Source `useInView(..., { amount: 0.6 })`.
  static const double _inViewAmount = 0.6;

  // Where the current count-up starts (source `fromRef`). Seeded at 0.
  double _from = 0;

  // Whether the count-up may play (source `if (startOnView && !inView) return`).
  late bool _armed = !widget.startOnView;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // startOnView needs an enclosing scrollable to measure against; without
    // one the widget counts as fully visible — arm on the first layout.
    if (!_armed && Scrollable.maybeOf(context) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_armed) setState(() => _armed = true);
      });
    }
  }

  @override
  void onScrollGeometryChanged() {
    if (_armed) return;
    if ((visibleFraction ?? 0) >= _inViewAmount) setState(() => _armed = true);
  }

  @override
  void didUpdateWidget(BeuiAnimatedNumber old) {
    super.didUpdateWidget(old);
    // Next animation counts from the previous target — but only once armed;
    // while gated the source's effect exits before touching `fromRef`, so the
    // eventual in-view play still counts up from the original seed.
    if (_armed && old.value != widget.value) _from = old.value.toDouble();
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
    return neg ? '-$buf' : buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final reduce = MediaQuery.disableAnimationsOf(context);

    // Reduced motion: no count-up — render the final value directly.
    if (reduce) {
      return Text(
        _format(widget.value),
        style: style,
        maxLines: 1,
        softWrap: false,
      );
    }

    // Gated: hold the seed until the widget scrolls into view.
    if (!_armed) {
      return Text(_format(_from), style: style, maxLines: 1, softWrap: false);
    }

    return SingleMotionBuilder(
      value: widget.value.toDouble(),
      from: _from,
      motion: CurvedMotion(widget.duration, beuiEaseOut),
      builder: (context, v, _) =>
          Text(_format(v), style: style, maxLines: 1, softWrap: false),
    );
  }
}
