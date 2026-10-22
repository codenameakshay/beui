import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'range_slider_shared.dart';

/// Ten evenly spaced snap stops span the track (source `STOP_COUNT`).
const int _stopCount = 10;

/// Thumb travel start, in px (source `HANDLE_START`).
const double _handleStart = 8;

/// Inset from the right edge for the last stop (source `HANDLE_END_INSET`).
const double _handleEndInset = 12;

/// Horizontal inset of the inline label / readout (source `TEXT_INSET`).
const double _textInset = 20;

const double _trackHeight = 40;
const double _thumbWidth = 4;
const double _thumbHeight = 24;

/// Bouncy grab feedback for the thumb scale. Source `SPRING_BOUNCY`.
const _grabSpring = SpringMotion(
  SpringDescription(mass: 0.7, stiffness: 500, damping: 14),
);

/// Test handle on the inline slider's track.
@visibleForTesting
const beuiInlineSliderTrackKey = ValueKey<String>('beui_inline_slider_track');

/// Test handle on the inline slider's thumb.
@visibleForTesting
const beuiInlineSliderThumbKey = ValueKey<String>('beui_inline_slider_thumb');

class _Stop {
  const _Stop(this.value, this.x);
  final double value;
  final double x;
}

double _mapBetweenStops(
  List<_Stop> stops,
  double point, {
  required bool fromValue,
}) {
  if (stops.isEmpty) return 0;
  if (stops.length == 1) {
    return fromValue ? stops.first.x : stops.first.value;
  }
  final fromOf = fromValue ? (s) => s.value : (s) => s.x;
  final toOf = fromValue ? (s) => s.x : (s) => s.value;
  var upperIndex = stops.indexWhere((s) => fromOf(s) >= point);
  if (upperIndex < 0) upperIndex = stops.length - 1;
  final upper = stops[upperIndex];
  final lower = stops[math.max(0, upperIndex - 1)];
  final fromSpan = fromOf(upper) - fromOf(lower);
  if (fromSpan == 0) return toOf(upper);
  return toOf(lower) +
      ((point - fromOf(lower)) / fromSpan) * (toOf(upper) - toOf(lower));
}

_Stop _nearestStop(List<_Stop> stops, double x) => stops.reduce(
  (best, stop) => (stop.x - x).abs() < (best.x - x).abs() ? stop : best,
);

/// An inset-fill slider with an inline label and value — the Flutter port of
/// beUI's `range-slider-inline`.
///
/// Ten evenly spaced stops span the track. The label and readout sit inside
/// the track; the thumb parts around either as it passes so the text stays
/// readable. Markers under text stay hidden but remain interactive.
///
/// Controlled **or** uncontrolled: pass [value] + [onChanged], or seed
/// [defaultValue]. Reduced motion snaps the thumb with no glide and drops the
/// grab-grow.
class BeuiInlineSlider extends StatefulWidget {
  /// Creates an inline slider. [label] is required (source).
  const BeuiInlineSlider({
    required this.label,
    this.value,
    this.defaultValue = 0,
    this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.enabled = true,
    this.format,
    this.showTicks = true,
    this.formatValueText,
    super.key,
  }) : assert(min < max, 'min must be < max'),
       assert(step > 0, 'step must be > 0');

  /// Compact label inside the left edge of the track.
  final String label;

  /// The selected value (controlled). When null the slider holds its own state.
  final double? value;

  /// The initial value when uncontrolled.
  final double defaultValue;

  /// Called with the new value on every change during a drag / key press.
  final ValueChanged<double>? onChanged;

  /// Called once when a drag gesture ends.
  final ValueChanged<double>? onChangeEnd;

  /// Lower bound.
  final double min;

  /// Upper bound.
  final double max;

  /// Rounds snap-stop values. While dragging, the readout keeps this step's
  /// decimal precision.
  final double step;

  /// Whether the slider responds to input.
  final bool enabled;

  /// Formats the inline value without changing its precision.
  final String Function(double value)? format;

  /// Show markers for the ten snap stops, except where they overlap text.
  final bool showTicks;

  /// Announced instead of the raw number.
  final String Function(double value)? formatValueText;

  @override
  State<BeuiInlineSlider> createState() => _BeuiInlineSliderState();
}

class _BeuiInlineSliderState extends State<BeuiInlineSlider> {
  late final FocusNode _focus = FocusNode(debugLabel: 'beui_inline_slider');
  final GlobalKey _labelKey = GlobalKey();
  final GlobalKey _readoutKey = GlobalKey();

  double? _internal;
  bool _grabbed = false;
  double _labelWidth = 22;
  double _readoutWidth = 24;
  double? _dragX;

  bool get _controlled => widget.value != null;
  double get _current => sliderClamp(
    _controlled ? widget.value! : (_internal ?? widget.defaultValue),
    widget.min,
    widget.max,
  );

  @override
  void initState() {
    super.initState();
    _internal = snapSliderValue(
      widget.defaultValue,
      widget.min,
      widget.max,
      widget.step,
    );
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _commit(double raw, {bool isEnd = false}) {
    final snapped = snapSliderValue(raw, widget.min, widget.max, widget.step);
    if (snapped != _current) {
      if (!_controlled) setState(() => _internal = snapped);
      widget.onChanged?.call(snapped);
    }
    if (isEnd) widget.onChangeEnd?.call(snapped);
  }

  void _measureText() {
    final labelBox = _labelKey.currentContext?.findRenderObject() as RenderBox?;
    final readBox =
        _readoutKey.currentContext?.findRenderObject() as RenderBox?;
    final lw = labelBox?.hasSize == true ? labelBox!.size.width : _labelWidth;
    final rw = readBox?.hasSize == true ? readBox!.size.width : _readoutWidth;
    if (lw != _labelWidth || rw != _readoutWidth) {
      setState(() {
        _labelWidth = lw;
        _readoutWidth = rw;
      });
    }
  }

  List<_Stop> _stops(double width) {
    final endX = math.max(_handleStart, width - _handleEndInset);
    final values = <double>{};
    for (var i = 0; i < _stopCount; i++) {
      values.add(
        snapSliderValue(
          widget.min + (i / (_stopCount - 1)) * (widget.max - widget.min),
          widget.min,
          widget.max,
          widget.step,
        ),
      );
    }
    final list = values.toList();
    return [
      for (var i = 0; i < list.length; i++)
        _Stop(
          list[i],
          list.length == 1
              ? _handleStart
              : _handleStart + (i / (list.length - 1)) * (endX - _handleStart),
        ),
    ];
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final stops = _stops(200); // values only; x unused
    final current = _current;
    double? next;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp) {
      next = stops
          .map((s) => s.value)
          .cast<double?>()
          .firstWhere((v) => v! > current, orElse: () => widget.max);
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.pageDown) {
      next = stops
          .map((s) => s.value)
          .toList()
          .reversed
          .cast<double?>()
          .firstWhere((v) => v! < current, orElse: () => widget.min);
    } else if (key == LogicalKeyboardKey.home) {
      next = widget.min;
    } else if (key == LogicalKeyboardKey.end) {
      next = widget.max;
    }
    if (next == null) return KeyEventResult.ignored;
    _commit(next);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureText());
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final format = widget.format ?? formatSliderNumber;
    final announced =
        widget.formatValueText?.call(_current) ?? format(_current);

    return Opacity(
      opacity: widget.enabled ? 1 : 0.5,
      child: Focus(
        focusNode: _focus,
        onKeyEvent: (_, event) => _onKey(event),
        child: Semantics(
          slider: true,
          enabled: widget.enabled,
          value: announced,
          increasedValue: announced,
          decreasedValue: announced,
          label: widget.label,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final stops = _stops(width);
              final restingX = _mapBetweenStops(
                stops,
                _current,
                fromValue: true,
              );
              final handleX = _grabbed && _dragX != null ? _dragX! : restingX;
              final endX = math.max(_handleStart, width - _handleEndInset);

              final labelStart = _textInset;
              final labelEnd = _textInset + _labelWidth;
              final readoutStart = width - _textInset - _readoutWidth;
              final readoutEnd = width - _textInset;

              double overlap(double start, double end) {
                final a = ((handleX + 4) - start) / 6;
                final b = (end - handleX) / 6;
                return sliderClamp(math.min(a, b), 0, 1);
              }

              final split = math.max(
                overlap(labelStart, labelEnd),
                overlap(readoutStart, readoutEnd),
              );

              bool overlapsText(double x) {
                bool hit(double start, double end) =>
                    x + 2 >= start && x - 2 <= end;
                return hit(labelStart, labelEnd) ||
                    hit(readoutStart, readoutEnd);
              }

              final ticks = widget.showTicks
                  ? [
                      for (final s in stops)
                        if (!overlapsText(s.x)) s.x,
                    ]
                  : const <double>[];

              final glide = motionFor(
                context,
                beuiSliderGlideSpring,
                isMovement: true,
              );

              Widget buildAt(double x) {
                final fillRight = x >= endX ? width - 2 : x + 8;
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(child: ColoredBox(color: colors.muted)),
                    Positioned(
                      left: 2,
                      top: 0,
                      bottom: 0,
                      width: math.max(0, fillRight - 2),
                      child: ColoredBox(
                        color: colors.foreground.withValues(alpha: 0.15),
                      ),
                    ),
                    Positioned(
                      left: _textInset,
                      top: 0,
                      bottom: 0,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: width * 0.4),
                          child: Text(
                            widget.label,
                            key: _labelKey,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              height: 20 / 14,
                              fontWeight: FontWeight.w500,
                              color: colors.foreground,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: _textInset,
                      top: 0,
                      bottom: 0,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: width * 0.4),
                          child: Text(
                            format(_current),
                            key: _readoutKey,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              height: 18 / 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: colors.foreground,
                            ),
                          ),
                        ),
                      ),
                    ),
                    for (final tick in ticks)
                      Positioned(
                        left: tick,
                        top: (_trackHeight - 4) / 2,
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.foreground.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    Positioned(
                      key: beuiInlineSliderThumbKey,
                      left: x,
                      top: 8,
                      width: _thumbWidth,
                      height: _thumbHeight,
                      child: SingleMotionBuilder(
                        value: _grabbed && widget.enabled && !reduce
                            ? 1.35
                            : 1.0,
                        motion: motionFor(
                          context,
                          _grabSpring,
                          isMovement: true,
                        ),
                        builder: (context, scaleY, child) =>
                            Transform.scale(scaleY: scaleY, child: child),
                        child: CustomPaint(
                          painter: _PartingThumbPainter(
                            color: colors.foreground,
                            split: split,
                          ),
                        ),
                      ),
                    ),
                    if (_focus.hasFocus)
                      beuiSliderFocusRing(radius: 8, color: colors.ring),
                  ],
                );
              }

              final body = (reduce || glide is NoMotion)
                  ? buildAt(handleX)
                  : SingleMotionBuilder(
                      value: handleX,
                      motion: _grabbed ? const NoMotion() : glide,
                      builder: (context, x, _) => buildAt(x),
                    );

              return GestureDetector(
                key: beuiInlineSliderTrackKey,
                behavior: HitTestBehavior.opaque,
                onTapDown: widget.enabled
                    ? (d) {
                        _focus.requestFocus();
                        final stop = _nearestStop(stops, d.localPosition.dx);
                        _commit(stop.value, isEnd: true);
                      }
                    : null,
                onPanStart: widget.enabled
                    ? (d) {
                        _focus.requestFocus();
                        setState(() {
                          _grabbed = true;
                          _dragX = sliderClamp(
                            d.localPosition.dx,
                            _handleStart,
                            endX,
                          );
                        });
                        _commit(
                          _mapBetweenStops(stops, _dragX!, fromValue: false),
                        );
                      }
                    : null,
                onPanUpdate: widget.enabled
                    ? (d) {
                        setState(() {
                          _dragX = sliderClamp(
                            d.localPosition.dx,
                            _handleStart,
                            endX,
                          );
                        });
                        _commit(
                          _mapBetweenStops(stops, _dragX!, fromValue: false),
                        );
                      }
                    : null,
                onPanEnd: widget.enabled
                    ? (_) {
                        final x = _dragX ?? restingX;
                        final stop = _nearestStop(stops, x);
                        setState(() {
                          _grabbed = false;
                          _dragX = null;
                        });
                        _commit(stop.value, isEnd: true);
                      }
                    : null,
                child: SizedBox(
                  height: _trackHeight,
                  width: width,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: body,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PartingThumbPainter extends CustomPainter {
  _PartingThumbPainter({required this.color, required this.split});

  final Color color;
  final double split;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final r = size.width / 2;
    // Caps move apart as [split] grows; stem fades.
    canvas.drawCircle(Offset(size.width / 2, r - split * 4), r, paint);
    canvas.drawCircle(
      Offset(size.width / 2, size.height - r + split * 4),
      r,
      paint,
    );
    if (split < 1) {
      paint.color = color.withValues(alpha: 1 - split);
      canvas.drawRRect(
        RRect.fromLTRBR(0, r, size.width, size.height - r, Radius.circular(r)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PartingThumbPainter old) =>
      old.color != color || old.split != split;
}
