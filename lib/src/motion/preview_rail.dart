import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
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

/// Which side of the rail the floating preview pops out on
/// (source `previewSide`).
enum BeuiPreviewRailPreviewSide {
  /// The preview floats on the leading side of the rail, and the rail itself
  /// moves to the trailing edge — the mirror image of [after].
  ///
  /// The source expresses this with mirrored insets (`right-16 left-4` plus
  /// `ml-auto` on the card), which only reads correctly once the consumer has
  /// flipped the rail to the trailing edge with `className`. Class-name
  /// overriding is [intentionally not ported](https://beui.dev), so the widget
  /// owns the flip: choosing [before] both moves the rail and mirrors the
  /// preview, giving the same rendering in one prop.
  before,

  /// The preview floats on the trailing side of the rail, hugging it — the
  /// source default (`right-4 left-16`).
  after,
}

/// The gap held open between adjacent tick cells, in logical pixels.
///
/// Cells used to abut at 0px, so sweeping a pointer across the rail crossed
/// from one hover region straight into the next and re-fired the whole spring
/// cascade on every row it passed — continuously, for the length of the sweep.
/// A 2px dead zone between cells breaks that without moving a single tick: the
/// pitch is still `itemSize`, the line is still centred in its slot.
const double _tickGap = 2;

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
    this.itemSize,
    @Deprecated(
      'Renamed to itemSize, matching the source prop. Will be removed in the '
      'next major; itemSize already wins when both are set.',
    )
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

  /// Extent of one item's slot along the rail axis — the source's `itemSize`
  /// (its grid track, `repeat(n, itemSize)`, and each item's own height/width).
  ///
  /// **Why it lives on the style, not on [BeuiPreviewRail].** The source keeps
  /// `itemSize` as a top-level prop because its sibling geometry (tick length,
  /// tick thickness) is spelled in Tailwind classes rather than props. The port
  /// has no class names: it collects that geometry into this one class, so
  /// [tickLength], [tickThickness] and `itemSize` are the same *kind* of knob
  /// and belong together. Putting `itemSize` on the widget would split the
  /// rail's geometry across two places, and — because it is the same quantity
  /// as the pre-existing [trackExtent] — would give one value two homes.
  ///
  /// Resolves to 24 when null, matching the source's own `itemSize = 24`
  /// default (`h-6`). Read it through [resolvedItemSize], which also applies
  /// the deprecated [trackExtent] fallback.
  final double? itemSize;

  /// Spacing track per item.
  ///
  /// Superseded by [itemSize], which is the same quantity under the source's
  /// own name. When both are set [itemSize] wins.
  @Deprecated(
    'Renamed to itemSize, matching the source prop. Will be removed in the '
    'next major; itemSize already wins when both are set.',
  )
  final double? trackExtent;

  /// The slot extent actually used: [itemSize], else the deprecated
  /// [trackExtent], else the source default of 24.
  ///
  /// The one place the alias is resolved, so the precedence rule cannot drift
  /// between the widget and its tests.
  double get resolvedItemSize =>
      itemSize ??
      // ignore: deprecated_member_use_from_same_package
      trackExtent ??
      24.0;

  /// Returns a copy with the given fields replaced.
  ///
  /// Setting [itemSize] also drops any inherited [trackExtent], so a caller can
  /// migrate off the alias without the old value silently surviving in a copy.
  BeuiPreviewRailStyle copyWith({
    Color? activeTickColor,
    Color? inactiveTickColor,
    double? tickLength,
    double? tickThickness,
    double? itemSize,
    @Deprecated('Renamed to itemSize, matching the source prop.')
    double? trackExtent,
  }) {
    return BeuiPreviewRailStyle(
      activeTickColor: activeTickColor ?? this.activeTickColor,
      inactiveTickColor: inactiveTickColor ?? this.inactiveTickColor,
      tickLength: tickLength ?? this.tickLength,
      tickThickness: tickThickness ?? this.tickThickness,
      itemSize: itemSize ?? this.itemSize,
      // ignore: deprecated_member_use_from_same_package
      trackExtent: itemSize != null ? null : (trackExtent ?? this.trackExtent),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeuiPreviewRailStyle &&
        other.activeTickColor == activeTickColor &&
        other.inactiveTickColor == inactiveTickColor &&
        other.tickLength == tickLength &&
        other.tickThickness == tickThickness &&
        other.resolvedItemSize == resolvedItemSize;
  }

  @override
  int get hashCode => Object.hash(
    activeTickColor,
    inactiveTickColor,
    tickLength,
    tickThickness,
    resolvedItemSize,
  );
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
/// ## Touch
///
/// Hover is a mouse concept, so on a touch device the rail used to be a strip of
/// anonymous dashes that navigated somewhere the user had no way to identify
/// *before committing*. On a non-hover-capable pointer the rail is therefore a
/// two-step control: the first tap on a tick reveals its preview card, and a
/// second tap on the *same* tick commits. Tapping a different tick previews that
/// one instead. Nothing changes on a mouse, trackpad, or keyboard — one tap
/// still commits, because the preview is already visible on hover.
///
/// With [showPreview] false there is nothing to preview, so touch commits on the
/// first tap like every other pointer.
///
/// ## Selection
///
/// Selection drives `aria-current` only in the source, but a navigation rail
/// whose current location is invisible is a navigation rail you cannot orient
/// in — so [highlightActive] defaults to **true** here, anchoring the resting
/// pyramid on the selected tick. Pass `false` for the source's decorative-free
/// rest state.
///
/// The preview can be dropped entirely with [showPreview], and floats on either
/// side of the rail via [previewSide]. [label] names the rail for assistive
/// technology.
///
/// **Controlled + uncontrolled**, following the source: pass [activeId] +
/// [onActiveChange] to control the selection, or omit [activeId] and seed with
/// [defaultActiveId] for internal state.
///
/// Reduced motion drops *movement* — tick scales and the card position snap to
/// their targets (the source's `duration: 0` branch) and the content swap fades
/// opacity-only.
class BeuiPreviewRail extends StatefulWidget {
  /// Creates a preview rail from [items].
  const BeuiPreviewRail({
    required this.items,
    this.label = 'Section navigation',
    this.orientation = BeuiPreviewRailOrientation.vertical,
    this.activeId,
    this.defaultActiveId,
    this.onActiveChange,
    this.onItemSelect,
    this.renderPreview,
    this.showPreview = true,
    this.previewSide = BeuiPreviewRailPreviewSide.after,
    this.highlightActive = true,
    this.style,
    this.child,
    super.key,
  });

  /// The rail entries, in order.
  final List<BeuiPreviewRailItem> items;

  /// Accessible name for the rail as a whole — the source's `aria-label` on its
  /// `<nav>` (default `"Section navigation"`).
  ///
  /// Applied as a labelled `Semantics` container around the ticks, so a screen
  /// reader announces the group before its items. The ticks keep their own
  /// labels ([BeuiPreviewRailItem.label]); this one names the group.
  final String label;

  /// Layout axis. Defaults to [BeuiPreviewRailOrientation.vertical].
  final BeuiPreviewRailOrientation orientation;

  /// Controlled selected id. When null the rail manages its own selection
  /// (seeded from [defaultActiveId], then the first item).
  final String? activeId;

  /// Initial selection for the uncontrolled case.
  ///
  /// Changing it later re-seeds the uncontrolled selection, so a parent that
  /// swaps its dataset does not end up with a rail pointing at a row that no
  /// longer exists.
  final String? defaultActiveId;

  /// Called with the id when an item is activated (tap/enter).
  ///
  /// Fires before [onItemSelect] on every activation, and is the callback half
  /// of the controlled [activeId] pair — a controlled rail is expected to route
  /// this back into [activeId].
  ///
  /// Also fires when the rail has to *fall back*: if the requested selection is
  /// not in [items] the rail selects the first item, and says so, instead of
  /// leaving the parent believing a stale id is still current.
  final ValueChanged<String>? onActiveChange;

  /// Called with the whole item when an item is activated (tap/enter).
  ///
  /// Distinct from [onActiveChange]: that one reports the *selection change* and
  /// is what a controlled parent echoes back into [activeId], while this one is
  /// the plain "the user picked this entry" side effect (the source fires it
  /// where the item's `href` navigation would happen). Both fire on every
  /// activation, [onActiveChange] first — including re-activating the already
  /// selected item.
  final ValueChanged<BeuiPreviewRailItem>? onItemSelect;

  /// Builds the preview card body for `item`. When null a default card (label +
  /// description) is used.
  ///
  /// **The returned subtree is not interactive.** The card is the source's
  /// `pointer-events-none` overlay — it floats over the rail's content region
  /// and must not swallow pointers aimed at what is underneath — so the rail
  /// wraps it in an [IgnorePointer]. Buttons, links, and scroll views inside a
  /// preview will render but never receive input; put those in the rail's
  /// [child] region instead.
  final Widget Function(BeuiPreviewRailItem item)? renderPreview;

  /// Whether the floating preview is rendered at all (source `showPreview`,
  /// default true).
  ///
  /// False leaves a bare rail: the ticks still form their hover pyramid, and
  /// the space the card would occupy is not reserved. [renderPreview] and
  /// [previewSide] are then unused, and touch activation collapses back to one
  /// tap because there is no preview step to take.
  final bool showPreview;

  /// Which side of the rail the preview floats on (source `previewSide`,
  /// default [BeuiPreviewRailPreviewSide.after]).
  ///
  /// Vertical orientation only — the horizontal rail always floats its card
  /// above the ticks, as the source does. Direction-aware: "before" is the
  /// leading side, so it flips under RTL.
  final BeuiPreviewRailPreviewSide previewSide;

  /// Whether the selected item stays highlighted while nothing is hovered or
  /// focused (source `highlightActive`).
  ///
  /// **Defaults to true**, which the source does not. At rest with this off,
  /// every tick sits at the 0.25 resting scale and the rail is four identical
  /// grey dashes with no indication of where you are — a "you are here" mark is
  /// not decoration on a navigation control. Pass false to restore the source's
  /// purely pointer/keyboard-driven highlight.
  ///
  /// It never summons the preview card — that stays bound to hover, focus, and
  /// the touch preview step.
  final bool highlightActive;

  /// Optional visual overrides.
  final BeuiPreviewRailStyle? style;

  /// Arbitrary content rendered in the preview's `min-h-0 flex-1` region — the
  /// Flutter analog of the source `PreviewRail`'s `children` slot (a single
  /// content region, not a per-item field). Optional and backward-compatible:
  /// when null the rail lays out exactly as before. In the vertical orientation
  /// it fills the area to the right of the rail and the preview card floats over
  /// it (the source's absolute, pointer-events-none overlay); in the horizontal
  /// orientation it sits below the rail.
  final Widget? child;

  @override
  State<BeuiPreviewRail> createState() => _BeuiPreviewRailState();
}

class _BeuiPreviewRailState extends State<BeuiPreviewRail> {
  String? _internalActiveId;
  String? _hoveredId;
  String? _focusedId;

  /// The tick a touch user has previewed but not yet committed to.
  String? _touchPreviewId;

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
    _reportFallbackIfNeeded();
  }

  @override
  void didUpdateWidget(BeuiPreviewRail old) {
    super.didUpdateWidget(old);
    // Re-seed the uncontrolled selection when the caller changes the seed.
    // Without this, `defaultActiveId` was read exactly once in initState and a
    // parent swapping datasets kept a selection from the previous one.
    if (widget.activeId == null &&
        widget.defaultActiveId != old.defaultActiveId &&
        widget.defaultActiveId != null) {
      _internalActiveId = widget.defaultActiveId;
    }
    if (widget.items != old.items || widget.activeId != old.activeId) {
      _reportFallbackIfNeeded();
    }
  }

  /// Tells the parent when the rail had to pick something other than what was
  /// asked for.
  ///
  /// The selection getter has always silently fallen back to the first item
  /// when the requested id was missing, which left `onActiveChange` reporting
  /// nothing and the parent's own state pointing at a row that is not there.
  void _reportFallbackIfNeeded() {
    final items = widget.items;
    if (items.isEmpty) return;
    final requested = widget.activeId ?? _internalActiveId;
    if (requested != null && items.any((i) => i.id == requested)) return;
    final fallback = items.first.id;
    if (widget.activeId == null) _internalActiveId = fallback;
    // After the frame: this runs from initState / didUpdateWidget, and a
    // controlled parent will want to setState in response.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onActiveChange?.call(fallback);
    });
  }

  String get _selectedId {
    final requested = widget.activeId ?? _internalActiveId;
    final hasIt = widget.items.any((i) => i.id == requested);
    if (hasIt) return requested!;
    return widget.items.isNotEmpty ? widget.items.first.id : '';
  }

  String? get _displayedId => _hoveredId ?? _focusedId ?? _touchPreviewId;

  void _select(BeuiPreviewRailItem item) {
    if (widget.activeId == null) setState(() => _internalActiveId = item.id);
    widget.onActiveChange?.call(item.id);
    widget.onItemSelect?.call(item);
  }

  /// One tap on a tick. [kind] is null for keyboard / assistive activation.
  void _activate(BeuiPreviewRailItem item, PointerDeviceKind? kind) {
    final hoverCapable =
        kind == null ||
        kind == PointerDeviceKind.mouse ||
        kind == PointerDeviceKind.trackpad ||
        kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus;

    // A pointer that can hover has already shown the preview, and a keyboard
    // user has already focused it — either way the destination is identified,
    // so activation commits. Same when there is no preview to show.
    if (hoverCapable || !widget.showPreview) {
      if (_touchPreviewId != null) setState(() => _touchPreviewId = null);
      _select(item);
      return;
    }

    if (_touchPreviewId == item.id) {
      // Second tap on the tick being previewed: commit.
      setState(() => _touchPreviewId = null);
      _select(item);
      return;
    }
    // First tap here (or a tap on a different tick): preview it.
    setState(() => _touchPreviewId = item.id);
  }

  void _setHovered(String? id) {
    if (_hoveredId == id) return;
    setState(() {
      _hoveredId = id;
      // A mouse has arrived; the touch preview step is no longer in play.
      if (id != null) _touchPreviewId = null;
    });
  }

  void _setFocused(String? id) {
    if (_focusedId != id) setState(() => _focusedId = id);
  }

  // ---- geometry -----------------------------------------------------------

  /// The requested slot extent, before any clamping for the available space.
  double get _requestedTrack =>
      widget.style?.resolvedItemSize ??
      // Source default: `itemSize = 24`.
      24.0;
  double get _tickLength => widget.style?.tickLength ?? 48.0;
  double get _tickThickness => widget.style?.tickThickness ?? 2.0;

  /// The floor a slot can be compressed to: the line itself plus the dead zone
  /// that keeps neighbouring hover regions apart.
  double get _minTrack => _tickThickness + _tickGap;

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

  /// Fits `n` slots into [available], compressing the pitch before giving up
  /// and scrolling.
  ///
  /// The rail used to size purely to its content: 14 items at 24px is 336px of
  /// hard-coded height inside whatever box the consumer gave it, and 20 items
  /// laid out horizontally on a phone was a plain `RenderFlex overflowed`.
  ({double track, bool scroll}) _fit(int n, double available) {
    if (n <= 0 || !available.isFinite || available <= 0) {
      return (track: _requestedTrack, scroll: false);
    }
    final ideal = available / n;
    if (ideal >= _requestedTrack) {
      return (track: _requestedTrack, scroll: false);
    }
    if (ideal >= _minTrack) return (track: ideal, scroll: false);
    // Even at the floor the rail is longer than its box — scroll it, with edge
    // fades so the clipped ends read as "more", not as "the end".
    return (track: _minTrack, scroll: true);
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = _isHorizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final fit = _fit(items.length, available);
        return _build(
          context,
          colors: colors,
          reduce: reduce,
          items: items,
          track: fit.track,
          scrollRail: fit.scroll,
          available: available,
        );
      },
    );
  }

  Widget _build(
    BuildContext context, {
    required BeuiColors colors,
    required bool reduce,
    required List<BeuiPreviewRailItem> items,
    required double track,
    required bool scrollRail,
    required double available,
  }) {
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
    final positionTarget = (displayed ? displayedIndex : _lastDisplayedIndex)
        .toDouble();

    final activeTick = widget.style?.activeTickColor ?? colors.foreground;
    final inactiveTick =
        widget.style?.inactiveTickColor ?? colors.mutedForeground;
    final selectedId = _selectedId;

    // The pyramid's apex: whatever is hovered/focused/previewed, else the
    // selection when [highlightActive] is on, else nothing (source
    // `highlightedId`). Kept separate from `displayedIndex` because the card is
    // bound to the display sources only — highlightActive anchors the ticks, it
    // never summons the preview.
    final highlightedIndex = displayed
        ? displayedIndex
        : (widget.highlightActive
              ? items.indexWhere((i) => i.id == selectedId)
              : -1);

    // ---- rail -------------------------------------------------------------

    final ticks = <Widget>[
      for (var i = 0; i < n; i++)
        _RailTick(
          key: ValueKey('tick-${items[i].id}'),
          item: items[i],
          isHorizontal: _isHorizontal,
          reduce: reduce,
          selected: items[i].id == selectedId,
          highlighted: i == highlightedIndex,
          previewing: items[i].id == _touchPreviewId,
          scale: _scaleFor(i, highlightedIndex),
          length: _tickLength,
          thickness: _tickThickness,
          track: track,
          activeColor: activeTick,
          inactiveColor: inactiveTick,
          onHover: (hover) => _setHovered(hover ? items[i].id : null),
          onFocus: (focus) => _setFocused(focus ? items[i].id : null),
          onActivate: (kind) => _activate(items[i], kind),
        ),
    ];

    Widget rail = _isHorizontal
        ? Row(mainAxisSize: MainAxisSize.min, children: ticks)
        : Column(mainAxisSize: MainAxisSize.min, children: ticks);

    if (scrollRail) {
      rail = _ScrollableRail(
        isHorizontal: _isHorizontal,
        extent: available,
        surface: colors.background,
        child: rail,
      );
    }

    // Clear hover when the pointer leaves the whole rail (source's
    // `onPointerLeave` on the <nav>). The labelled Semantics container is the
    // source's `<nav aria-label={label}>`; explicitChildNodes keeps each tick
    // its own node so the group name never swallows the item names.
    final railRegion = Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.label,
      child: MouseRegion(onExit: (_) => _setHovered(null), child: rail),
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
      // Source `pointer-events-none` — documented on [renderPreview].
      child: IgnorePointer(child: glideChild),
    );

    Widget glide(double pos) {
      final delta = (pos - centre) * track;
      final offset = _isHorizontal ? Offset(delta, 0) : Offset(0, delta);
      return Transform.translate(offset: offset, child: card);
    }

    // Position snaps under reduced motion (source `duration: 0`); otherwise it
    // springs along SPRING_LAYOUT — the source's `layoutId` shared-layout glide.
    // Skipped entirely when [showPreview] is false (source renders no preview
    // container at all), so the card's springs never run.
    final Widget? glidingCard = !widget.showPreview
        ? null
        : reduce
        ? positionedCard(glide(positionTarget))
        : SingleMotionBuilder(
            value: positionTarget,
            from: positionTarget,
            motion: beuiSpringLayout,
            builder: (context, pos, _) => positionedCard(glide(pos)),
          );

    if (_isHorizontal) {
      // Card floats above a centred rail; only x glides. `previewSide` is
      // vertical-only in the source, so the card stays above either way.
      //
      // The source does NOT stack the two: its preview grid is
      // `pointer-events-none absolute z-50 top-1/2 left-1/2 h-5 -translate-*`,
      // so the card takes no layout space and the `h-12` nav is centred in the
      // container by `flex-col items-center justify-center`. Reserving a slot
      // for the card above the rail instead pushes the rail off centre.
      final Widget layout = LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : _tickLength;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: Center(child: railRegion)),
              if (glidingCard != null)
                Positioned(
                  left: 0,
                  right: 0,
                  // The preview grid is `h-5` centred on the container, so a
                  // cell's bottom sits 10 below centre; each card is `bottom-12`
                  // (48) clear of it — 48 - 10 = 38 above the centre line.
                  bottom: h / 2 + 38,
                  child: Center(child: glidingCard),
                ),
            ],
          );
        },
      );

      // Source `min-h-0 flex-1` content: it follows the rail in flex order, so
      // here it sits below the horizontal rail.
      if (widget.child == null) return layout;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: layout),
          const SizedBox(height: 12),
          widget.child!,
        ],
      );
    }

    // Vertical: rail down one side (48 wide), card beside it; only y glides.
    // Source: the `flex-1` content fills the region next to the rail and the
    // preview card floats over it (absolute, pointer-events-none — the port
    // already wraps `glidingCard` in an IgnorePointer). With [previewSide]
    // `before` the whole arrangement mirrors: rail to the trailing edge, card
    // hugging it from the leading side (the source's mirrored insets + the
    // `ml-auto` that right-aligns the card).
    final before = widget.previewSide == BeuiPreviewRailPreviewSide.before;
    Widget? sideRegion = glidingCard == null
        ? null
        : Align(
            // The card hugs the rail: it sits at whichever edge the rail is on.
            alignment: before
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Source card is `w-full max-w-sm`: it fills the preview
                // column up to 384 and does NOT shrink-wrap its text, so its
                // width is stable no matter which item is displayed.
                final availableWidth = constraints.maxWidth;
                final w = availableWidth.isFinite && availableWidth < 384
                    ? availableWidth
                    : 384.0;
                return SizedBox(width: w, child: glidingCard);
              },
            ),
          );
    if (widget.child != null) {
      sideRegion = sideRegion == null
          ? widget.child!
          : Stack(
              children: [
                Positioned.fill(child: widget.child!),
                sideRegion,
              ],
            );
    }

    final beside = Expanded(child: sideRegion ?? const SizedBox.shrink());
    // The rail is at most the box it was given: `n * track` when that fits,
    // and the box itself when the ticks had to be compressed or scrolled.
    final railExtent = available.isFinite
        ? math.min(n * track, available)
        : n * track;
    return SizedBox(
      height: railExtent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: before
            ? [beside, const SizedBox(width: 16), railRegion]
            : [railRegion, const SizedBox(width: 16), beside],
      ),
    );
  }
}

/// A rail too long for its box: scrolls along its axis, with edge fades so the
/// clipped ends read as "there is more here".
class _ScrollableRail extends StatelessWidget {
  const _ScrollableRail({
    required this.isHorizontal,
    required this.extent,
    required this.surface,
    required this.child,
  });

  final bool isHorizontal;
  final double extent;
  final Color surface;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scroller = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        scrollDirection: isHorizontal ? Axis.horizontal : Axis.vertical,
        child: child,
      ),
    );

    final body = isHorizontal
        ? SizedBox(width: extent, child: scroller)
        : SizedBox(height: extent, child: scroller);

    return ShaderMask(
      shaderCallback: (rect) {
        return LinearGradient(
          begin: isHorizontal ? Alignment.centerLeft : Alignment.topCenter,
          end: isHorizontal ? Alignment.centerRight : Alignment.bottomCenter,
          colors: const [
            Color(0x00FFFFFF),
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: const [0.0, 0.06, 0.94, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: body,
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
    required this.previewing,
    required this.scale,
    required this.length,
    required this.thickness,
    required this.track,
    required this.activeColor,
    required this.inactiveColor,
    required this.onHover,
    required this.onFocus,
    required this.onActivate,
    super.key,
  });

  final BeuiPreviewRailItem item;
  final bool isHorizontal;
  final bool reduce;
  final bool selected;
  final bool highlighted;
  final bool previewing;
  final double scale;
  final double length;
  final double thickness;
  final double track;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<bool> onHover;
  final ValueChanged<bool> onFocus;
  final void Function(PointerDeviceKind? kind) onActivate;

  @override
  Widget build(BuildContext context) {
    // Cell: vertical → track tall, length wide; horizontal → length tall, track
    // wide (source `h-5 w-12` / `h-12 w-5`). The cell is one gap short of the
    // slot so neighbouring hover regions do not touch; the pitch is unchanged
    // and the line stays centred, so nothing moves.
    final slot = math.max(track - _tickGap, thickness);
    final cellWidth = isHorizontal ? slot : length;
    final cellHeight = isHorizontal ? length : slot;

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

    // Kind is captured on the down event and consumed by the tap, so the rail
    // can tell a finger from a mouse. Assistive / keyboard activation never
    // sets it, which is exactly the "commit immediately" path.
    PointerDeviceKind? lastKind;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      // Announce the intermediate touch state rather than leaving a screen
      // reader to wonder why the first activation did nothing visible to it.
      hint: previewing ? 'Previewing. Activate again to open' : null,
      // The dead zone is *outside* the hover region, not inside it: a Padding
      // wrapped around the MouseRegion would still report a hover across the
      // full slot and the cascade would keep re-firing.
      child: Padding(
        padding: isHorizontal
            ? const EdgeInsets.symmetric(horizontal: _tickGap / 2)
            : const EdgeInsets.symmetric(vertical: _tickGap / 2),
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
                  onActivate(null);
                  return null;
                },
              ),
            },
            onShowFocusHighlight: onFocus,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => lastKind = details.kind,
              onTap: () {
                final kind = lastKind;
                lastKind = null;
                onActivate(kind);
              },
              child: SizedBox(
                width: cellWidth,
                height: cellHeight,
                child: animatedLine,
              ),
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

    // Horizontal card is `w-72` (288); the vertical one is `w-full max-w-sm`
    // and gets its width from the caller, so pass the constraint straight
    // through rather than re-imposing one here.
    return SizedBox(
      width: isHorizontal ? 288.0 : null,
      child: AnimatedSwitcher(
        // The default layout builder is a `Stack(alignment: center)`, which
        // hands children LOOSE constraints — the card would shrink-wrap its
        // longest line and re-centre, so its width would jitter per item.
        // `passthrough` keeps the caller's tight width.
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: AlignmentDirectional.topStart,
          fit: StackFit.passthrough,
          children: <Widget>[...previousChildren, ?currentChild],
        ),
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
