import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// Pull-gesture lifecycle for [BeuiPullToRefresh] (source `PullToRefreshStatus`).
enum BeuiPullToRefreshStatus {
  /// At rest; no active pull.
  idle,

  /// User is dragging but has not reached the threshold.
  pulling,

  /// Drag distance is past the threshold; release will refresh.
  ready,

  /// [BeuiPullToRefresh.onRefresh] is running (or external [refreshing]).
  refreshing,
}

/// Native-feeling pull-to-refresh container with drag resistance, threshold
/// feedback and async refresh handling — the Flutter port of beUI's
/// `pull-to-refresh`.
///
/// Wraps [child] in a scrollable surface. When the scroll offset is at the top
/// and the user pulls down, content resists via an exponential curve
/// (`maxPull * (1 - e^{-d/maxPull})`). Crossing [threshold] and releasing runs
/// [onRefresh] while the content springs to [holdDistance]; it settles back to
/// zero when the future completes (unless [refreshing] is held externally).
///
/// Motion uses [beuiSpringPanel] for settle and [beuiSpringSwap] for indicator
/// snaps. Reduced motion drops content translation / scale / character orbit and
/// keeps opacity + label transitions.
class BeuiPullToRefresh extends StatefulWidget {
  /// Creates a pull-to-refresh surface.
  const BeuiPullToRefresh({
    required this.onRefresh,
    required this.child,
    this.refreshing = false,
    this.disabled = false,
    this.threshold = 76,
    this.maxPull = 132,
    this.holdDistance = 68,
    this.pullingLabel,
    this.releaseLabel,
    this.refreshingLabel,
    this.semanticLabel = 'Refreshable content',
    super.key,
  });

  /// Runs after the user pulls beyond [threshold] and releases.
  final FutureOr<void> Function() onRefresh;

  /// Scrollable content. Placed inside an internal [SingleChildScrollView].
  final Widget child;

  /// Keeps the indicator active while an externally managed refresh runs.
  final bool refreshing;

  /// Disables pull gestures.
  final bool disabled;

  /// Resisted pull distance in logical pixels required to refresh.
  final double threshold;

  /// Maximum resisted pull distance in logical pixels.
  final double maxPull;

  /// Content offset in logical pixels while refreshing.
  final double holdDistance;

  /// Label shown while pulling below threshold. Defaults to "Pull to refresh".
  final Widget? pullingLabel;

  /// Label shown once past threshold. Defaults to "Release to refresh".
  final Widget? releaseLabel;

  /// Label shown during refresh. Defaults to "Refreshing".
  final Widget? refreshingLabel;

  /// Accessibility label for the refreshable region (source `ariaLabel`).
  final String semanticLabel;

  @override
  State<BeuiPullToRefresh> createState() => _BeuiPullToRefreshState();
}

double _resistedDistance(double distance, double maxPull) {
  return maxPull * (1 - math.exp(-math.max(0, distance) / maxPull));
}

class _BeuiPullToRefreshState extends State<BeuiPullToRefresh> {
  final ScrollController _scroll = ScrollController();

  /// Live pull / settle target (source motion value `y`).
  double _y = 0;

  /// Whether a finger is currently driving `_y` directly (no spring).
  bool _dragging = false;

  BeuiPullToRefreshStatus _status = BeuiPullToRefreshStatus.idle;
  bool _internalRefreshing = false;

  // Gesture bookkeeping (source `gestureRef`).
  bool _gestureActive = false;
  int? _pointerId;
  double _startX = 0;
  double _startY = 0;

  /// Serializes refresh runs so a late completion cannot clobber a newer one.
  int _refreshGen = 0;

  bool get _isRefreshing => widget.refreshing || _internalRefreshing;

  double get _pullThreshold => math.max(24.0, widget.threshold);

  double get _pullLimit => math.max(widget.maxPull, _pullThreshold + 24);

  double get _restingDistance =>
      math.min(math.max(0.0, widget.holdDistance), _pullThreshold);

  @override
  void initState() {
    super.initState();
    if (widget.refreshing) {
      _status = BeuiPullToRefreshStatus.refreshing;
      _y = _restingDistance;
    }
  }

  @override
  void didUpdateWidget(BeuiPullToRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshing != oldWidget.refreshing ||
        widget.holdDistance != oldWidget.holdDistance ||
        widget.threshold != oldWidget.threshold) {
      _syncExternalRefreshing();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _setStatus(BeuiPullToRefreshStatus next) {
    if (_status == next) return;
    setState(() => _status = next);
  }

  void _setY(double next) {
    if ((_y - next).abs() < 0.01 && !_dragging) return;
    setState(() => _y = next);
  }

  void _syncExternalRefreshing() {
    if (_isRefreshing) {
      _setStatus(BeuiPullToRefreshStatus.refreshing);
      _dragging = false;
      _setY(_restingDistance);
      return;
    }
    if (_status == BeuiPullToRefreshStatus.refreshing) {
      _setStatus(BeuiPullToRefreshStatus.idle);
      _setY(0);
    }
  }

  void _updatePull(double distance) {
    if (widget.disabled || _isRefreshing) return;
    final next = _resistedDistance(distance, _pullLimit);
    setState(() {
      _dragging = true;
      _y = next;
      _status = next >= _pullThreshold
          ? BeuiPullToRefreshStatus.ready
          : BeuiPullToRefreshStatus.pulling;
    });
  }

  Future<void> _runRefresh() async {
    if (widget.disabled || _isRefreshing) return;

    final gen = ++_refreshGen;
    setState(() {
      _internalRefreshing = true;
      _dragging = false;
      _status = BeuiPullToRefreshStatus.refreshing;
      _y = _restingDistance;
    });

    try {
      await widget.onRefresh();
    } finally {
      if (mounted && gen == _refreshGen) {
        setState(() => _internalRefreshing = false);
        // External refreshing may still be held — leave y at hold distance.
        if (!widget.refreshing) {
          _setStatus(BeuiPullToRefreshStatus.idle);
          _setY(0);
        }
      }
    }
  }

  void _finishPull() {
    final shouldRefresh =
        _y >= _pullThreshold && !widget.disabled && !_isRefreshing;

    _gestureActive = false;
    _pointerId = null;

    if (shouldRefresh) {
      unawaited(_runRefresh());
      return;
    }

    setState(() {
      _dragging = false;
      _status = BeuiPullToRefreshStatus.idle;
      _y = 0;
    });
  }

  void _cancelGesture() {
    _gestureActive = false;
    _pointerId = null;
    if (_dragging && !_isRefreshing) {
      setState(() {
        _dragging = false;
        _status = BeuiPullToRefreshStatus.idle;
        _y = 0;
      });
    }
  }

  bool get _atTop => !_scroll.hasClients || _scroll.offset <= 0.5;

  void _onPointerDown(PointerDownEvent e) {
    if (!_atTop || widget.disabled || _isRefreshing) return;
    _gestureActive = true;
    _pointerId = e.pointer;
    _startX = e.position.dx;
    _startY = e.position.dy;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_gestureActive || e.pointer != _pointerId) return;

    final deltaX = e.position.dx - _startX;
    final deltaY = e.position.dy - _startY;

    if (!_atTop || deltaY < 0) {
      if (_dragging) {
        // User reversed or scrolled — abort the pull.
        _cancelGesture();
      } else {
        _gestureActive = false;
        _pointerId = null;
      }
      return;
    }

    // Prefer horizontal pans until a vertical pull is committed.
    if (!_dragging && deltaX.abs() > deltaY) return;

    if (deltaY > 0) {
      _updatePull(deltaY);
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    if (e.pointer != _pointerId) return;
    if (_gestureActive && (_dragging || _y > 0)) {
      _finishPull();
    } else {
      _gestureActive = false;
      _pointerId = null;
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (e.pointer != _pointerId) return;
    if (_gestureActive && (_dragging || _y > 0)) {
      _finishPull();
    } else {
      _gestureActive = false;
      _pointerId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final panelMotion = motionFor(context, beuiSpringPanel, isMovement: true);

    // While dragging (or reduced) the indicator must sit exactly where the
    // finger put it; only the release is sprung.
    //
    // This used to be expressed as `NoMotion`, which does NOT mean "snap" —
    // it holds its seeded value forever and never reaches the target (see
    // `test/motion/_no_motion_semantics_test.dart`). Because `_dragging` is
    // true for the whole pull, `y` stayed pinned at 0 for every frame of it:
    // the indicator never faded in, never scaled, and the content never
    // translated. Only the status *label* moved, because that reads plain
    // state rather than the animated value — which is why the bug survived
    // the existing tests, and why it hit every user, not just reduced-motion
    // ones.
    //
    // `active: false` is motor's own mechanism for this: it stops the
    // controller and assigns `controller.value = widget.value` outright. The
    // rendered value therefore tracks the drag frame for frame, AND the
    // controller stays seeded at the real position — so when `active` flips
    // back to true on release, the panel spring starts from where the finger
    // left off instead of springing up from a stale 0.
    final snapY = _dragging || reduce;

    final defaultLabelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: colors.mutedForeground,
      height: 1.2,
    );

    Widget labelFor(BeuiPullToRefreshStatus s) {
      final custom = switch (s) {
        BeuiPullToRefreshStatus.refreshing => widget.refreshingLabel,
        BeuiPullToRefreshStatus.ready => widget.releaseLabel,
        _ => widget.pullingLabel,
      };
      if (custom != null) return custom;
      final text = switch (s) {
        BeuiPullToRefreshStatus.refreshing => 'Refreshing',
        BeuiPullToRefreshStatus.ready => 'Release to refresh',
        _ => 'Pull to refresh',
      };
      return Text(text, style: defaultLabelStyle, textAlign: TextAlign.center);
    }

    return Semantics(
      label: widget.semanticLabel,
      liveRegion: true,
      container: true,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: SingleMotionBuilder(
          motion: panelMotion,
          active: !snapY,
          value: _y,
          builder: (context, y, _) {
            final progress = (y / _pullThreshold).clamp(0.0, 1.0);
            final indicatorOpacity = y <= 0
                ? 0.0
                : y < 10
                ? lerpDouble(0, 0.45, y / 10)!
                : lerpDouble(
                    0.45,
                    1.0,
                    ((y - 10) / math.max(1, _pullThreshold - 10)).clamp(
                      0.0,
                      1.0,
                    ),
                  )!;
            final indicatorScale = lerpDouble(
              0.86,
              1.0,
              progress.clamp(0.0, 1.0),
            )!;

            final contentY = reduce ? 0.0 : y;

            return ColoredBox(
              color: colors.background,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // Scrollable content (source content div with y).
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(0, contentY),
                      child: SingleChildScrollView(
                        controller: _scroll,
                        physics: (_dragging || _isRefreshing)
                            ? const NeverScrollableScrollPhysics()
                            : const AlwaysScrollableScrollPhysics(),
                        child: widget.child,
                      ),
                    ),
                  ),

                  // Indicator (source absolute top bar).
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 68, // h-[4.25rem]
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: indicatorOpacity.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: reduce ? 1.0 : indicatorScale,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  colors.background,
                                  colors.background.withValues(alpha: 0.95),
                                  colors.background.withValues(alpha: 0),
                                ],
                                stops: const [0, 0.55, 1],
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _RefreshBuddy(
                                  progress: progress,
                                  status: _status,
                                  reduce: reduce,
                                  bodyColor: colors.foreground,
                                  eyeColor: colors.background,
                                  strokeColor: colors.mutedForeground,
                                ),
                                const SizedBox(height: 2),
                                SizedBox(
                                  height: 16,
                                  child: _LabelSwap(
                                    status: _status,
                                    reduce: reduce,
                                    child: labelFor(_status),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Label cross-fade / slide (source LABEL_SWAP + AnimatePresence)
// ---------------------------------------------------------------------------

class _LabelSwap extends StatelessWidget {
  const _LabelSwap({
    required this.status,
    required this.reduce,
    required this.child,
  });

  final BeuiPullToRefreshStatus status;
  final bool reduce;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      switchInCurve: beuiEaseOut,
      switchOutCurve: beuiEaseOut,
      transitionBuilder: (child, animation) {
        if (reduce) {
          return FadeTransition(opacity: animation, child: child);
        }
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(status),
        child: Center(child: child),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// RefreshBuddy character (36×36 SVG port)
// ---------------------------------------------------------------------------

/// Compact looping character that stretches with pull progress and blinks /
/// spins while refreshing (source `RefreshBuddy`).
class _RefreshBuddy extends StatefulWidget {
  const _RefreshBuddy({
    required this.progress,
    required this.status,
    required this.reduce,
    required this.bodyColor,
    required this.eyeColor,
    required this.strokeColor,
  });

  final double progress;
  final BeuiPullToRefreshStatus status;
  final bool reduce;
  final Color bodyColor;
  final Color eyeColor;
  final Color strokeColor;

  @override
  State<_RefreshBuddy> createState() => _RefreshBuddyState();
}

class _RefreshBuddyState extends State<_RefreshBuddy>
    with SingleTickerProviderStateMixin {
  // CHARACTER_LOOP 0.9s / CALM_PULSE 1.2s — continuous tweens, not springs.
  late final AnimationController _loop = AnimationController(vsync: this);

  bool get _refreshing => widget.status == BeuiPullToRefreshStatus.refreshing;
  bool get _ready => widget.status == BeuiPullToRefreshStatus.ready;

  @override
  void initState() {
    super.initState();
    _syncLoop();
  }

  @override
  void didUpdateWidget(_RefreshBuddy oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status ||
        oldWidget.reduce != widget.reduce) {
      _syncLoop();
    }
  }

  void _syncLoop() {
    if (_refreshing) {
      final period = widget.reduce
          ? const Duration(milliseconds: 1200) // CALM_PULSE
          : const Duration(milliseconds: 900); // CHARACTER_LOOP
      if (_loop.duration != period) {
        _loop.duration = period;
      }
      if (!_loop.isAnimating) {
        _loop.repeat();
      }
    } else {
      _loop
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress.clamp(0.0, 1.0);
    // progress → lift / tilt / stretch (source useTransform).
    final lift = lerpDouble(-7, 0, p)!;
    final tilt = lerpDouble(-10, 0, p)!;
    final stretch = p <= 0.55
        ? lerpDouble(0.68, 1.1, p / 0.55)!
        : lerpDouble(1.1, 0.92, (p - 0.55) / 0.45)!;

    // Ready-state scale snap uses SPRING_SWAP (source svg animate scale).
    final scaleTarget = _ready && !widget.reduce ? 1.08 : 1.0;
    final swapMotion = motionFor(context, beuiSpringSwap, isMovement: true);

    Widget character = SingleMotionBuilder(
      motion: widget.reduce ? const NoMotion() : swapMotion,
      value: scaleTarget,
      builder: (context, bodyScale, _) {
        return AnimatedBuilder(
          animation: _loop,
          builder: (context, _) {
            final t = _loop.value;
            // easeInOut wave 0→1→0 for y/rotate/blink.
            final wave = math.sin(t * math.pi * 2); // -1..1
            final easeWave = beuiEaseInOut.transform(
              (math.sin(t * math.pi * 2) + 1) / 2,
            );

            double bodyY = 0;
            double bodyRotate = 0;
            double opacity = 1;
            // Spinner rests at -35° until ready, then snaps to 0 (SPRING_SWAP
            // approximated by the same loop clock / opacity fade).
            double spinnerRotate = (_ready || _refreshing) ? 0 : -35;
            double eyeScaleY = _ready && !widget.reduce ? 1.18 : 1.0;

            if (_refreshing) {
              if (widget.reduce) {
                // CALM_PULSE opacity [0.55, 1, 0.55]
                opacity = lerpDouble(0.55, 1.0, easeWave)!;
              } else {
                bodyY = wave * -2; // [0, -2, 0] approx via sin
                bodyRotate = wave * 3; // [-3, 3, -3]
                spinnerRotate = t * 360;
                // scaleY [1, 1, 0.15, 1, 1] — blink mid-cycle
                final blinkPhase = t % 1.0;
                if (blinkPhase > 0.35 && blinkPhase < 0.55) {
                  final local = ((blinkPhase - 0.35) / 0.2).clamp(0.0, 1.0);
                  eyeScaleY = local < 0.5
                      ? lerpDouble(1, 0.15, local * 2)!
                      : lerpDouble(0.15, 1, (local - 0.5) * 2)!;
                } else {
                  eyeScaleY = 1;
                }
              }
            }

            final spinnerOpacity = (_ready || _refreshing) ? 1.0 : 0.0;

            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, bodyY),
                child: Transform.rotate(
                  angle: bodyRotate * math.pi / 180,
                  child: Transform.scale(
                    scale: bodyScale,
                    child: CustomPaint(
                      size: const Size.square(36),
                      painter: _BuddyPainter(
                        bodyColor: widget.bodyColor,
                        eyeColor: widget.eyeColor,
                        strokeColor: widget.strokeColor,
                        spinnerRotateDeg: spinnerRotate,
                        spinnerOpacity: spinnerOpacity,
                        eyeScaleY: eyeScaleY,
                        mouth: _refreshing
                            ? _BuddyMouth.refreshing
                            : _ready
                            ? _BuddyMouth.smile
                            : _BuddyMouth.straight,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // Outer lift / tilt / stretch driven by pull progress (dropped under reduce).
    if (widget.reduce) {
      return SizedBox(width: 36, height: 36, child: character);
    }

    return SizedBox(
      width: 36,
      height: 36,
      child: Transform.translate(
        offset: Offset(0, lift),
        child: Transform.rotate(
          angle: tilt * math.pi / 180,
          alignment: Alignment.bottomCenter,
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.diagonal3Values(1.0, stretch, 1.0),
            child: character,
          ),
        ),
      ),
    );
  }
}

enum _BuddyMouth { straight, smile, refreshing }

class _BuddyPainter extends CustomPainter {
  _BuddyPainter({
    required this.bodyColor,
    required this.eyeColor,
    required this.strokeColor,
    required this.spinnerRotateDeg,
    required this.spinnerOpacity,
    required this.eyeScaleY,
    required this.mouth,
  });

  final Color bodyColor;
  final Color eyeColor;
  final Color strokeColor;
  final double spinnerRotateDeg;
  final double spinnerOpacity;
  final double eyeScaleY;
  final _BuddyMouth mouth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 36;

    // Spinner arc + dot (source motion.g, origin 18,18).
    if (spinnerOpacity > 0.01) {
      canvas.save();
      canvas.translate(18 * s, 18 * s);
      canvas.rotate(spinnerRotateDeg * math.pi / 180);
      canvas.translate(-18 * s, -18 * s);

      final arcPaint = Paint()
        ..color = strokeColor.withValues(alpha: spinnerOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * s
        ..strokeCap = StrokeCap.round;
      // Path "M18 2.5a15.5 15.5 0 0 1 12.7 6.6"
      final arc = Path()
        ..moveTo(18 * s, 2.5 * s)
        ..arcToPoint(
          Offset(30.7 * s, 9.1 * s),
          radius: Radius.circular(15.5 * s),
          clockwise: true,
        );
      canvas.drawPath(arc, arcPaint);

      canvas.drawCircle(
        Offset(31.3 * s, 10.2 * s),
        2.2 * s,
        Paint()..color = bodyColor.withValues(alpha: spinnerOpacity),
      );
      canvas.restore();
    }

    // Body rounded rect (x=7 y=7 w=22 h=22 rx=9).
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(7 * s, 7 * s, 22 * s, 22 * s),
      Radius.circular(9 * s),
    );
    canvas.drawRRect(bodyRect, Paint()..color = bodyColor);

    // Eyes with scaleY about (18, 16).
    canvas.save();
    canvas.translate(18 * s, 16 * s);
    canvas.scale(1.0, eyeScaleY);
    canvas.translate(-18 * s, -16 * s);
    final eyePaint = Paint()..color = eyeColor;
    canvas.drawCircle(Offset(14.2 * s, 16 * s), 1.45 * s, eyePaint);
    canvas.drawCircle(Offset(21.8 * s, 16 * s), 1.45 * s, eyePaint);
    canvas.restore();

    final mouthStroke = Paint()
      ..color = eyeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * s
      ..strokeCap = StrokeCap.round;

    switch (mouth) {
      case _BuddyMouth.straight:
        canvas.drawLine(
          Offset(14.5 * s, 21 * s),
          Offset(21.5 * s, 21 * s),
          mouthStroke,
        );
      case _BuddyMouth.smile:
        // "M14 20.5c1 2.4 7 2.4 8 0"
        final smile = Path()
          ..moveTo(14 * s, 20.5 * s)
          ..cubicTo(15 * s, 22.9 * s, 21 * s, 22.9 * s, 22 * s, 20.5 * s);
        canvas.drawPath(smile, mouthStroke);
      case _BuddyMouth.refreshing:
        canvas.drawCircle(
          Offset(18 * s, 21 * s),
          1.6 * s,
          Paint()..color = eyeColor,
        );
    }
  }

  @override
  bool shouldRepaint(_BuddyPainter old) =>
      old.bodyColor != bodyColor ||
      old.eyeColor != eyeColor ||
      old.strokeColor != strokeColor ||
      old.spinnerRotateDeg != spinnerRotateDeg ||
      old.spinnerOpacity != spinnerOpacity ||
      old.eyeScaleY != eyeScaleY ||
      old.mouth != mouth;
}
