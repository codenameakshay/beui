import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'range_slider_shared.dart';

// Source `range-slider-bubble.tsx` declares one component-local spring:
//
//   SPRING_TILT = { stiffness: 260, damping: 22, mass: 0.4 }
//
// Under-damped and deliberately loose (ζ ≈ 0.68) — the source comment reads
// "loose enough that the bubble keeps leaning a beat after the pointer stops".
// It matches none of the five shared `beuiSpring*` tokens, so it ports verbatim
// as a local const per source `AGENTS.md` / `docs/PORTING_SPEC.md` §1.
const _tiltSpring = SpringMotion(
  SpringDescription(mass: 0.4, stiffness: 260, damping: 22),
);

/// Drag speed — in **track percent per second** — that maxes out lean and
/// squash (source `FULL_TILT`).
const double _fullTilt = 320;

/// Exit motion for the bubble (source `exit: { transition: { duration: 0.12 } }`).
/// Deliberately faster than the spring entrance, per the library's motion rules.
const _bubbleExit = CurvedMotion(Duration(milliseconds: 120), beuiEaseOut);

// Geometry, from source: h-20 wrapper (80px) with px-5/pb-5 (20px) leaving room
// for the thumb, the bubble and the 48px hit area to overhang the 8px track.
const double _wrapperHeight = 80;
const double _wrapperPadX = 20;
const double _wrapperPadBottom = 20;
const double _trackHeight = 8;
const double _thumbSize = 20;
const double _hitOverhang = 20; // -inset-y-5 → 8 + 2×20 = 48px touch target
const double _bubbleLift = 24; // bottom-6

/// Test handle on the bubble slider's track.
@visibleForTesting
const beuiBubbleSliderTrackKey = ValueKey<String>('beui_bubble_slider_track');

/// Test handle on the bubble slider's thumb.
@visibleForTesting
const beuiBubbleSliderThumbKey = ValueKey<String>('beui_bubble_slider_thumb');

/// Test handle on the bubble slider's value bubble (only mounted while the
/// bubble is on screen).
@visibleForTesting
const beuiBubbleSliderBubbleKey = ValueKey<String>('beui_bubble_slider_bubble');

/// A slider with a velocity-reactive value bubble — a one-to-one port of beUI's
/// `range-slider-bubble`.
///
/// Grab the thumb and a value bubble pops out of it. The bubble reacts to **how
/// fast you drag**: it leans into the direction of travel and squashes along the
/// way, then settles upright when you let go. One spring drives the whole
/// reaction — lean is signed, squash reads its magnitude (source: two springs
/// off the same velocity would just run twice).
///
/// Motion, all four tokens as the source maps them:
/// * position → [beuiSliderGlideSpring] (`SPRING_GLIDE`), over-damped
/// * thumb grab scale 1.25 → [beuiSpringPress] (`SPRING_PRESS`)
/// * bubble entrance → [beuiSpringPanel] (`SPRING_PANEL`); exit is a flat 120ms
/// * lean/squash → the local `SPRING_TILT` (260/22/0.4), fed by the **velocity**
///   of the position spring
///
/// **Drag is a real control gesture, so it uses [GestureDetector]** (pan), not
/// `MouseRegion`. Keyboard: focus the track and the arrow keys nudge by one
/// [step] (Home/End jump to [min]/[max]).
///
/// Controlled **or** uncontrolled: pass [value] + [onChanged], or seed
/// [defaultValue].
///
/// Reduced motion places the fill and thumb at their step with no glide, drops
/// the grab-grow, drops lean/squash entirely, and fades the bubble in and out on
/// **opacity only** — the source's own reduce branch, and the rule that reduced
/// motion keeps opacity while dropping movement.
class BeuiBubbleSlider extends StatefulWidget {
  /// Creates a bubble slider over `[min, max]` quantised to [step].
  const BeuiBubbleSlider({
    this.value,
    this.defaultValue = 0,
    this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.enabled = true,
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

  /// Quantisation step.
  final double step;

  /// Whether the slider responds to input. A disabled slider is dimmed and
  /// unfocusable. (Source `disabled`, inverted to match the repo convention.)
  final bool enabled;

  /// Formats the value shown in the bubble.
  ///
  /// The value arrives already snapped to [step]; it is not rounded again, so
  /// the bubble never disagrees with the announced value on a fractional scale.
  final String Function(double value)? format;

  /// Announced instead of the raw number. Falls back to [format] — a bare
  /// number needs no value text, since it would only repeat the value itself.
  final String Function(double value)? formatValueText;

  /// The source's `aria-label` — announced for the slider.
  final String? label;

  @override
  State<BeuiBubbleSlider> createState() => _BeuiBubbleSliderState();
}

class _BeuiBubbleSliderState extends State<BeuiBubbleSlider>
    with BeuiSliderStateMixin<BeuiBubbleSlider> {
  late final FocusNode _focus = FocusNode(debugLabel: 'beui_bubble_slider');

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

    final glideMotion = motionFor(
      context,
      beuiSliderGlideSpring,
      isMovement: true,
    );
    // Case 2 of the resolver (a short fallback beats nothing, per drawer /
    // bottom-sheet): the springy dragging entrance collapses to the plain
    // exit curve under reduced motion instead of `beuiSpringPanel`.
    final revealMotion = motionFor(
      context,
      _dragging ? beuiSpringPanel : _bubbleExit,
      isMovement: true,
      reducedFallback: _bubbleExit,
    );

    final readout =
        widget.format?.call(currentValue) ?? formatSliderNumber(currentValue);

    // Everything is laid out in ONE 80px-tall Stack rather than nesting a
    // Stack inside the 8px track: a Stack hands its positioned children loose
    // constraints capped at its own size, so an 8px-tall Stack would squash the
    // bubble. Offsets are therefore measured from the wrapper's bottom edge,
    // with the source's px-5/pb-5 folded in as constants.
    const trackBottom = _wrapperPadBottom;
    const bubbleBottom = _wrapperPadBottom + _bubbleLift;
    const thumbBottom = _wrapperPadBottom + (_trackHeight - _thumbSize) / 2;
    const hitHeight = _trackHeight + 2 * _hitOverhang;
    const hitBottom = _wrapperPadBottom - _hitOverhang;

    final slider = LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = math.max(
          0.0,
          constraints.maxWidth - 2 * _wrapperPadX,
        );
        final targetPercent = valueFraction * 100;

        // Static per layout pass — rebuilt only when the theme or value text
        // changes, then reused by every spring frame.
        final trackBox = Positioned(
          left: _wrapperPadX,
          right: _wrapperPadX,
          bottom: trackBottom,
          height: _trackHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.muted,
              borderRadius: BorderRadius.circular(_trackHeight / 2),
            ),
          ),
        );
        final fillBox = DecoratedBox(
          decoration: BoxDecoration(
            color: colors.foreground,
            borderRadius: BorderRadius.circular(_trackHeight / 2),
          ),
        );
        final thumbBox = Container(
          key: beuiBubbleSliderThumbKey,
          width: _thumbSize,
          height: _thumbSize,
          decoration: BoxDecoration(
            color: colors.background,
            shape: BoxShape.circle,
            border: Border.all(color: colors.foreground, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        );
        final bubbleBox = _ValueBubble(
          text: readout,
          background: colors.foreground,
          foreground: colors.background,
        );

        Widget buildAt(double percent, double velocity) {
          final x = (percent / 100) * trackWidth;

          // One spring drives the whole reaction: lean is signed (which way the
          // bubble tips), squash reads its magnitude. Source maps velocity
          // [-320, 0, 320] → [1, 0, -1], clamped.
          final leanTarget = reduce
              ? 0.0
              : sliderClamp(-velocity / _fullTilt, -1, 1);

          Widget bubbleLayer(double reveal) {
            if (reveal <= 0.001 && !_dragging) return const SizedBox.shrink();
            // Enter and exit start from different places (scale 0.4 / y 10 in,
            // scale 0.5 / y 8 out), so the "from" tuple is chosen by direction
            // rather than replayed in reverse.
            final fromScale = _dragging ? 0.4 : 0.5;
            final fromY = _dragging ? 10.0 : 8.0;
            final scale = reduce ? 1.0 : fromScale + (1 - fromScale) * reveal;
            final dy = reduce ? 0.0 : fromY * (1 - reveal);

            return Opacity(
              opacity: sliderClamp(reveal, 0, 1),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: reduce
                    ? bubbleBox
                    : SingleMotionBuilder(
                        value: leanTarget,
                        motion: _tiltSpring,
                        builder: (context, lean, child) => Transform(
                          // originY: 1 — the bubble pivots on its own base, so
                          // it leans off the thumb rather than about its middle.
                          alignment: Alignment.bottomCenter,
                          transform:
                              Matrix4.rotationZ(lean * 16 * math.pi / 180)
                                ..multiply(
                                  Matrix4.diagonal3Values(
                                    (1 + lean.abs() * 0.18) * scale,
                                    (1 - lean.abs() * 0.12) * scale,
                                    1,
                                  ),
                                ),
                          child: child,
                        ),
                        child: bubbleBox,
                      ),
              ),
            );
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              trackBox,
              Positioned(
                left: _wrapperPadX,
                bottom: trackBottom,
                height: _trackHeight,
                width: x,
                child: fillBox,
              ),
              // Thumb — overhangs the track by half its width at both ends,
              // which the wrapper's padding leaves room for.
              Positioned(
                left: _wrapperPadX + x - _thumbSize / 2,
                bottom: thumbBottom,
                child: SingleMotionBuilder(
                  value: (_dragging && enabled && !reduce) ? 1.25 : 1.0,
                  motion: motionFor(context, beuiSpringPress, isMovement: true),
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: thumbBox,
                ),
              ),
              // Bubble — anchored to the thumb, leaning with drag velocity.
              Positioned(
                left: _wrapperPadX + x,
                bottom: bubbleBottom,
                child: IgnorePointer(
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, 0),
                    child: SingleMotionBuilder(
                      value: _dragging ? 1.0 : 0.0,
                      motion: revealMotion,
                      builder: (context, reveal, _) => bubbleLayer(reveal),
                    ),
                  ),
                ),
              ),
              // 8px of track is not a touch target — pad the hit area to 48px.
              Positioned(
                left: _wrapperPadX,
                right: _wrapperPadX,
                bottom: hitBottom,
                height: hitHeight,
                child: MouseRegion(
                  cursor: enabled
                      ? (_dragging
                            ? SystemMouseCursors.grabbing
                            : SystemMouseCursors.grab)
                      : SystemMouseCursors.basic,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) => _onPanStart(d, trackWidth),
                    onPanUpdate: (d) => _onPanUpdate(d, trackWidth),
                    onPanEnd: (_) => _onPanEnd(),
                    onPanCancel: _onPanEnd,
                  ),
                ),
              ),
              // LAST, and after the gesture surface: a conditional child
              // inserted BEFORE the GestureDetector would shift it down a slot
              // when focus arrives mid-gesture, and Flutter would rebuild its
              // recognizer state — silently dropping the in-flight drag. It
              // also matches the source, where the ringed button is the last
              // child. IgnorePointer keeps it out of hit testing.
              // The ring hugs the 48px hit surface (source puts it on the
              // button, not the 8px track), rounded-full → radius 24.
              if (_focus.hasFocus)
                Positioned(
                  left: _wrapperPadX - 4,
                  right: _wrapperPadX - 4,
                  bottom: hitBottom - 4,
                  height: hitHeight + 8,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: colors.foreground.withValues(alpha: 0.3),
                          width: 4,
                        ),
                        borderRadius: BorderRadius.circular(hitHeight / 2 + 4),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }

        // The position spring's own VELOCITY is what the bubble reacts to, so
        // it is read straight off the builder rather than differenced by hand.
        // Reduced motion bypasses the builder entirely: NoMotion freezes at the
        // source value instead of snapping, so the fill would stick.
        final Widget body;
        if (glideMotion is NoMotion) {
          body = buildAt(targetPercent, 0);
        } else {
          body = SingleVelocityMotionBuilder(
            value: targetPercent,
            motion: glideMotion,
            builder: (context, percent, velocity, _) =>
                buildAt(percent, velocity),
          );
        }

        return SizedBox(
          key: beuiBubbleSliderTrackKey,
          height: _wrapperHeight,
          width: double.infinity,
          child: body,
        );
      },
    );

    return MergeSemantics(
      child: Semantics(
        container: true,
        enabled: enabled,
        label: widget.label,
        slider: true,
        value: sliderValueText(widget.formatValueText, widget.format),
        increasedValue: sliderStepUpText(
          widget.formatValueText ?? widget.format,
        ),
        decreasedValue: sliderStepDownText(
          widget.formatValueText ?? widget.format,
        ),
        onIncrease: enabled ? increaseSliderValue : null,
        onDecrease: enabled ? decreaseSliderValue : null,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
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
    );
  }
}

/// The bubble itself — a rounded readout with a rotated-square tail, matching
/// the source's `rounded-xl … px-2.5 py-1` panel plus its `-bottom-1` tail.
class _ValueBubble extends StatelessWidget {
  const _ValueBubble({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: beuiBubbleSliderBubbleKey,
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            text,
            maxLines: 1,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: foreground,
            ),
          ),
        ),
        Positioned(
          bottom: -4,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
