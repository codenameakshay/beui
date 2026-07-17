import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '_engine.dart' show SingleMotionController, SpringMotion;

/// The two faces of the cylinder wall.
enum BeuiCylinderCurve {
  /// Inside of the cylinder (source default): the centre ball is the smallest
  /// and dips into a valley, growing and levelling out toward the edges.
  concave,

  /// Outside of the cylinder: the centre ball is the biggest and rides up on an
  /// arch, shrinking toward the edges.
  convex,
}

// ---------------------------------------------------------------------------
// Source constants (cylinder-carousel.tsx). Ported verbatim.
// ---------------------------------------------------------------------------

/// The carousel's bespoke *glide* spring — `{stiffness: 40, damping: 20,
/// mass: 3}` in the source. A Framer spring parameterized by stiffness/damping/
/// mass maps 1:1 onto [SpringDescription] (identical Hooke's-law form), so the
/// physics carry over with zero fidelity loss. It is deliberately soft and
/// heavy: a flick keeps rolling freely, drifts past the snap point and eases
/// back. The release velocity (items/second) is handed straight through via
/// `animateTo(..., withVelocity:)` so the roll never steps — it leaves the
/// finger at finger speed.
const _glideSpring = SpringMotion(
  SpringDescription(mass: 3, stiffness: 40, damping: 20),
);

/// How far a flick keeps rolling: projected items = release velocity ×
/// momentum (source `FLICK_MOMENTUM`).
const double _flickMomentum = 0.45;

/// Cap on a single flick's projected travel (source `MAX_FLICK_ITEMS`).
const double _maxFlickItems = 6;

/// The frame edge sits at this wall angle — how far the wall curves in frame
/// (source `THETA_EDGE`, 72°).
const double _thetaEdge = 72 * math.pi / 180;

/// Wall angle past which a ball is parked far off-stage, always hidden there
/// (source `THETA_CLAMP`, 95°).
const double _thetaClamp = 95 * math.pi / 180;

/// After a wheel gesture goes quiet for this long, the roll settles/snaps
/// (source `window.setTimeout(..., 140)`).
const Duration _wheelSettleDelay = Duration(milliseconds: 140);

/// A 3D cylinder carousel — the Flutter port of beUI's `cylinder-carousel`.
///
/// Every ball sits on the wall of a cylinder and is rendered through a single
/// perspective projection: horizontal position, size and height all share one
/// `1/(cosθ + k)` depth term, where θ is the ball's wall angle. Nothing
/// overlaps, fades or reorders — the frame edge is the exit, and items loop
/// continuously by wrapping to the nearest offset.
///
/// Two faces via [curve]: [BeuiCylinderCurve.concave] (default) is the inside
/// of the cylinder — the centre ball is smallest and dips into a valley,
/// growing toward the edges; [BeuiCylinderCurve.convex] is the outside — the
/// centre ball is biggest and rides an arch, shrinking toward the edges. Concave
/// balls follow the interior perspective spacing (slow, tight centre); convex
/// balls use uniform spacing (the interior projection would collapse the big
/// centre balls into each other).
///
/// **Motion.** A continuous `scroll` value, measured in item units, positions
/// the whole wall (`x = (i − scroll) × gap`). A drag writes it 1:1 so the wall
/// sticks to the pointer; on release the pointer velocity is handed to the soft,
/// heavy [_glideSpring] so the roll glides on and settles free (snapping to the
/// nearest item when [snap]). The wheel rolls it and settles ~140ms after it
/// goes quiet; arrow keys roll by one; [autoRotate] rolls it on its own until
/// touched, paused on hover.
///
/// **Reduced motion.** Direct manipulation is preserved — dragging still tracks
/// the pointer 1:1 — but the glide spring is dropped (releases snap instantly to
/// the target) and [autoRotate] is disabled, matching the source's
/// `useReducedMotion()` branch.
///
/// Controlled + uncontrolled: pass [index] + [onIndexChange] to drive the active
/// item externally, or leave [index] null and seed the initial position with
/// [defaultIndex] (the source is uncontrolled with `defaultIndex`; the
/// controlled [index] is the house `value`/`onChanged` convention layered on
/// top). [onIndexChange] always reports the settled centre item.
class BeuiCylinderCarousel extends StatefulWidget {
  /// Creates a cylinder carousel over [children].
  const BeuiCylinderCarousel({
    required this.children,
    this.itemSize = 200,
    this.visibleItems = 5,
    this.curve = BeuiCylinderCurve.concave,
    this.minScale = 0.55,
    this.dragSpeed = 1.5,
    this.arc,
    this.snap = true,
    this.autoRotate = false,
    this.autoRotateSpeed = 0.4,
    this.defaultIndex = 0,
    this.index,
    this.onIndexChange,
    this.height,
    super.key,
  });

  /// The balls, one per wall slot. Each is laid out in an [itemSize]-square box.
  final List<Widget> children;

  /// Max item box size in logical px (square) at full size, i.e. at the
  /// container edge. Balls shrink below this automatically so the row keeps
  /// breathing room in narrow containers.
  final double itemSize;

  /// How many item slots span the container width.
  final int visibleItems;

  /// Which face of the cylinder to show.
  final BeuiCylinderCurve curve;

  /// Scale of the smallest ball (centre for concave, edges for convex); the
  /// biggest reaches 1.
  final double minScale;

  /// Items rolled per item-width dragged — above 1 the wall outruns the pointer,
  /// which reads as a lighter, freer roll.
  final double dragSpeed;

  /// Curve depth in px: for concave, how far the edge balls ride above the
  /// centre one (valley); for convex, how far below (arch). 0 = flat line.
  /// Defaults to 35% of the resolved item size.
  final double? arc;

  /// Snap to the nearest item when the roll settles.
  final bool snap;

  /// Roll on its own until interacted with.
  final bool autoRotate;

  /// Auto-roll speed in items per second.
  final double autoRotateSpeed;

  /// Initial centre item when uncontrolled ([index] null).
  final int defaultIndex;

  /// Controlled active item. When non-null the carousel glides to this index
  /// whenever it changes; leave null for uncontrolled use.
  final int? index;

  /// Called with the settled centre item index whenever it changes.
  final ValueChanged<int>? onIndexChange;

  /// Stage height in px. Defaults to the resolved item size.
  final double? height;

  @override
  State<BeuiCylinderCarousel> createState() => _BeuiCylinderCarouselState();
}

class _BeuiCylinderCarouselState extends State<BeuiCylinderCarousel>
    with TickerProviderStateMixin {
  // scroll is in item units (continuous); item i sits at x = (i - scroll) * gap.
  late final SingleMotionController _scroll;
  late Ticker _autoTicker;
  Duration _autoLast = Duration.zero;

  int _activeIndex = 0;
  bool _dragging = false;
  bool _hovering = false;
  Timer? _wheelSettle;
  final FocusNode _focusNode = FocusNode(debugLabel: 'BeuiCylinderCarousel');

  // Per-drag velocity sampling (last two pointer positions/timestamps).
  double _startX = 0;
  double _startScroll = 0;
  double _lastX = 0;
  double _prevX = 0;
  Duration _lastT = Duration.zero;
  Duration _prevT = Duration.zero;

  // Geometry captured on the last build, needed by pointer handlers.
  double _gap = 1;

  // Cached each build so tick / pointer callbacks read it without touching
  // MediaQuery outside the build phase.
  bool _reduce = false;

  int get _count => widget.children.length;

  @override
  void initState() {
    super.initState();
    final seed = (widget.index ?? widget.defaultIndex).toDouble();
    _scroll = SingleMotionController(
      motion: _glideSpring,
      vsync: this,
      initialValue: seed,
    );
    _activeIndex = _indexFrom(seed);
    _scroll.addListener(_onScroll);
    _autoTicker = createTicker(_onAutoTick);
    if (widget.autoRotate) _autoTicker.start();
  }

  @override
  void didUpdateWidget(BeuiCylinderCarousel old) {
    super.didUpdateWidget(old);
    // Controlled index change → glide to the nearest wrapped target.
    if (widget.index != null && widget.index != old.index) {
      _glideTo(_nearestTargetFor(widget.index!), _scroll.velocity);
    }
    if (widget.autoRotate != old.autoRotate) {
      if (widget.autoRotate && !_autoTicker.isActive) {
        _autoLast = Duration.zero;
        _autoTicker.start();
      } else if (!widget.autoRotate && _autoTicker.isActive) {
        _autoTicker.stop();
      }
    }
  }

  @override
  void dispose() {
    _wheelSettle?.cancel();
    _autoTicker.dispose();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int _indexFrom(double v) {
    if (_count == 0) return 0;
    return ((v.round() % _count) + _count) % _count;
  }

  void _onScroll() {
    // The wall repaints via the AnimatedBuilder listening to `_scroll`; here we
    // only surface a settled index change.
    final idx = _indexFrom(_scroll.value);
    if (idx != _activeIndex) {
      _activeIndex = idx;
      widget.onIndexChange?.call(idx);
    }
  }

  // Nearest continuous scroll target whose rounded index equals `target`,
  // so a controlled jump takes the shortest way around the loop.
  double _nearestTargetFor(int target) {
    if (_count == 0) return _scroll.value;
    final current = _scroll.value;
    var delta = (target - current) % _count;
    delta -= (delta / _count).round() * _count;
    return current + delta;
  }

  // ---- glide / settle ----------------------------------------------------

  void _stopGlide() => _scroll.stop(canceled: true);

  /// Spring toward [to] carrying [velocity] (items/s), or snap instantly under
  /// reduced motion.
  void _glideTo(double to, double velocity) {
    _stopGlide();
    if (_reduce) {
      _scroll.value = to;
      return;
    }
    _scroll.animateTo(to, withVelocity: velocity);
  }

  void _settle(double velocity) {
    // Project how far the flick keeps rolling, then cap the *distance* at
    // MAX_FLICK_ITEMS — matching the source's `clamp(velocity * FLICK_MOMENTUM,
    // -6, 6)`. Clamping the raw velocity before scaling would cap travel at
    // 6 × 0.45 = 2.7 items instead of the intended 6. The raw velocity is still
    // handed to the settle spring unchanged so the roll leaves the finger at
    // finger speed.
    final projected =
        _scroll.value +
        (velocity * _flickMomentum).clamp(-_maxFlickItems, _maxFlickItems);
    _glideTo(widget.snap ? projected.roundToDouble() : projected, velocity);
  }

  void _rollBy(int dir) {
    _glideTo(_scroll.value.roundToDouble() + dir, _scroll.velocity);
  }

  // ---- pointer drag ------------------------------------------------------

  void _onPointerDown(PointerDownEvent e) {
    if (_count == 0) return;
    _stopGlide();
    _wheelSettle?.cancel();
    _dragging = true;
    final now = e.timeStamp;
    _startX = e.position.dx;
    _startScroll = _scroll.value;
    _lastX = _prevX = e.position.dx;
    _lastT = _prevT = now;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_dragging) return;
    _scroll.value =
        _startScroll - (e.position.dx - _startX) * widget.dragSpeed / _gap;
    _prevX = _lastX;
    _prevT = _lastT;
    _lastX = e.position.dx;
    _lastT = e.timeStamp;
  }

  void _onPointerUp(PointerEvent e) {
    if (!_dragging) return;
    _dragging = false;
    final dtMs = (_lastT - _prevT).inMicroseconds / 1000.0;
    final vpx = dtMs > 0 ? (_lastX - _prevX) / dtMs : 0.0; // px per ms
    // items per second: -vpx (px/ms) * dragSpeed * 1000 / gap.
    _settle(-vpx * widget.dragSpeed * 1000 / _gap);
  }

  // ---- wheel -------------------------------------------------------------

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || _count == 0) return;
    _stopGlide();
    final d = e.scrollDelta;
    final delta = d.dx.abs() > d.dy.abs() ? d.dx : d.dy;
    _scroll.value = _scroll.value + delta / _gap;
    _wheelSettle?.cancel();
    _wheelSettle = Timer(_wheelSettleDelay, () {
      if (mounted) _settle(_scroll.velocity);
    });
  }

  // ---- auto-rotate -------------------------------------------------------

  void _onAutoTick(Duration now) {
    if (_reduce) return;
    if (_autoLast == Duration.zero) {
      _autoLast = now;
      return;
    }
    final dt = (now - _autoLast).inMicroseconds / 1e6;
    _autoLast = now;
    if (!_dragging && !_hovering && !_scroll.isAnimating) {
      _scroll.value = _scroll.value + widget.autoRotateSpeed * dt;
    }
  }

  // ---- keyboard ----------------------------------------------------------

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _rollBy(1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _rollBy(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    _reduce = MediaQuery.disableAnimationsOf(context);
    final convex = widget.curve == BeuiCylinderCurve.convex;
    final edgeOffset = (widget.visibleItems + 1) / 2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stageWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 800.0;
        final halfWidth = stageWidth / 2;

        // Fit: the resting row's diameters may take at most ~65% of the stage;
        // `itemSize` only caps the result.
        var scaleSum = 0.0;
        for (var i = 0; i < widget.visibleItems; i++) {
          final t = (i - (widget.visibleItems - 1) / 2).abs() / edgeOffset;
          scaleSum += convex
              ? 1 - (1 - widget.minScale) * t
              : widget.minScale + (1 - widget.minScale) * t;
        }
        final size = math.min(widget.itemSize, stageWidth * 0.65 / scaleSum);

        final gap = stageWidth / (widget.visibleItems + 1);
        _gap = gap;
        final arc = widget.arc ?? size * 0.35;

        // Perspective constants (see source): the ball one slot past the frame
        // edge sits at THETA_EDGE with its centre on the container edge (scale
        // 1); k falls out of minScale, clamped so the projection stays
        // monotonic up to THETA_CLAMP.
        final alpha = _thetaEdge / edgeOffset;
        final k = math.max(
          0.2,
          (widget.minScale - math.cos(_thetaEdge)) / (1 - widget.minScale),
        );
        final projection =
            halfWidth * (math.cos(_thetaEdge) + k) / math.sin(_thetaEdge);

        final stageHeight = widget.height ?? size;

        return Focus(
          focusNode: _focusNode,
          onKeyEvent: _onKey,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            onEnter: (_) => _hovering = true,
            onExit: (_) => _hovering = false,
            child: Listener(
              onPointerDown: (e) {
                _focusNode.requestFocus();
                _onPointerDown(e);
              },
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerUp,
              onPointerSignal: _onPointerSignal,
              behavior: HitTestBehavior.opaque,
              // clip: also clips the transformed balls at the frame edge.
              child: ClipRect(
                child: SizedBox(
                  width: double.infinity,
                  height: stageHeight,
                  child: AnimatedBuilder(
                    animation: _scroll,
                    builder: (context, _) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var i = 0; i < _count; i++)
                          _CarouselBall(
                            scroll: _scroll.value,
                            index: i,
                            count: _count,
                            alpha: alpha,
                            k: k,
                            projection: projection,
                            gap: gap,
                            edgeOffset: edgeOffset,
                            minScale: widget.minScale,
                            convex: convex,
                            arc: arc,
                            halfWidth: halfWidth,
                            itemSize: size,
                            child: widget.children[i],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One ball on the cylinder wall, positioned from the continuous [scroll]
/// value. All geometry is a pure function of the wrapped offset — no state — so
/// the whole wall re-lays-out each frame as `scroll` changes.
class _CarouselBall extends StatelessWidget {
  const _CarouselBall({
    required this.scroll,
    required this.index,
    required this.count,
    required this.alpha,
    required this.k,
    required this.projection,
    required this.gap,
    required this.edgeOffset,
    required this.minScale,
    required this.convex,
    required this.arc,
    required this.halfWidth,
    required this.itemSize,
    required this.child,
  });

  final double scroll;
  final int index;
  final int count;

  /// Wall angle per item step, in radians.
  final double alpha;

  /// Camera distance term for the horizontal projection.
  final double k;

  /// Projection strength: maps sinθ/(cosθ+k) to px so θE lands on the edge.
  final double projection;

  /// Uniform slot width in px — convex spacing.
  final double gap;

  /// Offset at which a ball's centre sits on the container edge.
  final double edgeOffset;
  final double minScale;
  final bool convex;

  /// Curve depth in px between the centre ball and the edge balls.
  final double arc;
  final double halfWidth;
  final double itemSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Nearest wrapped offset so items loop around continuously.
    var o = index - scroll;
    o -= (o / count).round() * count;

    // Concave spacing follows the interior perspective (slow, tight centre);
    // convex pairs its big centre balls with uniform spacing.
    final double x;
    if (convex) {
      x = o * gap;
    } else {
      final th = o * alpha < -_thetaClamp
          ? -_thetaClamp
          : (o * alpha > _thetaClamp ? _thetaClamp : o * alpha);
      x = projection * math.sin(th) / (math.cos(th) + k);
    }

    // Linear in wall angle, not in depth: every step is visibly bigger than the
    // last — growing outward (concave) or inward (convex).
    final t = math.min(o.abs() / edgeOffset, _thetaClamp / _thetaEdge);
    final scale = convex
        ? 1 - (1 - minScale) * t
        : minScale + (1 - minScale) * t;

    // Parabola centred on the stage — valley for concave, arch for convex —
    // deliberately unclamped so a ball keeps the same curve past the edge and
    // entries never pop.
    final ty = x / halfWidth;
    final valley = arc * (0.5 - ty * ty);
    final y = convex ? -valley : valley;

    // Fully off-stage balls stop painting.
    final hidden = x.abs() > halfWidth + itemSize;
    if (hidden) return const SizedBox.shrink();

    // top:1/2 left:1/2 with a -itemSize/2 margin centres the box on the stage
    // origin; then translate by (x, y) and scale about the centre.
    return Positioned(
      left: halfWidth - itemSize / 2 + x,
      top: 0,
      bottom: 0,
      child: Center(
        child: Transform.translate(
          offset: Offset(0, y),
          child: Transform.scale(
            scale: scale,
            child: SizedBox(width: itemSize, height: itemSize, child: child),
          ),
        ),
      ),
    );
  }
}
