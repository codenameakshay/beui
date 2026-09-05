import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'range_slider_shared.dart';

// Source `range-slider-wave.tsx` declares one component-local spring:
//
//   SPRING_BAR = { stiffness: 420, damping: 20, mass: 0.5 }
//
// Under-damped (ζ ≈ 0.69), and deliberately so: the comment reads "soft enough
// that the crest wobbles as it travels". It matches none of the five shared
// `beuiSpring*` tokens — a `beuiSpringLayout` substitution would damp the wobble
// out and cost the component its identity — so it ports verbatim as a local
// const, per source `AGENTS.md` and `docs/PORTING_SPEC.md` §1.
const _barSpring = SpringMotion(
  SpringDescription(mass: 0.5, stiffness: 420, damping: 20),
);

/// Default bar count — "reads as a wave without turning into a stripe pattern"
/// (source `BARS`).
const int _defaultBars = 32;

/// Width of the crest **in bars**; bigger spreads the bell wider (source
/// `SPREAD`).
const double _spread = 2.6;

// Geometry, from source: h-20 track (80px), h-14 bars (56px), gap-1 (4px),
// rounded-xl focus ring (12px).
const double _trackHeight = 80;
const double _barHeight = 56;
const double _barGap = 4;
const double _focusRadius = 12;

/// Test handle on the wave slider's track.
@visibleForTesting
const beuiWaveSliderTrackKey = ValueKey<String>('beui_wave_slider_track');

/// Test handle on the wave slider's bar at [index].
@visibleForTesting
ValueKey<String> beuiWaveSliderBarKey(int index) =>
    ValueKey<String>('beui_wave_slider_bar_$index');

/// An equalizer slider — a one-to-one port of beUI's `range-slider-wave`.
///
/// There is no handle: [bars] equalizer bars span the track, and a Gaussian
/// **crest** rises around the value's position and falls back as it passes, so
/// the value reads as a travelling wave. Bars up to the value are filled; the
/// rest stay muted.
///
/// Motion: each bar's `scaleY` springs under a bespoke, deliberately
/// under-damped local spring (source `SPRING_BAR`, 420/20/0.5 — "soft enough
/// that the crest wobbles as it travels"), staggered by a per-bar delay of
/// `min(distance × 12ms, 120ms)`. That stagger is what makes the crest read as
/// travelling rather than as the whole row breathing at once.
///
/// **Drag is a real control gesture, so it uses [GestureDetector]** (pan), not
/// `MouseRegion`. Keyboard: focus the track and the arrow keys nudge by one
/// [step] (Home/End jump to [min]/[max]).
///
/// Controlled **or** uncontrolled: pass [value] + [onChanged], or seed
/// [defaultValue].
///
/// Reduced motion flattens every bar to a uniform 0.4 scale with no spring and
/// no stagger (the source's own reduce branch) — the fill/mute split still
/// tracks the value, so the control stays readable.
class BeuiWaveSlider extends StatefulWidget {
  /// Creates an equalizer slider over `[min, max]` quantised to [step].
  const BeuiWaveSlider({
    this.value,
    this.defaultValue = 0,
    this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.enabled = true,
    this.bars = _defaultBars,
    this.formatValueText,
    this.label,
    super.key,
  }) : assert(min < max, 'min must be < max'),
       assert(step > 0, 'step must be > 0'),
       assert(bars > 0, 'bars must be > 0');

  /// The selected value (controlled). When null the slider holds its own state,
  /// seeded from [defaultValue].
  final double? value;

  /// The initial value when uncontrolled.
  final double defaultValue;

  /// Called with the new value on every step change during a drag / key press.
  /// (Source `onValueChange`.)
  final ValueChanged<double>? onChanged;

  /// Called once when a drag gesture ends, with the final value.
  final ValueChanged<double>? onChangeEnd;

  /// Lower bound of the track.
  final double min;

  /// Upper bound of the track.
  final double max;

  /// Quantisation step.
  final double step;

  /// Whether the slider responds to input. A disabled slider is dimmed and
  /// unfocusable. (Source `disabled`, inverted to match the repo convention.)
  final bool enabled;

  /// Number of bars drawn across the track. Defaults to 32.
  final int bars;

  /// Announced instead of the raw number — pass one when the value carries a
  /// unit or suffix.
  final String Function(double value)? formatValueText;

  /// The source's `aria-label` — announced for the slider.
  final String? label;

  @override
  State<BeuiWaveSlider> createState() => _BeuiWaveSliderState();
}

class _BeuiWaveSliderState extends State<BeuiWaveSlider>
    with BeuiSliderStateMixin<BeuiWaveSlider> {
  late final FocusNode _focus = FocusNode(debugLabel: 'beui_wave_slider');

  bool _dragging = false;

  @override
  double? get sliderValue => widget.value;
  @override
  double get sliderDefaultValue => widget.defaultValue;
  @override
  double get sliderMin => widget.min;
  @override
  double get sliderMax => widget.max;
  @override
  double get sliderStep => widget.step;
  @override
  bool get sliderEnabled => widget.enabled;
  @override
  ValueChanged<double>? get sliderOnChanged => widget.onChanged;
  @override
  ValueChanged<double>? get sliderOnChangeEnd => widget.onChangeEnd;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details, double trackWidth) {
    if (!widget.enabled) return;
    _focus.requestFocus();
    setState(() => _dragging = true);
    commitValue(sliderValueFromDx(details.localPosition.dx, trackWidth));
  }

  void _onPanUpdate(DragUpdateDetails details, double trackWidth) {
    if (!widget.enabled || !_dragging) return;
    commitValue(sliderValueFromDx(details.localPosition.dx, trackWidth));
  }

  void _onPanEnd() {
    if (!_dragging) return;
    setState(() => _dragging = false);
    commitValue(currentValue, isEnd: true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.enabled;

    // The resolver owns the decision. `scaleY` is movement, so under reduced
    // motion it hands back NoMotion and each bar renders at its flat target
    // instead (NoMotion freezes at the source value — it does not snap).
    final barMotion = motionFor(context, _barSpring, isMovement: true);

    final bars = widget.bars;
    // The crest is centred on the handle's position expressed in bar indices.
    final head = valueFraction * (bars - 1);
    final headIndex = head.round();

    // `/45` keeps the unfilled bars above the 3:1 non-text contrast floor in
    // both themes (source measured 4.16 dark / 3.13 light).
    final filledColor = colors.foreground;
    final mutedColor = colors.foreground.withValues(alpha: 0.45);

    final children = <Widget>[];
    for (var i = 0; i < bars; i++) {
      if (i > 0) children.add(const SizedBox(width: _barGap));
      final distance = (i - head).abs();
      // Gaussian crest centred on the handle.
      final crest = math.exp(-(distance * distance) / (2 * _spread * _spread));
      final target = reduce ? 0.4 : 0.22 + crest * (_dragging ? 0.78 : 0.6);
      children.add(
        Expanded(
          child: _WaveBar(
            key: beuiWaveSliderBarKey(i),
            target: target,
            // min(distance * 0.012s, 0.12s) — the stagger that makes the crest
            // travel instead of the whole row breathing at once.
            delay: Duration(
              microseconds: math.min(distance * 12000, 120000).round(),
            ),
            color: i <= headIndex ? filledColor : mutedColor,
            motion: barMotion,
          ),
        ),
      );
    }

    final slider = LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _onPanStart(d, trackWidth),
          onPanUpdate: (d) => _onPanUpdate(d, trackWidth),
          onPanEnd: (_) => _onPanEnd(),
          onPanCancel: _onPanEnd,
          child: SizedBox(
            key: beuiWaveSliderTrackKey,
            height: _trackHeight,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: SizedBox(
                    height: _barHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
                if (_focus.hasFocus)
                  beuiSliderFocusRing(
                    radius: _focusRadius,
                    color: colors.foreground.withValues(alpha: 0.3),
                  ),
              ],
            ),
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
        value: sliderValueText(widget.formatValueText),
        increasedValue: sliderStepUpText(widget.formatValueText),
        decreasedValue: sliderStepDownText(widget.formatValueText),
        onIncrease: enabled ? increaseSliderValue : null,
        onDecrease: enabled ? decreaseSliderValue : null,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: MouseRegion(
            cursor: enabled
                ? (_dragging
                      ? SystemMouseCursors.grabbing
                      : SystemMouseCursors.grab)
                : SystemMouseCursors.basic,
            child: Focus(
              focusNode: _focus,
              canRequestFocus: enabled,
              skipTraversal: !enabled,
              onKeyEvent: (_, event) => handleSliderKey(event),
              onFocusChange: (_) => setState(() {}),
              child: slider,
            ),
          ),
        ),
      ),
    );
  }
}

/// One equalizer bar.
///
/// Owns its own [Timer] because the stagger is a **per-bar delay** on the
/// spring (source `transition={{ ...SPRING_BAR, delay }}`) and `motor` has no
/// delay parameter: the bar holds the previous target until its delay elapses,
/// then re-points the spring. A newer target cancels a pending one, which is
/// exactly how Framer's delayed `animate` behaves under a fast drag.
class _WaveBar extends StatefulWidget {
  const _WaveBar({
    required this.target,
    required this.delay,
    required this.color,
    required this.motion,
    super.key,
  });

  final double target;
  final Duration delay;
  final Color color;

  /// Already resolved against reduced motion by the parent; [NoMotion] means
  /// render flat at [target] with no spring and no stagger.
  final Motion motion;

  bool get reduce => motion is NoMotion;

  @override
  State<_WaveBar> createState() => _WaveBarState();
}

class _WaveBarState extends State<_WaveBar> {
  late double _applied = widget.target;
  Timer? _timer;

  @override
  void didUpdateWidget(covariant _WaveBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduce) {
      _timer?.cancel();
      _timer = null;
      _applied = widget.target;
      return;
    }
    if (widget.target != oldWidget.target) {
      _timer?.cancel();
      if (widget.delay <= Duration.zero) {
        _applied = widget.target;
      } else {
        final pending = widget.target;
        _timer = Timer(widget.delay, () {
          if (mounted) setState(() => _applied = pending);
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const SizedBox.expand(),
    );
    // Reduced motion: flat 0.4, applied directly. NoMotion freezes at the
    // source value rather than snapping, so the builder is bypassed entirely
    // (the pattern `docs/PORTING_SPEC.md` §1 prescribes for discrete targets).
    if (widget.reduce) {
      return Transform.scale(scaleY: widget.target, child: bar);
    }
    return SingleMotionBuilder(
      value: _applied,
      motion: widget.motion,
      builder: (context, scaleY, child) =>
          Transform.scale(scaleY: scaleY, child: child),
      child: bar,
    );
  }
}
