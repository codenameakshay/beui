import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../tokens/motion.dart';
import '_engine.dart';
import '_format.dart';
import '_scroll_geometry.dart';

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
/// (an odometer must never bounce past its number). Every column starts at `0`
/// (the source's `initial: y 0`) and holds there until the ticker **arms**: on
/// mount, or — with [startOnView] (the source default) — once 60% of the
/// widget is visible in the nearest enclosing scrollable. On arming the digits
/// roll in staggered left-to-right by [stagger]; once that reveal has played,
/// live value changes roll every digit immediately (a per-digit delay on live
/// updates reads as lag — the source's `entered` gate).
///
/// With [blur] true, each roll carries a fixed-window blur — `blur(10px) →
/// blur(0)` over `min(duration × 0.75, 320ms)`, the source's transition — so
/// the sharpening is time-based, not tied to how far the column happens to
/// travel.
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
    this.startOnView = true,
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

  /// Hold the entrance until 60% of the ticker is visible in the nearest
  /// enclosing scrollable (source `startOnView`, default true; `amount: 0.6`,
  /// once only). Without an enclosing scrollable the ticker counts as visible
  /// and arms on the first layout.
  final bool startOnView;

  /// Custom formatter. Takes precedence over [locale]. Receives the rounded int.
  final String Function(int value)? format;

  /// Text style. Falls back to the ambient [DefaultTextStyle].
  final TextStyle? style;

  @override
  State<BeuiNumberTicker> createState() => _BeuiNumberTickerState();
}

class _BeuiNumberTickerState extends State<BeuiNumberTicker>
    with ScrollGeometryMixin {
  // Source `useInView(..., { amount: 0.6 })`.
  static const double _inViewAmount = 0.6;

  // Whether the entrance has been triggered (mount, or in-view arming). Until
  // then every digit column holds at 0 — the source's gated `animate`.
  late bool _armed = !widget.startOnView;

  // Whether the staggered entrance reveal has already played. After it has,
  // live value changes roll every digit with no per-digit delay (source).
  bool _entered = false;
  Timer? _enterTimer;

  @override
  void initState() {
    super.initState();
    if (_armed) _startEnterWindow();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // startOnView needs an enclosing scrollable to measure against; without
    // one the widget counts as fully visible — arm on the first layout.
    if (!_armed && Scrollable.maybeOf(context) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _arm();
      });
    }
  }

  @override
  void onScrollGeometryChanged() {
    if (_armed) return;
    if ((visibleFraction ?? 0) >= _inViewAmount) _arm();
  }

  void _arm() {
    if (_armed) return;
    setState(() => _armed = true);
    _startEnterWindow();
  }

  /// The stagger is a one-shot entrance flourish; a single timer drops the
  /// per-digit delay once the reveal window has passed.
  void _startEnterWindow() {
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

  // Locale-free thousands grouping (server-safe, like the source's
  // `toLocaleString()` default).
  static String _grouped(int value) {
    final neg = value < 0;
    final grouped = beuiGroupThousands(value.abs().toString());
    return neg ? '-$grouped' : grouped;
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
            // Entrance only: `delay = entered ? 0 : i * stagger` (source).
            delay: (reduce || _entered) ? Duration.zero : widget.stagger * i,
            duration: widget.duration,
            blur: widget.blur,
            reduce: reduce,
            armed: reduce || _armed,
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
///
/// The column rests at `0` (source `initial`) until [armed], then rolls to
/// [digit] once its entrance [delay] has elapsed — the source's per-digit
/// `delay: i * stagger`, wired into a release [Timer] here because motor
/// motions carry no delay of their own. Each roll (re)starts the fixed
/// blur window.
class _Digit extends StatefulWidget {
  const _Digit({
    required this.digit,
    required this.delay,
    required this.duration,
    required this.blur,
    required this.reduce,
    required this.armed,
    required this.style,
    super.key,
  });

  final int digit;
  final Duration delay;
  final Duration duration;
  final bool blur;
  final bool reduce;
  final bool armed;
  final TextStyle style;

  @override
  State<_Digit> createState() => _DigitState();
}

class _DigitState extends State<_Digit> {
  // Source DIGIT_HEIGHT_EM 1.1 — the slot is 1.1× the font size tall.
  static const double _heightEm = 1.1;
  // Source `blur(10px)`; also the library's motion-blur budget cap.
  static final double _maxBlurSigma = beuiBlurSigma(10);

  Timer? _releaseTimer;

  // Whether the entrance delay has elapsed and the column may leave 0.
  late bool _released = widget.armed && widget.delay == Duration.zero;

  // Roll bookkeeping for the blur window: [_prevTarget] is where the column
  // was last told to sit; each change is a new roll and bumps [_rollGen],
  // which re-keys (restarts) the blur's fixed time window.
  int _prevTarget = 0;
  int _rollGen = 0;

  @override
  void initState() {
    super.initState();
    _scheduleRelease();
  }

  @override
  void didUpdateWidget(_Digit old) {
    super.didUpdateWidget(old);
    if (widget.armed && !old.armed) _scheduleRelease();
  }

  void _scheduleRelease() {
    if (!widget.armed || _released) return;
    if (widget.delay == Duration.zero) {
      _released = true;
      return;
    }
    _releaseTimer?.cancel();
    _releaseTimer = Timer(widget.delay, () {
      if (mounted) setState(() => _released = true);
    });
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    super.dispose();
  }

  /// The fixed blur window — the source's dedicated filter transition:
  /// `duration: min(duration * 0.75, 0.32)`.
  Duration get _blurWindow {
    final ms = (widget.duration.inMilliseconds * 0.75).round();
    return Duration(milliseconds: ms < 320 ? ms : 320);
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.style.fontSize ?? 14;
    final slot = fontSize * _heightEm;
    final width = fontSize * 0.62; // ~1ch for tabular figures

    Widget column(double y) {
      return Transform.translate(
        offset: Offset(0, -y * slot),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var n = 0; n < 10; n++)
              SizedBox(
                height: slot,
                child: Center(
                  child: Text(
                    '$n',
                    style: widget.style,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
          ],
        ),
      );
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
    if (widget.reduce) {
      return slotBox(column(widget.digit.toDouble()));
    }

    // Where the column should sit: held at 0 until released (source
    // `initial: y 0` + gated animate), then the live digit.
    final target = _released ? widget.digit : 0;
    if (target != _prevTarget) {
      // A new roll starts this frame — restart the blur window. (Derived
      // bookkeeping on this State, not a setState: the build consuming it is
      // already running.)
      _prevTarget = target;
      _rollGen++;
    }

    // The roll: an EASE_OUT curve over `duration`, driven through motor. Spring
    // tokens would overshoot — an odometer must settle exactly on its number —
    // so this mirrors the source's `{ duration, ease: EASE_OUT }` tween.
    Widget digitRoll = SingleMotionBuilder(
      value: target.toDouble(),
      from: 0,
      motion: motionFor(
        context,
        CurvedMotion(widget.duration, beuiEaseOut),
        isMovement: true,
      ),
      builder: (context, y, _) => slotBox(column(y)),
    );

    if (widget.blur && _rollGen > 0) {
      // Fixed-window blur riding the roll: sigma 5 → 0 over the window, eased
      // like the roll; re-keyed per roll so a live update re-blurs.
      digitRoll = TweenAnimationBuilder<double>(
        key: ValueKey(_rollGen),
        tween: Tween(begin: 1.0, end: 0.0),
        duration: _blurWindow,
        curve: beuiEaseOut,
        child: digitRoll,
        builder: (context, t, child) {
          final sigma = t * _maxBlurSigma;
          if (sigma <= 0.05) return child!;
          return ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: sigma,
              sigmaY: sigma,
              tileMode: TileMode.decal,
            ),
            child: child,
          );
        },
      );
    }

    return digitRoll;
  }
}
