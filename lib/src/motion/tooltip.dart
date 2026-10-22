import 'dart:async';
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
/// touch) and on keyboard focus, after a short [delay]; a global **warm window**
/// makes neighbouring tooltips open instantly once one has just closed. On touch
/// it reveals on long-press. The surface anchors to the trigger via the overlay
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
    this.delay = const Duration(milliseconds: 120),
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
  final Duration delay;

  @override
  State<BeuiTooltip> createState() => _BeuiTooltipState();
}

class _BeuiTooltipState extends State<BeuiTooltip> {
  static const int _warmWindowMs = 300;
  static int _lastHiddenAtMs = 0;

  bool _open = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _show({bool immediate = false}) {
    if (widget.disabled) return;
    _timer?.cancel();
    final warm =
        clock.now().millisecondsSinceEpoch - _lastHiddenAtMs < _warmWindowMs;
    final delay = immediate || warm ? Duration.zero : widget.delay;
    _timer = Timer(delay, () {
      if (mounted && !widget.disabled) setState(() => _open = true);
    });
  }

  void _hide() {
    _timer?.cancel();
    _timer = null;
    if (_open) {
      _lastHiddenAtMs = clock.now().millisecondsSinceEpoch;
      setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return BeuiOverlay(
      open: _open,
      barrier: false,
      trapFocus: false,
      onDismiss: _hide,
      enterDuration: Duration(milliseconds: reduce ? 140 : _enterMs),
      exitDuration: Duration(milliseconds: reduce ? 100 : 120),
      overlayBuilder: _buildTooltip,
      child: MouseRegion(
        onEnter: (_) => _show(),
        onExit: (_) => _hide(),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (focused) => focused ? _show() : _hide(),
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
  ) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final spec = _spec(widget.side, widget.align);

    return CompositedTransformFollower(
      link: link,
      showWhenUnlinked: false,
      targetAnchor: spec.targetAnchor,
      followerAnchor: spec.followerAnchor,
      offset: spec.gap,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: animation,
          // PERF: the opaque surface is built once and threaded through the
          // `child` slot; per-frame work is only the Transform / Opacity /
          // ImageFiltered wrappers below.
          child: _surface(colors),
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
    );
  }

  Widget _surface(BeuiColors colors) {
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
      size: switch (widget.side) {
        BeuiTooltipSide.left || BeuiTooltipSide.right => const Size(6, 10),
        _ => const Size(10, 6),
      },
      painter: _TooltipArrowPainter(
        fill: colors.background,
        border: colors.border,
        side: widget.side,
      ),
    );
    return switch (widget.side) {
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
