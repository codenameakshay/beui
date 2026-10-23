import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';

class _TooltipProviderScope extends InheritedWidget {
  const _TooltipProviderScope({required this.state, required super.child});
  final _TooltipProviderState state;

  static _TooltipProviderState? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_TooltipProviderScope>()
      ?.state;

  @override
  bool updateShouldNotify(_TooltipProviderScope oldWidget) =>
      state != oldWidget.state;
}

/// Timing and warm-window scope shared by descendant tooltips.
class BeuiTooltipProvider extends StatefulWidget {
  const BeuiTooltipProvider({
    required this.child,
    this.delay = const Duration(milliseconds: 120),
    this.closeDelay = Duration.zero,
    this.skipDelay = const Duration(milliseconds: 300),
    super.key,
  });

  final Duration delay;
  final Duration closeDelay;
  final Duration skipDelay;
  final Widget child;

  @override
  State<BeuiTooltipProvider> createState() => _TooltipProviderState();
}

class _TooltipProviderState extends State<BeuiTooltipProvider> {
  Object? _active;
  bool _activeVisible = false;
  VoidCallback? _closeActive;
  DateTime? _warmUntil;

  bool get _isWarm => _warmUntil != null && clock.now().isBefore(_warmUntil!);

  bool claim(Object owner, VoidCallback close) {
    final wasWarm = _isWarm || _activeVisible;
    if (_active != owner) {
      _closeActive?.call();
      _activeVisible = false;
    }
    _active = owner;
    _closeActive = close;
    _warmUntil = null;
    return wasWarm;
  }

  void markVisible(Object owner) {
    if (_active == owner) _activeVisible = true;
  }

  void release(Object owner, {bool warm = true}) {
    if (_active == owner) {
      _active = null;
      _closeActive = null;
      _warmUntil = warm && _activeVisible
          ? clock.now().add(widget.skipDelay)
          : null;
      _activeVisible = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      _TooltipProviderScope(state: this, child: widget.child);
}

/// The trigger slot of [BeuiTooltip.composed]. Child handlers remain intact.
class BeuiTooltipTrigger extends StatelessWidget {
  const BeuiTooltipTrigger({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

/// Content and placement for [BeuiTooltip.composed].
class BeuiTooltipContent extends StatelessWidget {
  const BeuiTooltipContent({
    required this.child,
    this.side = BeuiTooltipSide.top,
    this.align = BeuiTooltipAlign.center,
    this.arrow = false,
    this.sideOffset = 8,
    super.key,
  });
  final Widget child;
  final BeuiTooltipSide side;
  final BeuiTooltipAlign align;
  final bool arrow;
  final double sideOffset;
  @override
  Widget build(BuildContext context) => child;
}

/// Which side of the trigger the tooltip appears on.
enum BeuiTooltipSide {
  /// Above the trigger (default).
  top,

  /// To the right.
  right,

  /// Below.
  bottom,

  /// To the left.
  left,
}

/// Alignment of the tooltip along the cross axis of [BeuiTooltipSide].
enum BeuiTooltipAlign {
  /// Start edge (left for top/bottom, top for left/right).
  start,

  /// Centered on the trigger (default).
  center,

  /// End edge (right for top/bottom, bottom for left/right).
  end,
}

/// A hover, keyboard-focus, and touch tooltip built on [BeuiOverlay].
///
/// Hover respects [delay]; keyboard focus and touch taps reveal immediately.
/// The source's `TooltipSurface` scales from 0.94 and fades over 180ms, then
/// exits over 120ms. Reduced motion keeps the fade without scaling. A pointer
/// corridor lets the user cross the gap onto the label without closing it.
class BeuiTooltip extends StatefulWidget {
  /// Creates a tooltip around [child].
  const BeuiTooltip({
    required this.content,
    required this.child,
    this.side = BeuiTooltipSide.top,
    this.align = BeuiTooltipAlign.center,
    this.arrow = false,
    this.disabled = false,
    this.delay,
    this.closeDelay,
    this.sideOffset = 8,
    this.open,
    this.defaultOpen = false,
    this.onOpenChange,
    this.followCursor = false,
    this.avoidCollisions = true,
    super.key,
  });

  /// Composes typed trigger and content slots without painting content inline.
  BeuiTooltip.composed({
    required BeuiTooltipTrigger trigger,
    required BeuiTooltipContent tooltip,
    this.disabled = false,
    this.delay,
    this.closeDelay,
    this.open,
    this.defaultOpen = false,
    this.onOpenChange,
    this.followCursor = false,
    this.avoidCollisions = true,
    super.key,
  }) : child = trigger,
       content = tooltip.child,
       side = tooltip.side,
       align = tooltip.align,
       arrow = tooltip.arrow,
       sideOffset = tooltip.sideOffset;

  /// The tooltip body (usually a [Text]).
  final Widget content;

  /// The trigger.
  final Widget child;

  /// Which side to show on.
  final BeuiTooltipSide side;

  /// Cross-axis alignment against the trigger.
  final BeuiTooltipAlign align;

  /// Draw a pointer toward the trigger (source `arrow`).
  final bool arrow;

  /// Never show, e.g. while the label it carries is already visible.
  final bool disabled;

  /// Delay before opening on hover/focus (skipped within the warm window).
  final Duration? delay;

  /// Delay after leaving both trigger and tooltip.
  final Duration? closeDelay;

  /// Gap between trigger and floating surface in logical pixels.
  final double sideOffset;

  /// Controlled visibility. Omit to let pointer and focus manage visibility.
  final bool? open;

  /// Initial uncontrolled visibility.
  final bool defaultOpen;

  /// Visibility requests from hover, focus, touch, Escape, or outside presses.
  final ValueChanged<bool>? onOpenChange;

  /// Track the pointer while open; focus-triggered tooltips remain anchored.
  final bool followCursor;

  /// Flip sides and shift the surface to keep it inside the viewport.
  final bool avoidCollisions;

  @override
  State<BeuiTooltip> createState() => _BeuiTooltipState();
}

class _BeuiTooltipState extends State<BeuiTooltip> {
  final Object _owner = Object();
  final GlobalKey _triggerKey = GlobalKey();
  final GlobalKey _surfaceKey = GlobalKey();
  final FocusNode _triggerFocus = FocusNode(
    debugLabel: 'Tooltip trigger scope',
  );
  late bool _internalOpen = widget.defaultOpen;
  bool get _open => !widget.disabled && (widget.open ?? _internalOpen);
  bool _focused = false;
  bool _pointerFocus = false;
  bool _suppressed = false;
  Offset? _touchStart;
  bool _touchWasOpen = false;
  ({Path corridor, Rect source, Rect target})? _grace;
  Timer? _timer;
  Offset? _pointerGlobal;
  Offset _collisionShift = Offset.zero;
  BeuiTooltipSide? _resolvedSide;
  _TooltipProviderState? _provider;

  @override
  void initState() {
    super.initState();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalPointer);
    HardwareKeyboard.instance.addHandler(_onKeyboardModality);
  }

  @override
  void dispose() {
    _timer?.cancel();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onGlobalPointer);
    HardwareKeyboard.instance.removeHandler(_onKeyboardModality);
    _triggerFocus.dispose();
    _provider?.release(_owner);
    super.dispose();
  }

  bool _onKeyboardModality(KeyEvent event) {
    _pointerFocus = false;
    if (event is KeyDownEvent &&
        event.logicalKey != LogicalKeyboardKey.escape &&
        _triggerFocus.hasFocus) {
      _focused = true;
      _suppressed = false;
      _show(immediate: true);
    }
    return false;
  }

  @override
  void didUpdateWidget(covariant BeuiTooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.disabled && widget.disabled) {
      _timer?.cancel();
      _timer = null;
      if (widget.open == null) _internalOpen = false;
      _provider?.release(_owner, warm: false);
    }
    if (oldWidget.side != widget.side ||
        oldWidget.avoidCollisions != widget.avoidCollisions) {
      _resolvedSide = null;
      _collisionShift = Offset.zero;
      if (widget.avoidCollisions && _open) _measureCollision();
    }
  }

  void _show({bool immediate = false}) {
    if (widget.disabled) return;
    _timer?.cancel();
    _timer = null;
    if (_open) return;
    final warm = _provider?.claim(_owner, _hideFromProvider) ?? false;
    final delay = immediate || warm
        ? Duration.zero
        : widget.delay ??
              _provider?.widget.delay ??
              const Duration(milliseconds: 120);
    _timer = Timer(delay, () {
      _timer = null;
      if (mounted && !widget.disabled) {
        _provider?.markVisible(_owner);
        _commit(true);
        _measureCollision();
      }
    });
  }

  void _hideFromProvider() {
    _timer?.cancel();
    _timer = null;
    if (_open && mounted) _commit(false);
  }

  void _commit(bool next) {
    if (_open == next) return;
    if (widget.open == null) setState(() => _internalOpen = next);
    widget.onOpenChange?.call(next);
  }

  void _hide() {
    _timer?.cancel();
    _timer = null;
    _grace = null;
    final closeDelay =
        widget.closeDelay ?? _provider?.widget.closeDelay ?? Duration.zero;
    if (closeDelay > Duration.zero && _open) {
      _timer = Timer(closeDelay, _finishHide);
      return;
    }
    _finishHide();
  }

  void _finishHide({bool warm = true}) {
    if (_open) {
      _commit(false);
    }
    _provider?.release(_owner, warm: warm);
  }

  Rect? _bounds(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    return box == null || !box.hasSize
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
  }

  void _startGrace(Offset exit, GlobalKey from, GlobalKey to) {
    _timer?.cancel();
    _timer = null;
    final source = _bounds(from);
    final target = _bounds(to);
    if (!_open || widget.followCursor || source == null || target == null) {
      _hide();
      return;
    }
    final boundary = Offset(
      exit.dx.clamp(source.left, source.right),
      exit.dy.clamp(source.top, source.bottom),
    );
    final corridor = _graceCorridor(boundary, target);
    if (!corridor.contains(exit) &&
        !target.contains(exit) &&
        !source.contains(exit)) {
      _hide();
      return;
    }
    _grace = (corridor: corridor, source: source, target: target);
  }

  void _onGlobalPointer(PointerEvent event) {
    if (!_open) return;
    final trigger = _bounds(_triggerKey);
    final surface = _bounds(_surfaceKey);
    if (event is PointerDownEvent &&
        !(trigger?.contains(event.position) ?? false) &&
        !(surface?.contains(event.position) ?? false)) {
      _finishHide();
    }
    final grace = _grace;
    if (grace != null &&
        (event is PointerHoverEvent || event is PointerMoveEvent)) {
      if (grace.source.contains(event.position) ||
          grace.target.contains(event.position)) {
        return;
      }
      if (!grace.corridor.contains(event.position)) _hide();
    }
  }

  void _onPointerHover(PointerEvent event) {
    if (!widget.followCursor || _focused) return;
    _pointerGlobal = event.position;
    _measureCollision();
    if (_open) setState(() {});
  }

  void _measureCollision() {
    if (!widget.avoidCollisions) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_open || !widget.avoidCollisions) return;
      final trigger =
          _triggerKey.currentContext?.findRenderObject() as RenderBox?;
      final surface =
          _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
      if (trigger == null ||
          surface == null ||
          !trigger.hasSize ||
          !surface.hasSize) {
        return;
      }
      final media = MediaQuery.maybeOf(context);
      if (media == null) return;
      final origin = trigger.localToGlobal(Offset.zero);
      final triggerRect = origin & trigger.size;
      final anchorRect =
          widget.followCursor && !_focused && _pointerGlobal != null
          ? Rect.fromCenter(center: _pointerGlobal!, width: 1, height: 1)
          : triggerRect;
      final size = surface.size;
      final preferred = widget.side;
      var side = preferred;
      final room = <BeuiTooltipSide, double>{
        BeuiTooltipSide.top: anchorRect.top,
        BeuiTooltipSide.bottom: media.size.height - anchorRect.bottom,
        BeuiTooltipSide.left: anchorRect.left,
        BeuiTooltipSide.right: media.size.width - anchorRect.right,
      };
      final needed =
          (BeuiTooltipSide.top == preferred ||
              preferred == BeuiTooltipSide.bottom)
          ? size.height + widget.sideOffset
          : size.width + widget.sideOffset;
      if (room[preferred]! < needed) {
        final opposite = switch (preferred) {
          BeuiTooltipSide.top => BeuiTooltipSide.bottom,
          BeuiTooltipSide.bottom => BeuiTooltipSide.top,
          BeuiTooltipSide.left => BeuiTooltipSide.right,
          BeuiTooltipSide.right => BeuiTooltipSide.left,
        };
        final oppositeNeeded =
            (opposite == BeuiTooltipSide.top ||
                opposite == BeuiTooltipSide.bottom)
            ? size.height + widget.sideOffset
            : size.width + widget.sideOffset;
        if (room[opposite]! > room[preferred]! &&
            room[opposite]! >= oppositeNeeded) {
          side = opposite;
        }
      }
      final anchorPoint = _anchorOrigin(anchorRect, side);
      final positioned = _surfaceOrigin(anchorPoint, size, side, widget.align);
      final shift = Offset(
        math.max(8 - positioned.dx, 0) -
            math.max(positioned.dx + size.width - media.size.width + 8, 0),
        math.max(8 - positioned.dy, 0) -
            math.max(positioned.dy + size.height - media.size.height + 8, 0),
      );
      if (_resolvedSide != side || _collisionShift != shift) {
        setState(() {
          _resolvedSide = side;
          _collisionShift = shift;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _provider = _TooltipProviderScope.maybeOf(context);
    final side = _resolvedSide ?? widget.side;
    return BeuiOverlay(
      open: _open,
      barrier: false,
      trapFocus: false,
      onDismiss: _hide,
      enterDuration: const Duration(milliseconds: 180),
      exitDuration: const Duration(milliseconds: 120),
      overlayBuilder: (context, animation, link) =>
          _buildTooltip(context, animation, link, side),
      child: MouseRegion(
        onHover: _onPointerHover,
        onEnter: (event) {
          _grace = null;
          _pointerGlobal = event.position;
          if (!_suppressed) _show();
        },
        onExit: (event) {
          _suppressed = false;
          if (!_focused) _startGrace(event.position, _triggerKey, _surfaceKey);
        },
        child: Focus(
          key: _triggerKey,
          focusNode: _triggerFocus,
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (focused) {
            _focused = focused && !_pointerFocus;
            if (_focused) {
              _show(immediate: true);
            } else if (!focused) {
              _pointerFocus = false;
              _hide();
            }
          },
          child: Listener(
            onPointerDown: (event) {
              _pointerFocus = true;
              if (event.kind == PointerDeviceKind.mouse) {
                _suppressed = true;
                _finishHide();
              } else {
                _touchStart = event.position;
                _touchWasOpen = _open;
              }
            },
            onPointerCancel: (_) => _touchStart = null,
            onPointerUp: (event) {
              final start = _touchStart;
              _touchStart = null;
              if (start != null && (event.position - start).distance <= 18) {
                _touchWasOpen ? _finishHide() : _show(immediate: true);
              }
            },
            child: GestureDetector(
              onLongPressStart: (_) => _show(immediate: true),
              onLongPressEnd: (_) {
                _touchStart = null;
                _hide();
              },
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTooltip(
    BuildContext context,
    Animation<double> animation,
    LayerLink link,
    BeuiTooltipSide side,
  ) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    _measureCollision();
    final spec = _spec(side, widget.align);
    final trigger =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final pointerOffset =
        widget.followCursor &&
            !_focused &&
            _pointerGlobal != null &&
            trigger != null
        ? _pointerGlobal! -
              trigger.localToGlobal(Offset.zero) -
              Offset(trigger.size.width / 2, trigger.size.height / 2)
        : Offset.zero;
    final actualOffset = spec.gap + _collisionShift + pointerOffset;

    return CompositedTransformFollower(
      link: link,
      showWhenUnlinked: false,
      targetAnchor: widget.followCursor && !_focused && _pointerGlobal != null
          ? Alignment.center
          : spec.targetAnchor,
      followerAnchor: spec.followerAnchor,
      offset: actualOffset,
      child: KeyedSubtree(
        key: _surfaceKey,
        child: MouseRegion(
          onEnter: (_) {
            _grace = null;
            _timer?.cancel();
            _timer = null;
          },
          onExit: (event) {
            if (!_focused) {
              _startGrace(event.position, _surfaceKey, _triggerKey);
            }
          },
          child: IgnorePointer(
            ignoring: widget.followCursor || !_open,
            child: AnimatedBuilder(
              animation: animation,
              child: _surface(colors, side),
              builder: (context, surface) {
                final t = animation.value.clamp(0.0, 1.0);
                final exiting =
                    animation.status == AnimationStatus.reverse ||
                    animation.status == AnimationStatus.dismissed;
                final progress = exiting
                    ? 1 - beuiEaseOut.transform(1 - t)
                    : beuiEaseOut.transform(t);
                return Transform.scale(
                  scale: reduce ? 1 : 0.94 + 0.06 * progress,
                  alignment: spec.origin,
                  child: Opacity(opacity: progress, child: surface),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _surface(BeuiColors colors, BeuiTooltipSide side) {
    final bubble = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background, // bg-background (opaque)
        border: Border.all(color: colors.border), // border-border
        borderRadius: BorderRadius.circular(8), // rounded-lg
        boxShadow: const [
          // shadow-lg: 0 10px 15px -3px rgb(0 0 0 / .1),
          //           0 4px 6px -4px rgb(0 0 0 / .1)
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 15,
            spreadRadius: -3,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 6,
            spreadRadius: -4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        // CSS border-box includes the one-pixel border outside px-2.5/py-1.
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w500,
            color: colors.foreground, // text-foreground
          ),
          child: widget.content,
        ),
      ),
    );
    if (!widget.arrow) return bubble;
    final pointer = CustomPaint(
      size: const Size(12, 12),
      painter: _TooltipArrowPainter(
        fill: colors.background,
        border: colors.border,
        side: side,
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        bubble,
        switch (side) {
          BeuiTooltipSide.top => Positioned(bottom: -6, child: pointer),
          BeuiTooltipSide.bottom => Positioned(top: -6, child: pointer),
          BeuiTooltipSide.left => Positioned(right: -6, child: pointer),
          BeuiTooltipSide.right => Positioned(left: -6, child: pointer),
        },
      ],
    );
  }

  _TooltipSpec _spec(BeuiTooltipSide side, BeuiTooltipAlign align) {
    final start = align == BeuiTooltipAlign.start;
    final end = align == BeuiTooltipAlign.end;
    return switch (side) {
      BeuiTooltipSide.top => _TooltipSpec(
        targetAnchor: start
            ? Alignment.topLeft
            : end
            ? Alignment.topRight
            : Alignment.topCenter,
        followerAnchor: start
            ? Alignment.bottomLeft
            : end
            ? Alignment.bottomRight
            : Alignment.bottomCenter,
        gap: Offset(0, -widget.sideOffset),
        origin: Alignment.bottomCenter,
      ),
      BeuiTooltipSide.bottom => _TooltipSpec(
        targetAnchor: start
            ? Alignment.bottomLeft
            : end
            ? Alignment.bottomRight
            : Alignment.bottomCenter,
        followerAnchor: start
            ? Alignment.topLeft
            : end
            ? Alignment.topRight
            : Alignment.topCenter,
        gap: Offset(0, widget.sideOffset),
        origin: Alignment.topCenter,
      ),
      BeuiTooltipSide.left => _TooltipSpec(
        targetAnchor: start
            ? Alignment.topLeft
            : end
            ? Alignment.bottomLeft
            : Alignment.centerLeft,
        followerAnchor: start
            ? Alignment.topRight
            : end
            ? Alignment.bottomRight
            : Alignment.centerRight,
        gap: Offset(-widget.sideOffset, 0),
        origin: Alignment.centerRight,
      ),
      BeuiTooltipSide.right => _TooltipSpec(
        targetAnchor: start
            ? Alignment.topRight
            : end
            ? Alignment.bottomRight
            : Alignment.centerRight,
        followerAnchor: start
            ? Alignment.topLeft
            : end
            ? Alignment.bottomLeft
            : Alignment.centerLeft,
        gap: Offset(widget.sideOffset, 0),
        origin: Alignment.centerLeft,
      ),
    };
  }

  Offset _anchorOrigin(Rect trigger, BeuiTooltipSide side) {
    final horizontal = switch (widget.align) {
      BeuiTooltipAlign.start => trigger.left,
      BeuiTooltipAlign.center => trigger.center.dx,
      BeuiTooltipAlign.end => trigger.right,
    };
    final vertical = switch (widget.align) {
      BeuiTooltipAlign.start => trigger.top,
      BeuiTooltipAlign.center => trigger.center.dy,
      BeuiTooltipAlign.end => trigger.bottom,
    };
    return switch (side) {
      BeuiTooltipSide.top => Offset(horizontal, trigger.top),
      BeuiTooltipSide.bottom => Offset(horizontal, trigger.bottom),
      BeuiTooltipSide.left => Offset(trigger.left, vertical),
      BeuiTooltipSide.right => Offset(trigger.right, vertical),
    };
  }

  Offset _surfaceOrigin(
    Offset anchor,
    Size size,
    BeuiTooltipSide side,
    BeuiTooltipAlign align,
  ) {
    final cross = switch (align) {
      BeuiTooltipAlign.start => 0.0,
      BeuiTooltipAlign.center => 0.5,
      BeuiTooltipAlign.end => 1.0,
    };
    return switch (side) {
      BeuiTooltipSide.top => Offset(
        anchor.dx - size.width * cross,
        anchor.dy - size.height - widget.sideOffset,
      ),
      BeuiTooltipSide.bottom => Offset(
        anchor.dx - size.width * cross,
        anchor.dy + widget.sideOffset,
      ),
      BeuiTooltipSide.left => Offset(
        anchor.dx - size.width - widget.sideOffset,
        anchor.dy - size.height * cross,
      ),
      BeuiTooltipSide.right => Offset(
        anchor.dx + widget.sideOffset,
        anchor.dy - size.height * cross,
      ),
    };
  }
}

Path _graceCorridor(Offset exit, Rect target) {
  final start = Rect.fromCircle(center: exit, radius: 5);
  final points = [
    start.topLeft,
    start.topRight,
    start.bottomRight,
    start.bottomLeft,
    target.topLeft,
    target.topRight,
    target.bottomRight,
    target.bottomLeft,
  ]..sort((a, b) => a.dx == b.dx ? a.dy.compareTo(b.dy) : a.dx.compareTo(b.dx));
  double cross(Offset origin, Offset a, Offset b) =>
      (a.dx - origin.dx) * (b.dy - origin.dy) -
      (a.dy - origin.dy) * (b.dx - origin.dx);
  List<Offset> half(Iterable<Offset> points) {
    final hull = <Offset>[];
    for (final point in points) {
      while (hull.length >= 2 &&
          cross(hull[hull.length - 2], hull.last, point) <= 0) {
        hull.removeLast();
      }
      hull.add(point);
    }
    return hull..removeLast();
  }

  return Path()..addPolygon([...half(points), ...half(points.reversed)], true);
}

class _TooltipSpec {
  const _TooltipSpec({
    required this.targetAnchor,
    required this.followerAnchor,
    required this.gap,
    required this.origin,
  });
  final Alignment targetAnchor;
  final Alignment followerAnchor;
  final Offset gap;
  final Alignment origin;
}

class _TooltipArrowPainter extends CustomPainter {
  const _TooltipArrowPainter({
    required this.fill,
    required this.border,
    required this.side,
  });

  final Color fill;
  final Color border;
  final BeuiTooltipSide side;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    switch (side) {
      case BeuiTooltipSide.top:
        path
          ..moveTo(0, size.height / 2)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(size.width, size.height / 2);
      case BeuiTooltipSide.bottom:
        path
          ..moveTo(0, size.height / 2)
          ..lineTo(size.width / 2, 0)
          ..lineTo(size.width, size.height / 2);
      case BeuiTooltipSide.left:
        path
          ..moveTo(size.width / 2, 0)
          ..lineTo(size.width, size.height / 2)
          ..lineTo(size.width / 2, size.height);
      case BeuiTooltipSide.right:
        path
          ..moveTo(size.width / 2, 0)
          ..lineTo(0, size.height / 2)
          ..lineTo(size.width / 2, size.height);
    }
    canvas.drawPath(
      Path.from(path)..close(),
      Paint()
        ..color = fill
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _TooltipArrowPainter oldDelegate) =>
      fill != oldDelegate.fill ||
      border != oldDelegate.border ||
      side != oldDelegate.side;
}
