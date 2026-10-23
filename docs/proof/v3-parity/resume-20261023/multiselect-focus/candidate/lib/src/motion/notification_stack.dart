import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import '_focus_ring.dart';
import 'action_swap.dart';

/// One notification in a [BeuiNotificationStack] — the Flutter port of the
/// source's `NotificationStackItem`.
@immutable
class BeuiNotificationStackItem {
  /// Creates a stack item. [id] must be unique within the stack (it keys the
  /// card and the fan-out animation).
  const BeuiNotificationStackItem({
    required this.id,
    required this.title,
    this.description,
    this.trailing,
  });

  /// Stable identity within the stack.
  final String id;

  /// Primary line (source `title`).
  final String title;

  /// Optional secondary line (source `description`).
  final String? description;

  /// Optional trailing content — a timestamp, badge, avatar (source
  /// `trailing`). Rendered at the source's `text-xs` muted scale unless it
  /// carries its own style.
  final Widget? trailing;
}

// Source geometry tokens (notification-stack.tsx).
const double _stackPeek = 8; // STACK_PEEK — collapsed y offset per card
const double _stackInset =
    12; // STACK_INSET — collapsed horizontal inset per card
const double _cardGap = 4; // grid gap-1
const double _footerHeight = 36; // min-h-9
const double _footerTopMargin = 8; // mt-2
const double _surfacePadding = 12; // p-3
const double _cardRadius = 16; // rounded-2xl
const double _surfaceRadius = 24; // rounded-3xl
const double _defaultMaxWidth = 352; // max-w-[22rem]

// Source card transition — {duration: 0.32, ease: EASE_OUT} for the y + inset
// (clipPath) fan-out. The footer carries `layout="position"` with SPRING_LAYOUT
// and the background `layout` with {0.26, EASE_OUT}; in this port the whole
// surface morph (cards, footer position and the bg-muted surface) is driven by a
// single [beuiSpringLayout] progress so the growing card, the footer and the
// surface never separate into a seam (see the class doc). The label roll keeps
// its own timing via [BeuiActionSwapText].
const Duration _arrowDuration = Duration(milliseconds: 240);

/// A single collapsible stacked-notification "inbox" card — the Flutter port of
/// beUI's `NotificationStack`.
///
/// Collapsed, up to [maxVisible] cards peek out below the primary (each nudged
/// down [_stackPeek] and inset [_stackInset] narrower, only the primary's
/// content visible). On hover (hover-capable pointers only, via [MouseRegion]),
/// keyboard focus, or tap it expands into a vertical fanned list; the footer
/// rolls its label between [collapsedLabel] and [expandedLabel] (+ an up-right
/// arrow) via a [BeuiActionSwapText]. Empty, it renders a `BellOff` +
/// [emptyLabel] resting state.
///
/// Expansion is controllable ([expanded] / [defaultExpanded] /
/// [onExpandedChange], the value + callback pattern). Interactions mirror the
/// source: focus expands, blur collapses, Escape collapses and blurs; a tap
/// expands when collapsed, or fires [onViewAll] (falling back to collapsing)
/// when already expanded.
///
/// **Motion.** The surface morph rides [beuiSpringLayout] — the source's
/// `layout` family, which drives its background and footer. The source addition
/// of a distinct 0.32s/0.26s `EASE_OUT` for the cards/background is unified onto
/// the one layout spring here so the card list, the footer and the surface
/// resize as a single body with no seam. The widget grows *downward* as it
/// expands (rather than the source's upward overflow out of a fixed footprint),
/// so its hit area always covers the fanned list and hover never flickers.
///
/// Reduced motion ([MediaQuery.disableAnimationsOf]) snaps the expansion — the
/// morph is pure movement, so it is dropped — while the label roll degrades to
/// its own reduced-motion crossfade inside [BeuiActionSwapText].
class BeuiNotificationStack extends StatefulWidget {
  /// Creates a notification stack.
  const BeuiNotificationStack({
    required this.items,
    this.expanded,
    this.defaultExpanded = false,
    this.onExpandedChange,
    this.onViewAll,
    this.maxVisible = 3,
    this.collapsedLabel = 'Notifications',
    this.expandedLabel = 'View all',
    this.emptyLabel = 'All caught up',
    this.emptyIcon = LucideIcons.bell_off,
    this.maxWidth = _defaultMaxWidth,
    super.key,
  });

  /// The notifications, primary first (source `items`).
  final List<BeuiNotificationStackItem> items;

  /// Expanded state (controlled). When null the widget is uncontrolled and
  /// seeds its state from [defaultExpanded].
  final bool? expanded;

  /// Initial expansion when uncontrolled (source `defaultExpanded`).
  final bool defaultExpanded;

  /// Called whenever expansion is requested — with the next value (source
  /// `onExpandedChange`). Fires in both controlled and uncontrolled modes.
  final ValueChanged<bool>? onExpandedChange;

  /// Called when the surface is tapped while already expanded (source
  /// `onViewAll`). Without it a second tap collapses.
  final VoidCallback? onViewAll;

  /// How many of the leading items participate in the stack (source
  /// `maxVisible`, clamped to at least 1).
  final int maxVisible;

  /// Footer label when collapsed (source `collapsedLabel`).
  final String collapsedLabel;

  /// Footer label when expanded (source `expandedLabel`).
  final String expandedLabel;

  /// Resting-state label when [items] is empty (source `emptyLabel`).
  final String emptyLabel;

  /// Resting-state glyph when [items] is empty (source `BellOff`).
  final IconData emptyIcon;

  /// Surface width cap (source `max-w-[22rem]`).
  final double maxWidth;

  @override
  State<BeuiNotificationStack> createState() => _BeuiNotificationStackState();
}

class _BeuiNotificationStackState extends State<BeuiNotificationStack> {
  late bool _internalExpanded = widget.defaultExpanded;
  final FocusNode _focusNode = FocusNode(debugLabel: 'BeuiNotificationStack');
  bool _hasFocus = false;

  // Card-height measurement — the source relies on CSS grid auto-sizing; here we
  // measure each card at full width once so the fan-out can position variable
  // -height cards. Same technique as the dynamic-island's ResizeObserver port.
  List<GlobalKey> _measureKeys = const [];
  List<double>? _heights;
  int? _measuredSig;
  int? _pendingSig;

  bool get _isControlled => widget.expanded != null;
  bool get _expanded => widget.expanded ?? _internalExpanded;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _setExpanded(bool next) {
    // Mirrors the source `setValue`: only touch internal state when
    // uncontrolled, but always notify (the source fires from both onFocus and
    // onClick, so a collapsed tap can notify twice — kept for parity).
    if (!_isControlled && _internalExpanded != next) {
      setState(() => _internalExpanded = next);
    }
    widget.onExpandedChange?.call(next);
  }

  // --- interactions (mirror the source handlers) ---------------------------

  void _onFocusChange(bool focused) {
    _hasFocus = focused;
    _setExpanded(focused);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _expanded) {
      _setExpanded(false);
      _focusNode.unfocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onTap() {
    // Decide on the state the tap started from (the source reads the pre-focus
    // value): collapsed → expand; expanded → onViewAll, else collapse.
    if (!_expanded) {
      _focusNode.requestFocus();
      _setExpanded(true);
    } else if (widget.onViewAll != null) {
      widget.onViewAll!.call();
    } else {
      _setExpanded(false);
      _focusNode.unfocus();
    }
  }

  // --- measurement ---------------------------------------------------------

  int _signature(double width, List<BeuiNotificationStackItem> visible) {
    final scale = MediaQuery.textScalerOf(context).scale(14);
    return Object.hash(
      width.round(),
      scale,
      Object.hashAll(
        visible.map(
          (it) => Object.hash(
            it.id,
            it.title.length,
            it.description?.length ?? -1,
            it.trailing != null,
          ),
        ),
      ),
    );
  }

  void _ensureMeasured(int sig) {
    if (sig == _measuredSig || sig == _pendingSig) return;
    _pendingSig = sig;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingSig != sig) return;
      final heights = <double>[];
      for (final key in _measureKeys) {
        final box = key.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.hasSize) {
          // Not laid out yet — drop the pending flag so the next build retries.
          _pendingSig = null;
          if (mounted) setState(() {});
          return;
        }
        heights.add(box.size.height);
      }
      if (!mounted) return;
      setState(() {
        _heights = heights;
        _measuredSig = sig;
        _pendingSig = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);

    if (widget.items.isEmpty) return _emptyState(colors);

    final visible = widget.items
        .take(math.max(1, widget.maxVisible))
        .toList(growable: false);

    if (_measureKeys.length != visible.length) {
      _measureKeys = List.generate(visible.length, (_) => GlobalKey());
      _heights = null;
      _measuredSig = null;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? math.min(constraints.maxWidth, widget.maxWidth)
              : widget.maxWidth;
          final contentWidth = math.max(0.0, width - _surfacePadding * 2);

          final sig = _signature(width, visible);
          _ensureMeasured(sig);

          final heights = _heights;
          final measured = heights != null && heights.length == visible.length;
          final target = _expanded ? 1.0 : 0.0;

          Widget surface;
          if (!measured) {
            surface = _fallback(width, visible, colors);
          } else if (reduce) {
            surface = _surface(
              width,
              contentWidth,
              visible,
              heights,
              target,
              colors,
            );
          } else {
            surface = SingleMotionBuilder(
              value: target,
              motion: beuiSpringLayout,
              builder: (context, p, _) => _surface(
                width,
                contentWidth,
                visible,
                heights,
                p.clamp(0.0, 1.0),
                colors,
              ),
            );
          }

          // Hidden, non-interactive measuring column at full content width —
          // positioned so it never sizes the stack or takes hit tests.
          final measure = Positioned(
            left: 0,
            top: 0,
            width: contentWidth,
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < visible.length; i++)
                        KeyedSubtree(
                          key: _measureKeys[i],
                          child: _card(visible[i], 1, colors),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );

          // Bottom-anchored host: an in-flow sizer holds the resting height and
          // the animating surface hangs off its bottom edge, so expanding fans
          // the deck up over whatever sits above instead of pushing the footer
          // down the page (source `absolute inset-x-0 bottom-0`).
          final host = measured
              ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      width: width,
                      height: _collapsedSurfaceHeight(heights),
                    ),
                    Positioned(left: 0, right: 0, bottom: 0, child: surface),
                    measure,
                  ],
                )
              : Stack(clipBehavior: Clip.none, children: [surface, measure]);

          return _interactive(
            colors,
            // Badge + aria report the TOTAL count (source `items.length`), not
            // the capped number of peeking cards.
            widget.items.length,
            host,
          );
        },
      ),
    );
  }

  // --- interactive wrapper -------------------------------------------------

  Widget _interactive(BeuiColors colors, int count, Widget child) {
    final label = _expanded
        ? '$count notifications. ${widget.expandedLabel}.'
        : '$count notifications. Expand notifications.';

    final wrapped = BeuiFocusRing(
      focused: _hasFocus,
      borderRadius: BorderRadius.circular(_surfaceRadius),
      child: child,
    );

    return Semantics(
      button: true,
      label: label,
      child: Focus(
        focusNode: _focusNode,
        onFocusChange: _onFocusChange,
        onKeyEvent: _onKey,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => _setExpanded(true),
          onExit: (_) {
            if (!_hasFocus) _setExpanded(false);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onTap,
            child: wrapped,
          ),
        ),
      ),
    );
  }

  // --- surface -------------------------------------------------------------

  /// The surface's height at rest. The source sizes its host with a static
  /// in-flow copy of the primary card plus the footer strip, then overlays the
  /// real (animating) panel absolutely against the host's bottom — so the
  /// expanded deck never pushes the layout around, it just grows upward.
  double _collapsedSurfaceHeight(List<double> heights) {
    var stack = 0.0;
    for (var i = 0; i < heights.length; i++) {
      stack = math.max(stack, i * _stackPeek + heights[i]);
    }
    return stack +
        _footerTopMargin +
        _footerHeight +
        _surfacePadding * 2; // p-3 both sides
  }

  Widget _surface(
    double width,
    double contentWidth,
    List<BeuiNotificationStackItem> visible,
    List<double> heights,
    double p,
    BeuiColors colors,
  ) {
    final n = visible.length;

    // Collapsed vs expanded geometry. The surface itself lays the cards out
    // downward from its own top; the host pins the surface's *bottom* (source
    // `absolute inset-x-0 bottom-0`), so growing it fans the deck upward.
    var expandedCursor = 0.0;
    var collapsedStackHeight = 0.0;
    final collapsedTops = List<double>.filled(n, 0);
    final expandedTops = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      collapsedTops[i] = i * _stackPeek;
      expandedTops[i] = expandedCursor;
      expandedCursor += heights[i] + _cardGap;
      collapsedStackHeight = math.max(
        collapsedStackHeight,
        collapsedTops[i] + heights[i],
      );
    }
    final expandedStackHeight = expandedCursor - _cardGap;

    final stackHeight = lerpDouble(
      collapsedStackHeight,
      expandedStackHeight,
      p,
    )!;
    final footerTop = stackHeight + _footerTopMargin;
    final contentHeight = footerTop + _footerHeight;

    final children = <Widget>[];
    // Paint back-to-front so the primary (card 0) sits on top of the peeks.
    for (var i = n - 1; i >= 0; i--) {
      final top = lerpDouble(collapsedTops[i], expandedTops[i], p)!;
      final inset = lerpDouble(i * _stackInset, 0, p)!;
      final opacity = i == 0 ? 1.0 : p.clamp(0.0, 1.0);
      children.add(
        Positioned(
          top: top,
          left: inset,
          right: inset,
          child: _card(visible[i], opacity, colors),
        ),
      );
    }
    children.add(
      Positioned(
        top: footerTop,
        left: 4, // px-1
        right: 4,
        height: _footerHeight,
        child: _footer(colors, widget.items.length),
      ),
    );

    return Container(
      width: width,
      padding: const EdgeInsets.all(_surfacePadding),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(_surfaceRadius),
      ),
      child: SizedBox(
        width: contentWidth,
        height: contentHeight,
        child: Stack(clipBehavior: Clip.none, children: children),
      ),
    );
  }

  /// First-frame surface, shown for the single frame before the cards are
  /// measured: the primary card + footer, no peeks.
  Widget _fallback(
    double width,
    List<BeuiNotificationStackItem> visible,
    BeuiColors colors,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(_surfacePadding),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(_surfaceRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _card(visible.first, 1, colors),
          const SizedBox(height: _footerTopMargin),
          SizedBox(
            height: _footerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _footer(colors, widget.items.length),
            ),
          ),
        ],
      ),
    );
  }

  // --- pieces --------------------------------------------------------------

  Widget _card(
    BeuiNotificationStackItem item,
    double opacity,
    BeuiColors colors,
  ) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(
          color: colors.border.withValues(
            alpha: colors.border.a * 0.6,
          ), // border-border/60
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16), // px-4
      child: Opacity(
        opacity: opacity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16), // py-4
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14, // text-sm
                        height: 1.375, // leading-snug
                        fontWeight: FontWeight.w500,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                  if (item.trailing != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 12), // gap-3
                      child: DefaultTextStyle.merge(
                        style: TextStyle(
                          fontSize: 12, // text-xs
                          color: colors.mutedForeground,
                        ),
                        child: item.trailing!,
                      ),
                    ),
                ],
              ),
              if (item.description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6), // gap-1.5
                  child: Text(
                    item.description!,
                    style: TextStyle(
                      fontSize: 12, // text-xs
                      height: 1.625, // leading-relaxed
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer(BeuiColors colors, int count) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _countBadge(count, colors),
          const SizedBox(width: 8), // gap-2
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: BeuiActionSwapText(
                    value: _expanded ? 'expanded' : 'collapsed',
                    text: _expanded
                        ? widget.expandedLabel
                        : widget.collapsedLabel,
                    variant: BeuiActionSwapVariant.roll,
                    style: TextStyle(
                      fontSize: 14, // text-sm
                      fontWeight: FontWeight.w500,
                      color: colors.foreground,
                    ),
                  ),
                ),
                _arrow(colors, reduce),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrow(BeuiColors colors, bool reduce) {
    final icon = Padding(
      padding: const EdgeInsets.only(left: 4), // gap-1
      child: Icon(
        LucideIcons.arrow_up_right,
        size: 16,
        color: colors.foreground,
      ),
    );
    if (reduce) {
      return _expanded ? icon : const SizedBox.shrink();
    }
    return AnimatedSize(
      duration: _arrowDuration,
      curve: beuiEaseOut,
      alignment: Alignment.centerLeft,
      child: AnimatedSwitcher(
        duration: _arrowDuration,
        switchInCurve: Curves.linear,
        switchOutCurve: Curves.linear,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: _expanded
            ? icon
            : const SizedBox.shrink(key: ValueKey('beui-ns-no-arrow')),
      ),
    );
  }

  Widget _countBadge(int count, BeuiColors colors) {
    // Source hardcodes an orange badge (bg-orange-600 / dark bg-orange-500) with
    // an inset highlight; the vertical gradient approximates that highlight.
    final base = colors.brightness == Brightness.dark
        ? const Color(0xFFF97316) // orange-500
        : const Color(0xFFEA580C); // orange-600
    final top = Color.lerp(base, Colors.white, 0.16)!;
    return Container(
      width: 28, // size-7
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, base],
        ),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 12, // text-xs
          height: 1,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _emptyState(BeuiColors colors) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 20, // px-5
          vertical: 32, // py-8
        ),
        decoration: BoxDecoration(
          color: colors.muted.withValues(alpha: 0.7), // bg-muted/70
          borderRadius: BorderRadius.circular(_surfaceRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.emptyIcon, size: 16, color: colors.mutedForeground),
            const SizedBox(width: 8), // gap-2
            Flexible(
              child: Text(
                widget.emptyLabel,
                style: TextStyle(
                  fontSize: 14, // text-sm
                  fontWeight: FontWeight.w500,
                  color: colors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
