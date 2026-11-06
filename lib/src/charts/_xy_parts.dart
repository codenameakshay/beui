/// Shared axes, legend, and accessible table used by XY charts.
library;

import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, KeyDownEvent;

import '../motion/_engine.dart' show CurvedMotion, SingleMotionController;
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_shared.dart' show beuiChartColor;
import '_xy.dart' show BeuiXYRow;

/// Grid lines and tick labels for an XY plot.
///
/// Place this widget in a finite [Stack]. A vertical axis positions y ticks
/// and draws horizontal grid lines. A horizontal axis positions x ticks and
/// draws vertical grid lines.
class BeuiXYAxisLayer extends StatefulWidget {
  const BeuiXYAxisLayer({
    required this.ticks,
    required this.position,
    required this.axis,
    required this.from,
    required this.to,
    required this.labelOffset,
    required this.format,
    this.showGrid = true,
    this.showLabels = true,
    this.reduceMotion = false,
    super.key,
  });

  final List<double> ticks;
  final double Function(double) position;
  final Axis axis;
  final double from;
  final double to;
  final double labelOffset;
  final String Function(num) format;
  final bool showGrid;
  final bool showLabels;
  final bool reduceMotion;

  @override
  State<BeuiXYAxisLayer> createState() => _BeuiXYAxisLayerState();
}

class _BeuiXYAxisLayerState extends State<BeuiXYAxisLayer>
    with TickerProviderStateMixin {
  final _ticks = <double, _XYTick>{};

  @override
  void initState() {
    super.initState();
    _sync(initial: true);
  }

  @override
  void didUpdateWidget(covariant BeuiXYAxisLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(initial: false);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _sync({required bool initial}) {
    final active = widget.ticks.toSet();
    for (final tick in active) {
      final target = widget.position(tick);
      final record = _ticks[tick];
      if (record == null) {
        late final _XYTick created;
        final opacity = SingleMotionController(
          vsync: this,
          motion: const CurvedMotion(Duration(milliseconds: 160), beuiEaseOut),
          initialValue: initial ? 1 : 0,
        );
        created = _XYTick(
          tick: tick,
          position: SingleMotionController(
            motion: beuiSpringLayout,
            vsync: this,
            initialValue: target,
          ),
          opacity: opacity,
        );
        opacity.addListener(_changed);
        created.position.addListener(_changed);
        opacity.addStatusListener((status) {
          if ((status == AnimationStatus.dismissed ||
                  status == AnimationStatus.completed) &&
              !created.visible &&
              opacity.value == 0) {
            _remove(created);
          }
        });
        _ticks[tick] = created;
        if (!initial) opacity.animateTo(1);
      } else {
        if (!record.visible) {
          record.visible = true;
          record.opacity.motion = const CurvedMotion(
            Duration(milliseconds: 160),
            beuiEaseOut,
          );
          record.opacity.animateTo(1);
        }
        _move(record, target);
      }
    }
    for (final entry in _ticks.entries.toList()) {
      if (active.contains(entry.key) || !entry.value.visible) continue;
      entry.value.visible = false;
      entry.value.opacity.motion = const CurvedMotion(
        Duration(milliseconds: 100),
        beuiEaseOut,
      );
      entry.value.opacity.animateTo(0);
    }
  }

  void _move(_XYTick tick, double target) {
    if (widget.reduceMotion) {
      tick.position.stop();
      tick.position.value = target;
    } else if (tick.position.value != target) {
      tick.position.animateTo(target);
    }
  }

  void _remove(_XYTick tick) {
    if (!identical(_ticks[tick.tick], tick)) return;
    _ticks.remove(tick.tick);
    tick.dispose();
    _changed();
  }

  @override
  void dispose() {
    for (final tick in _ticks.values) {
      tick.dispose();
    }
    _ticks.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            for (final tick in _ticks.values)
              if (widget.showGrid)
                Positioned(
                  left: widget.axis == Axis.vertical
                      ? widget.from
                      : tick.position.value - .5,
                  right: widget.axis == Axis.vertical
                      ? size.width - widget.to
                      : null,
                  top: widget.axis == Axis.vertical
                      ? tick.position.value - .5
                      : widget.from,
                  bottom: widget.axis == Axis.vertical
                      ? null
                      : size.height - widget.to,
                  width: widget.axis == Axis.horizontal ? 1 : null,
                  height: widget.axis == Axis.vertical ? 1 : null,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: tick.opacity.value.clamp(0.0, 1.0),
                      child: ColoredBox(
                        color: colors.mutedForeground.withValues(
                          alpha: tick.tick == 0 ? .3 : .12,
                        ),
                      ),
                    ),
                  ),
                ),
            if (widget.showLabels)
              for (final tick in _ticks.values)
                Positioned(
                  left: widget.axis == Axis.vertical ? 0 : tick.position.value,
                  top: widget.axis == Axis.vertical
                      ? tick.position.value
                      : widget.labelOffset,
                  width: widget.axis == Axis.vertical
                      ? widget.labelOffset - 8
                      : null,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: Opacity(
                        opacity: tick.opacity.value.clamp(0.0, 1.0),
                        child: FractionalTranslation(
                          translation: widget.axis == Axis.vertical
                              ? const Offset(0, -.5)
                              : const Offset(-.5, 0),
                          child: Text(
                            widget.format(tick.tick),
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: colors.mutedForeground,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                            textAlign: widget.axis == Axis.vertical
                                ? TextAlign.right
                                : TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _XYTick {
  _XYTick({required this.tick, required this.position, required this.opacity});

  final double tick;
  final SingleMotionController position;
  final SingleMotionController opacity;
  bool visible = true;

  void dispose() {
    position.dispose();
    opacity.dispose();
  }
}

/// Wrapping, keyboard-operable series toggles for an XY chart.
class BeuiXYLegend extends StatelessWidget {
  const BeuiXYLegend({
    required this.rows,
    required this.hidden,
    required this.onToggle,
    required this.onHover,
    required this.canHover,
    required this.label,
    this.spacing = 4,
    super.key,
  });

  final List<BeuiXYRow> rows;
  final List<String> hidden;
  final ValueChanged<String> onToggle;
  final ValueChanged<String?> onHover;
  final bool canHover;
  final String label;
  final double spacing;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: label,
    child: Wrap(
      spacing: spacing,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final row in rows)
          _BeuiXYLegendItem(
            key: ValueKey(row.id),
            row: row,
            shown: !hidden.contains(row.id),
            onToggle: () => onToggle(row.id),
            onHover: onHover,
            canHover: canHover,
          ),
      ],
    ),
  );
}

class _BeuiXYLegendItem extends StatefulWidget {
  const _BeuiXYLegendItem({
    required this.row,
    required this.shown,
    required this.onToggle,
    required this.onHover,
    required this.canHover,
    super.key,
  });

  final BeuiXYRow row;
  final bool shown;
  final VoidCallback onToggle;
  final ValueChanged<String?> onHover;
  final bool canHover;

  @override
  State<_BeuiXYLegendItem> createState() => _BeuiXYLegendItemState();
}

class _BeuiXYLegendItemState extends State<_BeuiXYLegendItem> {
  bool _focused = false;
  bool _focusHighlight = false;
  bool _pointerHover = false;

  void _reportHover() {
    widget.onHover(
      !widget.shown
          ? null
          : widget.canHover && _pointerHover
          ? widget.row.id
          : _focused
          ? widget.row.id
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final color = beuiChartColor(widget.row.color, colors);
    return Semantics(
      button: true,
      toggled: widget.shown,
      label: widget.row.name,
      child: FocusableActionDetector(
        onFocusChange: (focused) {
          _focused = focused;
          _reportHover();
        },
        onShowFocusHighlight: (highlight) {
          _focusHighlight = highlight;
          if (mounted) setState(() {});
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onToggle();
              return null;
            },
          ),
        },
        child: MouseRegion(
          onEnter: widget.canHover
              ? (_) {
                  _pointerHover = true;
                  _reportHover();
                  setState(() {});
                }
              : null,
          onExit: (_) {
            _pointerHover = false;
            _reportHover();
            setState(() {});
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onToggle,
            child: ExcludeSemantics(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: widget.shown ? 1 : .5,
                child: CustomPaint(
                  foregroundPainter: _focusHighlight
                      ? _XYLegendFocusOutline(colors.ring)
                      : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 36),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: color, width: 2),
                              color: widget.shown ? color : Colors.transparent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 150),
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.canHover && _pointerHover
                                  ? colors.foreground
                                  : colors.mutedForeground,
                              decoration: widget.shown
                                  ? null
                                  : TextDecoration.lineThrough,
                              decorationColor: colors.mutedForeground
                                  .withValues(alpha: .6),
                            ),
                            child: Text(widget.row.name),
                          ),
                        ],
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
  }
}

class _XYLegendFocusOutline extends CustomPainter {
  const _XYLegendFocusOutline(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).inflate(3),
        const Radius.circular(9),
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_XYLegendFocusOutline oldDelegate) =>
      color != oldDelegate.color;
}

/// Screen-reader data table for chart rows and categories.
///
/// The table remains in its original order and includes every series, even
/// when a chart hides a series or a category contains a data gap. It adds no
/// focus stops for individual values.
class BeuiXYDataTable extends StatelessWidget {
  const BeuiXYDataTable({
    required this.label,
    required this.rows,
    required this.categories,
    required this.formatValue,
    super.key,
  });

  final String label;
  final List<BeuiXYRow> rows;
  final List<String> categories;
  final String Function(num) formatValue;

  String _value(BeuiXYRow row, int index) {
    if (index >= row.values.length || row.values[index] == null) {
      return 'No data';
    }
    return formatValue(row.values[index]!);
  }

  @override
  Widget build(BuildContext context) => ExcludeFocus(
    child: IgnorePointer(
      child: Opacity(
        opacity: 0,
        alwaysIncludeSemantics: true,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          role: SemanticsRole.table,
          label: '$label data',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                container: true,
                role: SemanticsRole.row,
                explicitChildNodes: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header('Category'),
                    for (final row in rows) _header(row.name),
                  ],
                ),
              ),
              for (var index = 0; index < categories.length; index++)
                Semantics(
                  container: true,
                  role: SemanticsRole.row,
                  explicitChildNodes: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _header(categories[index]),
                      for (final row in rows)
                        Semantics(
                          container: true,
                          role: SemanticsRole.cell,
                          label: _value(row, index),
                          child: const SizedBox.shrink(),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _header(String label) => Semantics(
    container: true,
    header: true,
    role: SemanticsRole.columnHeader,
    label: label,
    child: const SizedBox.shrink(),
  );
}

/// Draws a focus-visible outline around focusable descendants without adding a
/// focus stop of its own.
class BeuiXYFocusOutline extends StatefulWidget {
  const BeuiXYFocusOutline({required this.child, this.offset = 4, super.key});

  final Widget child;
  final double offset;

  @override
  State<BeuiXYFocusOutline> createState() => _BeuiXYFocusOutlineState();
}

enum _XYFocusModality { keyboard, pointer }

class _BeuiXYFocusOutlineState extends State<BeuiXYFocusOutline> {
  final FocusNode _focusNode = FocusNode(
    canRequestFocus: false,
    skipTraversal: true,
  );
  _XYFocusModality _modality =
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional
      ? _XYFocusModality.keyboard
      : _XYFocusModality.pointer;

  bool get _showOutline =>
      _hasFocusedDescendant &&
      _modality == _XYFocusModality.keyboard &&
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  bool get _hasFocusedDescendant {
    final primaryFocus = FocusManager.instance.primaryFocus;
    return primaryFocus != null &&
        primaryFocus != _focusNode &&
        primaryFocus.ancestors.contains(_focusNode);
  }

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_handleFocusManagerChange);
    FocusManager.instance.addHighlightModeListener(_handleHighlightModeChange);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusManagerChange);
    FocusManager.instance.removeHighlightModeListener(
      _handleHighlightModeChange,
    );
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusManagerChange() {
    if (mounted) setState(() {});
  }

  void _handleHighlightModeChange(FocusHighlightMode _) {
    if (mounted) setState(() {});
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && _modality != _XYFocusModality.keyboard) {
      setState(() => _modality = _XYFocusModality.keyboard);
    }
    return false;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_modality == _XYFocusModality.keyboard) {
      setState(() => _modality = _XYFocusModality.pointer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ring = _showOutline ? BeuiColors.resolve(context).ring : null;
    return Focus(
      focusNode: _focusNode,
      canRequestFocus: false,
      skipTraversal: true,
      child: Listener(
        onPointerDown: _handlePointerDown,
        child: CustomPaint(
          foregroundPainter: ring == null
              ? null
              : _BeuiXYFocusOutlinePainter(color: ring, offset: widget.offset),
          child: widget.child,
        ),
      ),
    );
  }
}

class _BeuiXYFocusOutlinePainter extends CustomPainter {
  const _BeuiXYFocusOutlinePainter({required this.color, required this.offset});

  final Color color;
  final double offset;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.0;
    const cornerRadius = 4.0;
    final expansion = offset + strokeWidth / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).inflate(expansion),
        Radius.circular(cornerRadius + expansion),
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(_BeuiXYFocusOutlinePainter oldDelegate) =>
      color != oldDelegate.color || offset != oldDelegate.offset;
}
