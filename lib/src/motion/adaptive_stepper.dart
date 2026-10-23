import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';

const _liquidMotion = CurvedMotion(
  Duration(milliseconds: 600),
  Cubic(0.22, 1.3, 0.71, 1),
);

/// A bounded quantity control whose value surface expands into unavailable
/// actions while preserving a fixed footprint.
///
/// Compose [BeuiAdaptiveStepperDecrement], [BeuiAdaptiveStepperValue], and
/// [BeuiAdaptiveStepperIncrement] as [children]. Supply [value] and
/// [onChanged] for controlled state, or seed [defaultValue] for internal state.
/// Values are clamped to [min] and [max].
class BeuiAdaptiveStepper extends StatefulWidget {
  /// Creates a composable adaptive stepper.
  const BeuiAdaptiveStepper({
    required this.children,
    this.value,
    this.defaultValue = 0,
    this.onChanged,
    this.min = 0,
    this.max = 10,
    this.step = 1,
    this.disabled = false,
    this.formatValueText,
    this.semanticLabel = 'Quantity',
    super.key,
  });

  /// The three stepper parts, typically in decrement/value/increment order.
  final List<Widget> children;

  /// The controlled value. When null, the stepper holds its own state.
  final double? value;

  /// Initial value for the uncontrolled stepper.
  final double defaultValue;

  /// Called after an enabled action changes the value.
  final ValueChanged<double>? onChanged;

  /// Lower inclusive bound.
  final double min;

  /// Upper inclusive bound.
  final double max;

  /// Positive step size. Non-positive or non-finite values use 1.
  final double step;

  /// Disables both actions.
  final bool disabled;

  /// Formats the value announced by assistive technology.
  final String Function(double value)? formatValueText;

  /// Accessible name for the quantity control.
  final String semanticLabel;

  @override
  State<BeuiAdaptiveStepper> createState() => _BeuiAdaptiveStepperState();
}

class _BeuiAdaptiveStepperState extends State<BeuiAdaptiveStepper> {
  late double _internalValue;
  int _direction = 0;
  final FocusNode _decrementFocus = FocusNode(debugLabel: 'Decrease value');
  final FocusNode _incrementFocus = FocusNode(debugLabel: 'Increase value');

  double get _lower => widget.min.isFinite ? widget.min : 0;
  double get _upper {
    final supplied = widget.max.isFinite ? widget.max : _lower;
    return supplied < _lower ? _lower : supplied;
  }

  double get _stride =>
      widget.step.isFinite && widget.step > 0 ? widget.step : 1;
  double get _value => _clamp(widget.value ?? _internalValue, _lower, _upper);
  bool get _atMin => _value <= _lower;
  bool get _atMax => _value >= _upper;

  @override
  void initState() {
    super.initState();
    final initial = widget.defaultValue.isFinite ? widget.defaultValue : _lower;
    _internalValue = _clamp(initial, _lower, _upper);
  }

  @override
  void dispose() {
    _decrementFocus.dispose();
    _incrementFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BeuiAdaptiveStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != null && widget.value != null) {
      if (widget.value! > oldWidget.value!) {
        _direction = 1;
      } else if (widget.value! < oldWidget.value!) {
        _direction = -1;
      }
    }
  }

  double _nextValue(bool increase) {
    final value = _value;
    final offset = (value - _lower) / _stride;
    final index = increase
        ? (offset + 1e-10).floor() + 1
        : (offset - 1e-10).ceil() - 1;
    final raw = _lower + index * _stride;
    return _clamp(double.parse(raw.toStringAsFixed(10)), _lower, _upper);
  }

  void _step(bool increase, {required bool restoreFocus}) {
    if (widget.disabled || (increase ? _atMax : _atMin)) return;
    final next = _nextValue(increase);
    if (next == _value) return;
    setState(() {
      _direction = increase ? 1 : -1;
      if (widget.value == null) _internalValue = next;
    });
    widget.onChanged?.call(next);

    if (!restoreFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (increase && _value >= _upper) {
        _decrementFocus.requestFocus();
      } else if (!increase && _value <= _lower) {
        _incrementFocus.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayValue = _value == _value.truncateToDouble()
        ? _value.toInt().toString()
        : _value.toString();
    final valueText = widget.formatValueText?.call(_value) ?? displayValue;
    return _AdaptiveStepperScope(
      value: _value,
      displayValue: displayValue,
      valueText: valueText,
      direction: _direction,
      atMin: _atMin,
      atMax: _atMax,
      disabled: widget.disabled,
      decrementFocus: _decrementFocus,
      incrementFocus: _incrementFocus,
      decrement: (keyboard) => _step(false, restoreFocus: keyboard),
      increment: (keyboard) => _step(true, restoreFocus: keyboard),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: widget.semanticLabel,
        value: valueText,
        enabled: !widget.disabled,
        child: SizedBox(
          width: 216,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _StepperLiquid(atMin: _atMin, atMax: _atMax),
              ...widget.children,
            ],
          ),
        ),
      ),
    );
  }
}

class _AdaptiveStepperScope extends InheritedWidget {
  const _AdaptiveStepperScope({
    required this.value,
    required this.displayValue,
    required this.valueText,
    required this.direction,
    required this.atMin,
    required this.atMax,
    required this.disabled,
    required this.decrementFocus,
    required this.incrementFocus,
    required this.decrement,
    required this.increment,
    required super.child,
  });

  final double value;
  final String displayValue;
  final String valueText;
  final int direction;
  final bool atMin;
  final bool atMax;
  final bool disabled;
  final FocusNode decrementFocus;
  final FocusNode incrementFocus;
  final ValueChanged<bool> decrement;
  final ValueChanged<bool> increment;

  static _AdaptiveStepperScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_AdaptiveStepperScope>();
    assert(
      scope != null,
      'Adaptive stepper parts must be inside BeuiAdaptiveStepper',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(_AdaptiveStepperScope oldWidget) =>
      value != oldWidget.value ||
      displayValue != oldWidget.displayValue ||
      valueText != oldWidget.valueText ||
      direction != oldWidget.direction ||
      atMin != oldWidget.atMin ||
      atMax != oldWidget.atMax ||
      disabled != oldWidget.disabled;
}

/// The decrement action, labelled “Decrease value”.
class BeuiAdaptiveStepperDecrement extends StatelessWidget {
  /// Creates the decrement action. An optional [child] replaces its icon.
  const BeuiAdaptiveStepperDecrement({this.child, super.key});

  /// Optional custom icon or action content.
  final Widget? child;

  @override
  Widget build(BuildContext context) => _AdaptiveStepperAction(
    increase: false,
    child: child ?? const Icon(LucideIcons.minus, size: 20),
  );
}

/// The live value surface, which expands to occupy space freed by a bound.
class BeuiAdaptiveStepperValue extends StatelessWidget {
  /// Creates the displayed value.
  const BeuiAdaptiveStepperValue({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = _AdaptiveStepperScope.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final colors = BeuiColors.resolve(context);
    final rect = _valueRect(scope);
    final movement = motionFor(context, _liquidMotion, isMovement: true);

    Widget output(Rect target) => Positioned.fromRect(
      rect: target,
      child: Semantics(
        liveRegion: true,
        label: scope.valueText,
        value: scope.valueText,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: Center(
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: reduce ? 0 : 180),
                  reverseDuration: Duration(milliseconds: reduce ? 0 : 120),
                  switchInCurve: beuiEaseOut,
                  switchOutCurve: beuiEaseOut,
                  transitionBuilder: (child, animation) {
                    final distance = reduce ? 0.0 : scope.direction * 0.32;
                    final exiting = animation.status == AnimationStatus.reverse;
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: exiting ? Offset.zero : Offset(0, distance),
                          end: exiting ? Offset(0, -distance) : Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    scope.displayValue,
                    key: ValueKey<String>(scope.displayValue),
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      color: colors.foreground,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (reduce) return output(rect);
    return MotionBuilder<Rect>(
      value: rect,
      motion: movement,
      converter: const RectMotionConverter(),
      builder: (context, current, _) => output(current),
    );
  }
}

/// The increment action, labelled “Increase value”.
class BeuiAdaptiveStepperIncrement extends StatelessWidget {
  /// Creates the increment action. An optional [child] replaces its icon.
  const BeuiAdaptiveStepperIncrement({this.child, super.key});

  /// Optional custom icon or action content.
  final Widget? child;

  @override
  Widget build(BuildContext context) => _AdaptiveStepperAction(
    increase: true,
    child: child ?? const Icon(LucideIcons.plus, size: 20),
  );
}

class _AdaptiveStepperAction extends StatefulWidget {
  const _AdaptiveStepperAction({required this.increase, required this.child});

  final bool increase;
  final Widget child;

  @override
  State<_AdaptiveStepperAction> createState() => _AdaptiveStepperActionState();
}

class _AdaptiveStepperActionState extends State<_AdaptiveStepperAction> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scope = _AdaptiveStepperScope.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final colors = BeuiColors.resolve(context);
    final hidden = widget.increase ? scope.atMax : scope.atMin;
    final focusNode = widget.increase
        ? scope.incrementFocus
        : scope.decrementFocus;
    final x = widget.increase
        ? (hidden ? 136.0 : 168.0)
        : (hidden ? 32.0 : 0.0);
    final rect = Rect.fromLTWH(x, 0, 48, 48);
    final movement = motionFor(context, _liquidMotion, isMovement: true);
    final label = widget.increase ? 'Increase value' : 'Decrease value';

    Widget actionAt(Rect target) {
      final action = Focus(
        canRequestFocus: !scope.disabled && !hidden,
        skipTraversal: hidden || scope.disabled,
        child: FocusableActionDetector(
          enabled: !scope.disabled && !hidden,
          focusNode: focusNode,
          mouseCursor: scope.disabled || hidden
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                if (!scope.disabled && !hidden) {
                  (widget.increase ? scope.increment : scope.decrement)(true);
                }
                return null;
              },
            ),
          },
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          onShowHoverHighlight: (value) => setState(() => _hovered = value),
          child: Listener(
            onPointerDown: (_) => setState(() => _pressed = true),
            onPointerUp: (_) => setState(() => _pressed = false),
            onPointerCancel: (_) => setState(() => _pressed = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: scope.disabled || hidden
                  ? null
                  : () => (widget.increase ? scope.increment : scope.decrement)(
                      false,
                    ),
              child: MouseRegion(
                onEnter: (_) => setState(() => _hovered = true),
                onExit: (_) => setState(() => _hovered = false),
                child: AnimatedOpacity(
                  opacity: hidden ? 0 : 1,
                  duration: Duration(milliseconds: reduce ? 0 : 140),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      color: !hidden && _hovered
                          ? colors.muted
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _focused ? colors.ring : Colors.transparent,
                        width: _focused ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: SingleMotionBuilder(
                        value: _pressed && !reduce && !hidden ? 0.94 : 1.0,
                        motion: motionFor(
                          context,
                          beuiSpringPress,
                          isMovement: true,
                        ),
                        builder: (context, scale, child) => Transform.scale(
                          scale: scale,
                          child: IconTheme(
                            data: IconThemeData(
                              color: scope.disabled
                                  ? colors.mutedForeground.withValues(
                                      alpha: 0.5,
                                    )
                                  : colors.foreground,
                              size: 20,
                            ),
                            child: child ?? widget.child,
                          ),
                        ),
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return Positioned.fromRect(
        rect: target,
        child: hidden
            ? ExcludeSemantics(child: action)
            : Semantics(
                button: true,
                label: label,
                enabled: !scope.disabled,
                child: action,
              ),
      );
    }

    if (reduce) return actionAt(rect);
    return MotionBuilder<Rect>(
      value: rect,
      motion: movement,
      converter: const RectMotionConverter(),
      builder: (context, current, _) => actionAt(current),
    );
  }
}

Rect _valueRect(_AdaptiveStepperScope scope) {
  if (scope.atMin && scope.atMax) return const Rect.fromLTWH(0, 0, 216, 48);
  if (scope.atMin) return const Rect.fromLTWH(0, 0, 152, 48);
  if (scope.atMax) return const Rect.fromLTWH(64, 0, 152, 48);
  return const Rect.fromLTWH(64, 0, 88, 48);
}

double _clamp(double value, double lower, double upper) {
  final finite = value.isFinite ? value : lower;
  return finite.clamp(lower, upper).toDouble();
}

class _StepperLiquid extends StatelessWidget {
  const _StepperLiquid({required this.atMin, required this.atMax});
  final bool atMin;
  final bool atMax;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final motion = motionFor(context, _liquidMotion, isMovement: true);
    final value = atMin && atMax
        ? const Rect.fromLTWH(0, 0, 216, 48)
        : atMin
        ? const Rect.fromLTWH(0, 0, 152, 48)
        : atMax
        ? const Rect.fromLTWH(64, 0, 152, 48)
        : const Rect.fromLTWH(64, 0, 88, 48);
    return MotionBuilder<Rect>(
      value: value,
      motion: motion,
      converter: const RectMotionConverter(),
      builder: (context, center, _) => SingleMotionBuilder(
        value: atMin ? 32 : 0,
        motion: motion,
        builder: (context, left, _) => SingleMotionBuilder(
          value: atMax ? 136 : 168,
          motion: motion,
          builder: (context, right, _) => IgnorePointer(
            child: CustomPaint(
              size: const Size(216, 48),
              painter: _LiquidPainter(
                rects: [
                  Rect.fromLTWH(left, 0, 48, 48),
                  center,
                  Rect.fromLTWH(right, 0, 48, 48),
                ],
                fill: colors.background,
                edge: colors.foreground.withValues(alpha: .08),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidPainter extends CustomPainter {
  const _LiquidPainter({
    required this.rects,
    required this.fill,
    required this.edge,
  });
  final List<Rect> rects;
  final Color fill;
  final Color edge;

  ui.ImageFilter _alpha(double slope, double intercept) => ColorFilter.matrix([
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    slope,
    intercept * 255,
  ]);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = (Offset.zero & size).inflate(48);
    final goo = ui.ImageFilter.compose(
      outer: _alpha(22, -8.67),
      inner: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
    );
    void shapes(ui.ImageFilter filter, BlendMode blend) {
      canvas.saveLayer(
        bounds,
        Paint()
          ..imageFilter = filter
          ..blendMode = blend,
      );
      for (final rect in rects) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(24)),
          Paint()..color = Colors.white,
        );
      }
      canvas.restore();
    }

    canvas.saveLayer(bounds, Paint());
    shapes(goo, BlendMode.srcOver);
    canvas.drawRect(
      bounds,
      Paint()
        ..color = fill
        ..blendMode = BlendMode.srcIn,
    );
    canvas.restore();

    final solid = ui.ImageFilter.compose(outer: _alpha(60, -29.5), inner: goo);
    canvas.saveLayer(bounds, Paint());
    shapes(solid, BlendMode.srcOver);
    shapes(
      ui.ImageFilter.compose(
        outer: ui.ImageFilter.erode(radiusX: 1, radiusY: 1),
        inner: solid,
      ),
      BlendMode.dstOut,
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..color = edge
        ..blendMode = BlendMode.srcIn,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LiquidPainter oldDelegate) =>
      fill != oldDelegate.fill ||
      edge != oldDelegate.edge ||
      List.generate(
        rects.length,
        (i) => rects[i] != oldDelegate.rects[i],
      ).any((changed) => changed);
}
