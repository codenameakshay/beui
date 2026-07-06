import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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
/// already physics-driven on every platform, so the wheel-interception half of
/// Lenis is deliberately not re-implemented; what carries over is the shared
/// state (`scrollY` / `progress` / `velocity`) and the eased programmatic
/// [BeuiSmoothScrollApi.scrollTo] with Lenis' expo-out curve and 1.2s default
/// duration.
///
/// Scroll-group widgets ([progress bars/rings, scroll-to buttons]) find this
/// via [BeuiSmoothScroll.of].
class BeuiSmoothScroll extends StatefulWidget {
  /// Creates a smooth-scroll provider around a subtree containing the
  /// scrollable to track.
  const BeuiSmoothScroll({
    required this.child,
    this.duration = const Duration(milliseconds: 1200),
    super.key,
  });

  /// The subtree; the outermost scrollable inside it is tracked.
  final Widget child;

  /// Default [BeuiSmoothScrollApi.scrollTo] glide duration (source
  /// `duration = 1.2`).
  final Duration duration;

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

  void _track(ScrollMetrics metrics, BuildContext? context) {
    if (!metrics.hasPixels) return;
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

  @override
  Widget build(BuildContext context) {
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
          child: widget.child,
        ),
      ),
    );
  }
}

class _SmoothScrollScope extends InheritedWidget {
  const _SmoothScrollScope({required this.api, required super.child});

  final BeuiSmoothScrollApi api;

  @override
  bool updateShouldNotify(_SmoothScrollScope oldWidget) => api != oldWidget.api;
}
