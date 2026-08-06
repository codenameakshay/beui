import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// One entry in a [BeuiDock] — an action, or a [BeuiDockItem.separator].
///
/// Carries the glyph and an optional [onTap] / [active] state. The dock owns the
/// gliding active pill (and, when enabled, magnification); an item only
/// describes itself.
///
/// The source exports the separator as its own component (`DockSeparator`), but
/// a dock is driven here by a *list of items* rather than by children, so the
/// port folds it into this model as a named constructor. That keeps [BeuiDock]'s
/// item list homogeneous ([List] of non-nullable [BeuiDockItem]) and keeps the
/// grouping visible at the call site.
class BeuiDockItem {
  /// Creates a dock item.
  const BeuiDockItem({
    this.icon,
    this.child,
    this.onTap,
    this.active = false,
    this.tooltip,
  }) : isSeparator = false,
       assert(
         icon != null || child != null,
         'Provide either an icon glyph or a custom child.',
       );

  /// A thin vertical rule that groups the actions on either side of it — the
  /// port of the source's `DockSeparator` (`mx-1 h-6 w-px self-center
  /// bg-border`), and what makes the "macOS-style dock with grouped actions"
  /// arrangement expressible.
  ///
  /// It is furniture, not an entry: it is **skipped by hover magnification**
  /// (it never scales, though it still occupies its 9px of the row so the
  /// cursor→item distances stay true), **skipped by keyboard traversal** (it
  /// holds nothing focusable), and **decorative for semantics** — the subtree is
  /// wrapped in [ExcludeSemantics], the port of the source's `aria-hidden`. It
  /// can never be [active], so it never attracts the pill.
  ///
  /// ```dart
  /// BeuiDock(items: [
  ///   BeuiDockItem(icon: LucideIcons.house, onTap: goHome),
  ///   BeuiDockItem(icon: LucideIcons.mail, onTap: openMail),
  ///   const BeuiDockItem.separator(),
  ///   BeuiDockItem(icon: LucideIcons.settings, onTap: openSettings),
  /// ]);
  /// ```
  const BeuiDockItem.separator()
    : icon = null,
      child = null,
      onTap = null,
      active = false,
      tooltip = null,
      isSeparator = true;

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

  /// Whether this entry is a decorative rule rather than an action — true only
  /// for [BeuiDockItem.separator]. See that constructor for what the dock skips.
  final bool isSeparator;
}

/// Painted width of a [BeuiDockItem.separator]: the 1px rule plus its `mx-1`
/// (4px) margins. Fixed — a separator does not scale with [BeuiDock.size], and
/// the hover-distance math must use this real width so the items to its right
/// magnify around the correct centres.
const double _separatorWidth = 9;

/// A dock — the Flutter port of beUI's `dock`.
///
/// **By default this is a one-to-one port of the React source**
/// (`components/motion/dock.tsx`): a flat glass bar (`items-end`, `rounded-2xl`,
/// a translucent card surface) of fixed-`size` items, whose only motion is a
/// gliding active **pill** behind the active item. The pill is a single element
/// that springs between items with [beuiSpringLayout] when the active item
/// changes (the source's `layoutId` shared-layout glide) — not a per-item
/// highlight that toggles on/off. The source has no magnification and no pointer
/// tracking, so the default dock has neither: no `MouseRegion`, no per-item
/// scale, items stay at [size].
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
/// **Grouping.** A [BeuiDockItem.separator] entry renders the source's
/// `DockSeparator` — a 1px vertical rule that splits the bar into groups. It is
/// decorative throughout: never magnified, never focusable, never active, and
/// hidden from semantics.
///
/// **Hover-only.** Magnification is driven by `MouseRegion`, so it never fires on
/// touch (matching the source's `useHoverCapable()` gate). **Reduced motion**
/// renders the static faithful dock even when [magnify] is `true` (no
/// magnification, no lift) and snaps the pill instead of gliding. Colours come
/// from [BeuiColors]; nothing is hardcoded.
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

  /// The items, left to right. Use [BeuiDockItem.separator] to group them with
  /// a vertical rule.
  final List<BeuiDockItem> items;

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
  final GlobalKey _stackKey = GlobalKey();
  late List<GlobalKey> _itemKeys;

  /// Cursor x in the dock-row's local coordinates, or null when not hovering.
  /// A [ValueNotifier] rather than setState, so each mousemove re-targets only
  /// the per-item scale springs (each item listens itself) instead of
  /// rebuilding the whole bar at pointer-event rate.
  final ValueNotifier<double?> _cursorX = ValueNotifier<double?>(null);

  /// Measured rect of the active item (in the dock Stack's space); the pill
  /// springs toward it. Null when no item is active.
  Rect? _pillRect;

  @override
  void initState() {
    super.initState();
    _itemKeys = List.generate(widget.items.length, (_) => GlobalKey());
  }

  @override
  void didUpdateWidget(BeuiDock old) {
    super.didUpdateWidget(old);
    if (widget.items.length != _itemKeys.length) {
      _itemKeys = List.generate(widget.items.length, (_) => GlobalKey());
    }
  }

  @override
  void dispose() {
    _cursorX.dispose();
    super.dispose();
  }

  /// Falloff width (px): how far the magnification reaches on either side of the
  /// cursor. Roughly two item-widths so a small cluster grows, like macOS.
  double get _falloff => widget.size * 2;

  /// Measure the active item's rect relative to the Stack so the pill can glide
  /// to it (the source's `layoutId` shared layout — measured one frame late, as
  /// the spec's measurement rule prescribes).
  void _measurePill() {
    if (!mounted) return;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;
    final idx = widget.items.indexWhere((it) => it.active);
    if (idx < 0) {
      if (_pillRect != null) setState(() => _pillRect = null);
      return;
    }
    final itemBox =
        _itemKeys[idx].currentContext?.findRenderObject() as RenderBox?;
    if (itemBox == null || !itemBox.hasSize) return;
    final topLeft = stackBox.globalToLocal(itemBox.localToGlobal(Offset.zero));
    final rect = topLeft & itemBox.size;
    if (rect != _pillRect) setState(() => _pillRect = rect);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);

    // Magnification is opt-in, hover-only, and off under reduced motion.
    final magnify = widget.magnify && !reduce;

    WidgetsBinding.instance.addPostFrameCallback((_) => _measurePill());

    // Lay out resting item centres so onHover can map cursor x → per-item
    // distance. These stay in the bar's local space (the MouseRegion frame), so
    // they include the bar's left padding. Separators contribute their painted
    // [_separatorWidth] (they are never magnified, but they do displace their
    // neighbours); everything is gap-separated. Distance is measured from the
    // *resting* grid even while items magnify — the standard, stable macOS
    // approximation.
    final padH = widget.gap + 2;
    final centers = <double>[];
    var cursor = padH;
    for (final item in widget.items) {
      final w = item.isSeparator ? _separatorWidth : widget.size;
      centers.add(cursor + w / 2);
      cursor += w + widget.gap;
    }

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < widget.items.length; i++) ...[
          if (i > 0) SizedBox(width: widget.gap),
          if (widget.items[i].isSeparator)
            _Separator(size: widget.size, color: colors.border)
          else
            KeyedSubtree(
              key: _itemKeys[i],
              child: _DockItemView(
                item: widget.items[i],
                size: widget.size,
                magnify: magnify,
                cursorX: _cursorX,
                center: centers[i],
                falloff: _falloff,
                maxScale: widget.maxScale,
                colors: colors,
              ),
            ),
        ],
      ],
    );

    // The pill lives behind the row in a shared Stack; one element glides
    // between active items (source: layoutId + SPRING_LAYOUT), rather than a
    // per-item highlight switching on/off.
    final stack = Stack(
      key: _stackKey,
      children: [
        if (_pillRect != null)
          Positioned.fill(
            child: IgnorePointer(
              child: _DockPill(
                rect: _pillRect!,
                color: colors.primary.withValues(alpha: 0.05), // bg-primary/5
                reduce: reduce,
              ),
            ),
          ),
        row,
      ],
    );

    // RepaintBoundary isolates the bar's animated repaints — the pill glide
    // and (with magnify) the per-frame magnification, both under the bar's
    // 28px-blur shadow — from the host page's layer. The shadow lives on the
    // outer DecoratedBox so the rounded clip (which bounds the backdrop blur)
    // doesn't crop it; the frosted fill, border and BackdropFilter sit inside.
    final bar = RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16), // rounded-2xl
          // `shadow-2xl` = `0 25px 50px -12px rgb(0 0 0 / 0.25)`. Tailwind's
          // shadow colour is black in both themes — tinting it with
          // `foreground` lit a white halo under the bar in dark mode, which
          // the source never shows.
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 50,
              spreadRadius: -12,
              offset: Offset(0, 25),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16), // rounded-2xl = 16px radius
          child: BackdropFilter(
            // backdrop-blur-xl = 24px CSS blur → sigma 24/2 = 12.
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: 4),
              decoration: BoxDecoration(
                color: colors.card.withValues(alpha: 0.8), // bg-card/80
                borderRadius: BorderRadius.circular(16), // rounded-2xl
                border: Border.all(color: colors.border),
              ),
              child: stack,
            ),
          ),
        ),
      ),
    );

    // No magnification → faithful static dock, no pointer tracking.
    if (!magnify) return bar;

    return MouseRegion(
      onHover: (e) => _cursorX.value = e.localPosition.dx,
      onExit: (_) => _cursorX.value = null,
      child: bar,
    );
  }
}

/// A single dock item — just the glyph (the active pill is drawn by the dock).
/// When [magnify] is on it is spring-scaled and lifted so the dock baseline
/// holds.
class _DockItemView extends StatelessWidget {
  const _DockItemView({
    required this.item,
    required this.size,
    required this.magnify,
    required this.cursorX,
    required this.center,
    required this.falloff,
    required this.maxScale,
    required this.colors,
  });

  final BeuiDockItem item;
  final double size;
  final bool magnify;

  /// Live cursor x in the bar's local space (null off-hover); each item
  /// listens to it itself so mousemove doesn't rebuild the whole bar.
  final ValueListenable<double?> cursorX;

  /// This item's resting horizontal centre in the bar's local space.
  final double center;

  /// Falloff width of the magnification (see [BeuiDock]).
  final double falloff;

  /// Peak magnification under the cursor (see [BeuiDock.maxScale]).
  final double maxScale;

  final BeuiColors colors;

  /// Target scale for this item given cursor [x] — the distance→scale mapping
  /// documented on [BeuiDock].
  double _scaleFor(double? x) {
    if (x == null) return 1;
    final d = (x - center).abs();
    final t = math.max(0.0, 1 - d / falloff);
    return 1 + (maxScale - 1) * t;
  }

  @override
  Widget build(BuildContext context) {
    final glyph =
        item.child ??
        Icon(item.icon, size: size * 0.46, color: colors.foreground);

    Widget content = SizedBox(
      width: size,
      height: size,
      child: Center(child: glyph),
    );

    if (item.tooltip != null) {
      content = Semantics(
        label: item.tooltip,
        button: item.onTap != null,
        child: content,
      );
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
    // (items-end) fixed, so items rise as they grow. The static glyph content
    // threads through the builders' child slots — only the sizing/transform
    // wrappers re-run per mousemove / spring frame.
    Widget slot(double scale, Widget child) => SizedBox(
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
            child: child,
          ),
        ),
      ),
    );

    return ValueListenableBuilder<double?>(
      valueListenable: cursorX,
      builder: (context, x, child) => SingleMotionBuilder(
        value: _scaleFor(x),
        motion: beuiSpringMouse,
        builder: (context, scale, child) => slot(scale, child!),
        child: child,
      ),
      child: content,
    );
  }
}

/// The single active pill that glides between items (source: `layoutId` +
/// `SPRING_LAYOUT`). Drawn behind the row, inset 2px from the active item with a
/// `rounded-xl` radius. Reduced motion snaps instead of gliding.
class _DockPill extends StatelessWidget {
  const _DockPill({
    required this.rect,
    required this.color,
    required this.reduce,
  });

  final Rect rect;
  final Color color;
  final bool reduce;

  Widget _place(Rect r, Widget box) {
    final w = math.max(0.0, r.width - 4); // inset-0.5 (2px each side)
    final h = math.max(0.0, r.height - 4);
    return Transform.translate(
      offset: Offset(r.left + 2, r.top + 2),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: w, height: h, child: box),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only the pill's placement/size animate; the decorated box itself is
    // static, so it threads through the MotionBuilder's child slot.
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12), // rounded-xl
      ),
    );
    if (reduce) return _place(rect, box);
    return MotionBuilder<Rect>(
      value: rect,
      motion: beuiSpringLayout,
      converter: const RectMotionConverter(),
      builder: (context, r, child) => _place(r, child!),
      child: box,
    );
  }
}

/// A vertical hairline divider — `h-6 w-px self-center bg-border`, rendered for
/// [BeuiDockItem.separator]. Sits in a full-height slot so it bottom-aligns with
/// the items, with the line itself vertically centred (the source's
/// `self-center`).
///
/// It is deliberately inert: no [MouseRegion], no scale builder and no gesture
/// or focus node, so it is skipped by magnification and by keyboard traversal;
/// [ExcludeSemantics] ports the source's `aria-hidden`, keeping it out of the
/// screen-reader order.
class _Separator extends StatelessWidget {
  const _Separator({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: size,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: (_separatorWidth - 1) / 2, // mx-1
          ),
          child: Center(
            child: SizedBox(
              width: 1,
              height: 24, // h-6 = 24px, fixed regardless of icon size
              child: ColoredBox(color: color),
            ),
          ),
        ),
      ),
    );
  }
}
