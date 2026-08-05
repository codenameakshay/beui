/// Internal foundation shared by the beUI slider family.
///
/// The source's five slider components (`range-slider`, `-fluid`, `-wave`,
/// `-bubble`, `-ruler`) all sit on one hook, `lib/hooks/use-slider.ts`, which
/// owns the controlled/uncontrolled value, the snap-to-step rule, the keyboard
/// contract and the ARIA wiring. This file is that hook's Flutter port:
/// [BeuiSliderStateMixin] for the value/keyboard half, [snapSliderValue] for the
/// snap rule, plus the family's shared spring token and focus ring.
///
/// **Not a widget and not exported from `lib/beui.dart`** — it is library
/// -private plumbing, so it does not violate the one-widget-per-file rule.
library;

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '_engine.dart';

/// `SPRING_GLIDE` — the slider family's **position** spring (source
/// `lib/ease.ts`).
///
/// stiffness 700 · damping 50 · mass 0.5 → ζ ≈ 1.5, over-damped, so a fill or
/// handle eases onto its snapped step and stops dead on the tick with no
/// rebound off either end. Consumed by `range-slider.tsx`,
/// `range-slider-fluid.tsx` and `range-slider-bubble.tsx`.
///
/// It is deliberately **not** one of the five `beuiSpring*` tokens in
/// `lib/src/tokens/motion.dart` — `docs/PORTING_SPEC.md` §1 files it under
/// *component-local springs* for `range-slider.tsx`. Because three sliders
/// share it, it gets exactly one definition here rather than a copy per file.
const beuiSliderGlideSpring = SpringMotion(
  SpringDescription(mass: 0.5, stiffness: 700, damping: 50),
);

/// Clamps [value] into `[lo, hi]`.
double sliderClamp(double value, double lo, double hi) =>
    math.min(hi, math.max(lo, value));

/// Rounds float dust off a computed step value.
///
/// Port of the source's `Number(x.toFixed(6))` guard: `0.1 + 0.2` is
/// `0.30000000000000004`, which would otherwise leak into tick labels and into
/// the `==` comparison that decides whether to fire `onChanged`.
double roundSliderValue(double value) => (value * 1e6).roundToDouble() / 1e6;

/// The nearest-tick rule shared by every slider — port of the source's
/// `snapSliderValue`.
///
/// [max] counts as a candidate in its own right, so a range the step does not
/// divide (0–10 by 4) can still report its own maximum instead of settling on
/// the last whole step (8).
double snapSliderValue(double value, double min, double max, double step) {
  final v = sliderClamp(value, min, max);
  final steps = ((v - min) / step).roundToDouble();
  final snapped = sliderClamp(roundSliderValue(min + steps * step), min, max);
  if ((v - max).abs() < (v - snapped).abs()) return max;
  return snapped;
}

/// Renders a number the way JavaScript's `String(number)` does: no trailing
/// `.0`, so a whole-number scale reads `40` and a half-step scale reads `72.5`.
String formatSliderNumber(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return roundSliderValue(value).toString();
}

/// The source's `focus-visible:ring-4` — a 4px ring painted **outside** the box
/// (Tailwind rings are outsets), as a border rather than a shadow so it never
/// fills the box it surrounds.
///
/// Place inside a `Stack(clipBehavior: Clip.none)`. Pass [inset] `true` for the
/// one component whose track is `overflow-hidden` (fluid), where the source
/// switches to `ring-inset` for exactly the same reason.
Widget beuiSliderFocusRing({
  required double radius,
  required Color color,
  bool inset = false,
  double width = 4,
}) {
  final ring = IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color, width: width),
        borderRadius: BorderRadius.circular(inset ? radius : radius + width),
      ),
    ),
  );
  if (inset) return Positioned.fill(child: ring);
  return Positioned(
    left: -width,
    top: -width,
    right: -width,
    bottom: -width,
    child: ring,
  );
}

/// The value / keyboard / a11y half of the source's `useSlider` hook.
///
/// A slider `State` mixes this in and forwards the eight `SliderOptions`
/// getters to its widget; it gets [currentValue], [valueFraction],
/// [commitValue], [handleSliderKey] and the semantics helpers for free. Every
/// slider therefore snaps identically, announces identically, and honours the
/// same key bindings — matching the source, where one hook backs all five.
mixin BeuiSliderStateMixin<W extends StatefulWidget> on State<W> {
  /// The controlled value, or null when the slider owns its state.
  double? get sliderValue;

  /// Seed for the internal value when [sliderValue] is null.
  double get sliderDefaultValue;

  /// Lower bound of the scale.
  double get sliderMin;

  /// Upper bound of the scale.
  double get sliderMax;

  /// Quantisation step.
  double get sliderStep;

  /// Whether the control accepts input.
  bool get sliderEnabled;

  /// Fired on every step change.
  ValueChanged<double>? get sliderOnChanged;

  /// Fired once when a drag gesture ends.
  ValueChanged<double>? get sliderOnChangeEnd;

  double? _internal;

  @override
  void initState() {
    super.initState();
    _internal = snapSliderValue(
      sliderDefaultValue,
      sliderMin,
      sliderMax,
      sliderStep,
    );
  }

  /// Whether the parent owns the value.
  bool get isSliderControlled => sliderValue != null;

  /// The live value, clamped into `[min, max]`.
  double get currentValue => sliderClamp(
    isSliderControlled ? sliderValue! : _internal!,
    sliderMin,
    sliderMax,
  );

  /// [currentValue] as a `0..1` position along the scale.
  double get valueFraction {
    final span = sliderMax - sliderMin;
    if (span <= 0) return 0;
    return (currentValue - sliderMin) / span;
  }

  /// Snaps [rawValue] to the nearest step and publishes it.
  ///
  /// Uncontrolled sliders update their own state; controlled ones only notify —
  /// the parent feeding [sliderValue] back is what moves the handle, the
  /// Flutter `Slider` contract.
  void commitValue(double rawValue, {bool isEnd = false}) {
    final snapped = snapSliderValue(rawValue, sliderMin, sliderMax, sliderStep);
    if (snapped != currentValue) {
      if (!isSliderControlled) setState(() => _internal = snapped);
      sliderOnChanged?.call(snapped);
    }
    if (isEnd) sliderOnChangeEnd?.call(snapped);
  }

  /// One step up.
  void increaseSliderValue() => commitValue(currentValue + sliderStep);

  /// One step down.
  void decreaseSliderValue() => commitValue(currentValue - sliderStep);

  /// The source's key contract, key for key: `←`/`↓` step down, `→`/`↑` step
  /// up, `Home` → [sliderMin], `End` → [sliderMax]. There is deliberately no
  /// PageUp/PageDown — the source has none.
  KeyEventResult handleSliderKey(KeyEvent event) {
    if (!sliderEnabled) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp) {
      increaseSliderValue();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown) {
      decreaseSliderValue();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      commitValue(sliderMin);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      commitValue(sliderMax);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Maps a local pointer x over a [trackWidth]-wide track to a raw value.
  double sliderValueFromDx(double dx, double trackWidth) {
    if (trackWidth <= 0) return sliderMin;
    final ratio = sliderClamp(dx / trackWidth, 0, 1);
    return sliderMin + ratio * (sliderMax - sliderMin);
  }

  /// The string a screen reader announces (`aria-valuetext`).
  ///
  /// [formatValueText] is the caller's override; [fallback] is the component's
  /// own formatter (fluid's `format`, ruler's `unit`), which the source lets a
  /// caller-supplied `formatValueText` outrank.
  String sliderValueText(
    String Function(double value)? formatValueText, [
    String Function(double value)? fallback,
  ]) =>
      formatValueText?.call(currentValue) ??
      fallback?.call(currentValue) ??
      formatSliderNumber(currentValue);

  /// `aria-valuetext` for one step up, for `Semantics.increasedValue`.
  String sliderStepUpText(String Function(double value)? formatValueText) {
    final next = snapSliderValue(
      currentValue + sliderStep,
      sliderMin,
      sliderMax,
      sliderStep,
    );
    return formatValueText?.call(next) ?? formatSliderNumber(next);
  }

  /// `aria-valuetext` for one step down, for `Semantics.decreasedValue`.
  String sliderStepDownText(String Function(double value)? formatValueText) {
    final prev = snapSliderValue(
      currentValue - sliderStep,
      sliderMin,
      sliderMax,
      sliderStep,
    );
    return formatValueText?.call(prev) ?? formatSliderNumber(prev);
  }
}
