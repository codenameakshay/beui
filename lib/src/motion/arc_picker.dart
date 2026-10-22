import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart' show NoMotion, SingleMotionController, SpringMotion;

// The source's SPRING_GLIDE (700 / 50 / 0.5) follows wheel and pointer input
// without lag; SPRING_LAYOUT settles the final detent and bracket frame.
const _glideSpring = SpringMotion(
  SpringDescription(mass: 0.5, stiffness: 700, damping: 50),
);
const _coastSeconds = 0.18;
const _wheelSettleDelay = Duration(milliseconds: 120);
const _bracketGap = 4.0;

/// One choice in a [BeuiArcPicker].
@immutable
class BeuiArcPickerOption {
  /// Creates an option with a stable [value], display [label], and optional
  /// disabled state.
  const BeuiArcPickerOption({
    required this.value,
    required this.label,
    this.disabled = false,
  });

  /// Stable identity returned by [BeuiArcPicker.onChanged].
  final String value;

  /// Text shown on the arc.
  final String label;

  /// Whether this option can be selected.
  final bool disabled;
}

/// The direction in which a [BeuiArcPicker]'s curve bows.
enum BeuiArcPickerSide { top, bottom, left, right }

/// A radial single-choice picker with drag momentum and keyboard controls.
///
/// Pass [value] and [onChanged] for controlled use, or omit [value] and seed
/// [defaultValue] to let the picker manage selection. Top and bottom arcs are
/// scrolled horizontally; left and right arcs are scrolled vertically.
class BeuiArcPicker extends StatefulWidget {
  /// Creates an arc picker over [options].
  const BeuiArcPicker({
    required this.options,
    this.value,
    this.defaultValue,
    this.onChanged,
    this.side = BeuiArcPickerSide.right,
    this.radius = 280,
    this.visibleCount = 7,
    this.itemHeight = 48,
    this.disabled = false,
    this.semanticLabel = 'Choose an option',
    super.key,
  });

  /// The choices displayed around the arc.
  final List<BeuiArcPickerOption> options;

  /// Controlled selected value. When null, [defaultValue] seeds internal state.
  final String? value;

  /// Initial value for uncontrolled use.
  final String? defaultValue;

  /// Called each time an enabled choice is selected or crossed.
  final ValueChanged<String>? onChanged;

  /// Direction the curve bows toward.
  final BeuiArcPickerSide side;

  /// Curve radius in logical pixels. Larger values make a gentler arc.
  final double radius;

  /// Number of choices visible along the arc.
  final int visibleCount;

  /// Minimum spacing between choices in logical pixels.
  final double itemHeight;

  /// Whether the entire picker is disabled.
  final bool disabled;

  /// Accessible label for the radio group.
  final String? semanticLabel;

  @override
  State<BeuiArcPicker> createState() => _BeuiArcPickerState();
}

class _BeuiArcPickerState extends State<BeuiArcPicker>
    with SingleTickerProviderStateMixin {
  late final SingleMotionController _position;
  late final FocusNode _focusNode = FocusNode(debugLabel: 'BeuiArcPicker');
  Timer? _wheelTimer;
  int? _internalIndex;
  int _selectedIndex = 0;
  int _lastPublished = -1;
  int _interaction = 0;
  double? _wheelTarget;
  double _dragStartCoordinate = 0;
  double _dragStartPosition = 0;
  double _lastCoordinate = 0;
  Duration _lastTime = Duration.zero;
  double _velocity = 0;
  bool _dragging = false;
  bool _tracking = false;
  bool _reduce = false;
  bool _focusVisible = false;

  bool get _horizontal =>
      widget.side == BeuiArcPickerSide.top ||
      widget.side == BeuiArcPickerSide.bottom;

  double get _spacing => math.max(
    math.max(32, widget.itemHeight.isFinite ? widget.itemHeight : 48),
    _horizontal ? _widestLabel + 48 : 0,
  );

  double get _widestLabel {
    if (widget.options.isEmpty) return 0;
    final style = const TextStyle(fontSize: 24, fontWeight: FontWeight.w300);
    return widget.options
        .map(
          (option) =>
              (TextPainter(
                text: TextSpan(text: option.label, style: style),
                textDirection: Directionality.of(context),
              )..layout()).width +
              16,
        )
        .fold<double>(0, math.max);
  }

  int get _firstEnabled => widget.options.indexWhere((o) => !o.disabled);
  int get _lastEnabled => widget.options.lastIndexWhere((o) => !o.disabled);

  int _indexFor(String? value) {
    final index = widget.options.indexWhere(
      (option) => option.value == value && !option.disabled,
    );
    return index >= 0 ? index : math.max(0, _firstEnabled);
  }

  int get _activeIndex => widget.value == null
      ? (_internalIndex ?? _indexFor(widget.defaultValue))
      : _indexFor(widget.value);

  double get _radius =>
      math.max(120, widget.radius.isFinite ? widget.radius : 280);

  int get _count => math.max(3, widget.visibleCount);

  @override
  void initState() {
    super.initState();
    _selectedIndex = _indexFor(widget.value ?? widget.defaultValue);
    _internalIndex = widget.value == null ? _selectedIndex : null;
    _lastPublished = _selectedIndex;
    _position = SingleMotionController(
      motion: _glideSpring,
      vsync: this,
      initialValue: _selectedIndex.toDouble(),
    )..addListener(_onPositionChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = motionFor(context, _glideSpring, isMovement: true) is NoMotion;
  }

  @override
  void didUpdateWidget(covariant BeuiArcPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _activeIndex;
    if (widget.value != null && widget.value != oldWidget.value) {
      _interaction++;
      _tracking = false;
      _selectedIndex = target;
      _lastPublished = target;
      if (_reduce) {
        _position.value = target.toDouble();
      } else {
        _position.animateTo(target.toDouble());
      }
    }
    if (oldWidget.options != widget.options &&
        _selectedIndex >= widget.options.length) {
      _selectedIndex = _indexFor(widget.value ?? widget.defaultValue);
      _position.value = _selectedIndex.toDouble();
    }
  }

  @override
  void dispose() {
    _wheelTimer?.cancel();
    _position
      ..removeListener(_onPositionChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onPositionChanged() {
    if (!_tracking) return;
    final at = _position.value.round().clamp(0, widget.options.length - 1);
    if (at == _lastPublished || widget.options.isEmpty) return;
    final direction = at > _lastPublished ? 1 : -1;
    for (
      var index = _lastPublished + direction;
      direction > 0 ? index <= at : index >= at;
      index += direction
    ) {
      if (!widget.options[index].disabled) _publish(index);
    }
  }

  void _publish(int index) {
    if (index < 0 ||
        index >= widget.options.length ||
        widget.options[index].disabled ||
        widget.disabled) {
      return;
    }
    _lastPublished = index;
    _selectedIndex = index;
    if (widget.value == null) setState(() => _internalIndex = index);
    widget.onChanged?.call(widget.options[index].value);
  }

  int _nearestEnabled(double position) {
    var best = _firstEnabled;
    if (best < 0) return 0;
    var distance = double.infinity;
    for (var i = 0; i < widget.options.length; i++) {
      if (widget.options[i].disabled) continue;
      final candidate = (i - position).abs();
      if (candidate < distance) {
        best = i;
        distance = candidate;
      }
    }
    return best;
  }

  void _settle(double target, {double velocity = 0}) {
    final interaction = ++_interaction;
    _wheelTimer?.cancel();
    _wheelTimer = null;
    _wheelTarget = null;
    _dragging = false;
    _tracking = !_reduce;
    final settledIndex = _nearestEnabled(
      target.clamp(0.0, math.max(0, widget.options.length - 1).toDouble()),
    );
    _publish(settledIndex);
    if (_reduce) {
      _position.value = settledIndex.toDouble();
      _tracking = false;
    } else {
      _position
          .animateTo(settledIndex.toDouble(), withVelocity: velocity)
          .whenCompleteOrCancel(() {
            if (mounted && interaction == _interaction) _tracking = false;
          });
    }
  }

  void _moveTo(int target) {
    if (widget.disabled || widget.options.isEmpty) return;
    _interaction++;
    _position.stop(canceled: true);
    _wheelTimer?.cancel();
    _wheelTarget = null;
    _dragging = false;
    _tracking = false;
    target = _nearestEnabled(target.toDouble());
    _publish(target);
    _lastPublished = target;
    if (_reduce) {
      _position.value = target.toDouble();
    } else {
      _position.animateTo(target.toDouble());
    }
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || widget.disabled || widget.options.isEmpty) {
      return;
    }
    final enabled = <int>[
      for (var i = 0; i < widget.options.length; i++)
        if (!widget.options[i].disabled) i,
    ];
    if (enabled.isEmpty) return;
    final current = enabled
        .indexOf(_selectedIndex)
        .clamp(0, enabled.length - 1);
    var next = current;
    final step = HardwareKeyboard.instance.isShiftPressed ? 5 : 1;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.arrowRight:
        next = current + step;
        break;
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.arrowLeft:
        next = current - step;
        break;
      case LogicalKeyboardKey.pageDown:
        next = current + 5;
        break;
      case LogicalKeyboardKey.pageUp:
        next = current - 5;
        break;
      case LogicalKeyboardKey.home:
        next = 0;
        break;
      case LogicalKeyboardKey.end:
        next = enabled.length - 1;
        break;
      default:
        return;
    }
    next = next.clamp(0, enabled.length - 1);
    _moveTo(enabled[next]);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        widget.disabled ||
        widget.options.isEmpty ||
        event.scrollDelta == Offset.zero) {
      return;
    }
    final delta = _horizontal
        ? (event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
              ? event.scrollDelta.dx
              : event.scrollDelta.dy)
        : event.scrollDelta.dy;
    final current = _wheelTarget ?? _position.value;
    if ((current <= _firstEnabled && delta < 0) ||
        (current >= _lastEnabled && delta > 0)) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (signal) {
      if (signal is! PointerScrollEvent) return;
      _wheelTimer?.cancel();
      if (_reduce) {
        _moveTo(_nearestEnabled(_selectedIndex + (delta.sign)));
        return;
      }
      _position.stop(canceled: true);
      _dragging = true;
      final target = (current + delta / _spacing).clamp(
        _firstEnabled.toDouble(),
        _lastEnabled.toDouble(),
      );
      _wheelTarget = target;
      _position.value = target;
      _tracking = true;
      _wheelTimer = Timer(_wheelSettleDelay, () => _settle(target));
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.disabled || widget.options.isEmpty || event.buttons != 1) return;
    _interaction++;
    _position.stop(canceled: true);
    _wheelTimer?.cancel();
    _wheelTarget = null;
    _dragging = true;
    _tracking = true;
    _dragStartCoordinate = _horizontal ? event.position.dx : event.position.dy;
    _lastCoordinate = _dragStartCoordinate;
    _dragStartPosition = _position.value;
    _lastTime = event.timeStamp;
    _velocity = 0;
    _focusNode.requestFocus();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_dragging) return;
    final coordinate = _horizontal ? event.position.dx : event.position.dy;
    final delta = coordinate - _dragStartCoordinate;
    final elapsed = (event.timeStamp - _lastTime).inMicroseconds / 1e6;
    if (elapsed > 0) {
      final instant = -((coordinate - _lastCoordinate) / _spacing) / elapsed;
      _velocity = _velocity * 0.35 + instant * 0.65;
    }
    _lastCoordinate = coordinate;
    _lastTime = event.timeStamp;
    final target = (_dragStartPosition - delta / _spacing).clamp(
      _firstEnabled.toDouble(),
      _lastEnabled.toDouble(),
    );
    _position.value = _reduce ? target.roundToDouble() : target;
  }

  void _onPointerUp(PointerEvent event) {
    if (!_dragging) return;
    final velocity = (event.timeStamp - _lastTime).inMilliseconds > 100
        ? 0.0
        : _velocity;
    _settle(
      _position.value + (_reduce ? 0 : velocity * _coastSeconds),
      velocity: velocity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce =
        motionFor(context, _glideSpring, isMovement: true) is NoMotion;
    if (reduce != _reduce) {
      _reduce = reduce;
      if (reduce) _position.value = _selectedIndex.toDouble();
    }
    final rowHeight = math.max(
      32,
      widget.itemHeight.isFinite ? widget.itemHeight : 48,
    );
    final height =
        (_horizontal
                ? math
                      .max(
                        rowHeight * 2,
                        _radius *
                                (1 -
                                    math.cos(
                                      math.min(
                                        1.35,
                                        _count * _spacing / (2 * _radius),
                                      ),
                                    )) +
                            rowHeight +
                            24,
                      )
                      .ceilToDouble()
                : _count * rowHeight)
            .toDouble();
    final width = _horizontal ? null : 240.0;
    final anchor = _horizontal
        ? 0.5
        : widget.side == BeuiArcPickerSide.left
        ? 0.58
        : 0.42;
    final textStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w300,
      color: colors.mutedForeground,
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      hint:
          'Drag ${_horizontal ? 'horizontally' : 'vertically'} or scroll to choose. Use arrow keys to move, Home and End to jump.',
      enabled: !widget.disabled,
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: !widget.disabled,
        onKeyEvent: (node, event) {
          final old = _selectedIndex;
          _onKey(event);
          return old != _selectedIndex
              ? KeyEventResult.handled
              : KeyEventResult.ignored;
        },
        onFocusChange: (value) => setState(() => _focusVisible = value),
        child: Listener(
          onPointerSignal: _onPointerSignal,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerUp,
          child: SizedBox(
            width: width,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                boxShadow: _focusVisible
                    ? [BoxShadow(color: colors.focusRing, spreadRadius: 2)]
                    : null,
              ),
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    for (var index = 0; index < widget.options.length; index++)
                      AnimatedBuilder(
                        animation: _position,
                        builder: (context, _) {
                          final at = _position.value;
                          final distance = index - at;
                          final angle = (distance * _spacing / _radius).clamp(
                            -1.5,
                            1.5,
                          );
                          final bend = _radius * (1 - math.cos(angle));
                          final along = _radius * math.sin(angle);
                          final dx = _horizontal
                              ? along
                              : widget.side == BeuiArcPickerSide.left
                              ? bend
                              : -bend;
                          final dy = _horizontal
                              ? (widget.side == BeuiArcPickerSide.top
                                    ? bend
                                    : -bend)
                              : along;
                          final centerY = _horizontal
                              ? widget.side == BeuiArcPickerSide.top
                                    ? 36.0
                                    : height - 36
                              : height / 2;
                          final centerX = _horizontal ? 0.0 : width! * anchor;
                          final selected = index == _activeIndex;
                          final option = widget.options[index];
                          final visibleOpacity =
                              (((_count / 2 + 0.5 - distance.abs()) / 1.5)
                                      .clamp(0, 1))
                                  .toDouble();
                          final rotation =
                              widget.side == BeuiArcPickerSide.left ||
                                  widget.side == BeuiArcPickerSide.bottom
                              ? -angle
                              : angle;
                          final maxWidth = _horizontal ? 240.0 : width! - 48;
                          return Positioned(
                            left: _horizontal ? 0 : centerX + dx,
                            right: _horizontal ? 0 : null,
                            top: centerY + dy - 12,
                            width: _horizontal ? null : maxWidth,
                            child: Transform.translate(
                              offset: _horizontal
                                  ? Offset(dx, 0)
                                  : Offset(
                                      widget.side == BeuiArcPickerSide.left
                                          ? -maxWidth
                                          : 0,
                                      0,
                                    ),
                              child: Transform.rotate(
                                angle: rotation,
                                child: Opacity(
                                  opacity: widget.disabled
                                      ? visibleOpacity * 0.5
                                      : visibleOpacity *
                                            (option.disabled ? 0.35 : 1),
                                  child: Align(
                                    alignment: _horizontal
                                        ? Alignment.center
                                        : widget.side == BeuiArcPickerSide.left
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: SizedBox(
                                      width: _horizontal ? null : maxWidth,
                                      child: Semantics(
                                        inMutuallyExclusiveGroup: true,
                                        checked: selected,
                                        enabled:
                                            !widget.disabled &&
                                            !option.disabled,
                                        label: option.label,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap:
                                              widget.disabled || option.disabled
                                              ? null
                                              : () => _moveTo(index),
                                          child: Text(
                                            option.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: _horizontal
                                                ? TextAlign.center
                                                : widget.side ==
                                                      BeuiArcPickerSide.left
                                                ? TextAlign.right
                                                : TextAlign.left,
                                            style: textStyle.copyWith(
                                              color: selected
                                                  ? colors.primary
                                                  : colors.mutedForeground,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    AnimatedBuilder(
                      animation: _position,
                      builder: (context, _) {
                        final text = widget.options.isEmpty
                            ? null
                            : widget.options[_activeIndex].label;
                        final textWidth = text == null
                            ? 0.0
                            : (TextPainter(
                                text: TextSpan(text: text, style: textStyle),
                                textDirection: Directionality.of(context),
                              )..layout()).width;
                        final verticalCenter =
                            (_horizontal
                                    ? (widget.side == BeuiArcPickerSide.top
                                          ? 36.0
                                          : height - 36)
                                    : height / 2)
                                .toDouble();
                        final x = _horizontal
                            ? 0.0
                            : widget.side == BeuiArcPickerSide.right
                            ? width! * anchor - 16 - _bracketGap
                            : width! * anchor - textWidth - 16 - _bracketGap;
                        return Positioned(
                          left: _horizontal ? 0 : x,
                          right: _horizontal ? 0 : null,
                          top: verticalCenter - 12,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: text == null ? 0 : 0.85,
                              child: Align(
                                alignment: _horizontal
                                    ? Alignment.center
                                    : Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '[',
                                      style: textStyle.copyWith(
                                        color: colors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: _bracketGap),
                                    SizedBox(width: textWidth),
                                    const SizedBox(width: _bracketGap),
                                    Text(
                                      ']',
                                      style: textStyle.copyWith(
                                        color: colors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (widget.options.isEmpty)
                      Center(
                        child: Text(
                          'No options',
                          style: TextStyle(color: colors.mutedForeground),
                        ),
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
