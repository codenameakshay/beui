import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// Status of a [BeuiAnimatedBadge] — a fixed, exhaustive set, mirroring the
/// source `AnimatedBadgeStatus` union.
///
/// Each status carries a default [icon] (a `LucideIcons` glyph) consumers may
/// override per status via [BeuiAnimatedBadge.icon]. Following the icon rule,
/// the defaults are the only `LucideIcons.*` references — the public API takes a
/// framework-native [IconData].
enum BeuiAnimatedBadgeStatus {
  /// Idle / informationless (source `neutral` → `Circle`).
  neutral(LucideIcons.circle),

  /// Informational (source `info` → `Info`).
  info(LucideIcons.info),

  /// Completed successfully (source `success` → `Check`).
  success(LucideIcons.check),

  /// Needs attention (source `warning` → `AlertTriangle`, renamed
  /// `triangle_alert` in Lucide 1.x).
  warning(LucideIcons.triangle_alert),

  /// Failed / error (source `danger` → `X`).
  danger(LucideIcons.x),

  /// In progress; the icon spins and the badge pulses by default
  /// (source `loading` → `LoaderCircle`).
  loading(LucideIcons.loader_circle);

  const BeuiAnimatedBadgeStatus(this.icon);

  /// The default glyph for this status — overridable per badge.
  final IconData icon;
}

/// Size of a [BeuiAnimatedBadge] (source `AnimatedBadgeSize`).
enum BeuiAnimatedBadgeSize {
  /// Compact (source `sm`: h-6, 11px text, 12px icon).
  sm,

  /// Default (source `md`: h-8, 12px text, 14px icon).
  md,
}

// ---------------------------------------------------------------------------
// Component-local springs — the source's per-channel roll/layout springs
// (`ICON_ROLL_VARIANTS` / `TEXT_ROLL_VARIANTS` / the container `layout`
// transition), verbatim. Bespoke to this component, not the SPRING_* tokens.
// ---------------------------------------------------------------------------

/// Roll y channel — the entering glyph/text springs up from below
/// (source `{ stiffness: 210, damping: 24, mass: 0.85 }`).
const _rollYSpring = SpringMotion(
  SpringDescription(mass: 0.85, stiffness: 210, damping: 24),
);

/// Roll scale channel, icon only — 0.92 → 1 on enter
/// (source `{ stiffness: 250, damping: 24, mass: 0.75 }`).
const _rollScaleSpring = SpringMotion(
  SpringDescription(mass: 0.75, stiffness: 250, damping: 24),
);

/// Container width morph (source `layout` spring
/// `{ stiffness: 420, damping: 30, mass: 0.7 }`).
const _layoutSpring = SpringMotion(
  SpringDescription(mass: 0.7, stiffness: 420, damping: 30),
);

/// A status badge whose icon and color animate on status change, with an
/// optional pulse — the Flutter port of beUI's `AnimatedBadge`.
///
/// On a status change the icon rolls out the top (blurring) while the new icon
/// rolls up from below into place on real springs ([_rollYSpring] /
/// [_rollScaleSpring]); color cross-fades over 300ms; and the container width
/// springs to fit the new label on [_layoutSpring] (the natural content width
/// is measured post-frame, the dynamic-island pattern). While
/// [BeuiAnimatedBadgeStatus.loading] the icon spins and (by default) a soft
/// ring pulses behind the badge.
///
/// Reduced motion drops the pulse and all icon/label *movement* (roll, scale,
/// blur, spin — and the width morph snaps) while keeping the color and opacity
/// cross-fade — the source's `useReducedMotion()` branch.
class BeuiAnimatedBadge extends StatefulWidget {
  /// Creates an animated status badge.
  const BeuiAnimatedBadge({
    this.status = BeuiAnimatedBadgeStatus.neutral,
    this.label,
    this.size = BeuiAnimatedBadgeSize.md,
    this.icon,
    this.showIcon = true,
    this.pulse,
    super.key,
  });

  /// Current status. Selects the color scheme and the default [icon].
  final BeuiAnimatedBadgeStatus status;

  /// Optional trailing text. When null, only the icon is shown.
  final String? label;

  /// Size.
  final BeuiAnimatedBadgeSize size;

  /// Overrides the status's default glyph. When null, [status]'s default
  /// ([BeuiAnimatedBadgeStatus.icon]) is used.
  final IconData? icon;

  /// Whether to show the leading icon (source `showIcon`).
  final bool showIcon;

  /// Whether the soft ring pulses behind the badge. Defaults to `true` only for
  /// [BeuiAnimatedBadgeStatus.loading] (source `pulse = status === "loading"`).
  final bool? pulse;

  bool get _pulse => pulse ?? (status == BeuiAnimatedBadgeStatus.loading);

  double get _height => switch (size) {
    BeuiAnimatedBadgeSize.sm => 24, // h-6
    BeuiAnimatedBadgeSize.md => 32, // h-8
  };

  double get _hPad => switch (size) {
    BeuiAnimatedBadgeSize.sm => 8, // px-2
    BeuiAnimatedBadgeSize.md => 12, // px-3
  };

  double get _gap => switch (size) {
    BeuiAnimatedBadgeSize.sm => 6, // gap-1.5
    BeuiAnimatedBadgeSize.md => 8, // gap-2
  };

  double get _iconSize => switch (size) {
    BeuiAnimatedBadgeSize.sm => 12, // h-3 w-3
    BeuiAnimatedBadgeSize.md => 14, // h-3.5 w-3.5
  };

  double get _textSize => switch (size) {
    BeuiAnimatedBadgeSize.sm => 11, // text-[11px]
    BeuiAnimatedBadgeSize.md => 12, // text-xs
  };

  @override
  State<BeuiAnimatedBadge> createState() => _BeuiAnimatedBadgeState();
}

class _BeuiAnimatedBadgeState extends State<BeuiAnimatedBadge> {
  /// Measures the content row's natural width post-frame (the dynamic-island
  /// `_scheduleMeasure` pattern), so the container width can be driven by the
  /// source's layout spring instead of a duration-eased AnimatedSize.
  final GlobalKey _contentKey = GlobalKey();
  double? _contentWidth;

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final w = box.size.width;
      if (_contentWidth == null || (w - _contentWidth!).abs() > 0.5) {
        setState(() => _contentWidth = w);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final scheme = _BadgeScheme.of(widget.status, colors);
    final radius = BorderRadius.circular(widget._height / 2); // rounded-full

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showIcon)
          _IconSlot(
            icon: widget.icon ?? widget.status.icon,
            status: widget.status,
            // A custom icon is never spun (source spins only the default
            // LoaderCircle); the default loading glyph becomes the spinner.
            customIcon: widget.icon != null,
            color: scheme.foreground,
            size: widget._iconSize,
            reduce: reduce,
          ),
        if (widget.showIcon && widget.label != null)
          SizedBox(width: widget._gap),
        if (widget.label != null)
          _LabelSlot(
            label: widget.label!,
            style: TextStyle(
              fontSize: widget._textSize,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: scheme.foreground,
              // Natural line box (no forced height:1.0) so the slot's ClipRect
              // doesn't shave descenders (y, g) at rest.
            ),
            reduce: reduce,
          ),
      ],
    );

    // Width morph — the source's `layout` spring {stiffness: 420, damping: 30,
    // mass: 0.7}. The content's natural width is measured post-frame (the
    // exiting roll layers are lifted out of layout by the popLayout stack, so
    // the measurement tracks only the incoming glyph/label) and the box width
    // springs to it; the OverflowBox lets the content keep its natural layout
    // mid-morph without Row-overflow errors. Reduced motion snaps (movement
    // dropped): the content is laid out at its natural width, unanimated.
    Widget sized;
    if (reduce) {
      sized = content;
    } else {
      _scheduleMeasure();
      final measured = KeyedSubtree(key: _contentKey, child: content);
      final w = _contentWidth;
      sized = w == null
          ? measured // first frame: natural width until measured
          : SingleMotionBuilder(
              value: w,
              motion: _layoutSpring,
              child: measured,
              builder: (context, width, child) => SizedBox(
                width: width < 0 ? 0 : width,
                child: OverflowBox(
                  minWidth: 0,
                  maxWidth: double.infinity,
                  child: child,
                ),
              ),
            );
    }

    // The container: color cross-fades (kept under reduced motion) via
    // AnimatedContainer; it shrink-wraps the spring-sized content above.
    final badge = AnimatedContainer(
      duration: const Duration(milliseconds: 300), // transition-colors
      curve: beuiEaseOut,
      height: widget._height,
      padding: EdgeInsets.symmetric(horizontal: widget._hPad),
      decoration: BoxDecoration(
        color: scheme.background,
        border: Border.all(color: scheme.border),
        borderRadius: radius,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        // `inline-flex items-center` — cross-axis centred, main axis flex-start.
        // Only observable when the badge is given a wider constraint than its
        // content (e.g. as a stretched grid item, as in the source preview).
        alignment: Alignment.centerLeft,
        children: [
          if (widget._pulse && !reduce)
            Positioned.fill(
              // The ring repaints every frame while breathing; isolate it so it
              // never re-rasterises the badge content (and vice versa).
              child: RepaintBoundary(
                child: _Pulse(color: scheme.foreground, radius: radius),
              ),
            ),
          sized,
        ],
      ),
    );

    return Semantics(
      liveRegion: true,
      container: true,
      child: ClipRRect(borderRadius: radius, child: badge),
    );
  }
}

/// Resolved badge colors for a status. Mirrors the source `STATUS_CLASS`,
/// reading theme tokens where they exist (neutral/info/danger) and the source's
/// fixed emerald/amber for success/warning.
class _BadgeScheme {
  const _BadgeScheme({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;

  factory _BadgeScheme.of(BeuiAnimatedBadgeStatus status, BeuiColors c) {
    final isDark = c.brightness == Brightness.dark;
    switch (status) {
      case BeuiAnimatedBadgeStatus.neutral:
        // border-border bg-card text-muted-foreground
        return _BadgeScheme(
          background: c.card,
          border: c.border,
          foreground: c.mutedForeground,
        );
      case BeuiAnimatedBadgeStatus.info:
      case BeuiAnimatedBadgeStatus.loading:
        // border-primary/30 bg-primary/10 text-primary
        return _BadgeScheme(
          background: c.primary.withValues(alpha: 0.10),
          border: c.primary.withValues(alpha: 0.30),
          foreground: c.primary,
        );
      case BeuiAnimatedBadgeStatus.success:
        // emerald-500 ring/bg, text emerald-600 (light) / emerald-400 (dark)
        const emerald500 = Color(0xFF10B981);
        final fg = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
        return _BadgeScheme(
          background: emerald500.withValues(alpha: 0.10),
          border: emerald500.withValues(alpha: 0.30),
          foreground: fg,
        );
      case BeuiAnimatedBadgeStatus.warning:
        // amber-500 ring/bg, text amber-600 (light) / amber-400 (dark)
        const amber500 = Color(0xFFF59E0B);
        final fg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
        return _BadgeScheme(
          background: amber500.withValues(alpha: 0.10),
          border: amber500.withValues(alpha: 0.30),
          foreground: fg,
        );
      case BeuiAnimatedBadgeStatus.danger:
        // border-destructive/30 bg-destructive/10 text-destructive
        return _BadgeScheme(
          background: c.destructive.withValues(alpha: 0.10),
          border: c.destructive.withValues(alpha: 0.30),
          foreground: c.destructive,
        );
    }
  }
}

/// The leading icon. On a status change the old icon rolls out the top (blur)
/// and the new one rolls up from below (spring + blur), matching the source
/// `ICON_ROLL_VARIANTS` + `AnimatePresence mode="popLayout"`. While loading the
/// icon spins. Reduced motion plays a plain cross-fade and disables the spin.
class _IconSlot extends StatelessWidget {
  const _IconSlot({
    required this.icon,
    required this.status,
    required this.customIcon,
    required this.color,
    required this.size,
    required this.reduce,
  });

  final IconData icon;
  final BeuiAnimatedBadgeStatus status;
  final bool customIcon;
  final Color color;
  final double size;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    // The default loading glyph is a centre-painted arc spun in place — a font
    // glyph rotated by RotationTransition wobbles (it spins around the widget
    // box, not the glyph's optical centre). A custom icon, or reduced motion,
    // renders a static glyph (source: spin only the default LoaderCircle).
    // The spinner repaints every frame; a RepaintBoundary isolates it.
    final spin =
        status == BeuiAnimatedBadgeStatus.loading && !reduce && !customIcon;
    final Widget glyph = spin
        ? RepaintBoundary(
            child: _LoaderSpinner(size: size, color: color),
          )
        : Icon(icon, size: size, color: color);

    // ClipRect = the source's per-span `overflow-hidden`: the rolling glyph is
    // clipped to its own box so the exiting icon vanishes the moment it clears.
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420), // enter (eased channels)
        reverseDuration: const Duration(milliseconds: 220), // icon exit tween
        switchInCurve: Curves.linear,
        switchOutCurve: Curves.linear,
        transitionBuilder: (child, animation) => _RollTransition(
          animation: animation,
          reduce: reduce,
          rise: size * 0.8, // source: y rolls 80% of the glyph box
          exitMs: 220,
          opacityFrom: 0.72,
          child: child,
        ),
        layoutBuilder: _popLayout,
        child: KeyedSubtree(
          key: ValueKey(
            'icon-${status.name}-${spin ? 'spin' : icon.codePoint}',
          ),
          child: glyph,
        ),
      ),
    );
  }
}

/// popLayout: exiting layers are lifted OUT of layout flow ([Positioned], so
/// they never size the [Stack]) and stacked over the incoming child — the slot
/// (and therefore the badge's width spring) tracks only the incoming content
/// immediately, matching Framer's `AnimatePresence mode="popLayout"`.
Widget _popLayout(Widget? current, List<Widget> previous) => Stack(
  clipBehavior: Clip.none,
  alignment: Alignment.center,
  children: [
    for (final p in previous)
      Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        child: Center(child: p), // vertically centred, natural width
      ),
    ?current,
  ],
);

/// The label slot. On a label change the old text rolls out the top (blur) and
/// the new text rolls up from below (spring + blur), matching the source
/// `TEXT_ROLL_VARIANTS`. Reduced motion plays a plain cross-fade.
class _LabelSlot extends StatelessWidget {
  const _LabelSlot({
    required this.label,
    required this.style,
    required this.reduce,
  });

  final String label;
  final TextStyle style;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420), // enter (eased channels)
        reverseDuration: const Duration(milliseconds: 200), // text exit tween
        switchInCurve: Curves.linear,
        switchOutCurve: Curves.linear,
        transitionBuilder: (child, animation) => _RollTransition(
          animation: animation,
          reduce: reduce,
          // Source: text rolls 85% of the line box (≈ fontSize × 1.3).
          rise: (style.fontSize ?? 12) * 1.3 * 0.85,
          exitMs: 200,
          opacityFrom: 0.76,
          scale: false, // text roll has no scale (source TEXT_ROLL_VARIANTS)
          rotate: false, // ...and no rotate (icon-only channel)
          child: child,
        ),
        layoutBuilder: _popLayout,
        child: Text(
          label,
          key: ValueKey('label-$label'),
          style: style,
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
  }
}

/// The roll transition shared by the icon and label slots — a faithful port of
/// the source `ICON_ROLL_VARIANTS` / `TEXT_ROLL_VARIANTS` per-channel spec:
///
/// * **y** — a real spring ([_rollYSpring], stiffness 210 / damping 24 /
///   mass 0.85) released when the child enters, from +[rise] (below) to 0.
///   The exit is a tween (the source's exits are duration-based):
///   0 → −[rise], [beuiEaseOut] over [exitMs].
/// * **scale** (icon only) — [_rollScaleSpring] (stiffness 250 / damping 24 /
///   mass 0.75), from 0.92 → 1 on enter.
/// * **rotate** (icon only) — enter −8° → 0 over 0.28s [beuiEaseOut]; exit
///   0 → +8° over [exitMs].
/// * **opacity** — enter [opacityFrom] → 1 over the 0.42s [beuiEaseOut]
///   window; exit fades to **0.5** (not 0) — the glyph is still ghost-visible
///   when the switcher removes it, matching the source endpoints.
/// * **blur** — 6px → 0 (sigma 3 → 0) over the 0.42s [beuiEaseOut] window on
///   enter; the exit blurs back in over [exitMs].
///
/// The eased channels ride elapsed-time windows off the (linear) switcher
/// animation; the spring channels are independent [SingleMotionBuilder]s
/// released on mount — the same released-spring pattern as text_reveal — and
/// keep settling on their own after the switcher's window closes. Direction is
/// read off the animation status per frame; the switcher's initial child
/// (already completed at mount) renders settled without rolling in. Reduced
/// motion collapses to a plain fade.
class _RollTransition extends StatefulWidget {
  const _RollTransition({
    required this.animation,
    required this.reduce,
    required this.rise,
    required this.exitMs,
    required this.opacityFrom,
    required this.child,
    this.scale = true,
    this.rotate = true,
  });

  final Animation<double> animation;
  final bool reduce;

  /// Roll distance — 80% of the glyph box (icon) / 85% of the line box (text),
  /// the source's `y` endpoints.
  final double rise;

  /// Exit tween duration in ms (must equal the slot's `reverseDuration`):
  /// 220 for the icon, 200 for the text.
  final int exitMs;

  /// Enter opacity start point (0.72 icon / 0.76 text).
  final double opacityFrom;

  final bool scale;
  final bool rotate;
  final Widget child;

  @override
  State<_RollTransition> createState() => _RollTransitionState();
}

class _RollTransitionState extends State<_RollTransition> {
  static const double _blurSigma = 3; // source blur(6px) → sigma 3
  static const double _enterMs = 420; // opacity/blur window (= switch duration)
  static const double _rotateMs = 280; // rotate-in window
  static const double _maxRotate = 8 * math.pi / 180; // 8°

  /// True when the animation was already completed at mount — the switcher's
  /// initial child, which must render settled rather than roll in. It still
  /// exits normally if a swap later reverses it.
  late final bool _settledAtMount =
      widget.animation.status == AnimationStatus.completed;

  @override
  Widget build(BuildContext context) {
    if (widget.reduce) {
      // Reduced motion: opacity kept, movement (y/scale/rotate/blur) dropped.
      return FadeTransition(opacity: widget.animation, child: widget.child);
    }
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, _) {
        final status = widget.animation.status;
        final exiting =
            status == AnimationStatus.reverse ||
            status == AnimationStatus.dismissed;
        if (exiting) return _exit(widget.animation.value);
        if (_settledAtMount) return widget.child; // initial child, at rest
        return _enter(widget.animation.value);
      },
    );
  }

  /// Exit: every channel is a [beuiEaseOut] tween over the slot's exit window
  /// (the switcher's linear reverse run, [widget.exitMs]) — the source's exits
  /// are duration-based, not springs. [t] runs 1 → 0.
  Widget _exit(double t) {
    final p = beuiEaseOut.transform((1 - t).clamp(0.0, 1.0));
    Widget c = _blurred(widget.child, _blurSigma * p);
    if (widget.rotate) {
      c = Transform.rotate(angle: _maxRotate * p, child: c); // 0 → +8°
    }
    return Opacity(
      opacity: (1 - 0.5 * p).clamp(0.0, 1.0), // fades to 0.5, not 0
      child: Transform.translate(
        offset: Offset(0, -widget.rise * p), // 0 → -rise, up and out the top
        child: c,
      ),
    );
  }

  /// Enter: rotate/opacity/blur are eased elapsed-time windows off the linear
  /// switcher progress [t]; y and scale are released springs.
  Widget _enter(double t) {
    final elapsedMs = t * _enterMs;
    final p = beuiEaseOut.transform((elapsedMs / _enterMs).clamp(0.0, 1.0));
    final opacity = widget.opacityFrom + (1 - widget.opacityFrom) * p;
    Widget c = _blurred(widget.child, _blurSigma * (1 - p));
    if (widget.rotate) {
      final rp = beuiEaseOut.transform((elapsedMs / _rotateMs).clamp(0.0, 1.0));
      c = Transform.rotate(angle: -_maxRotate * (1 - rp), child: c); // -8° → 0
    }
    return SingleMotionBuilder(
      value: 0.0,
      from: widget.rise, // released at mount: +rise (below) → 0
      motion: _rollYSpring,
      child: c,
      builder: (context, dy, child) {
        if (!widget.scale) {
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.translate(offset: Offset(0, dy), child: child),
          );
        }
        return SingleMotionBuilder(
          value: 1.0,
          from: 0.92, // source scale channel: 0.92 → 1
          motion: _rollScaleSpring,
          child: child,
          builder: (context, sc, inner) => Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, dy),
              child: Transform.scale(scale: sc, child: inner),
            ),
          ),
        );
      },
    );
  }

  static Widget _blurred(Widget child, double sigma) {
    if (sigma <= 0.05) return child;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.decal,
      ),
      child: child,
    );
  }
}

/// The soft ring that breathes behind the badge — source pulse:
/// `scale [0.94, 1.08, 0.94]`, `opacity [0.08, 0.16, 0.08]`, 1.6s easeInOut
/// loop. Decorative; opacity/scale only.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.color, required this.radius});

  final Color color;
  final BorderRadius radius;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // Triangle wave 0→1→0 over the loop, eased.
          final raw = _controller.value;
          final tri = raw < 0.5 ? raw * 2 : (1 - raw) * 2;
          final e = Curves.easeInOut.transform(tri);
          final scale = 0.94 + 0.14 * e; // 0.94 → 1.08
          final opacity = 0.08 + 0.08 * e; // 0.08 → 0.16
          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: widget.radius,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The loading spinner — a centre-painted 3/4 arc (matching Lucide's
/// `loader-circle`) spun in place by a [RotationTransition], 1s linear loop
/// (source's loading-icon `rotate: 360`). Custom-painted so it stays optically
/// centred and crisp at any size, instead of orbiting like a rotated font glyph.
class _LoaderSpinner extends StatefulWidget {
  const _LoaderSpinner({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  State<_LoaderSpinner> createState() => _LoaderSpinnerState();
}

class _LoaderSpinnerState extends State<_LoaderSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _SpinnerPainter(
          color: widget.color,
          stroke: widget.size * 0.12,
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter({required this.color, required this.stroke});

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    // 3/4 arc from the top, like Lucide's loader-circle.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) =>
      old.color != color || old.stroke != stroke;
}
