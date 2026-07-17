import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart' show SingleMotionBuilder;

/// One entry in a [BeuiPreviewRail].
///
/// The source's `PreviewRailItem` carries web-navigation fields (`href`,
/// `target`, `rel`) that have no Flutter analog — the port drops them and
/// surfaces selection through [BeuiPreviewRail.onActiveChange] instead. What
/// remains is the identity ([id]), the accessible [label], and an optional
/// [description] shown in the default preview card.
@immutable
class BeuiPreviewRailItem {
  /// Creates a rail item.
  const BeuiPreviewRailItem({
    required this.id,
    required this.label,
    this.description,
  });

  /// Stable identity used for selection and the shared-layout glide key.
  final String id;

  /// Accessible label; also the default preview card's title.
  final String label;

  /// Optional supporting copy rendered under [label] in the default preview.
  /// Ignored when a custom `renderPreview` is supplied.
  final Widget? description;
}

/// Layout axis of a [BeuiPreviewRail].
enum BeuiPreviewRailOrientation {
  /// Ticks stack top-to-bottom; the preview card sits to the right and glides
  /// vertically (source default).
  vertical,

  /// Ticks sit left-to-right along the bottom; the preview card floats above and
  /// glides horizontally.
  horizontal,
}

/// Optional visual overrides for [BeuiPreviewRail]. Null fields resolve from the
/// ambient [BeuiColors] theme extension (or sensible defaults). Mirrors the
/// source's `railClassName` / `previewClassName` slots with typed fields.
@immutable
class BeuiPreviewRailStyle {
  /// Creates a set of overrides.
  const BeuiPreviewRailStyle({
    this.activeTickColor,
    this.inactiveTickColor,
    this.tickLength,
    this.tickThickness,
    this.trackExtent,
  });

  /// Colour of the highlighted (nearest) tick. Defaults to `BeuiColors.foreground`.
  final Color? activeTickColor;

  /// Colour of the other ticks. Defaults to `BeuiColors.mutedForeground`.
  final Color? inactiveTickColor;

  /// Long axis of a tick line (source `w-12`/`h-12` → 48).
  final double? tickLength;

  /// Short axis / thickness of a tick line (source `h-0.5`/`w-0.5` → 2).
  final double? tickThickness;

  /// Spacing track per item (source `1.25rem` → 20).
  final double? trackExtent;

  /// Returns a copy with the given fields replaced.
  BeuiPreviewRailStyle copyWith({
    Color? activeTickColor,
    Color? inactiveTickColor,
    double? tickLength,
    double? tickThickness,
    double? trackExtent,
  }) {
    return BeuiPreviewRailStyle(
      activeTickColor: activeTickColor ?? this.activeTickColor,
      inactiveTickColor: inactiveTickColor ?? this.inactiveTickColor,
      tickLength: tickLength ?? this.tickLength,
      tickThickness: tickThickness ?? this.tickThickness,
      trackExtent: trackExtent ?? this.trackExtent,
    );
  }
}

/// An equalizer-style navigation rail whose tick nearest the pointer magnifies
/// and whose preview card glides to track it — the Flutter port of beUI's
/// `preview-rail`.
///
/// Each item renders as a short tick line. The item under the pointer (hover) or
/// keyboard focus is the *displayed* item; its tick scales to `1` while
/// neighbours ease down by distance (`1 → 0.68 → 0.44 → 0.25`), and with nothing
/// displayed every tick rests at `0.25`. Both the per-tick scale and the preview
/// card's position ride the source's **`SPRING_LAYOUT`** (stiffness 360 · damping
/// 32 · mass 0.6, [beuiSpringLayout]) — the tick scales spring, and the single
/// preview card physically glides along the rail from one item's row/column to
/// the next (the source's `layoutId` shared-layout). Inside the card the content
/// cross-fades on each change: opacity + a 4px rise + a σ3 → 0 unblur over 180ms
/// `EASE_OUT` (exit quicker at 120ms), mirroring the source's `AnimatePresence`.
///
/// Selection is decorative-free in the source — it drives only `aria-current`, not
/// the tick visuals — so this port keeps the highlight purely hover/focus-driven
/// and exposes selection through [activeId]/[onActiveChange] for parity.
///
/// **Controlled + uncontrolled**, following the source: pass [activeId] +
/// [onActiveChange] to control the selection, or omit [activeId] and seed with
/// [defaultActiveId] for internal state.
///
/// Hover is wired on `MouseRegion`, so it never fires on touch (the source's
/// `useHoverCapable()` gate). Reduced motion drops *movement* — tick scales and
/// the card position snap to their targets (the source's `duration: 0` branch)
/// and the content swap fades opacity-only.
class BeuiPreviewRail extends StatefulWidget {
  /// Creates a preview rail from [items].
  const BeuiPreviewRail({
    required this.items,
    this.orientation = BeuiPreviewRailOrientation.vertical,
    this.activeId,
    this.defaultActiveId,
    this.onActiveChange,
    this.renderPreview,
    this.style,
    super.key,
  });

  /// The rail entries, in order.
  final List<BeuiPreviewRailItem> items;

  /// Layout axis. Defaults to [BeuiPreviewRailOrientation.vertical].
  final BeuiPreviewRailOrientation orientation;

  /// Controlled selected id. When null the rail manages its own selection
  /// (seeded from [defaultActiveId], then the first item).
  final String? activeId;

  /// Initial selection for the uncontrolled case.
  final String? defaultActiveId;

  /// Called with the id when an item is activated (tap/enter).
  final ValueChanged<String>? onActiveChange;

  /// Builds the preview card body for [item]. When null a default card (label +
  /// description) is used.
  final Widget Function(BeuiPreviewRailItem item)? renderPreview;

  /// Optional visual overrides.
  final BeuiPreviewRailStyle? style;

  @override
  State<BeuiPreviewRail> createState() => _BeuiPreviewRailState();
}

class _BeuiPreviewRailState extends State<BeuiPreviewRail> {
  String? _internalActiveId;
  String? _hoveredId;
  String? _focusedId;

  // The card holds its last-displayed position/content while it fades out, so
  // leaving the rail doesn't snap the card to the top before it disappears.
  int _lastDisplayedIndex = 0;
  BeuiPreviewRailItem? _lastDisplayedItem;

  @override
  void initState() {
    super.initState();
    _internalActiveId =
        widget.defaultActiveId ??
        (widget.items.isNotEmpty ? widget.items.first.id : '');
  }

  String get _selectedId {
    final requested = widget.activeId ?? _internalActiveId;
    final hasIt = widget.items.any((i) => i.id == requested);
    if (hasIt) return requested!;
    return widget.items.isNotEmpty ? widget.items.first.id : '';
  }

  String? get _displayedId => _hoveredId ?? _focusedId;

  void _select(String id) {
    if (widget.activeId == null) setState(() => _internalActiveId = id);
    widget.onActiveChange?.call(id);
  }

  void _setHovered(String? id) {
    if (_hoveredId != id) setState(() => _hoveredId = id);
  }

  void _setFocused(String? id) {
    if (_focusedId != id) setState(() => _focusedId = id);
  }

  // ---- geometry -----------------------------------------------------------

  double get _track => widget.style?.trackExtent ?? 20.0;
  double get _tickLength => widget.style?.tickLength ?? 48.0;
  double get _tickThickness => widget.style?.tickThickness ?? 2.0;

  bool get _isHorizontal =>
      widget.orientation == BeuiPreviewRailOrientation.horizontal;

  /// Per-tick target scale by distance from the displayed item. Mirrors the
  /// source: displayed → 1, |Δ|1 → 0.68, |Δ|2 → 0.44, else → 0.25; and with
  /// nothing displayed (index < 0) every tick rests at 0.25.
  double _scaleFor(int index, int displayedIndex) {
    if (displayedIndex < 0) return 0.25;
    final distance = (index - displayedIndex).abs();
    if (distance == 0) return 1.0;
    if (distance == 1) return 0.68;
    if (distance == 2) return 0.44;
    return 0.25;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();

    final displayedId = _displayedId;
    final displayedIndex = displayedId == null
        ? -1
        : items.indexWhere((i) => i.id == displayedId);
    final displayed = displayedIndex >= 0;
    if (displayed) {
      _lastDisplayedIndex = displayedIndex;
      _lastDisplayedItem = items[displayedIndex];
    }
    final n = items.length;
    final centre = (n - 1) / 2.0;
    // Position target the card glides toward: the live displayed index, or the
    // held index while fading out.
    final positionTarget =
        (displayed ? displayedIndex : _lastDisplayedIndex).toDouble();

    final activeTick = widget.style?.activeTickColor ?? colors.foreground;
    final inactiveTick =
        widget.style?.inactiveTickColor ?? colors.mutedForeground;
    final selectedId = _selectedId;

    // ---- rail -------------------------------------------------------------

    final ticks = <Widget>[
      for (var i = 0; i < n; i++)
        _RailTick(
          key: ValueKey('tick-${items[i].id}'),
          item: items[i],
          isHorizontal: _isHorizontal,
          reduce: reduce,
          selected: items[i].id == selectedId,
          highlighted: i == displayedIndex,
          scale: _scaleFor(i, displayedIndex),
          length: _tickLength,
          thickness: _tickThickness,
          track: _track,
          activeColor: activeTick,
          inactiveColor: inactiveTick,
          onHover: (hover) => _setHovered(hover ? items[i].id : null),
          onFocus: (focus) => _setFocused(focus ? items[i].id : null),
          onTap: () => _select(items[i].id),
        ),
    ];

    final rail = _isHorizontal
        ? Row(mainAxisSize: MainAxisSize.min, children: ticks)
        : Column(mainAxisSize: MainAxisSize.min, children: ticks);

    // Clear hover when the pointer leaves the whole rail (source's
    // `onPointerLeave` on the <nav>).
    final railRegion = MouseRegion(
      onExit: (_) => _setHovered(null),
      child: rail,
    );

    // ---- preview card -----------------------------------------------------

    final cardItem = displayed ? items[displayedIndex] : _lastDisplayedItem;
    final card = _PreviewCard(
      item: cardItem,
      isHorizontal: _isHorizontal,
      reduce: reduce,
      colors: colors,
      renderPreview: widget.renderPreview,
    );

    // The card translates along the rail axis to the active track. Distance in
    // pixels from the rail centre is `(pos - centre) * track`.
    Widget positionedCard(Widget glideChild) => AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      curve: beuiEaseOut,
      opacity: displayed ? 1.0 : 0.0,
      child: IgnorePointer(child: glideChild),
    );

    Widget glide(double pos) {
      final delta = (pos - centre) * _track;
      final offset = _isHorizontal ? Offset(delta, 0) : Offset(0, delta);
      return Transform.translate(offset: offset, child: card);
    }

    // Position snaps under reduced motion (source `duration: 0`); otherwise it
    // springs along SPRING_LAYOUT — the source's `layoutId` shared-layout glide.
    final glidingCard = reduce
        ? positionedCard(glide(positionTarget))
        : SingleMotionBuilder(
            value: positionTarget,
            from: positionTarget,
            motion: beuiSpringLayout,
            builder: (context, pos, _) => positionedCard(glide(pos)),
          );

    if (_isHorizontal) {
      // Card floats above a bottom-aligned rail; only x glides.
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 132,
            width: n * _track,
            child: OverflowBox(
              maxWidth: double.infinity,
              alignment: Alignment.bottomCenter,
              child: Align(alignment: Alignment.bottomCenter, child: glidingCard),
            ),
          ),
          const SizedBox(height: 12),
          railRegion,
        ],
      );
    }

    // Vertical: rail on the left (48 wide), card to the right; only y glides.
    return SizedBox(
      height: n * _track,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          railRegion,
          const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 384),
                child: glidingCard,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single interactive tick: a short line that springs its scale toward the
/// magnitude set by its distance from the displayed item.
class _RailTick extends StatelessWidget {
  const _RailTick({
    required this.item,
    required this.isHorizontal,
    required this.reduce,
    required this.selected,
    required this.highlighted,
    required this.scale,
    required this.length,
    required this.thickness,
    required this.track,
    required this.activeColor,
    required this.inactiveColor,
    required this.onHover,
    required this.onFocus,
    required this.onTap,
    super.key,
  });

  final BeuiPreviewRailItem item;
  final bool isHorizontal;
  final bool reduce;
  final bool selected;
  final bool highlighted;
  final double scale;
  final double length;
  final double thickness;
  final double track;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<bool> onHover;
  final ValueChanged<bool> onFocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Cell: vertical → track tall, length wide; horizontal → length tall, track
    // wide (source `h-5 w-12` / `h-12 w-5`).
    final cellWidth = isHorizontal ? track : length;
    final cellHeight = isHorizontal ? length : track;

    // The line itself, aligned to its scale origin (vertical origin-left,
    // horizontal origin-bottom).
    final line = Container(
      width: isHorizontal ? thickness : length,
      height: isHorizontal ? length : thickness,
      color: highlighted ? activeColor : inactiveColor,
    );
    final origin = isHorizontal ? Alignment.bottomCenter : Alignment.centerLeft;
    final align = Align(alignment: origin, child: line);

    Widget scaled(double value) => Transform(
      alignment: origin,
      transform: Matrix4.diagonal3Values(
        isHorizontal ? 1.0 : value,
        isHorizontal ? value : 1.0,
        1.0,
      ),
      child: align,
    );

    // Snap under reduced motion; otherwise spring the scale on SPRING_LAYOUT.
    final animatedLine = reduce
        ? scaled(scale)
        : SingleMotionBuilder(
            value: scale,
            motion: beuiSpringLayout,
            builder: (context, value, _) => scaled(value),
          );

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: MouseRegion(
        onEnter: (_) => onHover(true),
        cursor: SystemMouseCursors.click,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                onTap();
                return null;
              },
            ),
          },
          onShowFocusHighlight: onFocus,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(
              width: cellWidth,
              height: cellHeight,
              child: animatedLine,
            ),
          ),
        ),
      ),
    );
  }
}

/// The preview surface whose content cross-fades (opacity + 4px rise + σ3 unblur,
/// 180ms `EASE_OUT`; 120ms exit) when the displayed item changes — the source's
/// keyed `AnimatePresence`. Opacity-only under [reduce].
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.item,
    required this.isHorizontal,
    required this.reduce,
    required this.colors,
    required this.renderPreview,
  });

  final BeuiPreviewRailItem? item;
  final bool isHorizontal;
  final bool reduce;
  final BeuiColors colors;
  final Widget Function(BeuiPreviewRailItem item)? renderPreview;

  @override
  Widget build(BuildContext context) {
    final current = item;
    final body = current == null
        ? const SizedBox.shrink()
        : KeyedSubtree(
            key: ValueKey(current.id),
            child: renderPreview?.call(current) ?? _defaultPreview(current),
          );

    final width = isHorizontal ? 288.0 : double.infinity;
    return SizedBox(
      width: isHorizontal ? width : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        reverseDuration: const Duration(milliseconds: 120),
        switchInCurve: beuiEaseOut,
        switchOutCurve: beuiEaseOut,
        transitionBuilder: (child, animation) {
          if (reduce) return FadeTransition(opacity: animation, child: child);
          return FadeTransition(
            opacity: animation,
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, inner) {
                final t = animation.value;
                final blur = 3.0 * (1 - t);
                // Enter: y 4 → 0 (source `y: 4 → 0`, blur(6px) → 0 mapped to σ3).
                Widget out = Transform.translate(
                  offset: Offset(0, 4 * (1 - t)),
                  child: inner,
                );
                if (blur > 0.05) {
                  out = ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: blur,
                      sigmaY: blur,
                      tileMode: TileMode.decal,
                    ),
                    child: out,
                  );
                }
                return out;
              },
              child: child,
            ),
          );
        },
        child: body,
      ),
    );
  }

  Widget _defaultPreview(BeuiPreviewRailItem item) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16), // rounded-2xl
        border: Border.all(color: colors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colors.cardForeground,
              ),
            ),
            if (item.description != null) ...[
              const SizedBox(height: 4),
              DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: colors.mutedForeground,
                ),
                child: item.description!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
