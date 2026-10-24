import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

// The source's flick glide is deliberately softer than the shared layout
// token, preserving a little of the pointer velocity as the track settles.
const _timelineGlideSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 120, damping: 24),
);

/// A dated entry displayed by [BeuiTimeline].
@immutable
class BeuiTimelineEvent {
  /// Creates an event. [date] accepts a [DateTime] or an ISO date string.
  const BeuiTimelineEvent({
    required this.id,
    required this.date,
    required this.title,
    this.media,
    this.meta,
  });

  /// Stable identity used by `value` and `defaultValue`.
  final String id;

  /// A [DateTime] or parseable ISO date string. String dates are read in UTC.
  final Object date;

  /// Event heading.
  final String title;

  /// Optional card media.
  final Widget? media;

  /// Optional footer content.
  final Widget? meta;

  /// Resolves the event date to UTC, preserving the source's date-only behavior.
  DateTime get dateTime {
    final value = date;
    if (value is DateTime) return value.toUtc();
    if (value is String) {
      final dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);
      if (dateOnly) {
        final parts = value.split('-').map(int.parse).toList();
        return DateTime.utc(parts[0], parts[1], parts[2]);
      }
      return DateTime.parse(value).toUtc();
    }
    throw ArgumentError.value(
      date,
      'date',
      'Use DateTime or an ISO date string.',
    );
  }
}

/// A draggable horizontal event timeline with keyboard navigation.
///
/// [value] makes the timeline controlled; otherwise [defaultValue] seeds its
/// internal selection. Movement glides with the shared-layout spring and snaps
/// directly to the target when reduced motion is enabled.
class BeuiTimeline extends StatefulWidget {
  /// Creates a timeline from [events].
  const BeuiTimeline({
    required this.events,
    this.value,
    this.defaultValue,
    this.onChanged,
    this.onValueChange,
    this.itemWidth = 340,
    this.height = 600,
    this.years = true,
    this.ruler = true,
    this.cables = true,
    this.formatDate,
    this.formatYear,
    this.semanticLabel = 'Timeline',
    super.key,
  });

  /// Events in chronological display order.
  final List<BeuiTimelineEvent> events;

  /// Selected event id (controlled).
  final String? value;

  /// Initial selected id in uncontrolled mode.
  final String? defaultValue;

  /// Called when selection changes; alias matching Flutter conventions.
  final ValueChanged<String>? onChanged;

  /// Called when selection changes; source API spelling.
  final ValueChanged<String>? onValueChange;

  /// Maximum card width at full scale.
  final double itemWidth;

  /// Stage height.
  final double height;

  /// Whether large parallax year labels are shown.
  final bool years;

  /// Whether tick groups appear between cards.
  final bool ruler;

  /// Whether the center-to-card cable lines are shown.
  final bool cables;

  /// Formats the date shown on each card.
  final String Function(DateTime date)? formatDate;

  /// Formats the large year labels.
  final String Function(DateTime date)? formatYear;

  /// Accessible label for the timeline region.
  final String semanticLabel;

  @override
  State<BeuiTimeline> createState() => _BeuiTimelineState();
}

class _BeuiTimelineState extends State<BeuiTimeline> {
  late String? _internalValue;
  late double _position;
  final Map<String, FocusNode> _focusNodes = {};
  double? _dragStartX;
  double _dragStartPosition = 0;
  double _step = 1;

  bool get _controlled => widget.value != null;
  String? get _selectedId => _controlled ? widget.value : _internalValue;
  int get _selectedIndex {
    final index = widget.events.indexWhere((event) => event.id == _selectedId);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    _internalValue =
        widget.defaultValue ??
        (widget.events.isEmpty ? null : widget.events.first.id);
    _position = _indexFor(_internalValue);
    _syncFocusNodes();
  }

  @override
  void didUpdateWidget(covariant BeuiTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFocusNodes();
    if (widget.value != oldWidget.value || widget.events != oldWidget.events) {
      _position = _selectedIndex.toDouble();
    }
  }

  void _syncFocusNodes() {
    final ids = widget.events.map((event) => event.id).toSet();
    for (final id in _focusNodes.keys.toList()) {
      if (!ids.contains(id)) _focusNodes.remove(id)?.dispose();
    }
    for (final id in ids) {
      _focusNodes.putIfAbsent(id, () => FocusNode(debugLabel: 'Timeline $id'));
    }
  }

  double _indexFor(String? id) {
    final index = widget.events.indexWhere((event) => event.id == id);
    return math.max(0, index).toDouble();
  }

  void _choose(int index, {bool requestFocus = false}) {
    if (widget.events.isEmpty) return;
    final target = index.clamp(0, widget.events.length - 1);
    final id = widget.events[target].id;
    setState(() {
      if (!_controlled) _internalValue = id;
      _position = target.toDouble();
    });
    if (id != _selectedId || !_controlled) {
      widget.onChanged?.call(id);
      if (!identical(widget.onChanged, widget.onValueChange)) {
        widget.onValueChange?.call(id);
      }
    }
    if (requestFocus) _focusNodes[id]?.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, int index) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final target = switch (key) {
      LogicalKeyboardKey.arrowRight => index + 1,
      LogicalKeyboardKey.arrowLeft => index - 1,
      LogicalKeyboardKey.home => 0,
      LogicalKeyboardKey.end => widget.events.length - 1,
      _ => null,
    };
    if (target == null) return KeyEventResult.ignored;
    _choose(target, requestFocus: true);
    return KeyEventResult.handled;
  }

  void _dragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    _dragStartPosition = _position;
  }

  void _dragUpdate(DragUpdateDetails details, int last) {
    final startX = _dragStartX;
    if (startX == null) return;
    final next =
        (_dragStartPosition - (details.globalPosition.dx - startX) / _step)
            .clamp(-0.3, last + 0.3);
    setState(() => _position = next);
    final nearest = next.round().clamp(0, last);
    final nextId = widget.events[nearest].id;
    if (nextId != _selectedId) {
      if (!_controlled) setState(() => _internalValue = nextId);
      widget.onChanged?.call(nextId);
      widget.onValueChange?.call(nextId);
    }
  }

  void _dragEnd(DragEndDetails details, int last) {
    _dragStartX = null;
    final projected =
        _position + (-details.velocity.pixelsPerSecond.dx / _step) * 0.3;
    _choose(projected.round().clamp(0, last));
  }

  String _dateLabel(DateTime date) =>
      widget.formatDate?.call(date) ??
      '${_month(date.month)} ${date.day} ’${(date.year % 100).toString().padLeft(2, '0')}';

  String _yearLabel(DateTime date) =>
      widget.formatYear?.call(date) ??
      '’${(date.year % 100).toString().padLeft(2, '0')}';

  String _month(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final last = math.max(0, widget.events.length - 1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 800.0;
        final cardWidth = math.min(
          widget.itemWidth,
          width * (width < 640 ? 0.58 : 0.36),
        );
        final gap = (cardWidth * 0.22).clamp(40.0, 72.0);
        _step = cardWidth * 0.72 + gap;
        return Semantics(
          container: true,
          label: widget.semanticLabel,
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: ClipRect(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _dragStart,
                onHorizontalDragUpdate: (details) => _dragUpdate(details, last),
                onHorizontalDragEnd: (details) => _dragEnd(details, last),
                child: reduce
                    ? _buildStage(
                        context,
                        colors: colors,
                        position: _position,
                        width: width,
                        cardWidth: cardWidth,
                        gap: gap,
                        last: last,
                      )
                    : SingleMotionBuilder(
                        value: _position,
                        motion: motionFor(
                          context,
                          _timelineGlideSpring,
                          isMovement: true,
                        ),
                        builder: (context, position, _) => _buildStage(
                          context,
                          colors: colors,
                          position: position,
                          width: width,
                          cardWidth: cardWidth,
                          gap: gap,
                          last: last,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStage(
    BuildContext context, {
    required BeuiColors colors,
    required double position,
    required double width,
    required double cardWidth,
    required double gap,
    required int last,
  }) {
    final center = width / 2;
    final height = widget.height;
    final children = <Widget>[];
    if (widget.years) {
      var previousYear = -1;
      for (var i = 0; i < widget.events.length; i++) {
        final date = widget.events[i].dateTime;
        if (date.year == previousYear) continue;
        previousYear = date.year;
        final markPosition = i == 0 ? 0.0 : i - 0.5;
        children.add(
          Positioned(
            left: center + (markPosition - position) * _step * 0.5,
            top: height * 0.066,
            child: FractionalTranslation(
              translation: const Offset(-0.5, 0),
              child: Text(
                _yearLabel(date),
                style: TextStyle(
                  color: colors.foreground.withValues(alpha: 0.06),
                  fontSize: height * 0.2,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -height * 0.015,
                ),
              ),
            ),
          ),
        );
      }
    }
    if (widget.cables) {
      children.add(
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _TimelineCablesPainter(
                position: position,
                count: widget.events.length,
                step: _step,
                cardWidth: cardWidth,
                height: height,
                color: colors.foreground.withValues(alpha: 0.14),
              ),
            ),
          ),
        ),
      );
    }
    children.add(
      Positioned(
        left: center,
        top: 0,
        bottom: 0,
        child: IgnorePointer(
          child: Container(
            width: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.foreground.withValues(alpha: 0),
                  colors.foreground.withValues(alpha: 0.8),
                  colors.foreground.withValues(alpha: 0),
                ],
                stops: const [0, 0.06, 1],
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.ruler) {
      for (var i = 0; i < last; i++) {
        final relative = i - position;
        final x = center + (relative + 0.5) * _step;
        children.add(
          Positioned(
            left: x - 24,
            top: height * 0.5,
            child: Row(
              children: List.generate(
                5,
                (tick) => Container(
                  width: 1,
                  height: cardWidth * (tick == 2 ? 0.2 : 0.13),
                  margin: EdgeInsets.symmetric(
                    horizontal: cardWidth * 0.22 * 0.7 / 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.foreground.withValues(
                      alpha: tick == 2 ? 0.45 : 0.25,
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    for (var i = 0; i < widget.events.length; i++) {
      final event = widget.events[i];
      final date = event.dateTime;
      final relative = i - position;
      final abs = relative.abs();
      final scale = 1 - 0.28 * math.min(abs, 1);
      final x = relative.abs() <= 1
          ? relative * (cardWidth * (1 + 0.72) / 2 + gap)
          : relative.sign *
                ((cardWidth * (1 + 0.72) / 2 + gap) + (abs - 1) * _step);
      final active = i == _selectedIndex;
      children.add(
        Positioned(
          left: center + x - cardWidth / 2,
          top: 0,
          bottom: 0,
          width: cardWidth,
          child: Center(
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: 1 - 0.45 * math.min(abs, 1),
                child: _TimelineCard(
                  event: event,
                  dateLabel: _dateLabel(date),
                  width: cardWidth,
                  active: active,
                  colors: colors,
                  focusNode: _focusNodes[event.id]!,
                  onTap: () => _choose(i, requestFocus: true),
                  onKeyEvent: (node, key) => _onKey(node, key, i),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Stack(clipBehavior: Clip.hardEdge, children: children);
  }
}

class _TimelineCard extends StatefulWidget {
  const _TimelineCard({
    required this.event,
    required this.dateLabel,
    required this.width,
    required this.active,
    required this.colors,
    required this.focusNode,
    required this.onTap,
    required this.onKeyEvent,
  });

  final BeuiTimelineEvent event;
  final String dateLabel;
  final double width;
  final bool active;
  final BeuiColors colors;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;

  @override
  State<_TimelineCard> createState() => _TimelineCardState();
}

class _TimelineCardState extends State<_TimelineCard> {
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _TimelineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final dateLabel = widget.dateLabel;
    final width = widget.width;
    final active = widget.active;
    final colors = widget.colors;
    final focusNode = widget.focusNode;
    final onTap = widget.onTap;
    final onKeyEvent = widget.onKeyEvent;
    final radius = BorderRadius.circular(24);
    final highlighted = _hovered || focusNode.hasFocus;
    final movement =
        highlighted &&
        motionFor(context, beuiSpringLayout, isMovement: true) is! NoMotion;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      button: true,
      focusable: active,
      selected: active,
      inMutuallyExclusiveGroup: true,
      label: '$dateLabel, ${event.title}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, movement ? -7 : 0, 0)
            ..scaleByDouble(
              movement ? 1.025 : 1.0,
              movement ? 1.025 : 1.0,
              1,
              1,
            ),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: colors.foreground.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : const [],
          ),
          child: SizedBox(
            width: width,
            child: Focus(
              focusNode: focusNode,
              skipTraversal: !active,
              onKeyEvent: onKeyEvent,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: colors.card,
                        border: Border.all(
                          color: highlighted ? colors.ring : colors.border,
                          width: highlighted ? 1.5 : 1,
                        ),
                        borderRadius: radius,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateLabel,
                                  style: TextStyle(
                                    color: colors.mutedForeground,
                                    fontSize: 12,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  event.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.foreground,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: SizedBox(
                              height: width * 10 / 16,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.background,
                                    border: Border.all(color: colors.border),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: event.media ?? const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                          if (event.meta case final meta?)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                10,
                                14,
                                12,
                              ),
                              child: DefaultTextStyle(
                                style: TextStyle(
                                  color: colors.mutedForeground,
                                  fontSize: 14,
                                ),
                                child: meta,
                              ),
                            )
                          else
                            const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    AnimatedBuilder(
                      animation: focusNode,
                      builder: (context, child) => focusNode.hasFocus
                          ? Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: radius,
                                    border: Border.all(
                                      color: colors.ring,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
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

class _TimelineCablesPainter extends CustomPainter {
  const _TimelineCablesPainter({
    required this.position,
    required this.count,
    required this.step,
    required this.cardWidth,
    required this.height,
    required this.color,
  });

  final double position;
  final int count;
  final double step;
  final double cardWidth;
  final double height;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final center = size.width / 2;
    for (var i = 0; i < count; i++) {
      final offset = i - position;
      final distance = offset.abs();
      final opacity = ((1.6 - distance) / 0.6).clamp(0.0, 1.0);
      if (opacity == 0) continue;
      paint.color = color.withValues(alpha: color.a * opacity);
      final scale = 1 - 0.28 * math.min(distance, 1);
      final x = center + offset * step;
      final reach = cardWidth * scale * 0.4;
      for (final y in [0.0, height]) {
        canvas.drawLine(
          Offset(center, y),
          Offset(x - reach, height / 2),
          paint,
        );
        canvas.drawLine(
          Offset(center, y),
          Offset(x + reach, height / 2),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineCablesPainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.count != count ||
      oldDelegate.step != step ||
      oldDelegate.cardWidth != cardWidth ||
      oldDelegate.height != height ||
      oldDelegate.color != color;
}
