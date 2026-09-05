import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '_engine.dart';

/// Which action rail a row is revealing (source `SwipeSide`).
enum BeuiSwipeSide {
  /// The leading rail (swipe right).
  left,

  /// The trailing rail (swipe left).
  right,
}

/// Color tone of a swipe action (source `SwipeActionTone`).
enum BeuiSwipeActionTone {
  /// Muted (default).
  neutral,

  /// Foreground.
  primary,

  /// Emerald.
  success,

  /// Amber.
  warning,

  /// Destructive.
  danger,
}

/// The open row + side of a [BeuiSwipeableList] (source
/// `SwipeableListValue`).
@immutable
class BeuiSwipeableListValue {
  /// Creates an open-state value.
  const BeuiSwipeableListValue({required this.id, required this.side});

  /// The open row's id.
  final String id;

  /// Which rail is revealed.
  final BeuiSwipeSide side;

  @override
  bool operator ==(Object other) =>
      other is BeuiSwipeableListValue && other.id == id && other.side == side;

  @override
  int get hashCode => Object.hash(id, side);
}

/// One contextual action behind a row (source `SwipeAction`).
@immutable
class BeuiSwipeAction {
  /// Creates a swipe action. Provide [icon] or [customIcon].
  const BeuiSwipeAction({
    required this.id,
    required this.label,
    this.icon,
    this.customIcon,
    this.tone = BeuiSwipeActionTone.neutral,
    this.disabled = false,
    this.onPressed,
  }) : assert(
         icon != null || customIcon != null,
         'Provide an icon glyph or a custom icon widget.',
       );

  /// Stable identity.
  final String id;

  /// Accessible name (visually the rail shows only the icon).
  final String label;

  /// Action glyph.
  final IconData? icon;

  /// Custom glyph (overrides [icon]).
  final Widget? customIcon;

  /// Color tone.
  final BeuiSwipeActionTone tone;

  /// Disables and dims the action.
  final bool disabled;

  /// Invoked with the owning row.
  final ValueChanged<BeuiSwipeableListItem>? onPressed;
}

/// One row of a [BeuiSwipeableList] (source `SwipeableListItem`).
@immutable
class BeuiSwipeableListItem {
  /// Creates a row.
  const BeuiSwipeableListItem({
    required this.id,
    this.title,
    this.description,
    this.meta,
    this.leading,
    this.content,
    this.leftActions = const [],
    this.rightActions = const [],
    this.disabled = false,
  });

  /// Stable identity.
  final String id;

  /// Primary line.
  final String? title;

  /// Secondary line.
  final String? description;

  /// Trailing meta text (e.g. a timestamp).
  final String? meta;

  /// Leading widget (e.g. an avatar).
  final Widget? leading;

  /// Replaces the default title/description/meta layout.
  final Widget? content;

  /// Actions revealed by swiping right.
  final List<BeuiSwipeAction> leftActions;

  /// Actions revealed by swiping left.
  final List<BeuiSwipeAction> rightActions;

  /// Disables swiping and dims the row.
  final bool disabled;
}

/// Fires when a revealed action is chosen.
typedef BeuiSwipeActionCallback =
    void Function(
      BeuiSwipeableListItem item,
      BeuiSwipeAction action,
      BeuiSwipeSide side,
    );

// Distance-based release spring keeps short rebounds and full reveals feeling
// equally direct, closer to native mobile lists (source ROW_SETTLE,
// 560 · 48 · 0.82).
const _rowSettle = SpringMotion(
  SpringDescription(mass: 0.82, stiffness: 560, damping: 48),
);

// Release decision constants (source values).
const _openDistanceRatio = 0.46;
const _closeDistanceRatio = 0.72;
const _openVelocity = 720.0;
const _closeVelocity = 320.0;
const _flingDistance = 14.0;
const _dragElastic = 0.04;

// Release velocity is clamped to this before it feeds the settle spring (source
// RELEASE_VELOCITY_LIMIT). A fast flick carries up to this much momentum into
// the spring; a slow drag to the same release point carries almost none.
const _releaseVelocityLimit = 1500.0;

double _clampReleaseVelocity(double velocity) =>
    math.max(-_releaseVelocityLimit, math.min(_releaseVelocityLimit, velocity));

/// Rows that swipe left/right to reveal contextual actions — the Flutter port
/// of beUI's `SwipeableList`.
///
/// One row is open at a time; `value` follows the controlled + uncontrolled
/// convention. Release snaps on the settle spring using the source's
/// distance/velocity decision tree. Reduced motion keeps the swipe gesture
/// but snaps instead of springing.
class BeuiSwipeableList extends StatefulWidget {
  /// Creates a swipeable list.
  const BeuiSwipeableList({
    required this.items,
    this.value = _unset,
    this.defaultValue,
    this.onValueChange,
    this.onAction,
    this.actionWidth = 56,
    this.revealThreshold = 34,
    this.closeOnAction = true,
    super.key,
  });

  static const BeuiSwipeableListValue _unset = BeuiSwipeableListValue(
    id: ' beui-uncontrolled',
    side: BeuiSwipeSide.left,
  );

  /// The rows.
  final List<BeuiSwipeableListItem> items;

  /// Controlled open row (`null` = all closed); omit for uncontrolled.
  final BeuiSwipeableListValue? value;

  /// Initial open row when uncontrolled.
  final BeuiSwipeableListValue? defaultValue;

  /// Fires with the row the list wants open (`null` to close).
  final ValueChanged<BeuiSwipeableListValue?>? onValueChange;

  /// Fires when a revealed action is chosen.
  final BeuiSwipeActionCallback? onAction;

  /// Width of one action cell (source `actionWidth = 56`).
  final double actionWidth;

  /// Minimum reveal distance before a release opens (source
  /// `revealThreshold = 34`).
  final double revealThreshold;

  /// Close the row after an action (source `closeOnAction = true`).
  final bool closeOnAction;

  bool get _controlled => !identical(value, _unset);

  @override
  State<BeuiSwipeableList> createState() => _BeuiSwipeableListState();
}

class _BeuiSwipeableListState extends State<BeuiSwipeableList> {
  BeuiSwipeableListValue? _internal;

  @override
  void initState() {
    super.initState();
    _internal = widget.defaultValue;
  }

  BeuiSwipeableListValue? get _open =>
      widget._controlled ? widget.value : _internal;

  void _setOpen(BeuiSwipeableListValue? next) {
    if (!widget._controlled) setState(() => _internal = next);
    widget.onValueChange?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8, // gap-2
      children: [
        for (final item in widget.items)
          _SwipeRow(
            key: ValueKey(item.id),
            item: item,
            actionWidth: widget.actionWidth,
            revealThreshold: widget.revealThreshold,
            openSide: _open?.id == item.id ? _open!.side : null,
            anotherOpen: _open != null && _open!.id != item.id,
            closeOnAction: widget.closeOnAction,
            onOpenChanged: (side) => _setOpen(
              side == null
                  ? null
                  : BeuiSwipeableListValue(id: item.id, side: side),
            ),
            onAction: widget.onAction,
          ),
      ],
    );
  }
}

class _SwipeRow extends StatefulWidget {
  const _SwipeRow({
    required this.item,
    required this.actionWidth,
    required this.revealThreshold,
    required this.openSide,
    required this.anotherOpen,
    required this.closeOnAction,
    required this.onOpenChanged,
    required this.onAction,
    super.key,
  });

  final BeuiSwipeableListItem item;
  final double actionWidth;
  final double revealThreshold;
  final BeuiSwipeSide? openSide;
  final bool anotherOpen;
  final bool closeOnAction;
  final ValueChanged<BeuiSwipeSide?> onOpenChanged;
  final BeuiSwipeActionCallback? onAction;

  @override
  State<_SwipeRow> createState() => _SwipeRowState();
}

class _SwipeRowState extends State<_SwipeRow>
    with SingleTickerProviderStateMixin {
  // The row's live horizontal position. The pointer owns it during a drag; a
  // release settles it on the row spring — carrying the clamped release
  // velocity so a flick keeps its momentum (source `x` motion value + settleX).
  late final SingleMotionController _controller;
  double _raw = 0;
  bool _dragging = false;

  // Mirrors source `commandedTargetRef`: the last target we settled toward, so
  // an externally driven target change (a controlled `value`, or another row
  // opening and closing this one) does not redundantly re-settle a target that
  // is already in flight.
  double _commandedTarget = 0;

  double get _leftWidth => widget.item.leftActions.length * widget.actionWidth;
  double get _rightWidth =>
      widget.item.rightActions.length * widget.actionWidth;

  double _targetXFor(BeuiSwipeSide? side) => switch (side) {
    BeuiSwipeSide.left => _leftWidth,
    BeuiSwipeSide.right => -_rightWidth,
    null => 0,
  };

  double get _targetX => _targetXFor(widget.openSide);

  @override
  void initState() {
    super.initState();
    _commandedTarget = _targetX;
    _controller = SingleMotionController(
      motion: _rowSettle,
      vsync: this,
      initialValue: _targetX,
    );
  }

  @override
  void didUpdateWidget(covariant _SwipeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Source targetX effect: settle toward an externally changed target — a
    // controlled `value`, or another row's open state closing this one. This
    // path carries no velocity (only a release flick does).
    final target = _targetX;
    if (!_dragging && _commandedTarget != target) {
      _settleX(target);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Constraints [-rightWidth, leftWidth] with 0.04 elasticity beyond.
  double _display(double raw) {
    if (raw > _leftWidth) return _leftWidth + (raw - _leftWidth) * _dragElastic;
    if (raw < -_rightWidth) {
      return -_rightWidth + (raw + _rightWidth) * _dragElastic;
    }
    return raw;
  }

  /// Port of source `settleX`: stop any in-flight spring and settle toward
  /// [nextX], injecting the clamped release [velocity] so a flick carries
  /// momentum into the spring. Reduced motion snaps (source `x.set`).
  void _settleX(double nextX, {double velocity = 0}) {
    _commandedTarget = nextX;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = nextX;
      return;
    }
    _controller.animateTo(nextX, withVelocity: _clampReleaseVelocity(velocity));
  }

  void _onDragStart(DragStartDetails details) {
    // Take over from wherever the spring currently is (source onDragStart stops
    // the animation; the drag then owns x from its live mid-spring position,
    // not the committed target).
    _controller.stop(canceled: true);
    _dragging = true;
    _raw = _controller.value;
    // Opening a new row closes any other open one (source onDragStart).
    if (widget.anotherOpen) widget.onOpenChanged(null);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _raw += details.delta.dx;
    // The pointer drives x directly during a drag (source `style={{ x }}`).
    _controller.value = _display(_raw);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    final latest = _controller.value;
    final openSide = widget.openSide;
    final leftOpenThreshold = math.max(
      widget.revealThreshold,
      _leftWidth * _openDistanceRatio,
    );
    final rightOpenThreshold = math.max(
      widget.revealThreshold,
      _rightWidth * _openDistanceRatio,
    );

    BeuiSwipeSide? next;
    if (openSide == BeuiSwipeSide.left) {
      next =
          (latest < _leftWidth * _closeDistanceRatio ||
              velocity < -_closeVelocity)
          ? null
          : BeuiSwipeSide.left;
    } else if (openSide == BeuiSwipeSide.right) {
      next =
          (latest.abs() < _rightWidth * _closeDistanceRatio ||
              velocity > _closeVelocity)
          ? null
          : BeuiSwipeSide.right;
    } else if (_leftWidth > 0 &&
        latest > 0 &&
        (latest > leftOpenThreshold ||
            (velocity > _openVelocity && latest > _flingDistance))) {
      next = BeuiSwipeSide.left;
    } else if (_rightWidth > 0 &&
        latest < 0 &&
        (latest < -rightOpenThreshold ||
            (velocity < -_openVelocity && latest < -_flingDistance))) {
      next = BeuiSwipeSide.right;
    }

    _dragging = false;
    // Source snapTo: settle (carrying the release velocity) AND report on every
    // release, even when the side is unchanged. Settling first pins
    // `_commandedTarget`, so the didUpdateWidget reaction skips a redundant
    // zero-velocity re-settle when onOpenChanged flips openSide.
    _settleX(_targetXFor(next), velocity: velocity);
    widget.onOpenChanged(next);
  }

  void _onDragCancel() {
    _dragging = false;
    _settleX(_targetX);
  }

  void _handleAction(BeuiSwipeAction action, BeuiSwipeSide side) {
    action.onPressed?.call(widget.item);
    widget.onAction?.call(widget.item, action, side);
    if (widget.closeOnAction) widget.onOpenChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final item = widget.item;

    Widget surface = Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(16), // rounded-2xl
        boxShadow: const [
          // shadow-sm
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child:
          item.content ??
          Row(
            spacing: 12, // gap-3
            children: [
              if (item.leading != null) item.leading!,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.title != null)
                      Text(
                        item.title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colors.foreground,
                        ),
                      ),
                    if (item.description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.mutedForeground,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (item.meta != null)
                Text(
                  item.meta!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.mutedForeground,
                  ),
                ),
            ],
          ),
    );

    if (!item.disabled) {
      surface = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        onHorizontalDragCancel: _onDragCancel,
        child: MouseRegion(cursor: SystemMouseCursors.grab, child: surface),
      );
    }

    // The pointer drives x during a drag; release settles on the row spring,
    // carrying the clamped release velocity (see _settleX). Reduced motion
    // snaps instead of springing (source settleX `x.set`).
    surface = ListenableBuilder(
      listenable: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(_controller.value, 0),
        child: child,
      ),
      child: surface,
    );

    final rail = Positioned.fill(
      child: IgnorePointer(
        ignoring: widget.openSide == null,
        child: Row(
          children: [
            for (final action in item.leftActions)
              _RailButton(
                action: action,
                width: widget.actionWidth,
                colors: colors,
                onPressed: () => _handleAction(action, BeuiSwipeSide.left),
              ),
            const Spacer(),
            for (final action in item.rightActions)
              _RailButton(
                action: action,
                width: widget.actionWidth,
                colors: colors,
                onPressed: () => _handleAction(action, BeuiSwipeSide.right),
              ),
          ],
        ),
      ),
    );

    Widget row = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.muted,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(children: [rail, surface]),
      ),
    );
    if (item.disabled) row = Opacity(opacity: 0.6, child: row);
    return row;
  }
}

({Color color, Color? dark}) _toneColor(
  BeuiSwipeActionTone tone,
  BeuiColors c,
) {
  final isDark = c.brightness == Brightness.dark;
  switch (tone) {
    case BeuiSwipeActionTone.neutral:
      return (color: c.mutedForeground, dark: null);
    case BeuiSwipeActionTone.primary:
      return (color: c.foreground, dark: null);
    case BeuiSwipeActionTone.success:
      return (
        color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
        dark: null,
      );
    case BeuiSwipeActionTone.warning:
      return (
        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
        dark: null,
      );
    case BeuiSwipeActionTone.danger:
      return (color: c.destructive, dark: null);
  }
}

class _RailButton extends StatefulWidget {
  const _RailButton({
    required this.action,
    required this.width,
    required this.colors,
    required this.onPressed,
  });

  final BeuiSwipeAction action;
  final double width;
  final BeuiColors colors;
  final VoidCallback onPressed;

  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    // Source: the neutral tone is muted and shifts to `foreground` on hover
    // (`text-muted-foreground group-hover:text-foreground`); every other tone
    // is hover-stable.
    final tone = action.tone == BeuiSwipeActionTone.neutral && _hovered
        ? widget.colors.foreground
        : _toneColor(action.tone, widget.colors).color;

    Widget body = SizedBox(
      width: widget.width,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36, // h-9 w-9
          height: 36,
          alignment: Alignment.center,
          transformAlignment: Alignment.center,
          transform: Matrix4.diagonal3Values(
            _pressed ? 0.95 : 1,
            _pressed ? 0.95 : 1,
            1,
          ),
          decoration: BoxDecoration(
            color: _hovered ? widget.colors.background : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: action.customIcon ?? Icon(action.icon, size: 16, color: tone),
        ),
      ),
    );

    if (action.disabled) body = Opacity(opacity: 0.5, child: body);

    return Semantics(
      button: true,
      enabled: !action.disabled,
      label: action.label,
      child: MouseRegion(
        cursor: action.disabled
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: action.disabled
              ? null
              : (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: action.disabled ? null : widget.onPressed,
          child: body,
        ),
      ),
    );
  }
}
