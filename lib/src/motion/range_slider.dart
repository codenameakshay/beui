import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

// Source `range-slider.tsx` (lines 22–26) exposes two component-local springs:
//
//   SPRING_GLIDE  = { stiffness: 700, damping: 50, mass: 0.5 }  // POSITION
//   SPRING_BOUNCY = { stiffness: 500, damping: 14, mass: 0.7 }  // grab SCALE
//
// SPRING_GLIDE is critically/over-damped (NO overshoot): it drives the thumb +
// fill POSITION so the handle glides butterily between snapped steps and lands
// exactly on the tick without bouncing past it. SPRING_BOUNCY is underdamped
// (springy): it drives the thumb's grab-grow SCALE *only* (scaleY 1 → 1.35),
// the bit of personality you feel under the finger.
//
// Both carry over verbatim as component-local SpringMotion constants
// (sanctioned by the source's `AGENTS.md` for genuinely component-specific
// tuning) — neither matches one of the five shared `beuiSpring*` tokens. No
// elastic-curve approximation.

/// Glide for the thumb/fill **position** — critically damped, no overshoot, so
/// the handle eases onto each snapped step and stops dead on the tick. Source
/// `SPRING_GLIDE`.
const _glideSpring = SpringMotion(
  SpringDescription(mass: 0.5, stiffness: 700, damping: 50),
);

/// Bouncy grab feedback for the thumb **scale** only. Source `SPRING_BOUNCY`.
const _grabSpring = SpringMotion(
  SpringDescription(mass: 0.7, stiffness: 500, damping: 14),
);

/// Test handle on the single-thumb slider's thumb.
@visibleForTesting
const beuiRangeSliderThumbKey = ValueKey<String>('beui_range_slider_thumb');

/// Test handle on the dual slider's low (start) thumb.
@visibleForTesting
const beuiRangeSliderStartThumbKey = ValueKey<String>(
  'beui_range_slider_thumb_start',
);

/// Test handle on the dual slider's high (end) thumb.
@visibleForTesting
const beuiRangeSliderEndThumbKey = ValueKey<String>(
  'beui_range_slider_thumb_end',
);

double _clamp(double v, double lo, double hi) => math.min(hi, math.max(lo, v));

// Shared track geometry (source `h-10`, `w-1.5`, `h-5`, `inset-x-2`).
const double _trackHeight = 40;
const double _thumbWidth = 6;
const double _thumbHeight = 20;
const double _tickInset = 8;

/// A single-thumb slider — a one-to-one port of beUI's `range-slider`.
///
/// One vertical-bar thumb selects a value over `[min, max]`; a fill runs from the
/// left track edge to the thumb. Tick dots mark each [step]. The thumb + fill
/// **glide** to each snapped step under a critically-damped spring ([_glideSpring],
/// the source's `SPRING_GLIDE`) — no overshoot, it stops exactly on the tick.
/// Grabbing the thumb grows it (scaleY 1 → 1.35) under the bouncy [_grabSpring]
/// (`SPRING_BOUNCY`), the only springy/overshooting part of the control.
///
/// **Drag is a real control gesture, so it uses [GestureDetector]** (pan), not
/// `MouseRegion` — the `MouseRegion` rule is only for decorative hover effects.
/// Keyboard: focus the slider and the arrow keys nudge by one [step]
/// (Home/End jump to [min]/[max]).
///
/// Controlled **or** uncontrolled (per the source and `AGENTS.md`): pass [value]
/// + [onChanged], or seed [defaultValue] and let the slider hold state.
///
/// Reduced motion (via the central [motionFor] resolver) snaps the thumb to its
/// step with **no glide** and drops the grab-grow — the value still changes.
class BeuiRangeSlider extends StatefulWidget {
  /// Creates a single-thumb slider over `[min, max]` quantised to [step].
  const BeuiRangeSlider({
    this.value,
    this.defaultValue = 0,
    this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.enabled = true,
    this.showTicks = true,
    this.label,
    super.key,
  }) : assert(min < max, 'min must be < max'),
       assert(step > 0, 'step must be > 0');

  /// The selected value (controlled). When null the slider holds its own state,
  /// seeded from [defaultValue].
  final double? value;

  /// The initial value when uncontrolled.
  final double defaultValue;

  /// Called with the new value on every step change during a drag / key press.
  final ValueChanged<double>? onChanged;

  /// Called once when a drag gesture ends, with the final value.
  final ValueChanged<double>? onChangeEnd;

  /// Lower bound of the track.
  final double min;

  /// Upper bound of the track.
  final double max;

  /// Quantisation step; the thumb snaps to the nearest multiple, and one tick
  /// dot is drawn per step boundary.
  final double step;

  /// Whether the slider responds to input. A disabled slider is dimmed and
  /// unfocusable.
  final bool enabled;

  /// Whether to draw a tick dot at each step. Suppressed automatically when
  /// there would be too many dots to read (> 50).
  final bool showTicks;

  /// Optional accessibility label announced for the slider.
  final String? label;

  @override
  State<BeuiRangeSlider> createState() => _BeuiRangeSliderState();
}

class _BeuiRangeSliderState extends State<BeuiRangeSlider> {
  late final FocusNode _focus = FocusNode(debugLabel: 'beui_range_slider');

  double? _internal;
  bool _grabbed = false;

  /// Continuous finger position (px) during an active drag, so the thumb + fill
  /// follow the pointer EXACTLY (no glide lag). Null off-drag — then the position
  /// glides to the snapped step. The reported value still snaps.
  double? _dragX;

  bool get _controlled => widget.value != null;

  double get _current =>
      _clamp(_controlled ? widget.value! : _internal!, widget.min, widget.max);

  @override
  void initState() {
    super.initState();
    _internal = widget.defaultValue;
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  double _snap(double value) {
    final steps = ((value - widget.min) / widget.step).roundToDouble();
    return _clamp(widget.min + steps * widget.step, widget.min, widget.max);
  }

  double _fraction(double value) =>
      (value - widget.min) / (widget.max - widget.min);

  double _travel(double trackWidth) => trackWidth - _thumbWidth;

  double _valueFromDx(double dx, double trackWidth) {
    final travel = _travel(trackWidth);
    if (travel <= 0) return widget.min;
    final ratio = _clamp((dx - _thumbWidth / 2) / travel, 0, 1);
    return widget.min + ratio * (widget.max - widget.min);
  }

  void _commit(double rawValue, {bool isEnd = false}) {
    final snapped = _snap(rawValue);
    if (snapped != _current) {
      if (!_controlled) setState(() => _internal = snapped);
      widget.onChanged?.call(snapped);
    }
    if (isEnd) widget.onChangeEnd?.call(snapped);
  }

  /// Clamps a finger x to the thumb-centre travel range.
  double _clampThumbX(double dx, double trackWidth) =>
      _clamp(dx, _thumbWidth / 2, trackWidth - _thumbWidth / 2);

  void _onPanStart(DragStartDetails details, double trackWidth) {
    if (!widget.enabled) return;
    _focus.requestFocus();
    setState(() {
      _grabbed = true;
      _dragX = _clampThumbX(details.localPosition.dx, trackWidth);
    });
    _commit(_valueFromDx(details.localPosition.dx, trackWidth));
  }

  void _onPanUpdate(DragUpdateDetails details, double trackWidth) {
    if (!widget.enabled || !_grabbed) return;
    setState(() => _dragX = _clampThumbX(details.localPosition.dx, trackWidth));
    _commit(_valueFromDx(details.localPosition.dx, trackWidth));
  }

  void _onPanEnd() {
    if (!_grabbed) return;
    setState(() {
      _grabbed = false;
      _dragX = null; // release → glide to the snapped step
    });
    _commit(_current, isEnd: true);
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp) {
      _commit(_current + widget.step);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown) {
      _commit(_current - widget.step);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _commit(widget.min);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _commit(widget.max);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.enabled;
    final current = _current;

    // Ask the resolver whether the position may glide. NoMotion freezes at the
    // source value rather than snapping to the target, so under reduced motion
    // we place the thumb/fill directly at the step (instant, no glide).
    final glideMotion = motionFor(context, _glideSpring, isMovement: true);

    final steps = ((widget.max - widget.min) / widget.step).floor();
    final showTicks = widget.showTicks && steps > 0 && steps <= 50;

    final slider = LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final travel = _travel(trackWidth);
        final targetX = _thumbWidth / 2 + _fraction(current) * travel;

        Widget thumb() {
          final grow = _grabbed && enabled && !reduce;
          final isFocused = _focus.hasFocus;
          return SingleMotionBuilder(
            value: grow ? 1.35 : 1.0,
            motion: reduce ? const NoMotion() : _grabSpring,
            builder: (context, scaleY, child) =>
                Transform.scale(scaleY: scaleY, child: child),
            child: Container(
              key: beuiRangeSliderThumbKey,
              width: _thumbWidth,
              height: _thumbHeight,
              decoration: BoxDecoration(
                color: colors.foreground,
                borderRadius: BorderRadius.circular(3), // `rounded-sm`
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
                border: isFocused
                    ? Border.all(color: colors.ring, width: 2)
                    : null,
              ),
            ),
          );
        }

        // Both the fill width and the thumb position are driven by the same
        // x, so the fill's right edge tracks the thumb exactly (source binds
        // `left` to one motion value for both).
        Widget buildAt(double x) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Track + fill + ticks, clipped to rounded-lg so the fill rounds
              // at the left corners (source `overflow-hidden rounded-lg`).
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(child: ColoredBox(color: colors.muted)),
                      Positioned(
                        left: 0,
                        width: x,
                        top: 0,
                        bottom: 0,
                        child: ColoredBox(
                          color: colors.foreground.withValues(alpha: 0.15),
                        ),
                      ),
                      if (showTicks)
                        Positioned(
                          left: _tickInset,
                          right: _tickInset,
                          top: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final w = c.maxWidth;
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    for (var i = 0; i <= steps; i++)
                                      Positioned(
                                        left: (i / steps) * w - 2,
                                        top: _trackHeight / 2 - 2,
                                        child: Container(
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: colors.foreground.withValues(
                                              alpha: 0.25,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Thumb — outside the clip so its shadow isn't shaved.
              Positioned(
                left: x - _thumbWidth / 2,
                top: (_trackHeight - _thumbHeight) / 2,
                child: thumb(),
              ),
            ],
          );
        }

        // During an active drag the handle is placed DIRECTLY at the pointer —
        // no spring — so it follows the finger exactly. Off a drag (keyboard,
        // and the settle after release) it glides onto the snapped step.
        final Widget body;
        if (_dragX != null && enabled) {
          body = buildAt(_clampThumbX(_dragX!, trackWidth));
        } else if (glideMotion is NoMotion) {
          body = buildAt(targetX); // reduced motion
        } else {
          body = SingleMotionBuilder(
            value: targetX,
            motion: glideMotion,
            builder: (context, x, _) => buildAt(x),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _onPanStart(d, trackWidth),
          onPanUpdate: (d) => _onPanUpdate(d, trackWidth),
          onPanEnd: (_) => _onPanEnd(),
          onPanCancel: _onPanEnd,
          child: SizedBox(
            height: _trackHeight,
            width: double.infinity,
            child: body,
          ),
        );
      },
    );

    return MergeSemantics(
      child: Semantics(
        container: true,
        enabled: enabled,
        label: widget.label,
        slider: true,
        value: '${current.round()}',
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: MouseRegion(
            cursor: enabled
                ? (_grabbed
                      ? SystemMouseCursors.grabbing
                      : SystemMouseCursors.grab)
                : SystemMouseCursors.basic,
            child: Focus(
              focusNode: _focus,
              canRequestFocus: enabled,
              onKeyEvent: (_, event) => _onKey(event),
              onFocusChange: (_) => setState(() {}),
              child: slider,
            ),
          ),
        ),
      ),
    );
  }
}

/// Which of the dual slider's two thumbs an interaction is addressing.
enum _Thumb { start, end }

/// A two-thumb range slider — a **Flutter-only extension** beyond the source's
/// single-thumb `range-slider` (the source ships only one handle).
///
/// Two handles select a `[start, end]` band over `[min, max]`. The track shows a
/// tick dot at every step ([divisions]); the active band between the thumbs is
/// highlighted. Each thumb **glides** to its snapped step under the same
/// critically-damped [_glideSpring] as the single-thumb slider — no overshoot —
/// and grows under the bouncy [_grabSpring] on grab. The thumbs **cannot cross**
/// (each is clamped to the other).
///
/// Drag uses [GestureDetector] (pan picks the nearer thumb); keyboard focuses a
/// thumb and the arrow keys nudge it by one step.
///
/// Controlled **or** uncontrolled: pass [values] + [onChanged], or seed
/// [defaultValues]. Reduced motion snaps both thumbs with no glide and drops the
/// grab-grow — values still change.
class BeuiRangeSliderDual extends StatefulWidget {
  /// Creates a range slider over `[min, max]` split into [divisions] steps.
  const BeuiRangeSliderDual({
    this.values,
    this.defaultValues = const RangeValues(20, 60),
    this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 100,
    this.divisions = 20,
    this.enabled = true,
    this.showTicks = true,
    this.label,
    super.key,
  }) : assert(min < max, 'min must be < max'),
       assert(divisions > 0, 'divisions must be > 0');

  /// The selected band (controlled). When null the slider holds its own state,
  /// seeded from [defaultValues].
  final RangeValues? values;

  /// The initial band when uncontrolled.
  final RangeValues defaultValues;

  /// Called with the new band on every step change during a drag / key press.
  final ValueChanged<RangeValues>? onChanged;

  /// Called once when a drag gesture ends, with the final band.
  final ValueChanged<RangeValues>? onChangeEnd;

  /// Lower bound of the track.
  final double min;

  /// Upper bound of the track.
  final double max;

  /// Number of equal steps between [min] and [max]. The step size is
  /// `(max - min) / divisions`; one tick dot is drawn per step boundary.
  final int divisions;

  /// Whether the slider responds to input.
  final bool enabled;

  /// Whether to draw a tick dot at each step (suppressed above 50 dots).
  final bool showTicks;

  /// Optional accessibility label announced for the slider group.
  final String? label;

  @override
  State<BeuiRangeSliderDual> createState() => _BeuiRangeSliderDualState();
}

class _BeuiRangeSliderDualState extends State<BeuiRangeSliderDual> {
  late final FocusNode _startFocus = FocusNode(debugLabel: 'beui_range_start');
  late final FocusNode _endFocus = FocusNode(debugLabel: 'beui_range_end');

  RangeValues? _internal;
  _Thumb? _dragging;
  _Thumb? _grabbed;

  /// Continuous finger position (px) while a thumb is being dragged, so the
  /// dragged handle (and the band edge) follow the pointer exactly.
  double? _dragX;

  bool get _controlled => widget.values != null;

  double _clampThumbX(double dx, double trackWidth) =>
      _clamp(dx, _thumbWidth / 2, trackWidth - _thumbWidth / 2);

  double get _step => (widget.max - widget.min) / widget.divisions;

  RangeValues get _current {
    final raw = _controlled ? widget.values! : _internal!;
    final lo = _clamp(raw.start, widget.min, widget.max);
    final hi = _clamp(raw.end, widget.min, widget.max);
    return RangeValues(math.min(lo, hi), math.max(lo, hi));
  }

  @override
  void initState() {
    super.initState();
    _internal = widget.defaultValues;
  }

  @override
  void dispose() {
    _startFocus.dispose();
    _endFocus.dispose();
    super.dispose();
  }

  double _snap(double value) {
    final steps = ((value - widget.min) / _step).roundToDouble();
    return _clamp(widget.min + steps * _step, widget.min, widget.max);
  }

  double _fraction(double value) =>
      (value - widget.min) / (widget.max - widget.min);

  double _travel(double trackWidth) => trackWidth - _thumbWidth;

  void _commit(_Thumb thumb, double rawValue, {bool isEnd = false}) {
    final cur = _current;
    final snapped = _snap(rawValue);
    final RangeValues next;
    if (thumb == _Thumb.start) {
      next = RangeValues(math.min(snapped, cur.end), cur.end);
    } else {
      next = RangeValues(cur.start, math.max(snapped, cur.start));
    }
    if (next != cur) {
      if (!_controlled) setState(() => _internal = next);
      widget.onChanged?.call(next);
    }
    if (isEnd) widget.onChangeEnd?.call(next);
  }

  double _valueFromDx(double dx, double trackWidth) {
    final travel = _travel(trackWidth);
    if (travel <= 0) return widget.min;
    final ratio = _clamp((dx - _thumbWidth / 2) / travel, 0, 1);
    return widget.min + ratio * (widget.max - widget.min);
  }

  _Thumb _nearest(double value) {
    final cur = _current;
    final dStart = (value - cur.start).abs();
    final dEnd = (value - cur.end).abs();
    if (dStart == dEnd) return value < cur.start ? _Thumb.start : _Thumb.end;
    return dStart < dEnd ? _Thumb.start : _Thumb.end;
  }

  void _onPanStart(DragStartDetails details, double trackWidth) {
    if (!widget.enabled) return;
    final value = _valueFromDx(details.localPosition.dx, trackWidth);
    final thumb = _nearest(value);
    setState(() {
      _dragging = thumb;
      _grabbed = thumb;
      _dragX = _clampThumbX(details.localPosition.dx, trackWidth);
    });
    (thumb == _Thumb.start ? _startFocus : _endFocus).requestFocus();
    _commit(thumb, value);
  }

  void _onPanUpdate(DragUpdateDetails details, double trackWidth) {
    if (!widget.enabled || _dragging == null) return;
    setState(() => _dragX = _clampThumbX(details.localPosition.dx, trackWidth));
    _commit(_dragging!, _valueFromDx(details.localPosition.dx, trackWidth));
  }

  void _onPanEnd() {
    if (_dragging == null) return;
    final thumb = _dragging!;
    setState(() {
      _dragging = null;
      _grabbed = null;
      _dragX = null; // release → glide to the snapped step
    });
    final cur = _current;
    _commit(thumb, thumb == _Thumb.start ? cur.start : cur.end, isEnd: true);
  }

  void _nudge(_Thumb thumb, double delta) {
    if (!widget.enabled) return;
    final cur = _current;
    final base = thumb == _Thumb.start ? cur.start : cur.end;
    _commit(thumb, base + delta);
  }

  KeyEventResult _onKey(_Thumb thumb, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp) {
      _nudge(thumb, _step);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown) {
      _nudge(thumb, -_step);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _commit(thumb, thumb == _Thumb.start ? widget.min : _current.start);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _commit(thumb, thumb == _Thumb.start ? _current.end : widget.max);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.enabled;
    final cur = _current;

    final glideMotion = motionFor(context, _glideSpring, isMovement: true);

    final steps = widget.divisions;
    final showTicks = widget.showTicks && steps > 0 && steps <= 50;

    final slider = LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final travel = _travel(trackWidth);

        double centerX(double value) =>
            _thumbWidth / 2 + _fraction(value) * travel;

        Widget thumb(_Thumb which, FocusNode focus, Key key) {
          final grow = _grabbed == which && enabled && !reduce;
          final isFocused = focus.hasFocus;
          return SingleMotionBuilder(
            value: grow ? 1.35 : 1.0,
            motion: reduce ? const NoMotion() : _grabSpring,
            builder: (context, scaleY, child) =>
                Transform.scale(scaleY: scaleY, child: child),
            child: Container(
              key: key,
              width: _thumbWidth,
              height: _thumbHeight,
              decoration: BoxDecoration(
                color: colors.foreground,
                borderRadius: BorderRadius.circular(3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
                border: isFocused
                    ? Border.all(color: colors.ring, width: 2)
                    : null,
              ),
            ),
          );
        }

        Widget thumbAt(_Thumb which, double x, FocusNode focus, Key key) =>
            Positioned(
              left: x - _thumbWidth / 2,
              top: (_trackHeight - _thumbHeight) / 2,
              child: Focus(
                focusNode: focus,
                canRequestFocus: enabled,
                onKeyEvent: (_, event) => _onKey(which, event),
                onFocusChange: (_) => setState(() {}),
                child: thumb(which, focus, key),
              ),
            );

        // The band + both thumbs read the same live x per side, so the fill
        // always spans exactly between the handles. The dragged side follows the
        // pointer (near-instant); the other side glides to its snapped step.
        Widget buildBand(double sx, double ex) => Stack(
          clipBehavior: Clip.none,
          children: [
            // Track + fill band + ticks, clipped to rounded-lg.
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: ColoredBox(color: colors.muted)),
                    Positioned(
                      left: math.min(sx, ex),
                      width: (ex - sx).abs(),
                      top: 0,
                      bottom: 0,
                      child: ColoredBox(
                        color: colors.foreground.withValues(alpha: 0.15),
                      ),
                    ),
                    if (showTicks)
                      Positioned(
                        left: _tickInset,
                        right: _tickInset,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: LayoutBuilder(
                            builder: (context, c) {
                              final w = c.maxWidth;
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  for (var i = 0; i <= steps; i++)
                                    Positioned(
                                      left: (i / steps) * w - 2,
                                      top: _trackHeight / 2 - 2,
                                      child: Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: colors.foreground.withValues(
                                            alpha: 0.25,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Thumbs — outside the clip so their shadow isn't shaved.
            thumbAt(_Thumb.end, ex, _endFocus, beuiRangeSliderEndThumbKey),
            thumbAt(
              _Thumb.start,
              sx,
              _startFocus,
              beuiRangeSliderStartThumbKey,
            ),
          ],
        );

        final draggingSide = (_dragX != null && enabled) ? _dragging : null;

        // Resolves one side's x: the dragged side is placed DIRECTLY at the
        // pointer (exact, no glide); the other side glides to its snapped step.
        Widget side(_Thumb which, double snapped, Widget Function(double x) b) {
          if (draggingSide == which) {
            return b(_clampThumbX(_dragX!, trackWidth));
          }
          if (glideMotion is NoMotion) return b(snapped); // reduced motion
          return SingleMotionBuilder(
            value: snapped,
            motion: glideMotion,
            builder: (context, x, _) => b(x),
          );
        }

        final Widget body = side(
          _Thumb.start,
          centerX(cur.start),
          (sx) => side(_Thumb.end, centerX(cur.end), (ex) => buildBand(sx, ex)),
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _onPanStart(d, trackWidth),
          onPanUpdate: (d) => _onPanUpdate(d, trackWidth),
          onPanEnd: (_) => _onPanEnd(),
          onPanCancel: _onPanEnd,
          child: SizedBox(
            height: _trackHeight,
            width: double.infinity,
            child: body,
          ),
        );
      },
    );

    return MergeSemantics(
      child: Semantics(
        container: true,
        enabled: enabled,
        label: widget.label,
        slider: true,
        value: '${cur.start.round()} – ${cur.end.round()}',
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: MouseRegion(
            cursor: enabled
                ? (_dragging != null
                      ? SystemMouseCursors.grabbing
                      : SystemMouseCursors.grab)
                : SystemMouseCursors.basic,
            child: slider,
          ),
        ),
      ),
    );
  }
}
