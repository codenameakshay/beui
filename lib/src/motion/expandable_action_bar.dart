import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// Size of a [BeuiExpandableActionBar] (source `ExpandableActionBarSize`).
enum BeuiExpandableActionBarSize {
  /// Compact (source `sm`).
  sm,

  /// Default (source `md`).
  md,
}

/// One action in a [BeuiExpandableActionBar] (source
/// `ExpandableActionBarItem`).
@immutable
class BeuiExpandableActionBarItem {
  /// Creates an action item. Provide [icon] or [customIcon].
  const BeuiExpandableActionBarItem({
    required this.id,
    required this.label,
    this.icon,
    this.customIcon,
    this.onPressed,
    this.disabled = false,
    this.active = false,
    this.badge,
    this.shortcut,
  }) : assert(
         icon != null || customIcon != null,
         'Provide an icon glyph or a custom icon widget.',
       );

  /// Stable identity.
  final String id;

  /// The label revealed on expansion.
  final String label;

  /// Leading glyph.
  final IconData? icon;

  /// Custom leading content (overrides [icon]).
  final Widget? customIcon;

  /// Invoked on tap.
  final VoidCallback? onPressed;

  /// Disables and dims the item.
  final bool disabled;

  /// Marks this item as the resting highlight.
  final bool active;

  /// Small trailing badge (pinned to the corner while collapsed).
  final Widget? badge;

  /// Keyboard hint shown after the label when expanded.
  final String? shortcut;
}

/// Item layout/highlight spring (source `ITEM_TRANSITION`, 460 · 34 · 0.62).
const _itemSpring = SpringMotion(
  SpringDescription(mass: 0.62, stiffness: 460, damping: 34),
);

/// Label unfurl spring (source `LABEL_TRANSITION`, 380 · 32 · 0.7).
const _labelSpring = SpringMotion(
  SpringDescription(mass: 0.7, stiffness: 380, damping: 32),
);

/// A pill rail of icon actions that unfurl labels on hover/focus, with a
/// highlight that glides between items — the Flutter port of beUI's
/// `ExpandableActionBar`.
///
/// `expanded` follows the controlled + uncontrolled convention. Hover
/// expansion runs on [MouseRegion] (never fires on touch); focus expansion
/// covers keyboard users. Reduced motion snaps the label widths and drops the
/// slide/blur and press scale.
class BeuiExpandableActionBar extends StatefulWidget {
  /// Creates an expandable action bar.
  const BeuiExpandableActionBar({
    required this.items,
    this.expanded,
    this.defaultExpanded = false,
    this.onExpandedChange,
    this.activeId,
    this.onAction,
    this.size = BeuiExpandableActionBarSize.md,
    this.expandOnHover = true,
    this.expandOnFocus = true,
    this.collapseDelay = const Duration(milliseconds: 90),
    super.key,
  });

  /// The actions.
  final List<BeuiExpandableActionBarItem> items;

  /// Controlled expansion; null for uncontrolled with [defaultExpanded].
  final bool? expanded;

  /// Initial expansion when uncontrolled.
  final bool defaultExpanded;

  /// Fires when the bar wants to expand/collapse.
  final ValueChanged<bool>? onExpandedChange;

  /// Highlighted item id (overrides per-item `active`).
  final String? activeId;

  /// Fires with the tapped item (after its own `onPressed`).
  final ValueChanged<BeuiExpandableActionBarItem>? onAction;

  /// Size preset.
  final BeuiExpandableActionBarSize size;

  /// Expand while a pointer hovers the rail (source `expandOnHover`).
  final bool expandOnHover;

  /// Expand while focus is inside the rail (source `expandOnFocus`).
  final bool expandOnFocus;

  /// Grace period before collapsing after the pointer leaves (source
  /// `collapseDelay = 90`).
  final Duration collapseDelay;

  @override
  State<BeuiExpandableActionBar> createState() =>
      _BeuiExpandableActionBarState();
}

class _Metrics {
  const _Metrics({
    required this.trackPad,
    required this.gap,
    required this.itemHeight,
    required this.itemPad,
    required this.iconSize,
    required this.fontSize,
  });

  final double trackPad;
  final double gap;
  final double itemHeight;
  final double itemPad;
  final double iconSize;
  final double fontSize;
}

// sm: min-h-9 gap-1 p-1 text-xs, item h-7 min-w-7 px-1.5, icon 14.
// md: min-h-11 gap-1.5 p-1.5 text-sm, item h-8 min-w-8 px-2, icon 16.
const _metrics = {
  BeuiExpandableActionBarSize.sm: _Metrics(
    trackPad: 4,
    gap: 4,
    itemHeight: 28,
    itemPad: 6,
    iconSize: 14,
    fontSize: 12,
  ),
  BeuiExpandableActionBarSize.md: _Metrics(
    trackPad: 6,
    gap: 6,
    itemHeight: 32,
    itemPad: 8,
    iconSize: 16,
    fontSize: 14,
  ),
};

class _BeuiExpandableActionBarState extends State<BeuiExpandableActionBar> {
  late bool _internalExpanded = widget.defaultExpanded;
  String? _hoveredId;
  Timer? _collapseTimer;
  final Map<String, GlobalKey> _itemKeys = {};
  final GlobalKey _trackKey = GlobalKey();
  Rect? _highlightRect;

  bool get _expanded => widget.expanded ?? _internalExpanded;

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  void _setExpanded(bool value) {
    if (widget.expanded == null) setState(() => _internalExpanded = value);
    widget.onExpandedChange?.call(value);
  }

  void _open() {
    _collapseTimer?.cancel();
    _collapseTimer = null;
    _setExpanded(true);
  }

  /// Collapse after a grace period so a pointer skimming the gap between
  /// items doesn't flap the rail (source `collapseDelay`).
  void _close() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(widget.collapseDelay, () {
      _collapseTimer = null;
      if (!mounted) return;
      _setExpanded(false);
      setState(() => _hoveredId = null);
    });
  }

  String? get _highlightId {
    final active =
        widget.activeId ?? widget.items.where((i) => i.active).firstOrNull?.id;
    return _hoveredId ?? active;
  }

  void _scheduleHighlightMeasure() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final id = _highlightId;
      final itemBox =
          _itemKeys[id]?.currentContext?.findRenderObject() as RenderBox?;
      final trackBox =
          _trackKey.currentContext?.findRenderObject() as RenderBox?;
      if (id == null || itemBox == null || trackBox == null) {
        if (_highlightRect != null) setState(() => _highlightRect = null);
        return;
      }
      final rect =
          itemBox.localToGlobal(Offset.zero, ancestor: trackBox) & itemBox.size;
      if (rect != _highlightRect) setState(() => _highlightRect = rect);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final m = _metrics[widget.size]!;
    _scheduleHighlightMeasure();

    // Prune anchors for items that are gone so a long-lived bar does not leak
    // a GlobalKey per item ever configured.
    final liveIds = {for (final item in widget.items) item.id};
    _itemKeys.removeWhere((id, _) => !liveIds.contains(id));

    final track = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: beuiBlurSigma(24), // backdrop-blur-xl
          sigmaY: beuiBlurSigma(24),
        ),
        child: Container(
          padding: EdgeInsets.all(m.trackPad),
          decoration: BoxDecoration(
            color: colors.card.withValues(alpha: 0.9),
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              // shadow-2xl
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 50,
                offset: Offset(0, 25),
                spreadRadius: -12,
              ),
            ],
          ),
          child: NotificationListener<SizeChangedLayoutNotification>(
            onNotification: (_) {
              _scheduleHighlightMeasure();
              return true;
            },
            child: Stack(
              key: _trackKey,
              children: [
                if (_highlightRect != null)
                  MotionBuilder<Rect>(
                    value: _highlightRect!,
                    motion: reduce ? const NoMotion() : _itemSpring,
                    converter: const RectMotionConverter(),
                    builder: (context, rect, _) {
                      final r = reduce ? _highlightRect! : rect;
                      return Positioned(
                        left: r.left,
                        top: r.top,
                        width: r.width,
                        height: r.height,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      );
                    },
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: m.gap,
                  children: [
                    for (final item in widget.items)
                      SizeChangedLayoutNotifier(
                        child: _BarItem(
                          key: _itemKeys.putIfAbsent(item.id, GlobalKey.new),
                          item: item,
                          metrics: m,
                          expanded: _expanded,
                          highlighted: _highlightId == item.id,
                          reduce: reduce,
                          colors: colors,
                          onHover: () {
                            _collapseTimer?.cancel();
                            _collapseTimer = null;
                            setState(() => _hoveredId = item.id);
                            _scheduleHighlightMeasure();
                          },
                          onAction: () {
                            item.onPressed?.call();
                            widget.onAction?.call(item);
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (!widget.expandOnFocus) return;
        if (focused) {
          _open();
        } else {
          _close();
        }
      },
      child: MouseRegion(
        onEnter: (_) {
          if (widget.expandOnHover) _open();
        },
        onExit: (_) {
          setState(() => _hoveredId = null);
          if (widget.expandOnHover) _close();
        },
        child: track,
      ),
    );
  }
}

class _BarItem extends StatefulWidget {
  const _BarItem({
    required this.item,
    required this.metrics,
    required this.expanded,
    required this.highlighted,
    required this.reduce,
    required this.colors,
    required this.onHover,
    required this.onAction,
    super.key,
  });

  final BeuiExpandableActionBarItem item;
  final _Metrics metrics;
  final bool expanded;
  final bool highlighted;
  final bool reduce;
  final BeuiColors colors;
  final VoidCallback onHover;
  final VoidCallback onAction;

  @override
  State<_BarItem> createState() => _BarItemState();
}

class _BarItemState extends State<_BarItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final m = widget.metrics;
    final colors = widget.colors;
    final reduce = widget.reduce;
    final color = widget.highlighted
        ? colors.foreground
        : colors.mutedForeground;

    final icon = SizedBox(
      width: m.iconSize,
      height: m.iconSize,
      child: item.customIcon ?? Icon(item.icon, size: m.iconSize, color: color),
    );

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        _Unfurl(
          expanded: widget.expanded,
          reduce: reduce,
          leadGap: 8, // marginLeft: 8
          slide: true,
          child: Text(
            item.label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: m.fontSize,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
        if (item.shortcut != null)
          _Unfurl(
            expanded: widget.expanded,
            reduce: reduce,
            leadGap: 4,
            child: Text(
              item.shortcut!,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(fontSize: 10, color: colors.mutedForeground),
            ),
          ),
        if (item.badge != null && widget.expanded)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: _Badge(colors: colors, child: item.badge!),
          ),
      ],
    );

    content = Container(
      height: m.itemHeight,
      constraints: BoxConstraints(minWidth: m.itemHeight),
      padding: EdgeInsets.symmetric(horizontal: m.itemPad),
      alignment: Alignment.center,
      child: content,
    );

    // Collapsed badge pins to the top-right corner (source absolute).
    if (item.badge != null && !widget.expanded) {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          Positioned(
            top: 2,
            right: 2,
            child: _Badge(colors: colors, child: item.badge!),
          ),
        ],
      );
    }

    Widget body = SingleMotionBuilder(
      value: _pressed && !reduce && !item.disabled ? 0.96 : 1.0,
      motion: _itemSpring,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: content,
    );

    if (item.disabled) {
      body = Opacity(opacity: 0.4, child: body);
    }

    return Semantics(
      button: true,
      enabled: !item.disabled,
      label: item.label,
      child: MouseRegion(
        cursor: item.disabled
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => widget.onHover(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: item.disabled
              ? null
              : (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: item.disabled ? null : widget.onAction,
          child: body,
        ),
      ),
    );
  }
}

/// Label/shortcut unfurl: width 0→natural on the label spring, sliding in
/// from -4px with a 3px blur (source label `animate`). Reduced motion snaps
/// the width and keeps only the fade.
class _Unfurl extends StatelessWidget {
  const _Unfurl({
    required this.expanded,
    required this.reduce,
    required this.leadGap,
    required this.child,
    this.slide = false,
  });

  final bool expanded;
  final bool reduce;
  final double leadGap;
  final bool slide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      value: expanded ? 1.0 : 0.0,
      motion: _labelSpring,
      active: !reduce, // reduced motion: snap (source duration 0)
      builder: (context, raw, inner) {
        final t = raw.clamp(0.0, 1.0);
        if (t <= 0.001) return const SizedBox.shrink();
        Widget body = Opacity(opacity: t, child: inner);
        if (!reduce && slide) {
          final sigma = (1 - t) * 1.5; // blur(3px) ≈ σ1.5
          if (sigma > 0.05) {
            body = ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.decal,
              ),
              child: body,
            );
          }
          body = Transform.translate(
            offset: Offset(-4 * (1 - t), 0),
            child: body,
          );
        }
        return ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: math.max(0.0, raw),
            child: Padding(
              padding: EdgeInsets.only(left: leadGap),
              child: body,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.colors, required this.child});

  final BeuiColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16, // h-4
      constraints: const BoxConstraints(minWidth: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.destructive,
        borderRadius: BorderRadius.circular(999),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontSize: 10,
          height: 1,
          color: colors.primaryForeground,
        ),
        child: child,
      ),
    );
  }
}
