import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'
    show PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/widgets.dart';

/// Lenis' own expo-out curve — the canonical smooth-scroll easing (source
/// `EASE_SCROLL`, `1.001 - 2^(-10t)`). Component-local, like the source keeps
/// it out of `lib/ease.ts`: the shared tokens are UI-motion beziers, this is a
/// scroll-glide function.
const Curve beuiEaseScroll = _EaseScrollCurve();

class _EaseScrollCurve extends Curve {
  const _EaseScrollCurve();

  @override
  double transformInternal(double t) =>
      math.min(1, 1.001 - math.pow(2, -10 * t).toDouble());
}

/// Axis a [BeuiSmoothScroll] provider drives (source `orientation`).
enum BeuiSmoothScrollOrientation {
  /// Tracks the vertical scrollable; a plain mouse wheel scrolls it, as usual.
  vertical,

  /// Tracks the horizontal scrollable, and maps the vertical mouse wheel onto
  /// it.
  ///
  /// Flutter's own wheel handling only feeds a horizontal scrollable from
  /// horizontal wheel deltas (shift-wheel, or a trackpad swipe), so a plain
  /// mouse wheel leaves a horizontal rail motionless. Lenis' `orientation`
  /// closes exactly that gap, and so does this.
  horizontal,
}

/// The smooth-scroll state shared by the scroll-animation group — the Flutter
/// port of the source's `SmoothScrollApi` (Lenis provider + hook).
///
/// `scrollY`/`progress`/`velocity` are live [ValueListenable]s fed by the
/// tracked scrollable; [scrollTo]/[scrollToContext] glide with [beuiEaseScroll]
/// and jump instantly under reduced motion.
abstract interface class BeuiSmoothScrollApi {
  /// Current scroll offset in px (source `scrollY`).
  ValueListenable<double> get scrollY;

  /// Scroll position as 0..1 of the scrollable extent (source `progress`).
  ValueListenable<double> get progress;

  /// Signed scroll velocity in px/frame (source `velocity`).
  ValueListenable<double> get velocity;

  /// Glides to an absolute pixel offset (+[offset] extra, e.g. a negative
  /// value to clear a sticky header). Respects reduced motion (jumps).
  Future<void> scrollTo(
    double to, {
    double offset = 0,
    Duration? duration,
    bool immediate = false,
  });

  /// Glides until [target]'s render object is revealed at [alignment]
  /// (0 = leading edge), plus [offset] px. Respects reduced motion.
  Future<void> scrollToContext(
    BuildContext target, {
    double offset = 0,
    Duration? duration,
    bool immediate = false,
    double alignment = 0,
  });
}

/// Provider that tracks the nearest descendant scrollable and exposes the
/// shared scroll state — the Flutter port of the source `SmoothScroll`
/// (Lenis provider).
///
/// **Documented reduced parity** (spec §7): Lenis exists to re-add inertial
/// smoothing to the browser's stepped wheel scrolling. Flutter scrolling is
/// already physics-driven on every platform, so Lenis' *replacement* of the
/// platform scroller is deliberately not re-implemented — a wrapper cannot
/// suppress the wheel step an inner `Scrollable` applies (it wins the
/// [PointerSignalResolver], being deeper in the hit-test path), and taking the
/// scroll position away from Flutter's own physics would cost more than it
/// buys. What carries over is the shared state (`scrollY` / `progress` /
/// `velocity`), the eased programmatic [BeuiSmoothScrollApi.scrollTo] with
/// Lenis' expo-out curve and 1.2s default duration, and the knobs below, each
/// mapped onto the Flutter scroll model rather than onto Lenis' internals:
/// [orientation], [wheelMultiplier], [touch] and [lerp].
///
/// Under reduced motion the whole smoothing layer is bypassed and the platform
/// scroller is handed back full control (spec §6) — matching the source, whose
/// reduced-motion branch renders a plain `<div>` with no Lenis at all. State
/// tracking and an instant [BeuiSmoothScrollApi.scrollTo] remain.
///
/// Scroll-group widgets ([progress bars/rings, scroll-to buttons]) find this
/// via [BeuiSmoothScroll.of].
class BeuiSmoothScroll extends StatefulWidget {
  /// Creates a smooth-scroll provider around a subtree containing the
  /// scrollable to track.
  const BeuiSmoothScroll({
    required this.child,
    this.orientation = BeuiSmoothScrollOrientation.vertical,
    this.lerp = 0.1,
    this.duration = const Duration(milliseconds: 1200),
    this.wheelMultiplier = 1.0,
    this.touch = false,
    super.key,
  }) : assert(lerp > 0 && lerp < 1, 'lerp is a per-frame factor in (0, 1)'),
       assert(wheelMultiplier > 0, 'wheelMultiplier must be positive');

  /// The subtree; the outermost scrollable inside it whose axis matches
  /// [orientation] is tracked.
  final Widget child;

  /// Which axis this provider drives (source `orientation`, default
  /// [BeuiSmoothScrollOrientation.vertical]).
  ///
  /// Two effects. It selects the scrollable to track — `scrollY`, `progress`,
  /// `velocity` and `scrollTo` all bind to the nearest scrollable on this axis,
  /// so a horizontal rail inside a vertical page no longer has to compete for
  /// the provider. And it routes the wheel: with
  /// [BeuiSmoothScrollOrientation.horizontal] a plain vertical mouse wheel is
  /// mapped onto the horizontal offset, which Flutter does not do on its own.
  final BeuiSmoothScrollOrientation orientation;

  /// Smoothing factor; lower is smoother and heavier (source `lerp = 0.1`).
  ///
  /// Lenis reads this as a per-frame follow factor — each frame it closes
  /// `lerp` of the remaining distance — and uses it for *user-driven* scrolling,
  /// while [duration] covers programmatic glides. The port keeps that split:
  /// `lerp` shapes the settle wherever this provider drives the scroll itself
  /// rather than delegating to the platform, which today means the [touch]
  /// momentum settle. It is read as the same quantity, converted to a decay
  /// constant of `-ln(1 - lerp) × 60` per second, so a Lenis `lerp` value ports
  /// across unchanged: 0.1 settles in roughly 0.5s, 0.05 is twice as heavy.
  ///
  /// Inert while [touch] is false, since every other path is the platform's own
  /// physics.
  final double lerp;

  /// Default [BeuiSmoothScrollApi.scrollTo] glide duration (source
  /// `duration = 1.2`).
  final Duration duration;

  /// Wheel scroll speed multiplier (source `wheelMultiplier = 1`).
  ///
  /// `2` makes one wheel notch travel twice as far, `0.5` half. Implemented as
  /// a correction on top of the step Flutter's own `Scrollable` already
  /// applied, so at the default `1` the provider does not touch wheel events at
  /// all. Ignored under reduced motion.
  final double wheelMultiplier;

  /// Whether smoothing also applies to touch input (source `touch = false`).
  ///
  /// Lenis calls this `syncTouch` and leaves it off because native momentum is
  /// already good on mobile — the same is true, more so, of Flutter's
  /// per-platform scroll physics, so the default keeps flings exactly as the
  /// platform renders them. Setting it true replaces the platform's friction
  /// simulation with Lenis' exponential follow, parameterised by [lerp]: the
  /// fling decays toward `offset + velocity / decay` instead of coasting on
  /// friction. Drag tracking, overscroll and edge bounce are untouched, and the
  /// override is skipped under reduced motion.
  ///
  /// Supplied through [ScrollConfiguration], so it reaches every descendant
  /// scrollable that has not been given explicit `physics` of its own.
  final bool touch;

  /// The nearest enclosing provider's API.
  static BeuiSmoothScrollApi of(BuildContext context) => maybeOf(context)!;

  /// The nearest enclosing provider's API, or null when there is none.
  static BeuiSmoothScrollApi? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SmoothScrollScope>()?.api;

  @override
  State<BeuiSmoothScroll> createState() => _BeuiSmoothScrollState();
}

class _BeuiSmoothScrollState extends State<BeuiSmoothScroll>
    implements BeuiSmoothScrollApi {
  final ValueNotifier<double> _scrollY = ValueNotifier(0);
  final ValueNotifier<double> _progress = ValueNotifier(0);
  final ValueNotifier<double> _velocity = ValueNotifier(0);

  /// Context inside the tracked scrollable, captured from its notifications —
  /// resolves the live [ScrollPosition] for programmatic scrolls.
  BuildContext? _scrollableContext;
  double _lastY = 0;
  DateTime? _lastTime;

  @override
  ValueListenable<double> get scrollY => _scrollY;
  @override
  ValueListenable<double> get progress => _progress;
  @override
  ValueListenable<double> get velocity => _velocity;

  @override
  void dispose() {
    _scrollY.dispose();
    _progress.dispose();
    _velocity.dispose();
    super.dispose();
  }

  Axis get _axis => switch (widget.orientation) {
    BeuiSmoothScrollOrientation.vertical => Axis.vertical,
    BeuiSmoothScrollOrientation.horizontal => Axis.horizontal,
  };

  void _track(ScrollMetrics metrics, BuildContext? context) {
    if (!metrics.hasPixels) return;
    // Only the configured axis feeds the shared state, so a rail and the page
    // it sits in can each own a provider without stealing the other's metrics.
    if (metrics.axis != _axis) return;
    final y = metrics.pixels;
    final now = DateTime.now();
    final dtMs = _lastTime == null
        ? 16.0
        : math.max(1, now.difference(_lastTime!).inMicroseconds / 1000);
    _velocity.value = (y - _lastY) / dtMs * 16; // px/frame, as the source
    _lastY = y;
    _lastTime = now;
    _scrollY.value = y;
    _progress.value = metrics.maxScrollExtent > 0
        ? (y / metrics.maxScrollExtent).clamp(0.0, 1.0)
        : 0;
    if (context != null) _scrollableContext = context;
  }

  ScrollPosition? _resolvePosition() {
    final context = _scrollableContext;
    if (context == null || !context.mounted) return null;
    return Scrollable.maybeOf(context)?.position;
  }

  bool get _reduce => MediaQuery.disableAnimationsOf(context);

  Future<void> _drive(
    ScrollPosition position,
    double to, {
    required Duration? duration,
    required bool immediate,
  }) async {
    final target = to.clamp(position.minScrollExtent, position.maxScrollExtent);
    if (immediate || _reduce) {
      position.jumpTo(target);
      return;
    }
    await position.animateTo(
      target,
      duration: duration ?? widget.duration,
      curve: beuiEaseScroll,
    );
  }

  @override
  Future<void> scrollTo(
    double to, {
    double offset = 0,
    Duration? duration,
    bool immediate = false,
  }) async {
    final position = _resolvePosition();
    if (position == null) return;
    await _drive(
      position,
      to + offset,
      duration: duration,
      immediate: immediate,
    );
  }

  @override
  Future<void> scrollToContext(
    BuildContext target, {
    double offset = 0,
    Duration? duration,
    bool immediate = false,
    double alignment = 0,
  }) async {
    final position = _resolvePosition();
    final render = target.findRenderObject();
    if (position == null || render == null) return;
    final viewport = RenderAbstractViewport.maybeOf(render);
    if (viewport == null) return;
    final reveal = viewport.getOffsetToReveal(render, alignment).offset;
    await _drive(
      position,
      reveal + offset,
      duration: duration,
      immediate: immediate,
    );
  }

  /// Applies the wheel correction Flutter's own `Scrollable` cannot.
  ///
  /// Our handler runs before the inner `Scrollable`'s (it is shallower in the
  /// hit-test path, and the scrollable's own step is deferred to the
  /// [PointerSignalResolver] at the end of dispatch), and `pointerScroll` is
  /// relative — so applying `wanted - native` here lands the frame on exactly
  /// `wanted`.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final position = _resolvePosition();
    if (position == null) return;

    final delta = event.scrollDelta;
    // What Flutter is about to apply on this axis.
    final native = _axis == Axis.vertical ? delta.dy : delta.dx;
    // What Lenis would apply: the axis' own delta, plus — on a horizontal
    // provider — the vertical wheel a plain mouse sends, all scaled.
    final wanted =
        (_axis == Axis.horizontal ? delta.dx + delta.dy : delta.dy) *
        widget.wheelMultiplier;

    var extra = wanted - native;
    if (extra.abs() < precisionErrorTolerance) return;
    // Pixels grow opposite to the delta in a reversed scrollable.
    if (axisDirectionIsReversed(position.axisDirection)) extra = -extra;
    final target = (position.pixels + extra).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target != position.pixels) position.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _reduce;
    Widget child = widget.child;

    // Touch smoothing: swap the platform's friction fling for Lenis' follow.
    // Layered onto the ambient behaviour so drag handling, overscroll and edge
    // bounce keep coming from the platform default.
    if (widget.touch && !reduce) {
      final behavior = ScrollConfiguration.of(context);
      child = ScrollConfiguration(
        behavior: behavior.copyWith(
          physics: _BeuiLerpScrollPhysics(
            lerp: widget.lerp,
          ).applyTo(behavior.getScrollPhysics(context)),
        ),
        child: child,
      );
    }

    // Wheel routing: only mounted when it has something to do, so the default
    // provider adds no pointer handling whatsoever.
    final needsWheel =
        !reduce && (widget.wheelMultiplier != 1.0 || _axis == Axis.horizontal);
    if (needsWheel) {
      child = Listener(onPointerSignal: _onPointerSignal, child: child);
    }

    return _SmoothScrollScope(
      api: this,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) {
          if (n.depth == 0) _track(n.metrics, n.context);
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.depth == 0) _track(n.metrics, n.context);
            return false;
          },
          child: child,
        ),
      ),
    );
  }
}

/// Replaces the platform's friction fling with Lenis' exponential follow, so
/// touch momentum settles the way the wheel smoothing does (source
/// `syncTouch`). Everything else — drag, overscroll, edge bounce, tolerances —
/// delegates to the parent physics.
class _BeuiLerpScrollPhysics extends ScrollPhysics {
  const _BeuiLerpScrollPhysics({required this.lerp, super.parent});

  /// Per-frame follow factor (source `lerp`).
  final double lerp;

  /// Continuous-time equivalent of "close [lerp] of the gap each frame at
  /// 60fps": `(1 - lerp) = e^(-decay / 60)`.
  double get _decay => -math.log(1 - lerp.clamp(0.001, 0.999)) * 60;

  @override
  _BeuiLerpScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _BeuiLerpScrollPhysics(lerp: lerp, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tolerance = toleranceFor(position);
    // Out of range (bounce back) or no real momentum: the platform knows best.
    if (position.outOfRange || velocity.abs() < tolerance.velocity) {
      return super.createBallisticSimulation(position, velocity);
    }
    final decay = _decay;
    // Target chosen so the follow starts at exactly the fling velocity:
    // x'(0) = (target - start) × decay = velocity.
    final target = (position.pixels + velocity / decay).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < tolerance.distance) {
      return super.createBallisticSimulation(position, velocity);
    }
    return _LerpDecaySimulation(
      start: position.pixels,
      target: target,
      decay: decay,
      tolerance: tolerance,
    );
  }
}

/// `x(t) = target - (target - start)·e^(-decay·t)` — the continuous form of
/// Lenis' per-frame `damp(current, target, lerp)`.
class _LerpDecaySimulation extends Simulation {
  _LerpDecaySimulation({
    required this.start,
    required this.target,
    required this.decay,
    required super.tolerance,
  });

  final double start;
  final double target;
  final double decay;

  @override
  double x(double time) => target - (target - start) * math.exp(-decay * time);

  @override
  double dx(double time) => (target - start) * decay * math.exp(-decay * time);

  @override
  bool isDone(double time) => (target - x(time)).abs() < tolerance.distance;
}

class _SmoothScrollScope extends InheritedWidget {
  const _SmoothScrollScope({required this.api, required super.child});

  final BeuiSmoothScrollApi api;

  @override
  bool updateShouldNotify(_SmoothScrollScope oldWidget) => api != oldWidget.api;
}
