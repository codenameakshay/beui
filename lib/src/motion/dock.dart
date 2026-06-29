import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// One entry in a [BeuiDock].
///
/// Carries the glyph and an optional [onTap] / [active] state. The dock owns the
/// gliding active pill (and, when enabled, magnification); an item only
/// describes itself.
class BeuiDockItem {
  /// Creates a dock item.
  const BeuiDockItem({
    this.icon,
    this.child,
    this.onTap,
    this.active = false,
    this.tooltip,
  }) : assert(icon != null || child != null,
            'Provide either an icon glyph or a custom child.');

  /// Glyph for the item (framework-native — pick any [IconData]).
  final IconData? icon;

  /// Custom content, used instead of [icon] when set.
  final Widget? child;

  /// Tap handler. When non-null the item is focusable/pressable.
  final VoidCallback? onTap;

  /// Whether the gliding active pill sits behind this item.
  final bool active;

  /// Accessible label / semantics for the item.
  final String? tooltip;
}

/// A dock — the Flutter port of beUI's `dock`.
///
/// **By default this is a one-to-one port of the React source**
/// (`components/motion/dock.tsx`): a flat glass bar (`items-end`, `rounded-2xl`,
/// a translucent card surface) of fixed-`size` items, whose only motion is a
/// gliding active **pill** (`layoutId` + `SPRING_LAYOUT`) behind the active item.
/// The source has no magnification and no pointer tracking, so the default dock
/// has neither: no `MouseRegion`, no per-item scale, items stay at [size].
///
/// **[magnify] is a Flutter-only enhancement — it is NOT present in the React
/// source.** Setting `magnify: true` opts into a macOS-style magnifying dock on
/// top of the faithful base: as the pointer moves across the bar, each item
/// scales by its *horizontal* distance to the cursor and lifts so the bar's
/// baseline stays put.
///
/// **Distance → scale** (only when [magnify] is `true`). For item centre `cx`
/// and cursor `x`, with `d = |x - cx|`:
///
/// ```text
/// t     = max(0, 1 - d / falloff)      // 1 under the cursor → 0 past falloff
/// scale = 1 + (maxScale - 1) * t       // 1 → maxScale
/// ```
///
/// `falloff` is two item-widths, so a small cluster grows like macOS. Each
/// item's scale is spring-smoothed with [beuiSpringMouse] — the source's
/// continuous cursor-follow token (the same one `tilt-card` / `magnetic` use),
/// re-targeted on every `MouseRegion.onHover`. On exit all items relax to 1.
///
/// **Hover-only.** Magnification is driven by `MouseRegion`, so it never fires on
/// touch (matching the source's `useHoverCapable()` gate). **Reduced motion**
/// renders the static faithful dock even when [magnify] is `true` (no
/// magnification, no lift). Colours come from [BeuiColors]; nothing is hardcoded.
class BeuiDock extends StatefulWidget {
  /// Creates a dock from [items].
  const BeuiDock({
    required this.items,
    this.magnify = false,
    this.size = 44,
    this.maxScale = 1.6,
    this.gap = 6,
    super.key,
  });

  /// The items, left to right. A `null` entry renders a vertical separator.
  final List<BeuiDockItem?> items;

  /// Opt in to the macOS-style cursor magnification (a Flutter-only enhancement;
  /// **not** in the React source). Defaults to `false` — the faithful flat dock.
  final bool magnify;

  /// Resting size (px) of each item.
  final double size;

  /// Peak magnification of the item directly under the cursor. Only used when
  /// [magnify] is `true`.
  final double maxScale;

  /// Horizontal gap (px) between items.
  final double gap;

  @override
  State<BeuiDock> createState() => _BeuiDockState();
}

class _BeuiDockState extends State<BeuiDock> {
  /// Cursor x in the dock-row's local coordinates, or null when not hovering.
  double? _cursorX;

  /// Falloff width (px): how far the magnification reaches on either side of the
  /// cursor. Roughly two item-widths so a small cluster grows, like macOS.
  double get _falloff => widget.size * 2;

  /// Target scale for an item whose horizontal centre is [centerX].
  double _scaleFor(double centerX) {
    final x = _cursorX;
    if (x == null) return 1;
    final d = (x - centerX).abs();
    final t = math.max(0.0, 1 - d / _falloff);
    return 1 + (widget.maxScale - 1) * t;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);

    // Magnification is opt-in, hover-only, and off under reduced motion.
    final magnify = widget.magnify && !reduce;

    // Lay out resting item centres so onHover can map cursor x → per-item
    // distance. These stay in the bar's local space (the MouseRegion frame), so
    // they include the bar's left padding. Separators take half an item-width;
    // everything is gap-separated. Distance is measured from the *resting* grid
    // even while items magnify — the standard, stable macOS approximation.
    final padH = widget.gap + 2;
    final centers = <double>[];
    var cursor = padH;
    for (final item in widget.items) {
      final w = item == null ? widget.size / 2 : widget.size;
      centers.add(cursor + w / 2);
      cursor += w + widget.gap;
    }

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < widget.items.length; i++) ...[
          if (i > 0) SizedBox(width: widget.gap),
          if (widget.items[i] == null)
            _Separator(height: widget.size * 0.55, color: colors.border)
          else
            _DockItemView(
              item: widget.items[i]!,
              size: widget.size,
              magnify: magnify,
              targetScale: magnify ? _scaleFor(centers[i]) : 1.0,
              colors: colors,
            ),
        ],
      ],
    );

    final bar = Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: 4),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16), // rounded-2xl
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.foreground.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: row,
    );

    // No magnification → faithful static dock, no pointer tracking.
    if (!magnify) return bar;

    return MouseRegion(
      onHover: (e) => setState(() => _cursorX = e.localPosition.dx),
      onExit: (_) => setState(() => _cursorX = null),
      child: bar,
    );
  }
}

/// A single dock item. Renders the glyph + active pill; when [magnify] is on it
/// is spring-scaled and lifted so the dock baseline holds.
class _DockItemView extends StatelessWidget {
  const _DockItemView({
    required this.item,
    required this.size,
    required this.magnify,
    required this.targetScale,
    required this.colors,
  });

  final BeuiDockItem item;
  final double size;
  final bool magnify;
  final double targetScale;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    Widget glyph = item.child ??
        Icon(item.icon, size: size * 0.46, color: colors.foreground);

    Widget content = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Gliding active pill (source: layoutId + SPRING_LAYOUT). It appears /
          // clears behind the active item.
          if (item.active)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12), // rounded-xl
                  ),
                ),
              ),
            ),
          Center(child: glyph),
        ],
      ),
    );

    if (item.tooltip != null) {
      content = Semantics(
          label: item.tooltip, button: item.onTap != null, child: content);
    }
    if (item.onTap != null) {
      content = GestureDetector(
        onTap: item.onTap,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: content),
      );
    }

    // Faithful (no magnification) → fixed-size item, no scaling at all.
    if (!magnify) return content;

    // The slot grows with the scale so neighbours push apart (macOS dock) and
    // the row reflows; bottom-anchored sizing keeps the bar's baseline
    // (items-end) fixed, so items rise as they grow.
    Widget slot(double scale) => SizedBox(
          width: size * scale,
          height: size * scale,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: size,
              height: size,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: content,
              ),
            ),
          ),
        );

    return SingleMotionBuilder(
      value: targetScale,
      motion: beuiSpringMouse,
      builder: (context, scale, _) => slot(scale),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      height: height,
      child: ColoredBox(color: color),
    );
  }
}
