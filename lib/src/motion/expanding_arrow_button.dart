import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

// Source accent for ExpandingArrowButton (hardcoded `bg-lime-300` in React).
const _lime300 = Color(0xFFBEF264);
const _neutral950 = Color(0xFF0A0A0A);

// Dotted-chevron trail opacities (source `ARROW_OPACITY`).
const _arrowOpacity = <double>[1, 0.78, 0.54, 0.32, 0.16];

// ---------------------------------------------------------------------------
// Expanding arrow button
// ---------------------------------------------------------------------------

/// An accent tile that expands into a dotted-arrow trail on hover or focus —
/// the Flutter port of beUI's `ExpandingArrowButton`.
///
/// Idle: a 52×full-height lime tile with a single dotted chevron sits on the
/// left of a dark pill; the label sits to its right. On hover (mouse) or
/// keyboard focus the tile springs to nearly full width (`SPRING_LAYOUT`),
/// the single chevron fades out, and a trail of five chevrons fade/slide in
/// staggered left-to-right. Press scales to 0.97 (`SPRING_PRESS`). Reduced
/// motion snaps the layout and drops movement (opacity still transitions).
class BeuiExpandingArrowButton extends StatefulWidget {
  /// Creates an expanding-arrow CTA.
  const BeuiExpandingArrowButton({
    required this.child,
    this.onPressed,
    this.accentColor,
    this.backgroundColor,
    this.labelStyle,
    this.focusNode,
    super.key,
  });

  /// Label content (usually a [Text]).
  final Widget child;

  /// Tap callback. Null disables the button.
  final VoidCallback? onPressed;

  /// Accent tile colour. Defaults to source lime-300.
  final Color? accentColor;

  /// Pill background. Defaults to source neutral-950.
  final Color? backgroundColor;

  /// Style applied to the label. Defaults to white 18px medium.
  final TextStyle? labelStyle;

  /// Optional external focus node.
  final FocusNode? focusNode;

  @override
  State<BeuiExpandingArrowButton> createState() =>
      _BeuiExpandingArrowButtonState();
}

class _BeuiExpandingArrowButtonState extends State<BeuiExpandingArrowButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;
  bool get _active => _enabled && (_hovered || _focused);

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final accent = widget.accentColor ?? _lime300;
    final bg = widget.backgroundColor ?? _neutral950;
    final layoutMotion = motionFor(context, beuiSpringLayout, isMovement: true);
    final pressMotion = motionFor(context, beuiSpringPress, isMovement: true);

    // Scale: press 0.97; NoMotion freezes at source so under reduce we paint
    // scale 1.0 directly rather than driving a builder with NoMotion.
    final scaleTarget = !_enabled || reduce
        ? 1.0
        : _pressed
        ? 0.97
        : 1.0;

    Widget button = FocusableActionDetector(
      focusNode: widget.focusNode,
      enabled: _enabled,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      onShowHoverHighlight: (v) {
        // Hover-only — FocusableActionDetector already gates to mouse hosts.
        setState(() => _hovered = v);
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _enabled ? 1 : 0.5,
          child: SizedBox(
            height: 64, // h-16
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 288), // min-w-72
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6), // p-1.5
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxW = constraints.maxWidth;
                      // Idle 52px; active almost full width minus 12px inset
                      // (source: `calc(100% - 12px)` with left-1.5).
                      final targetW = _active
                          ? math.max(52.0, maxW - 12)
                          : 52.0;

                      Widget shell = Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          // Expanding accent tile.
                          if (reduce)
                            _AccentTile(
                              width: targetW,
                              active: _active,
                              reduce: true,
                              accent: accent,
                            )
                          else
                            SingleMotionBuilder(
                              motion: layoutMotion,
                              value: targetW,
                              builder: (context, width, child) => _AccentTile(
                                width: width,
                                active: _active,
                                reduce: false,
                                accent: accent,
                              ),
                            ),
                          // Label — fades/slides out when active.
                          Padding(
                            padding: const EdgeInsets.only(left: 76, right: 20),
                            child: _LabelFade(
                              active: _active,
                              reduce: reduce,
                              style:
                                  widget.labelStyle ??
                                  const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.36,
                                    color: Colors.white,
                                  ),
                              child: widget.child,
                            ),
                          ),
                        ],
                      );

                      if (reduce) return shell;
                      return SingleMotionBuilder(
                        motion: pressMotion,
                        value: scaleTarget,
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: shell,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(button: true, enabled: _enabled, child: button);
  }
}

class _AccentTile extends StatelessWidget {
  const _AccentTile({
    required this.width,
    required this.active,
    required this.reduce,
    required this.accent,
  });

  final double width;
  final bool active;
  final bool reduce;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Idle single chevron.
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: Duration(milliseconds: reduce ? 0 : 100),
                  curve: beuiEaseOut,
                  opacity: active ? 0 : 1,
                  child: const Center(
                    child: _DottedChevron(
                      color: _neutral950,
                      size: Size(20, 28),
                    ),
                  ),
                ),
              ),
              // Active trail — only laid out once the tile is wide enough so
              // five 20px chevrons fit (avoids Row overflow mid-spring).
              if (active && width >= 140)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        for (var i = 0; i < _arrowOpacity.length; i++)
                          _TrailChevron(
                            index: i,
                            active: active,
                            reduce: reduce,
                            opacity: _arrowOpacity[i],
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrailChevron extends StatelessWidget {
  const _TrailChevron({
    required this.index,
    required this.active,
    required this.reduce,
    required this.opacity,
  });

  final int index;
  final bool active;
  final bool reduce;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final delay = active && !reduce
        ? Duration(milliseconds: 40 + index * 25)
        : Duration.zero;
    final color = _neutral950.withValues(alpha: opacity);

    return TweenAnimationBuilder<double>(
      // Re-key so the delay restarts when active flips.
      key: ValueKey<bool>(active),
      tween: Tween(begin: active ? 0 : 1, end: active ? 1 : 0),
      duration: Duration(milliseconds: reduce ? 0 : 180),
      curve: beuiEaseOut,
      builder: (context, t, child) {
        // Apply delay by holding at 0 until the delay window passes — a simple
        // approximation of Framer's per-item delay without a ticker per chevron.
        return child!;
      },
      child: _DelayedReveal(
        delay: delay,
        active: active,
        reduce: reduce,
        child: Transform.translate(
          offset: Offset(active && !reduce ? 0 : -6, 0),
          child: Opacity(
            opacity: active ? 1 : 0,
            child: _DottedChevron(color: color, size: const Size(20, 28)),
          ),
        ),
      ),
    );
  }
}

/// Fades/slides [child] in after [delay] when [active] becomes true.
class _DelayedReveal extends StatefulWidget {
  const _DelayedReveal({
    required this.delay,
    required this.active,
    required this.reduce,
    required this.child,
  });

  final Duration delay;
  final bool active;
  final bool reduce;
  final Widget child;

  @override
  State<_DelayedReveal> createState() => _DelayedRevealState();
}

class _DelayedRevealState extends State<_DelayedReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync(immediate: true);
  }

  @override
  void didUpdateWidget(_DelayedReveal old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active || old.reduce != widget.reduce) {
      _sync();
    }
  }

  void _sync({bool immediate = false}) {
    _timer?.cancel();
    if (widget.reduce) {
      _c.value = widget.active ? 1 : 0;
      return;
    }
    if (widget.active) {
      if (immediate || widget.delay == Duration.zero) {
        _c.forward(from: 0);
      } else {
        _c.value = 0;
        _timer = Timer(widget.delay, () {
          if (mounted && widget.active) _c.forward(from: 0);
        });
      }
    } else {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = CurvedAnimation(parent: _c, curve: beuiEaseOut).value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset((1 - t) * -6, 0),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _LabelFade extends StatelessWidget {
  const _LabelFade({
    required this.active,
    required this.reduce,
    required this.style,
    required this.child,
  });

  final bool active;
  final bool reduce;
  final TextStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: Duration(milliseconds: reduce ? 0 : 120),
      curve: beuiEaseOut,
      opacity: active ? 0 : 1,
      child: AnimatedSlide(
        duration: Duration(milliseconds: reduce ? 0 : 120),
        curve: beuiEaseOut,
        offset: active && !reduce ? const Offset(0.04, 0) : Offset.zero,
        child: DefaultTextStyle(style: style, child: child),
      ),
    );
  }
}

/// Source `DottedChevron` — five dots forming a chevron in a 20×28 viewBox.
class _DottedChevron extends StatelessWidget {
  const _DottedChevron({required this.color, required this.size});

  final Color color;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: size, painter: _DottedChevronPainter(color));
  }
}

class _DottedChevronPainter extends CustomPainter {
  _DottedChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    // viewBox 0 0 20 28 — scale to [size].
    final sx = size.width / 20;
    final sy = size.height / 28;
    const dots = <Offset>[
      Offset(4, 4),
      Offset(10, 9),
      Offset(16, 14),
      Offset(10, 19),
      Offset(4, 24),
    ];
    for (final d in dots) {
      canvas.drawCircle(Offset(d.dx * sx, d.dy * sy), 2 * sx, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedChevronPainter old) => old.color != color;
}

// ---------------------------------------------------------------------------
// Hold action button
// ---------------------------------------------------------------------------

/// Fill direction for [BeuiHoldActionButton].
enum BeuiHoldActionDirection {
  /// Liquid fill rises from the bottom (source `vertical`).
  vertical,

  /// Liquid fill sweeps from the left (source `horizontal`).
  horizontal,
}

/// Hold-to-confirm CTA with a liquid fill — port of `HoldActionButton`.
///
/// Press and hold for [holdDuration]; the fill animates linearly and fires
/// [onHoldComplete] when it finishes. Release early to cancel. Reduced motion
/// cross-fades the fill instead of translating it.
class BeuiHoldActionButton extends StatefulWidget {
  /// Creates a hold-action button.
  const BeuiHoldActionButton({
    required this.child,
    this.direction = BeuiHoldActionDirection.vertical,
    this.holdingLabel = const Text('Keep holding'),
    this.completeLabel = const Text('Done'),
    this.holdDuration = const Duration(milliseconds: 1600),
    this.onHoldComplete,
    this.fillColor,
    this.backgroundColor,
    this.foregroundColor,
    this.enabled = true,
    super.key,
  });

  /// Idle label.
  final Widget child;

  /// Fill direction.
  final BeuiHoldActionDirection direction;

  /// Label while holding.
  final Widget holdingLabel;

  /// Label after a successful hold.
  final Widget completeLabel;

  /// Time the user must hold to complete.
  final Duration holdDuration;

  /// Called once when the hold reaches completion.
  final VoidCallback? onHoldComplete;

  /// Liquid fill colour. Defaults to sky-400.
  final Color? fillColor;

  /// Button background. Defaults to theme [BeuiColors.primary].
  final Color? backgroundColor;

  /// Label colour. Defaults to theme [BeuiColors.primaryForeground].
  final Color? foregroundColor;

  /// Whether the button accepts input.
  final bool enabled;

  @override
  State<BeuiHoldActionButton> createState() => _BeuiHoldActionButtonState();
}

class _BeuiHoldActionButtonState extends State<BeuiHoldActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
  )..addStatusListener(_onStatus);

  bool _holding = false;
  bool _completed = false;
  bool _completedFired = false;
  bool _pressed = false;

  @override
  void didUpdateWidget(BeuiHoldActionButton old) {
    super.didUpdateWidget(old);
    if (old.holdDuration != widget.holdDuration) {
      _fill.duration = widget.holdDuration;
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _holding && !_completedFired) {
      _completedFired = true;
      setState(() => _completed = true);
      widget.onHoldComplete?.call();
    }
  }

  void _startHold() {
    if (!widget.enabled || _holding) return;
    _completedFired = false;
    setState(() {
      _holding = true;
      _completed = false;
      _pressed = true;
    });
    _fill.forward(from: 0);
  }

  void _cancelHold() {
    if (!_holding && !_pressed) return;
    setState(() {
      _holding = false;
      _completed = false;
      _pressed = false;
    });
    // Source cancels with a 0.24s EASE_OUT reverse.
    _fill.animateBack(
      0,
      duration: const Duration(milliseconds: 240),
      curve: beuiEaseOut,
    );
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<BeuiColors>() ?? BeuiColors.light();
    final reduce = MediaQuery.disableAnimationsOf(context);
    final bg = widget.backgroundColor ?? colors.primary;
    final fg = widget.foregroundColor ?? colors.primaryForeground;
    final fill = widget.fillColor ?? const Color(0xFF38BDF8); // sky-400
    final active = _holding || _completed;
    final pressMotion = motionFor(context, beuiSpringPress, isMovement: true);
    final scaleTarget = !widget.enabled || reduce
        ? 1.0
        : _pressed
        ? 0.98
        : 1.0;

    Widget shell = Semantics(
      button: true,
      enabled: widget.enabled,
      child: FocusableActionDetector(
        enabled: widget.enabled,
        child: Listener(
          onPointerDown: widget.enabled ? (_) => _startHold() : null,
          onPointerUp: widget.enabled ? (_) => _cancelHold() : null,
          onPointerCancel: widget.enabled ? (_) => _cancelHold() : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: widget.enabled ? 1 : 0.5,
            child: SizedBox(
              height: 64,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 288),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Liquid fill.
                        AnimatedBuilder(
                          animation: _fill,
                          builder: (context, child) {
                            if (reduce) {
                              return Opacity(
                                opacity: active ? 1 : 0,
                                child: ColoredBox(color: fill),
                              );
                            }
                            final t = _fill.value;
                            final isH =
                                widget.direction ==
                                BeuiHoldActionDirection.horizontal;
                            return FractionalTranslation(
                              translation: isH
                                  ? Offset(t - 1, 0)
                                  : Offset(0, 1.15 * (1 - t)),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ColoredBox(color: fill),
                                  if (isH)
                                    const Align(
                                      alignment: Alignment.centerRight,
                                      child: _HoldWave(horizontal: true),
                                    )
                                  else
                                    const Align(
                                      alignment: Alignment.topCenter,
                                      child: _HoldWave(horizontal: false),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        // Labels.
                        DefaultTextStyle(
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.16,
                            color: fg,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _CrossFadeLabel(
                                visible: !active,
                                reduce: reduce,
                                child: widget.child,
                              ),
                              _CrossFadeLabel(
                                visible: _holding && !_completed,
                                reduce: reduce,
                                child: widget.holdingLabel,
                              ),
                              _CrossFadeLabel(
                                visible: _completed,
                                reduce: reduce,
                                child: widget.completeLabel,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (reduce) return shell;
    return SingleMotionBuilder(
      motion: pressMotion,
      value: scaleTarget,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: shell,
    );
  }
}

class _CrossFadeLabel extends StatelessWidget {
  const _CrossFadeLabel({
    required this.visible,
    required this.reduce,
    required this.child,
  });

  final bool visible;
  final bool reduce;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: Duration(milliseconds: reduce ? 0 : 120),
      curve: beuiEaseOut,
      opacity: visible ? 1 : 0,
      child: child,
    );
  }
}

/// Scrolling wave edge for the hold fill (decorative).
class _HoldWave extends StatefulWidget {
  const _HoldWave({required this.horizontal});
  final bool horizontal;

  @override
  State<_HoldWave> createState() => _HoldWaveState();
}

class _HoldWaveState extends State<_HoldWave>
    with SingleTickerProviderStateMixin {
  // Single forward pass — a forever-repeat pins pumpAndSettle in tests, and
  // the primary feedback is the fill translation itself.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF38BDF8);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        if (widget.horizontal) {
          return Transform.translate(offset: Offset(0, -t * 120), child: child);
        }
        return Transform.translate(offset: Offset(-t * 120, 0), child: child);
      },
      child: CustomPaint(
        size: widget.horizontal ? const Size(24, 240) : const Size(240, 24),
        painter: _WavePainter(horizontal: widget.horizontal, color: color),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.horizontal, required this.color});
  final bool horizontal;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (horizontal) {
      // Vertical wave strip on the right edge of a horizontal fill.
      path.moveTo(0, 0);
      path.lineTo(12, 0);
      for (var y = 0.0; y <= 240; y += 60) {
        path.cubicTo(2, y + 20, 2, y + 40, 12, y + 60);
      }
      path.lineTo(0, 240);
      path.close();
    } else {
      path.moveTo(0, 12);
      for (var x = 0.0; x <= 240; x += 60) {
        path.cubicTo(x + 20, 2, x + 40, 2, x + 60, 12);
      }
      path.lineTo(240, 24);
      path.lineTo(0, 24);
      path.close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.horizontal != horizontal || old.color != color;
}

// ---------------------------------------------------------------------------
// Slide action button
// ---------------------------------------------------------------------------

/// Drag-the-thumb-to-confirm control — port of `SlideActionButton`.
///
/// The thumb springs with [beuiSpringLayout] on release; crossing [threshold]
/// of track width completes, fires [onComplete], then resets after [resetDelay].
class BeuiSlideActionButton extends StatefulWidget {
  /// Creates a slide-to-confirm control.
  const BeuiSlideActionButton({
    required this.child,
    this.completeLabel = const Text('Complete'),
    this.threshold = 0.82,
    this.resetDelay = const Duration(milliseconds: 1200),
    this.onComplete,
    this.thumbColor,
    this.fillColor,
    this.trackColor,
    super.key,
  });

  /// Idle track label.
  final Widget child;

  /// Label shown after completion.
  final Widget completeLabel;

  /// Fraction of max drag distance required to complete (0–1).
  final double threshold;

  /// How long the completed state stays before auto-reset.
  final Duration resetDelay;

  /// Called once when the user slides past the threshold.
  final VoidCallback? onComplete;

  /// Thumb colour. Defaults to theme primary.
  final Color? thumbColor;

  /// Fill colour behind the thumb. Defaults to theme primary.
  final Color? fillColor;

  /// Track background. Defaults to primary at 10% alpha.
  final Color? trackColor;

  @override
  State<BeuiSlideActionButton> createState() => _BeuiSlideActionButtonState();
}

class _BeuiSlideActionButtonState extends State<BeuiSlideActionButton> {
  double _x = 0;
  double _maxDistance = 0;
  bool _dragging = false;
  bool _completed = false;
  bool _completedFired = false;
  bool _pressed = false;
  Timer? _resetTimer;
  final GlobalKey _trackKey = GlobalKey();
  final GlobalKey _thumbKey = GlobalKey();

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _measure() {
    final track = _trackKey.currentContext?.size;
    final thumb = _thumbKey.currentContext?.size;
    if (track == null || thumb == null) return;
    final next = math.max(track.width - thumb.width - 8, 0.0);
    if ((next - _maxDistance).abs() > 0.5) {
      setState(() => _maxDistance = next);
    }
  }

  void _complete() {
    if (_completedFired || _maxDistance == 0) return;
    _completedFired = true;
    setState(() {
      _completed = true;
      _x = _maxDistance;
      _dragging = false;
    });
    widget.onComplete?.call();
    _resetTimer?.cancel();
    _resetTimer = Timer(widget.resetDelay, _reset);
  }

  void _reset() {
    setState(() {
      _completed = false;
      _completedFired = false;
      _x = 0;
    });
  }

  void _onDragEnd() {
    if (_completed) return;
    if (_x >= _maxDistance * widget.threshold) {
      _complete();
    } else {
      setState(() {
        _dragging = false;
        _x = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<BeuiColors>() ?? BeuiColors.light();
    final reduce = MediaQuery.disableAnimationsOf(context);
    final thumbColor =
        widget.thumbColor ?? (_completed ? colors.background : colors.primary);
    final thumbFg = _completed ? colors.foreground : colors.primaryForeground;
    final fill = widget.fillColor ?? colors.primary;
    final track = widget.trackColor ?? colors.primary.withValues(alpha: 0.1);
    final layoutMotion = motionFor(context, beuiSpringLayout, isMovement: true);
    final pressMotion = motionFor(context, beuiSpringPress, isMovement: true);
    final safeMax = math.max(_maxDistance, 1.0);
    final progress = (_x / safeMax).clamp(0.0, 1.0);
    // Label fades across 0 → 0.35 → 0.65 of travel (source useTransform).
    final labelOpacityClamped = progress <= 0
        ? 1.0
        : progress >= 0.65
        ? 0.0
        : ui.lerpDouble(1.0, 0.0, ((progress - 0.35) / 0.30).clamp(0.0, 1.0))!;

    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    final xTarget = _x;
    final scaleTarget = reduce || _completed
        ? 1.0
        : _pressed
        ? 0.94
        : 1.0;

    Widget thumb = SizedBox(
      key: _thumbKey,
      width: 56,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: thumbColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: IconTheme(
          data: IconThemeData(color: thumbFg, size: 20),
          child: Center(
            child: CustomPaint(
              size: const Size(20, 20),
              painter: _SlideIconPainter(progress: progress, color: thumbFg),
            ),
          ),
        ),
      ),
    );

    // Press scale on thumb.
    if (!reduce) {
      thumb = SingleMotionBuilder(
        motion: pressMotion,
        value: scaleTarget,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: thumb,
      );
    }

    Widget positionedThumb;
    if (_dragging || reduce) {
      positionedThumb = Transform.translate(
        offset: Offset(xTarget, 0),
        child: thumb,
      );
    } else {
      positionedThumb = SingleMotionBuilder(
        motion: layoutMotion,
        value: xTarget,
        builder: (context, x, child) =>
            Transform.translate(offset: Offset(x, 0), child: child),
        child: thumb,
      );
    }

    return Semantics(
      button: true,
      label: 'Slide action',
      child: SizedBox(
        key: _trackKey,
        height: 64,
        width: 288,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: track,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // Fill.
                Positioned.fill(
                  child: Transform(
                    alignment: Alignment.centerLeft,
                    transform: Matrix4.diagonal3Values(progress, 1, 1),
                    child: ColoredBox(color: fill),
                  ),
                ),
                // Idle label.
                Positioned.fill(
                  child: Opacity(
                    opacity: _completed ? 0 : labelOpacityClamped,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 40),
                        child: DefaultTextStyle(
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colors.foreground,
                          ),
                          child: widget.child,
                        ),
                      ),
                    ),
                  ),
                ),
                // Complete label.
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: Duration(milliseconds: reduce ? 0 : 150),
                    curve: beuiEaseOut,
                    opacity: _completed ? 1 : 0,
                    child: Center(
                      child: DefaultTextStyle(
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colors.primaryForeground,
                        ),
                        child: widget.completeLabel,
                      ),
                    ),
                  ),
                ),
                // Thumb.
                Positioned(
                  left: 4,
                  top: 4,
                  child: GestureDetector(
                    onTap: _completed
                        ? null
                        : () {
                            // Keyboard / a11y: Enter/Space complete immediately
                            // (source onKeyDown).
                          },
                    onPanStart: _completed
                        ? null
                        : (_) => setState(() {
                            _dragging = true;
                            _pressed = true;
                          }),
                    onPanUpdate: _completed
                        ? null
                        : (d) => setState(() {
                            _x = (_x + d.delta.dx).clamp(0.0, _maxDistance);
                          }),
                    onPanEnd: _completed
                        ? null
                        : (_) {
                            setState(() => _pressed = false);
                            _onDragEnd();
                          },
                    onPanCancel: _completed
                        ? null
                        : () {
                            setState(() {
                              _pressed = false;
                              _dragging = false;
                              _x = 0;
                            });
                          },
                    child: FocusableActionDetector(
                      enabled: !_completed,
                      actions: <Type, Action<Intent>>{
                        ActivateIntent: CallbackAction<ActivateIntent>(
                          onInvoke: (_) {
                            _complete();
                            return null;
                          },
                        ),
                      },
                      child: positionedThumb,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Morphs arrow → checkmark as [progress] goes 0→1.
class _SlideIconPainter extends CustomPainter {
  _SlideIconPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Key shapes in a 24×24 viewBox, scaled to [size].
    final s = size.width / 24;
    Offset p(double x, double y) => Offset(x * s, y * s);

    // Arrow: M 8 5 L 15 12 L 8 19
    // Mid:   M 7 8 L 12 14 L 17 10
    // Check: M 5 12 L 10 17 L 19 7
    final t = progress.clamp(0.0, 1.0);
    late Offset a, b, c;
    if (t < 0.5) {
      final u = t / 0.5;
      a = Offset.lerp(p(8, 5), p(7, 8), u)!;
      b = Offset.lerp(p(15, 12), p(12, 14), u)!;
      c = Offset.lerp(p(8, 19), p(17, 10), u)!;
    } else {
      final u = (t - 0.5) / 0.5;
      a = Offset.lerp(p(7, 8), p(5, 12), u)!;
      b = Offset.lerp(p(12, 14), p(10, 17), u)!;
      c = Offset.lerp(p(17, 10), p(19, 7), u)!;
    }
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SlideIconPainter old) =>
      old.progress != progress || old.color != color;
}
