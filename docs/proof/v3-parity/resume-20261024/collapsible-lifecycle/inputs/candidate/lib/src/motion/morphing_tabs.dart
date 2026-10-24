import 'dart:math' as math;
import 'dart:ui' show ImageFilter, SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// An item displayed by [BeuiMorphingTabs].
@immutable
class BeuiMorphingTabsItem {
  const BeuiMorphingTabsItem({
    required this.id,
    required this.label,
    required this.content,
    this.icon,
    this.disabled = false,
  });

  final String id;
  final String label;
  final IconData? icon;
  final Widget content;
  final bool disabled;
}

const _springGlide = SpringMotion(
  SpringDescription(mass: 0.5, stiffness: 700, damping: 50),
);
const _springPress = SpringMotion(
  SpringDescription(mass: 0.6, stiffness: 500, damping: 30),
);

const _maxTabWidth = 176.0;
const _minTabWidth = 96.0;
const _tabHeight = 56.0;
const _railHeight = 80.0;
const _panelInset = 16.0;
const _panelRadius = 28.0;
const _tabRadius = 24.0;
const _liquidJoin = 24.0;

// Source hardcodes these regardless of page theme.
const _chrome = Color(0xFF292929);
const _cream = Color(0xFFFAFAF8);
const _creamText = Color(0xFF181818);
const _inactiveFg = Color(0xB3FFFFFF);
const _inactiveHover = Color(0x0FFFFFFF);
const _draggingFill = Color(0x14FFFFFF);

/// Reorderable tabs whose selected item joins the panel below it.
class BeuiMorphingTabs extends StatefulWidget {
  const BeuiMorphingTabs({
    required this.items,
    this.value = _unset,
    this.defaultValue,
    this.onValueChange,
    this.onOrderChange,
    this.onClose,
    this.semanticLabel = 'Tabs',
    super.key,
  });

  static const String _unset = '\u0000beui-uncontrolled';

  final List<BeuiMorphingTabsItem> items;
  final String? value;
  final String? defaultValue;
  final ValueChanged<String?>? onValueChange;
  final ValueChanged<List<String>>? onOrderChange;
  final ValueChanged<String>? onClose;
  final String semanticLabel;

  bool get _controlled => value != _unset;

  @override
  State<BeuiMorphingTabs> createState() => _BeuiMorphingTabsState();
}

class _BeuiMorphingTabsState extends State<BeuiMorphingTabs> {
  late List<String> _order = widget.items.map((item) => item.id).toList();
  late String? _internalValue =
      widget.defaultValue ??
      (widget.items.isEmpty ? null : widget.items.first.id);
  String? _draggedId;
  double _dragDelta = 0;
  List<String>? _dragInitialOrder;
  String? _pressedId;
  String? _hoveredId;
  final Map<String, FocusNode> _focusNodes = {};

  String? get _value => widget._controlled ? widget.value : _internalValue;

  List<BeuiMorphingTabsItem> get _orderedItems {
    final items = {for (final item in widget.items) item.id: item};
    final ordered = _order
        .map((id) => items[id])
        .whereType<BeuiMorphingTabsItem>()
        .toList();
    for (final item in widget.items) {
      if (!ordered.any((candidate) => candidate.id == item.id)) {
        ordered.add(item);
      }
    }
    return ordered;
  }

  BeuiMorphingTabsItem? get _activeItem {
    final items = _orderedItems;
    for (final item in items) {
      if (item.id == _value && !item.disabled) return item;
    }
    for (final item in items) {
      if (!item.disabled) return item;
    }
    return items.firstOrNull;
  }

  @override
  void didUpdateWidget(covariant BeuiMorphingTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.items.map((item) => item.id).toSet();
    _order = [
      ..._order.where(ids.contains),
      ...widget.items
          .map((item) => item.id)
          .where((id) => !_order.contains(id)),
    ];
    _focusNodes.removeWhere((id, node) {
      if (ids.contains(id)) return false;
      node.dispose();
      return true;
    });
    if (!widget._controlled &&
        !_order.contains(_internalValue) &&
        _order.isNotEmpty) {
      _internalValue = _order.first;
    }
  }

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _select(String? id) {
    if (id != null &&
        widget.items.any((item) => item.id == id && item.disabled)) {
      return;
    }
    if (!widget._controlled) setState(() => _internalValue = id);
    widget.onValueChange?.call(id);
  }

  void _move(String id, int delta) {
    final from = _order.indexOf(id);
    if (from < 0) return;
    final to = (from + delta).clamp(0, _order.length - 1);
    if (from == to) return;
    setState(() {
      final next = [..._order];
      final item = next.removeAt(from);
      next.insert(to, item);
      _order = next;
    });
    widget.onOrderChange?.call(List.unmodifiable(_order));
  }

  void _onTabKey(BeuiMorphingTabsItem item, KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    final direction = key == LogicalKeyboardKey.arrowLeft
        ? -1
        : key == LogicalKeyboardKey.arrowRight
        ? 1
        : 0;
    if (direction == 0) return;
    if (HardwareKeyboard.instance.isAltPressed) {
      _move(item.id, direction);
      return;
    }
    final enabled = _orderedItems
        .where((candidate) => !candidate.disabled)
        .toList();
    if (enabled.isEmpty) return;
    final index = enabled.indexWhere((candidate) => candidate.id == item.id);
    if (index < 0) return;
    final next = enabled[(index + direction + enabled.length) % enabled.length];
    _select(next.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[next.id]?.requestFocus();
    });
  }

  void _beginDrag(String id) {
    if (widget.items.any((item) => item.id == id && item.disabled)) return;
    _draggedId = id;
    _dragDelta = 0;
    _dragInitialOrder = List.of(_order);
  }

  void _updateDrag(double delta, double slotWidth) {
    if (_draggedId == null) return;
    _dragDelta += delta;
    final from = _order.indexOf(_draggedId!);
    final step = slotWidth;
    final shifts = (_dragDelta / step).round();
    final to = (from + shifts).clamp(0, _order.length - 1);
    if (to == from) return;
    setState(() {
      final next = [..._order];
      final dragged = next.removeAt(from);
      next.insert(to, dragged);
      _order = next;
      _dragDelta -= (to - from) * step;
    });
  }

  void _endDrag() {
    if (_draggedId == null) return;
    final initialOrder = _dragInitialOrder;
    _draggedId = null;
    _dragDelta = 0;
    _dragInitialOrder = null;
    if (initialOrder != null && !_sameOrder(initialOrder, _order)) {
      widget.onOrderChange?.call(List.unmodifiable(_order));
    }
    setState(() {});
  }

  bool _sameOrder(List<String> a, List<String> b) =>
      a.length == b.length &&
      a.indexed.every((entry) => entry.$2 == b[entry.$1]);

  @override
  Widget build(BuildContext context) {
    final items = _orderedItems;
    if (items.isEmpty) return const SizedBox.shrink();
    final reduce =
        motionFor(context, _springGlide, isMovement: true) is NoMotion;
    final glideMotion = motionFor(context, _springGlide, isMovement: true);
    final active = _activeItem;
    final activeIndex = active == null ? 0 : items.indexOf(active);
    const panelColor = _cream;
    const rootColor = _chrome;
    const panelText = _creamText;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 600.0;
        final innerWidth = math.max(0.0, width - _panelInset * 2);
        var tabGap = MediaQuery.sizeOf(context).width >= 768 ? 16.0 : 12.0;
        double widthAt(double gap) =>
            ((innerWidth - gap * (items.length - 1)) / items.length)
                .floorToDouble();
        var slotWidth = math.min(_maxTabWidth, widthAt(tabGap));
        if (slotWidth < _minTabWidth) {
          if (items.length > 1 && widthAt(0) >= _minTabWidth) {
            slotWidth = _minTabWidth;
            tabGap = math.max(
              0,
              ((innerWidth - _minTabWidth * items.length) / (items.length - 1))
                  .floorToDouble(),
            );
          } else {
            slotWidth = math.max(0, widthAt(0));
            tabGap = 0;
          }
        }
        final tabWidths = List.filled(items.length, slotWidth);
        final tabLefts = <double>[];
        var cursor = _panelInset;
        for (final tabWidth in tabWidths) {
          tabLefts.add(cursor);
          cursor += tabWidth + tabGap;
        }
        final safeIndex = activeIndex < 0
            ? 0
            : math.min(activeIndex, tabWidths.length - 1);
        final tabWidth = tabWidths[safeIndex];
        final pathWidth = math.max(0.0, width - _panelInset * 2);
        final maxLeft = math.max(0.0, pathWidth - tabWidth);
        final tabLocalLeft = (tabLefts[safeIndex] - _panelInset).clamp(
          0.0,
          maxLeft,
        );

        return Container(
          decoration: BoxDecoration(
            color: rootColor,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: _railHeight,
                  left: _panelInset,
                  right: _panelInset,
                ),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 256),
                  decoration: BoxDecoration(
                    color: panelColor,
                    borderRadius: BorderRadius.circular(_panelRadius),
                  ),
                  child: active == null
                      ? const SizedBox(height: 256)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(_panelRadius),
                          child: Semantics(
                            container: true,
                            explicitChildNodes: true,
                            label: '${active.label} panel',
                            role: SemanticsRole.tabPanel,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              switchInCurve: Curves.easeOut,
                              transitionBuilder: (child, animation) =>
                                  AnimatedBuilder(
                                    animation: animation,
                                    child: child,
                                    builder: (context, child) {
                                      final fade = FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      );
                                      if (reduce) return fade;
                                      final sigma = animation.isCompleted
                                          ? 0.0
                                          : 3 * (1 - animation.value);
                                      return ImageFiltered(
                                        imageFilter: ImageFilter.blur(
                                          sigmaX: sigma,
                                          sigmaY: sigma,
                                        ),
                                        child: fade,
                                      );
                                    },
                                  ),
                              child: KeyedSubtree(
                                key: ValueKey(active.id),
                                child: DefaultTextStyle(
                                  style: TextStyle(color: panelText),
                                  child: active.content,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                right: 0,
                height: _railHeight + _panelRadius,
                child: IgnorePointer(
                  child: glideMotion is NoMotion
                      ? CustomPaint(
                          painter: _MorphingTabsPainter(
                            left: tabLocalLeft,
                            width: tabWidth,
                            surfaceWidth: pathWidth,
                            color: panelColor,
                          ),
                        )
                      : SingleMotionBuilder(
                          value: tabLocalLeft,
                          motion: glideMotion,
                          builder: (context, left, _) => CustomPaint(
                            painter: _MorphingTabsPainter(
                              left: left,
                              width: tabWidth,
                              surfaceWidth: pathWidth,
                              color: panelColor,
                            ),
                          ),
                        ),
                ),
              ),
              SizedBox(
                height: _railHeight,
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  role: SemanticsRole.tabBar,
                  label: widget.semanticLabel,
                  child: Stack(
                    children: [
                      for (var index = 0; index < items.length; index++)
                        Positioned(
                          left: tabLefts[index],
                          top: 24,
                          width: tabWidths[index],
                          height: _tabHeight,
                          child: _buildTab(
                            context,
                            item: items[index],
                            active: items[index].id == active?.id,
                            slotWidth: tabWidths[index] + tabGap,
                            reduce: reduce,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTab(
    BuildContext context, {
    required BeuiMorphingTabsItem item,
    required bool active,
    required double slotWidth,
    required bool reduce,
  }) {
    final focus = _focusNodes.putIfAbsent(item.id, () => FocusNode());
    final fg = active ? _creamText : _inactiveFg;
    final isDragging = _draggedId == item.id;
    final hovered = _hoveredId == item.id;
    return Semantics(
      container: true,
      role: SemanticsRole.tab,
      label: item.label,
      selected: active,
      enabled: !item.disabled,
      inMutuallyExclusiveGroup: true,
      onTap: item.disabled ? null : () => _select(item.id),
      child: Focus(
        focusNode: focus,
        skipTraversal: !active,
        onKeyEvent: (node, event) {
          _onTabKey(item, event);
          final isArrow =
              event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.arrowRight;
          return isArrow ? KeyEventResult.handled : KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: item.disabled
              ? SystemMouseCursors.basic
              : SystemMouseCursors.grab,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: item.disabled
                ? null
                : (_) => _beginDrag(item.id),
            onHorizontalDragUpdate: item.disabled
                ? null
                : (details) {
                    _updateDrag(details.delta.dx, slotWidth);
                  },
            onHorizontalDragEnd: item.disabled ? null : (_) => _endDrag(),
            onHorizontalDragCancel: _endDrag,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(_tabRadius),
                ),
                onHover: item.disabled
                    ? null
                    : (hovering) {
                        setState(() {
                          if (hovering) {
                            _hoveredId = item.id;
                          } else if (_hoveredId == item.id) {
                            _hoveredId = null;
                          }
                        });
                      },
                onTap: item.disabled
                    ? null
                    : () {
                        focus.requestFocus();
                        _select(item.id);
                      },
                onHighlightChanged: (highlighted) {
                  setState(() => _pressedId = highlighted ? item.id : null);
                },
                child: reduce
                    ? _tabSurface(item, active, isDragging, hovered, fg, reduce)
                    : SingleMotionBuilder(
                        value: _pressedId == item.id ? 0.97 : 1,
                        motion: motionFor(
                          context,
                          _springPress,
                          isMovement: true,
                        ),
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: _tabSurface(
                          item,
                          active,
                          isDragging,
                          hovered,
                          fg,
                          reduce,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabSurface(
    BeuiMorphingTabsItem item,
    bool active,
    bool isDragging,
    bool hovered,
    Color foreground,
    bool reduce,
  ) => AnimatedContainer(
    duration: reduce ? Duration.zero : const Duration(milliseconds: 160),
    curve: Curves.easeOut,
    decoration: BoxDecoration(
      color: active
          ? _cream
          : isDragging
          ? _draggingFill
          : hovered
          ? _inactiveHover
          : Colors.transparent,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(_tabRadius),
      ),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            0,
            widget.onClose == null ? 12 : 40,
            active ? 0 : 8,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: math.max(40, constraints.maxWidth),
                maxWidth: math.max(40, constraints.maxWidth),
                child: Row(
                  spacing: 8,
                  children: [
                    if (item.icon != null)
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(item.icon, size: 18, color: foreground),
                      ),
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.onClose != null)
          Positioned(
            right: 8,
            top: active ? 16 : 12,
            child: IconButton(
              tooltip: 'Close ${item.label}',
              visualDensity: VisualDensity.standard,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 24, height: 24),
              icon: const Icon(LucideIcons.x, size: 14),
              color: foreground.withValues(alpha: 0.7),
              onPressed: () => widget.onClose?.call(item.id),
            ),
          ),
      ],
    ),
  );
}

class _MorphingTabsPainter extends CustomPainter {
  const _MorphingTabsPainter({
    required this.left,
    required this.width,
    required this.surfaceWidth,
    required this.color,
  });

  final double left;
  final double width;
  final double surfaceWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (surfaceWidth <= 0 || width <= 0) return;
    final panelLeft = _panelInset;
    final panelRight = _panelInset + surfaceWidth;
    final tabLeft = (panelLeft + left).clamp(panelLeft, panelRight - width);
    final tabRight = tabLeft + width;
    final bottom = _railHeight;
    final top = bottom - _tabHeight;
    final leftJoin = math.max(panelLeft, tabLeft - _liquidJoin);
    final rightJoin = math.min(panelRight, tabRight + _liquidJoin);
    final leftDepth = math.min(_liquidJoin, tabLeft - leftJoin);
    final rightDepth = math.min(_liquidJoin, rightJoin - tabRight);
    final path = Path()
      ..moveTo(panelLeft, bottom + _panelRadius)
      ..lineTo(panelLeft, bottom + math.min(_panelRadius, leftJoin - panelLeft))
      ..quadraticBezierTo(
        panelLeft,
        bottom,
        panelLeft + math.min(_panelRadius, leftJoin - panelLeft),
        bottom,
      )
      ..lineTo(leftJoin, bottom)
      ..cubicTo(
        leftJoin + leftDepth * 0.55,
        bottom,
        tabLeft,
        bottom - leftDepth * 0.45,
        tabLeft,
        bottom - leftDepth,
      )
      ..lineTo(tabLeft, top + _tabRadius)
      ..quadraticBezierTo(tabLeft, top, tabLeft + _tabRadius, top)
      ..lineTo(tabRight - _tabRadius, top)
      ..quadraticBezierTo(tabRight, top, tabRight, top + _tabRadius)
      ..lineTo(tabRight, bottom - rightDepth)
      ..cubicTo(
        tabRight,
        bottom - rightDepth * 0.45,
        rightJoin - rightDepth * 0.55,
        bottom,
        rightJoin,
        bottom,
      )
      ..lineTo(
        panelRight - math.min(_panelRadius, panelRight - rightJoin),
        bottom,
      )
      ..quadraticBezierTo(
        panelRight,
        bottom,
        panelRight,
        bottom + math.min(_panelRadius, panelRight - rightJoin),
      )
      ..lineTo(panelRight, bottom + _panelRadius)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MorphingTabsPainter oldDelegate) =>
      left != oldDelegate.left ||
      width != oldDelegate.width ||
      surfaceWidth != oldDelegate.surfaceWidth ||
      color != oldDelegate.color;
}
