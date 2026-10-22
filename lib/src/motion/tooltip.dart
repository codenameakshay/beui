import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart' show SingleMotionBuilder, SpringMotion;

/// The source's bespoke tooltip enter spring for scale/offset:
/// `{stiffness: 380, damping: 30, mass: 0.7}`.
const _enterSpring = SpringMotion(
  SpringDescription(mass: 0.7, stiffness: 380, damping: 30),
);

/// Per-channel enter windows on the overlay clock: opacity finishes at 140ms
/// (source `opacity: { duration: 0.14 }`, EASE_OUT), blur at 180ms (source
/// `filter: { duration: 0.18 }`, EASE_OUT); scale/offset ride [_enterSpring]
/// independently. The overlay's enter duration spans the full spring settle
/// (the longest window).
const _enterMs = 300;
const _opacityInMs = 140;
const _blurInMs = 180;

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

/// Optional compositional trigger wrapper.
class BeuiTooltipTrigger extends StatelessWidget {
  const BeuiTooltipTrigger({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

/// Optional compositional content wrapper.
class BeuiTooltipContent extends StatelessWidget {
  const BeuiTooltipContent({required this.child, super.key});
  final Widget child;
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

/// A hover/focus tooltip with a spring spawn and blur enter/exit — the Flutter
/// port of beUI's `tooltip`, built on [BeuiOverlay].
///
/// Opens on pointer hover (hover-capable only — `MouseRegion` never fires on
/// touch) and on keyboard focus, after a short [delay]. A surrounding
/// [BeuiTooltipProvider] shares timing and its warm window across siblings. On
/// touch it reveals on long-press. The surface anchors to the trigger via the overlay
/// [LayerLink] and rises into place from near the trigger: scale + offset ride
/// the source's bespoke 380/30/0.7 spring, while opacity (140ms) and blur
/// (180ms) run on their own `EASE_OUT` windows. The exit eases *forward* to its
/// own targets (scale 0.94, 4.8px away, blur σ1.5, opacity 0) over 120ms
/// (source `exit` `duration: 0.12`) — it is not a time-reversed entrance.
/// Reduced motion fades opacity only
/// (140ms in / 100ms out).
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
    this.followCursor = false,
    this.avoidCollisions = true,
    super.key,
  });

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
  bool _open = false;
  bool _focused = false;
  bool _skipEnterAnimation = false;
  Timer? _timer;
  Offset? _pointerGlobal;
  Offset _collisionShift = Offset.zero;
  BeuiTooltipSide? _resolvedSide;
  _TooltipProviderState? _provider;

  @override
  void dispose() {
    _timer?.cancel();
    _provider?.release(_owner);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BeuiTooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.disabled && widget.disabled) {
      _timer?.cancel();
      _timer = null;
      if (_open) setState(() => _open = false);
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
    _skipEnterAnimation = warm;
    final delay = immediate || warm
        ? Duration.zero
        : widget.delay ??
              _provider?.widget.delay ??
              const Duration(milliseconds: 120);
    _timer = Timer(delay, () {
      _timer = null;
      if (mounted && !widget.disabled) {
        _provider?.markVisible(_owner);
        setState(() => _open = true);
        _measureCollision();
      }
    });
  }

  void _hideFromProvider() {
    _timer?.cancel();
    _timer = null;
    if (_open && mounted) setState(() => _open = false);
  }

  void _hide() {
    _timer?.cancel();
    _timer = null;
    final closeDelay = _provider?.widget.closeDelay ?? Duration.zero;
    if (closeDelay > Duration.zero && _open) {
      _timer = Timer(closeDelay, _finishHide);
      return;
    }
    _finishHide();
  }

  void _finishHide({bool warm = true}) {
    if (_open) {
      setState(() => _open = false);
    }
    _provider?.release(_owner, warm: warm);
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
          ? size.height + 8
          : size.width + 8;
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
            ? size.height + 8
            : size.width + 8;
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
    final reduce = MediaQuery.disableAnimationsOf(context);
    return BeuiOverlay(
      open: _open,
      barrier: false,
      trapFocus: false,
      onDismiss: _hide,
      enterDuration: _skipEnterAnimation
          ? Duration.zero
          : Duration(milliseconds: reduce ? 140 : _enterMs),
      exitDuration: Duration(milliseconds: reduce ? 100 : 120),
      overlayBuilder: (context, animation, link) =>
          _buildTooltip(context, animation, link, side),
      child: MouseRegion(
        onHover: _onPointerHover,
        onEnter: (event) {
          _pointerGlobal = event.position;
          _show();
        },
        onExit: (_) => _hide(),
        child: Focus(
          key: _triggerKey,
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (focused) {
            _focused = focused;
            focused ? _show() : _hide();
          },
          child: GestureDetector(
            onLongPressStart: (_) => _show(immediate: true),
            onLongPressEnd: (_) => _hide(),
            child: widget.child,
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
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: animation,
            // PERF: the opaque surface is built once and threaded through the
            // `child` slot; per-frame work is only the Transform / Opacity /
            // ImageFiltered wrappers below.
            child: _surface(colors, side),
            builder: (context, surface) {
              final t = animation.value.clamp(0.0, 1.0);
              final exiting =
                  animation.status == AnimationStatus.reverse ||
                  animation.status == AnimationStatus.dismissed;
              if (reduce) {
                // Opacity-only: 140ms in / 100ms out, EASE_OUT forward in each
                // direction.
                final opacity = exiting
                    ? 1 - beuiEaseOut.transform(1 - t)
                    : beuiEaseOut.transform(t);
                return Opacity(opacity: opacity, child: surface);
              }
              if (exiting) {
                // Forward-eased exit with its OWN targets (not a reversed
                // entrance): 120ms EASE_OUT to scale 0.94, 4.8px toward the
                // trigger (0.6 × the 8px enter offset), source blur(3px) → σ1.5,
                // opacity 0.
                final p = beuiEaseOut.transform(1 - t); // exit progress 0 → 1
                final blur = 1.5 * p;
                Widget body = surface!;
                if (blur > 0.05) {
                  body = ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: blur,
                      sigmaY: blur,
                      tileMode: TileMode.decal,
                    ),
                    child: body,
                  );
                }
                return Transform.translate(
                  offset: spec.away * (0.6 * p),
                  child: Transform.scale(
                    scale: 1 - 0.06 * p,
                    alignment: spec.origin,
                    child: Opacity(opacity: 1 - p, child: body),
                  ),
                );
              }
              // Enter: opacity over the first 140ms of the clock, blur over the
              // first 180ms — both EASE_OUT; scale/offset ride the 380/30/0.7
              // spring on its own ticker.
              final opacity = beuiEaseOut.transform(
                (t * (_enterMs / _opacityInMs)).clamp(0.0, 1.0),
              );
              // Source enter blur(5px) → σ2.5, closed over the 180ms window.
              final blur =
                  2.5 *
                  (1 -
                      beuiEaseOut.transform(
                        (t * (_enterMs / _blurInMs)).clamp(0.0, 1.0),
                      ));
              return SingleMotionBuilder(
                value: 1.0,
                from: 0.0,
                motion: _enterSpring,
                child: surface,
                builder: (context, s, inner) {
                  Widget body = inner!;
                  if (blur > 0.05) {
                    body = ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: blur,
                        sigmaY: blur,
                        tileMode: TileMode.decal,
                      ),
                      child: body,
                    );
                  }
                  return Transform.translate(
                    offset: spec.away * (1 - s),
                    child: Transform.scale(
                      scale: 0.9 + 0.1 * s,
                      alignment: spec.origin,
                      child: Opacity(opacity: opacity, child: body),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _surface(BeuiColors colors, BeuiTooltipSide side) {
    // Source surface: `rounded-lg border border-border bg-background px-2.5 py-1
    // text-xs font-medium text-foreground shadow-lg` — a SOLID OPAQUE pill, no
    // backdrop blur.
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.foreground, // text-foreground
          ),
          child: widget.content,
        ),
      ),
    );
    if (!widget.arrow) return bubble;
    final pointer = CustomPaint(
      size: switch (side) {
        BeuiTooltipSide.left || BeuiTooltipSide.right => const Size(6, 10),
        _ => const Size(10, 6),
      },
      painter: _TooltipArrowPainter(
        fill: colors.background,
        border: colors.border,
        side: side,
      ),
    );
    return switch (side) {
      BeuiTooltipSide.top => Column(
        mainAxisSize: MainAxisSize.min,
        children: [bubble, pointer],
      ),
      BeuiTooltipSide.bottom => Column(
        mainAxisSize: MainAxisSize.min,
        children: [pointer, bubble],
      ),
      BeuiTooltipSide.left => Row(
        mainAxisSize: MainAxisSize.min,
        children: [bubble, pointer],
      ),
      BeuiTooltipSide.right => Row(
        mainAxisSize: MainAxisSize.min,
        children: [pointer, bubble],
      ),
    };
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
        gap: const Offset(0, -8),
        away: const Offset(0, 8),
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
        gap: const Offset(0, 8),
        away: const Offset(0, -8),
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
        gap: const Offset(-8, 0),
        away: const Offset(8, 0),
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
        gap: const Offset(8, 0),
        away: const Offset(-8, 0),
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
        anchor.dy - size.height - 8,
      ),
      BeuiTooltipSide.bottom => Offset(
        anchor.dx - size.width * cross,
        anchor.dy + 8,
      ),
      BeuiTooltipSide.left => Offset(
        anchor.dx - size.width - 8,
        anchor.dy - size.height * cross,
      ),
      BeuiTooltipSide.right => Offset(
        anchor.dx + 8,
        anchor.dy - size.height * cross,
      ),
    };
  }
}

class _TooltipSpec {
  const _TooltipSpec({
    required this.targetAnchor,
    required this.followerAnchor,
    required this.gap,
    required this.away,
    required this.origin,
  });
  final Alignment targetAnchor;
  final Alignment followerAnchor;
  final Offset gap;
  final Offset away;
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
          ..moveTo(0, 0)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(size.width, 0);
      case BeuiTooltipSide.bottom:
        path
          ..moveTo(0, size.height)
          ..lineTo(size.width / 2, 0)
          ..lineTo(size.width, size.height);
      case BeuiTooltipSide.left:
        path
          ..moveTo(0, 0)
          ..lineTo(size.width, size.height / 2)
          ..lineTo(0, size.height);
      case BeuiTooltipSide.right:
        path
          ..moveTo(size.width, 0)
          ..lineTo(0, size.height / 2)
          ..lineTo(size.width, size.height);
    }
    path.close();
    canvas.drawPath(
      path,
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
