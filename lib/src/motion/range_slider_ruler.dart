import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'range_slider_shared.dart';

// Source `range-slider-ruler.tsx` declares one component-local spring:
//
//   SPRING_SNAP = { stiffness: 500, damping: 40, mass: 0.6 }
//
// Over-damped (ζ ≈ 1.15) on purpose — the source comment reads "settle spring
// for the snap after a flick — quick, no overshoot past the tick". A ruler that
// bounced past the tick it just landed on would read as broken. It matches none
// of the five shared `beuiSpring*` tokens, so it ports verbatim as a local const
// per source `AGENTS.md` / `docs/PORTING_SPEC.md` §1.
const _snapSpring = SpringMotion(
  SpringDescription(mass: 0.6, stiffness: 500, damping: 40),
);

/// Framer `dragTransition={{ power: 0.22 }}` — the fraction of the release
/// velocity (px/s) that becomes coast distance (px). Framer's inertia model is
/// `amplitude = power × velocity`, so projecting the flick's landing point with
/// the same constant and then springing to the nearest tick reproduces
/// "momentum, then settle" as one continuous motion.
const double _momentumPower = 0.22;

/// Framer `dragElastic={0.03}` — how far past a constraint the strip may be
/// dragged. Three percent: just enough resistance to feel the end of the scale.
const double _dragElastic = 0.03;

// Geometry, from source: pt-1/pb-3 readout row (4/12px), text-3xl (30px)
// readout, h-12 (48px) scale, h-3.5/h-7 ticks (14/28px) with pb-[18px], and a
// bottom-5 (20px) needle 3×36px. Focus ring is rounded-2xl (16px).
const double _scaleHeight = 48;
const double _tickBottom = 18;
const double _minorTick = 14;
const double _majorTick = 28;
const double _needleBottom = 20;
const double _needleWidth = 3;
const double _needleHeight = 36;
const double _focusRadius = 16;
const double _labelBox = 48;

/// Test handle on the ruler slider's scrolling scale.
@visibleForTesting
const beuiRulerSliderStripKey = ValueKey<String>('beui_ruler_slider_strip');

/// Test handle on the ruler slider's fixed needle.
@visibleForTesting
const beuiRulerSliderNeedleKey = ValueKey<String>('beui_ruler_slider_needle');

/// Test handle on the ruler slider's numeric readout.
@visibleForTesting
const beuiRulerSliderReadoutKey = ValueKey<String>('beui_ruler_slider_readout');

/// A ruler slider — a one-to-one port of beUI's `range-slider-ruler`.
///
/// The needle stays put and the **scale scrolls under it**, rather than a handle
/// moving along a track. A flick carries momentum and settles onto the nearest
/// tick. Fractional steps read at the step's own precision, so `step: 0.5`
/// shows `72.5` while `step: 1` shows `72`.
///
/// Motion: the release is modelled as *one* continuous motion — the flick's
/// landing point is projected from the release velocity with Framer's own
/// inertia constant, snapped to the nearest tick, and then reached by the local
/// `SPRING_SNAP` (500/40/0.6) carrying that velocity forward. The source splits
/// this into an inertia transition followed by a snap spring; a single
/// velocity-seeded spring to the projected tick produces the same
/// coast-then-settle without a second animation kicking in mid-flight.
///
/// **Drag is a real control gesture, so it uses [GestureDetector]** (horizontal
/// drag), not `MouseRegion`. Keyboard: focus the ruler and the arrow keys nudge
/// by one [step] (Home/End jump to [min]/[max]); a key press takes the scale
/// back from momentum, so a coasting strip cannot swallow the input.
///
/// Controlled **or** uncontrolled: pass [value] + [onChanged], or seed
/// [defaultValue].
///
/// Reduced motion drops momentum entirely — the strip is placed on its tick the
/// instant you let go, exactly as the source's `dragMomentum={!reduce}` +
/// immediate `x.set(snapped)` branch does.
class BeuiRulerSlider extends StatefulWidget {
  /// Creates a ruler slider over `[min, max]` quantised to [step].
  const BeuiRulerSlider({
    this.value,
    this.defaultValue = 0,
    this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.enabled = true,
    this.gap = 14,
    this.majorEvery = 5,
    this.unit,
    this.formatValueText,
    this.label,
    super.key,
  }) : assert(min < max, 'min must be < max'),
       assert(step > 0, 'step must be > 0'),
       assert(gap > 0, 'gap must be > 0'),
       assert(majorEvery > 0, 'majorEvery must be > 0');

  /// The selected value (controlled). When null the slider holds its own state,
  /// seeded from [defaultValue].
  final double? value;

  /// The initial value when uncontrolled.
  final double defaultValue;

  /// Called with the new value on every step change during a drag / key press.
  /// (Source `onValueChange`.)
  final ValueChanged<double>? onChanged;

  /// Called once when the strip settles after a drag, with the final value.
  final ValueChanged<double>? onChangeEnd;

  /// Lower bound of the scale.
  final double min;

  /// Upper bound of the scale.
  final double max;

  /// Quantisation step. Also sets the readout's precision: `0.5` reads
  /// `"72.5"`, `1` reads `"72"`.
  final double step;

  /// Whether the slider responds to input. A disabled slider is dimmed and
  /// unfocusable. (Source `disabled`, inverted to match the repo convention.)
  final bool enabled;

  /// Pixels between two steps. Defaults to 14.
  final double gap;

  /// Label every Nth step; those ticks are drawn tall. Defaults to 5.
  final int majorEvery;

  /// Unit shown next to the value — and, unless [formatValueText] overrides it,
  /// folded into the announcement (`"72.5 kg"` beats a bare `"72.5"`).
  final String? unit;

  /// Announced instead of the raw number. Outranks the [unit]-derived default.
  final String Function(double value)? formatValueText;

  /// The source's `aria-label` — announced for the slider.
  final String? label;

  @override
  State<BeuiRulerSlider> createState() => _BeuiRulerSliderState();
}

class _BeuiRulerSliderState extends State<BeuiRulerSlider>
    with BeuiSliderStateMixin<BeuiRulerSlider>, SingleTickerProviderStateMixin {
  late final FocusNode _focus = FocusNode(debugLabel: 'beui_ruler_slider');
  late final SingleMotionController _x;

  /// While the pointer drives the strip (or its momentum still runs) `x` owns
  /// the value; outside of that the value owns `x`.
  bool _interacting = false;

  /// A new gesture or key press bumps this, so a settle that resolves late
  /// cannot clear [_interacting] underneath an active drag.
  int _gesture = 0;

  bool _reduce = false;

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
  void initState() {
    super.initState();
    _x = SingleMotionController(
      motion: _snapSpring,
      vsync: this,
      initialValue: _xFor(currentValue),
    )..addListener(_onStripMoved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The decision still goes through the central resolver even though the
    // component acts on it itself (spec §1, outcome 3): momentum is movement,
    // so a NoMotion answer means land on the tick with no coast at all.
    _reduce = motionFor(context, _snapSpring, isMovement: true) is NoMotion;
  }

  @override
  void didUpdateWidget(covariant BeuiRulerSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_interacting) _syncStrip();
  }

  @override
  void dispose() {
    _x
      ..removeListener(_onStripMoved)
      ..dispose();
    _focus.dispose();
    super.dispose();
  }

  // --- scale geometry -------------------------------------------------------

  /// `(max - min) / step`, float dust rounded off — the number of steps the
  /// scale spans, which need not be a whole number (0–10 by 4 spans 2.5).
  double get _span => roundSliderValue((widget.max - widget.min) / widget.step);

  /// Total travel of the strip, in pixels.
  double get _maxOffset => _span * widget.gap;

  double _xFor(double value) =>
      -((value - widget.min) / widget.step) * widget.gap;

  double _valueForX(double x) => widget.min + (-x / widget.gap) * widget.step;

  /// The nearest-tick position for a strip offset. [max] is a candidate in its
  /// own right, so a flick near the end does not settle on the last whole step.
  double _snappedX(double x) => _xFor(
    snapSliderValue(_valueForX(x), widget.min, widget.max, widget.step),
  );

  /// Hard bounds with the source's 3% rubber-band past them.
  double _withElastic(double x) {
    if (x > 0) return x * _dragElastic;
    if (x < -_maxOffset) return -_maxOffset + (x + _maxOffset) * _dragElastic;
    return x;
  }

  void _syncStrip() {
    // The source sets `x` outright here rather than animating: an external value
    // change is not a gesture, so the scale should already be where the value
    // says it is.
    final target = _xFor(currentValue);
    if (_x.value != target) _x.value = target;
  }

  // --- gesture --------------------------------------------------------------

  void _onStripMoved() {
    if (!_interacting) return;
    commitValue(_valueForX(_x.value));
  }

  void _onDragStart(DragStartDetails details) {
    if (!widget.enabled) return;
    _focus.requestFocus();
    _gesture++;
    _x.stop();
    setState(() => _interacting = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled || !_interacting) return;
    _x.value = _withElastic(_x.value + details.delta.dx);
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_interacting) return;
    _settle(details.velocity.pixelsPerSecond.dx);
  }

  void _onDragCancel() {
    if (!_interacting) return;
    _settle(0);
  }

  void _settle(double velocity) {
    final id = ++_gesture;
    if (_reduce) {
      // No momentum under reduced motion — land on the tick immediately.
      _x.value = _snappedX(_x.value);
      commitValue(_valueForX(_x.value), isEnd: true);
      setState(() => _interacting = false);
      return;
    }
    // Project where the flick would coast to, snap THAT to a tick, then let one
    // velocity-seeded spring carry the strip there: coast and settle in a single
    // continuous motion, with no second animation taking over mid-flight.
    final projected = _x.value + velocity * _momentumPower;
    final target = _snappedX(
      projected.clamp(-_maxOffset - widget.gap, widget.gap),
    );
    _x.animateTo(target, withVelocity: velocity).whenCompleteOrCancel(() {
      if (!mounted || _gesture != id) return;
      commitValue(_valueForX(_x.value), isEnd: true);
      setState(() => _interacting = false);
    });
  }

  KeyEventResult _onKey(KeyEvent event) {
    // A key press takes the scale back from momentum: without this the coasting
    // strip keeps committing its own value and swallows the keyboard input.
    _x.stop();
    _gesture++;
    _interacting = false;
    final result = handleSliderKey(event);
    if (result == KeyEventResult.handled) _syncStrip();
    return result;
  }

  // --- readout --------------------------------------------------------------

  /// Decimal places the step implies, so `0.5` reads "72.5" and `1` reads "72".
  /// A fixed width keeps the readout from jittering as the value rolls.
  int get _decimals {
    final text = widget.step.toString();
    final dot = text.indexOf('.');
    if (dot < 0) return 0;
    final fraction = text.substring(dot + 1);
    if (fraction == '0') return 0;
    return fraction.length;
  }

  String _readout(double value) => value.toStringAsFixed(_decimals);

  /// The `unit`-derived announcement (`"72.5 kg"`), or null when there is no
  /// unit — a bare number needs no value text.
  String Function(double value)? get _unitText => widget.unit == null
      ? null
      : (value) => '${_readout(value)} ${widget.unit}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final enabled = widget.enabled;

    final gap = widget.gap;
    final span = _span;
    // The range need not divide by the step (0–10 by 4). Full ticks stop at the
    // last whole one and max gets a tick of its own, so the scale never runs
    // past the value the slider can actually report.
    final wholeSteps = span.floor();
    final remainder = span - wholeSteps;

    final tickColor = colors.foreground.withValues(alpha: 0.7);
    // Minor ticks at /45 clear the 3:1 non-text contrast floor in both themes.
    final minorColor = colors.foreground.withValues(alpha: 0.45);

    Widget tickLine(double offset, {required bool major}) => Positioned(
      left: offset - 0.5,
      bottom: _tickBottom,
      width: 1,
      height: major ? _majorTick : _minorTick,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: major ? tickColor : minorColor,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );

    Widget tickLabel(double offset, double value) => Positioned(
      left: offset - _labelBox / 2,
      bottom: 0,
      width: _labelBox,
      child: Text(
        formatSliderNumber(value),
        textAlign: TextAlign.center,
        maxLines: 1,
        style: TextStyle(
          fontSize: 10,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: colors.mutedForeground,
        ),
      ),
    );

    final tickWidgets = <Widget>[];
    for (var i = 0; i <= wholeSteps; i++) {
      final offset = i * gap;
      final major = i % widget.majorEvery == 0;
      tickWidgets.add(tickLine(offset, major: major));
      if (major) {
        tickWidgets.add(
          tickLabel(offset, roundSliderValue(widget.min + i * widget.step)),
        );
      }
    }
    // A tiny remainder puts this label close to the one before it. That is what
    // a scale ending a hair past a step looks like.
    if (remainder > 0) {
      tickWidgets
        ..add(tickLine(_maxOffset, major: true))
        ..add(tickLabel(_maxOffset, widget.max));
    }

    // Built once per theme/config change and handed to the AnimatedBuilder as
    // its `child`, so a momentum frame only re-runs the Transform — not up to a
    // few hundred tick nodes.
    final tickLayer = RepaintBoundary(
      child: Stack(
        key: beuiRulerSliderStripKey,
        clipBehavior: Clip.none,
        children: tickWidgets,
      ),
    );

    final readoutRow = Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            _readout(currentValue),
            key: beuiRulerSliderReadoutKey,
            style: TextStyle(
              // `text-3xl` is 30/36, not 30/font-metrics. Without the explicit
              // line height the row is as tall as whatever font happens to be
              // resolved, which pushed the whole scale down the page.
              fontSize: 30,
              height: 36 / 30,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: colors.foreground,
            ),
          ),
          if (widget.unit != null) ...[
            const SizedBox(width: 4),
            Text(
              widget.unit!,
              // `text-sm` — 14/20.
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                color: colors.mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );

    final scale = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: _scaleHeight,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            // Masked, not overlaid with background-coloured gradients — the fade
            // has to work on any surface the slider is dropped onto.
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0x00000000),
                Color(0xFF000000),
                Color(0xFF000000),
                Color(0x00000000),
              ],
              stops: [0, 0.18, 0.82, 1],
            ).createShader(rect),
            child: Stack(
              // The source's mask lives on this box, and a CSS mask clips its
              // element to the border box (`mask-clip: border-box`). The needle
              // is `bottom-5 h-9` inside an `h-12` box, so its top 8px fall
              // outside and the browser cuts them. Clip here for the same
              // silhouette — unclipped, the needle spears up into the readout.
              clipBehavior: Clip.hardEdge,
              children: [
                AnimatedBuilder(
                  animation: _x,
                  child: tickLayer,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(width / 2 + _x.value, 0),
                    child: child,
                  ),
                ),
                // Needle — the read head the scale moves under.
                Positioned(
                  key: beuiRulerSliderNeedleKey,
                  left: width / 2 - _needleWidth / 2,
                  bottom: _needleBottom,
                  width: _needleWidth,
                  height: _needleHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.foreground,
                      borderRadius: BorderRadius.circular(_needleWidth / 2),
                    ),
                  ),
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
        value: sliderValueText(widget.formatValueText, _unitText),
        increasedValue: sliderStepUpText(widget.formatValueText ?? _unitText),
        decreasedValue: sliderStepDownText(widget.formatValueText ?? _unitText),
        onIncrease: enabled ? increaseSliderValue : null,
        onDecrease: enabled ? decreaseSliderValue : null,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: MouseRegion(
            cursor: enabled
                ? (_interacting
                      ? SystemMouseCursors.grabbing
                      : SystemMouseCursors.grab)
                : SystemMouseCursors.basic,
            child: Focus(
              focusNode: _focus,
              canRequestFocus: enabled,
              skipTraversal: !enabled,
              onKeyEvent: (_, event) => _onKey(event),
              onFocusChange: (_) => setState(() {}),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _onDragStart,
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                onHorizontalDragCancel: _onDragCancel,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // overflow-hidden on the root: the strip runs far past both
                    // edges. The focus ring sits OUTSIDE this clip, matching CSS
                    // (a ring is painted on the element, not clipped by its own
                    // overflow).
                    ClipRRect(
                      borderRadius: BorderRadius.circular(_focusRadius),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [readoutRow, scale],
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
            ),
          ),
        ),
      ),
    );
  }
}
