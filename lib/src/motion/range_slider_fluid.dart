import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'range_slider_shared.dart';

// Geometry, from source `range-slider-fluid.tsx`:
//   h-12        → 48px tall pill
//   rounded-full→ fully rounded (radius = height / 2)
//   px-5        → 20px horizontal padding on the label row
//   text-sm     → 14px, font-medium → w500
const double _height = 48;
const double _radius = _height / 2;
const double _padX = 20;

/// Scale the whole pill takes while grabbed (source `scale: dragging ? 1.03`).
const double _grabScale = 1.03;

/// Test handle on the fluid slider's track (the whole pill is the control).
@visibleForTesting
const beuiFluidSliderTrackKey = ValueKey<String>('beui_fluid_slider_track');

/// Test handle on the fluid slider's liquid fill.
@visibleForTesting
const beuiFluidSliderFillKey = ValueKey<String>('beui_fluid_slider_fill');

/// A thumbless slider — a one-to-one port of beUI's `range-slider-fluid`.
///
/// The whole pill is the control: there is no handle, the **fill** glides to the
/// new value behind a rounded liquid cap, and the label reads inverted wherever
/// the fill has covered it. The fill is revealed by *clipping a full-width
/// layer* rather than by animating a box's width (source: at 0% the clip is
/// empty, so no hairline of a sub-pixel box is left behind, and the label inside
/// is never re-laid out) — the clip's rounded right edge is the liquid cap.
///
/// Motion: the position glides under [beuiSliderGlideSpring] (`SPRING_GLIDE`,
/// over-damped — it eases onto the step and never rebounds), and grabbing the
/// pill grows it to 1.03 under [beuiSpringPress] (`SPRING_PRESS`).
///
/// **Drag is a real control gesture, so it uses [GestureDetector]** (pan), not
/// `MouseRegion` — that rule covers decorative hover effects only. Keyboard:
/// focus the pill and the arrow keys nudge by one [step] (Home/End jump to
/// [min]/[max]).
///
/// Controlled **or** uncontrolled: pass [value] + [onChanged], or seed
/// [defaultValue] and let the slider hold state.
///
/// Reduced motion places the fill at its step with **no glide** and drops the
/// grab-grow; the value still changes and the label still inverts.
class BeuiFluidSlider extends StatefulWidget {
  /// Creates a thumbless fluid slider over `[min, max]` quantised to [step].
  const BeuiFluidSlider({
    this.value,
    this.defaultValue = 0,
    this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.enabled = true,
    this.labelText,
    this.format,
    this.formatValueText,
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
  /// (Source `onValueChange`.)
  final ValueChanged<double>? onChanged;

  /// Called once when a drag gesture ends, with the final value.
  final ValueChanged<double>? onChangeEnd;

  /// Lower bound of the track.
  final double min;

  /// Upper bound of the track.
  final double max;

  /// Quantisation step; the fill snaps to the nearest multiple.
  final double step;

  /// Whether the slider responds to input. A disabled slider is dimmed and
  /// unfocusable. (Source `disabled`, inverted to match the repo convention.)
  final bool enabled;

  /// Text shown on the **left** of the track — the source's `label` prop.
  ///
  /// Named `labelText` because [label] already carries the source's `aria-label`
  /// across the whole slider family, matching `BeuiRangeSlider`. This is the
  /// same split Flutter's own `InputDecoration` makes.
  final String? labelText;

  /// Formats the value shown on the **right** of the track.
  ///
  /// Defaults to `"<value>%"`. The value arrives already snapped to [step], so
  /// it is not rounded again — that would make the label disagree with the
  /// announced value.
  final String Function(double value)? format;

  /// Announced instead of the raw number. Falls back to [format], so a caller
  /// who only sets [format] still gets `"35%"` read out rather than `"35"`.
  final String Function(double value)? formatValueText;

  /// The source's `aria-label` — announced for the slider.
  final String? label;

  @override
  State<BeuiFluidSlider> createState() => _BeuiFluidSliderState();
}

class _BeuiFluidSliderState extends State<BeuiFluidSlider>
    with BeuiSliderStateMixin<BeuiFluidSlider> {
  late final FocusNode _focus = FocusNode(debugLabel: 'beui_fluid_slider');

  bool _grabbed = false;

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

  String _format(double v) =>
      widget.format?.call(v) ?? '${formatSliderNumber(v)}%';

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details, double trackWidth) {
    if (!widget.enabled) return;
    _focus.requestFocus();
    setState(() => _grabbed = true);
    commitValue(sliderValueFromDx(details.localPosition.dx, trackWidth));
  }

  void _onPanUpdate(DragUpdateDetails details, double trackWidth) {
    if (!widget.enabled || !_grabbed) return;
    commitValue(sliderValueFromDx(details.localPosition.dx, trackWidth));
  }

  void _onPanEnd() {
    if (!_grabbed) return;
    setState(() => _grabbed = false);
    commitValue(currentValue, isEnd: true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.enabled;

    // The resolver owns the decision; NoMotion freezes at the source value
    // rather than snapping to the target, so under reduced motion we place the
    // fill directly at its step instead of piping NoMotion into the builder.
    final glideMotion = motionFor(
      context,
      beuiSliderGlideSpring,
      isMovement: true,
    );

    final valueText = _format(currentValue);

    // Two identical rows, drawn in opposite tones and pinned to the same box, so
    // the copy inverts glyph-for-glyph exactly where the fill's cap crosses it.
    Widget row(Color tone) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: _padX),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.labelText ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: tone,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            valueText,
            maxLines: 1,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: tone,
            ),
          ),
        ],
      ),
    );

    final slider = LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final targetFill = valueFraction * trackWidth;

        // Static per layout pass — the track, both label rows and the fill's
        // colour layer are built ONCE and reused by every spring frame, so a
        // frame only re-runs the clipper (identical widget instances
        // short-circuit their subtree rebuilds).
        final restingRow = IgnorePointer(child: row(colors.foreground));
        final invertedLayer = Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: ColoredBox(color: colors.foreground)),
            Positioned.fill(
              child: IgnorePointer(child: row(colors.background)),
            ),
          ],
        );

        Widget buildAt(double fillWidth) => Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_radius),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: ColoredBox(color: colors.muted)),
                    Positioned.fill(child: restingRow),
                    // The liquid cap — port of
                    // `clip-path: inset(0 N% 0 0 round 9999px)`. A `9999px`
                    // CSS radius is clamped by the used-value rules to half the
                    // clipped box's shorter side, so a narrow fill is a
                    // circle-ended lozenge and a full one is the track's own
                    // pill. At width 0 nothing is laid out at all, which is the
                    // whole reason the source clips instead of animating a
                    // width: no hairline of a sub-pixel box is left behind.
                    Positioned(
                      key: beuiFluidSliderFillKey,
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: sliderClamp(fillWidth, 0, trackWidth),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          math.min(fillWidth, _height) / 2,
                        ),
                        // The inverted copy stays full-track width and pinned
                        // left, so it never re-lays out as the cap sweeps
                        // across it — the text lines up glyph for glyph with
                        // the copy underneath.
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          maxWidth: trackWidth,
                          child: SizedBox(
                            width: trackWidth,
                            height: _height,
                            child: invertedLayer,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ring-inset: an outset ring would be shaved by the track's own
            // overflow-hidden, which is why the source insets this one.
            if (_focus.hasFocus)
              beuiSliderFocusRing(
                radius: _radius,
                color: colors.foreground.withValues(alpha: 0.4),
                inset: true,
              ),
          ],
        );

        final Widget body;
        if (glideMotion is NoMotion) {
          body = buildAt(targetFill); // reduced motion — snap, no glide
        } else {
          body = SingleMotionBuilder(
            value: targetFill,
            motion: glideMotion,
            builder: (context, w, _) => buildAt(w),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _onPanStart(d, trackWidth),
          onPanUpdate: (d) => _onPanUpdate(d, trackWidth),
          onPanEnd: (_) => _onPanEnd(),
          onPanCancel: _onPanEnd,
          child: SizedBox(
            key: beuiFluidSliderTrackKey,
            height: _height,
            width: double.infinity,
            child: body,
          ),
        );
      },
    );

    // Transient press feedback: the target itself is reduce-gated (spec §1 —
    // never freeze a press mid-squish by piping NoMotion into it).
    final pressed = _grabbed && enabled && !reduce;

    return MergeSemantics(
      child: Semantics(
        container: true,
        enabled: enabled,
        label: widget.label,
        slider: true,
        value: sliderValueText(widget.formatValueText, _format),
        increasedValue: sliderStepUpText(widget.formatValueText ?? _format),
        decreasedValue: sliderStepDownText(widget.formatValueText ?? _format),
        onIncrease: enabled ? increaseSliderValue : null,
        onDecrease: enabled ? decreaseSliderValue : null,
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
              skipTraversal: !enabled,
              onKeyEvent: (_, event) => handleSliderKey(event),
              onFocusChange: (_) => setState(() {}),
              child: SingleMotionBuilder(
                value: pressed ? _grabScale : 1.0,
                motion: motionFor(context, beuiSpringPress, isMovement: true),
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: slider,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
