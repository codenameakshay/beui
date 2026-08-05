import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'range_slider_shared.dart';

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
/// (Now shared by the whole slider family — see `range_slider_shared.dart`,
/// where it has its single definition. Aliased here so every reference in this
/// file, and the commentary above, still reads as the source's `SPRING_GLIDE`.)
const _glideSpring = beuiSliderGlideSpring;

/// Bouncy grab feedback for the thumb **scale** only. Source `SPRING_BOUNCY`.
const _grabSpring = SpringMotion(
  SpringDescription(mass: 0.7, stiffness: 500, damping: 14),
);

/// Test handle on the single-thumb slider's thumb.
@visibleForTesting
const beuiRangeSliderThumbKey = ValueKey<String>('beui_range_slider_thumb');

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

  void _onPanStart(DragStartDetails details, double trackWidth) {
    if (!widget.enabled) return;
    _focus.requestFocus();
    setState(() => _grabbed = true);
    _commit(_valueFromDx(details.localPosition.dx, trackWidth));
  }

  void _onPanUpdate(DragUpdateDetails details, double trackWidth) {
    if (!widget.enabled || !_grabbed) return;
    _commit(_valueFromDx(details.localPosition.dx, trackWidth));
  }

  void _onPanEnd() {
    if (!_grabbed) return;
    setState(() => _grabbed = false);
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
                borderRadius: BorderRadius.circular(
                  2,
                ), // `rounded-sm` (0.125rem)
                boxShadow: [
                  const BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                  // focus-visible:ring-4 ring-foreground/30 — a 4px ring hugging
                  // the thumb (Tailwind rings paint OUTSIDE the box).
                  if (isFocused)
                    BoxShadow(
                      color: colors.foreground.withValues(alpha: 0.3),
                      spreadRadius: 4,
                    ),
                ],
              ),
            ),
          );
        }

        // Static per layout pass: the track, the fill's box, the tick layer,
        // and the thumb are built ONCE here and reused by every buildAt frame.
        // Identical widget instances short-circuit their subtree rebuilds, so
        // a spring frame only re-runs the cheap Positioned wrappers below
        // (fill width + thumb left) — not the track or up to 51 tick dots.
        final trackBox = Positioned.fill(
          child: ColoredBox(color: colors.muted),
        );
        final fillBox = ColoredBox(
          color: colors.foreground.withValues(alpha: 0.15),
        );
        final Widget? tickLayer;
        if (showTicks) {
          // Tick positions are a pure function of the measured trackWidth (the
          // ticks span the inset band), so no nested LayoutBuilder is needed.
          final w = math.max(0.0, trackWidth - 2 * _tickInset);
          tickLayer = Positioned(
            left: _tickInset,
            right: _tickInset,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Stack(
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
                          color: colors.foreground.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        } else {
          tickLayer = null;
        }
        final thumbWidget = thumb();

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
                      trackBox,
                      Positioned(
                        left: 0,
                        width: x,
                        top: 0,
                        bottom: 0,
                        child: fillBox,
                      ),
                      ?tickLayer,
                    ],
                  ),
                ),
              ),
              // Thumb — outside the clip so its shadow isn't shaved.
              Positioned(
                left: x - _thumbWidth / 2,
                top: (_trackHeight - _thumbHeight) / 2,
                child: thumbWidget,
              ),
            ],
          );
        }

        // The handle is driven off the SNAPPED value (`current` → targetX)
        // through SPRING_GLIDE, so during a drag it detents live between steps
        // and eases onto each tick — matching the source, where `pos` always
        // springs toward the snapped percent (the raw pointer x is never bound
        // to the thumb). Reduced motion places it at the step with no glide.
        final Widget body;
        if (glideMotion is NoMotion) {
          body = buildAt(targetX); // reduced motion — snap, no glide
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
