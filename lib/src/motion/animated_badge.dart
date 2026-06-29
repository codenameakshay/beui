import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';

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

/// A status badge whose icon and color animate on status change, with an
/// optional pulse — the Flutter port of beUI's `AnimatedBadge`.
///
/// On a status change the icon rolls out the top (blurring) while the new icon
/// rolls up from below into place; color cross-fades over 300ms; and the
/// container width springs to fit the new label. While [BeuiAnimatedBadgeStatus.loading]
/// the icon spins and (by default) a soft ring pulses behind the badge.
///
/// Reduced motion drops the pulse and all icon/label *movement* (roll, scale,
/// blur, spin) while keeping the color and opacity cross-fade — the source's
/// `useReducedMotion()` branch.
class BeuiAnimatedBadge extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final scheme = _BadgeScheme.of(status, colors);
    final radius = BorderRadius.circular(_height / 2); // rounded-full

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon)
          _IconSlot(
            icon: icon ?? status.icon,
            status: status,
            color: scheme.foreground,
            size: _iconSize,
            reduce: reduce,
          ),
        if (showIcon && label != null) SizedBox(width: _gap),
        if (label != null)
          _LabelSlot(
            label: label!,
            style: TextStyle(
              fontSize: _textSize,
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

    // The container: color cross-fades (kept under reduced motion) via
    // AnimatedContainer; width morphs to fit the new label via AnimatedSize on
    // `beuiEaseOut` — the source `layout` transition, ported the same way the
    // reference StatefulButton ports its width morph (curve, not snap). Reduced
    // motion zeroes the size animation so the width snaps.
    final badge = AnimatedContainer(
      duration: const Duration(milliseconds: 300), // transition-colors
      curve: beuiEaseOut,
      height: _height,
      padding: EdgeInsets.symmetric(horizontal: _hPad),
      decoration: BoxDecoration(
        color: scheme.background,
        border: Border.all(color: scheme.border),
        borderRadius: radius,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (_pulse && !reduce)
            Positioned.fill(
              child: _Pulse(color: scheme.foreground, radius: radius),
            ),
          // Width morph (source `layout`). Reduced motion snaps (no AnimatedSize,
          // which dislikes a zero duration and would re-dirty itself).
          if (reduce)
            content
          else
            AnimatedSize(
              duration: const Duration(milliseconds: 360),
              curve: beuiEaseOut,
              alignment: Alignment.center,
              child: content,
            ),
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
    required this.color,
    required this.size,
    required this.reduce,
  });

  final IconData icon;
  final BeuiAnimatedBadgeStatus status;
  final Color color;
  final double size;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    Widget glyph = Icon(icon, size: size, color: color);
    if (status == BeuiAnimatedBadgeStatus.loading && !reduce) {
      glyph = _Spinner(child: glyph);
    }

    // ClipRect = the source's per-span `overflow-hidden`: the rolling glyph is
    // clipped to its own box so the exiting icon vanishes the moment it clears.
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420), // enter
        reverseDuration: const Duration(milliseconds: 200), // exit is faster
        switchInCurve: Curves.linear,
        switchOutCurve: Curves.linear,
        transitionBuilder: (child, animation) => _RollTransition(
          animation: animation,
          reduce: reduce,
          rise: size,
          child: child,
        ),
        // popLayout: stack out-going on top of in-coming without reflow.
        layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.center, children: [...previous, ?current]),
        child: KeyedSubtree(
          key: ValueKey('icon-${status.name}-${icon.codePoint}'),
          child: glyph,
        ),
      ),
    );
  }
}

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
        duration: const Duration(milliseconds: 420), // enter
        reverseDuration: const Duration(milliseconds: 200), // exit is faster
        switchInCurve: Curves.linear,
        switchOutCurve: Curves.linear,
        transitionBuilder: (child, animation) => _RollTransition(
          animation: animation,
          reduce: reduce,
          rise: (style.fontSize ?? 12) * 1.3, // ≈ the natural line box height
          scale: false, // text roll has no scale (source TEXT_ROLL_VARIANTS)
          child: child,
        ),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerLeft,
          children: [...previous, ?current],
        ),
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

/// The roll transition shared by the icon and label slots — the y-rise, scale,
/// blur and opacity all ride the live [animation] progress, eased with
/// [beuiEaseOut] (the source's `EASE_OUT` per-channel transitions; the literal
/// Framer springs can't track a duration-based switcher, so a single eased roll
/// is used — the same proven shape as the action-swap roll). Reduced motion
/// collapses to a plain fade.
///
/// [AnimatedSwitcher] runs the same builder for the entering child (forward,
/// 0→1) and the exiting child (reverse, 1→0). Direction is read off the status
/// **per frame**. The entering glyph rolls UP from below into place; the
/// exiting one rolls UP and out the top (source `ICON_ROLL_VARIANTS` /
/// `TEXT_ROLL_VARIANTS`: `y 80%→0` in, `0→-80%` out). The caller clips each slot
/// to its glyph box (source `overflow-hidden`), so the exit vanishes cleanly.
class _RollTransition extends StatelessWidget {
  const _RollTransition({
    required this.animation,
    required this.reduce,
    required this.rise,
    required this.child,
    this.scale = true,
  });

  final Animation<double> animation;
  final bool reduce;

  /// Roll distance — the glyph/line box height, so the content fully clears the
  /// (clipped) slot on exit and starts fully below on enter.
  final double rise;
  final bool scale;
  final Widget child;

  static const double _blur = 3; // source blur(6px) ≈ sigma 3

  @override
  Widget build(BuildContext context) {
    if (reduce) return FadeTransition(opacity: animation, child: child);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final exiting = animation.status == AnimationStatus.reverse;
        final t = animation.value; // live linear progress (1→0 while exiting)
        final easedIn = beuiEaseOut.transform(t);
        final easedOut = beuiEaseInOut.transform(t);
        // enter: +rise (below) → 0 (easeOut). exit: 0 → -rise up and out
        // (easeInOut, so it clears steadily rather than lingering at centre).
        final dy =
            exiting ? -(1 - easedOut) * rise : (1 - easedIn) * rise;
        final sc = scale ? 0.92 + 0.08 * easedIn : 1.0;
        // Exit fades linearly (source exit is fast); enter fades eased.
        final opacity = exiting ? t : easedIn;
        final blur = (1 - t) * _blur;
        Widget c = child;
        if (blur > 0.05) {
          c = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: blur,
              sigmaY: blur,
              tileMode: TileMode.decal,
            ),
            child: c,
          );
        }
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: scale ? Transform.scale(scale: sc, child: c) : c,
          ),
        );
      },
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

/// A continuously spinning wrapper — the source's loading-icon `rotate: 360`,
/// 1s linear loop.
class _Spinner extends StatefulWidget {
  const _Spinner({required this.child});

  final Widget child;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
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
    return RotationTransition(turns: _controller, child: widget.child);
  }
}
