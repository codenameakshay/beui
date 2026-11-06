import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/services.dart';

import '../overlay/beui_overlay.dart';
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
    this.titleWidget,
    this.description,
    this.descriptionWidget,
    this.trailing,
  });

  /// Stable identity within the stack.
  final String id;

  /// Primary line (source `title`).
  final String title;

  /// Optional rich title content, retaining [title] for existing callers.
  final Widget? titleWidget;

  /// Optional secondary line (source `description`).
  final String? description;

  /// Optional rich description content, retaining [description].
  final Widget? descriptionWidget;

  /// Optional trailing content — a timestamp, badge, avatar (source
  /// `trailing`). Rendered at the source's `text-xs` muted scale unless it
  /// carries its own style.
  final Widget? trailing;
}

class _TapSnapshot {
  const _TapSnapshot({required this.expanded, required this.pointerType});

  final bool expanded;
  final PointerDeviceKind pointerType;
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

const Duration _cardDuration = Duration(milliseconds: 320);
const Duration _backgroundDuration = Duration(milliseconds: 260);
const Duration _arrowDuration = Duration(milliseconds: 220);

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
/// source: focus expands, blur collapses, Escape collapses while retaining focus; a tap
/// expands when collapsed, or fires [onViewAll] (falling back to collapsing)
/// when already expanded.
///
/// **Motion.** Cards use the source 320ms `EASE_OUT`, the background uses its
/// 260ms `EASE_OUT`, and the footer position uses [beuiSpringLayout]. The host
/// keeps the invisible primary-card-plus-footer footprint and the surface fans
/// upward from its fixed bottom edge.
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
  final Object _tapRegionGroup = Object();
  bool _hasFocus = false;
  bool _focusVisible = false;
  _TapSnapshot? _tapSnapshot;
  bool _tapExpanded = false;

  // Card-height measurement — the source relies on CSS grid auto-sizing; here we
  // measure each card at full width once so the fan-out can position variable
  // -height cards. Same technique as the dynamic-island's ResizeObserver port.
  List<GlobalKey> _measureKeys = const [];
  List<double>? _heights;
  int? _measuredSig;
  int? _pendingSig;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChange);
  }

  bool get _isControlled => widget.expanded != null;
  bool get _expanded => widget.expanded ?? _internalExpanded;

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onHighlightModeChange(FocusHighlightMode mode) {
    final visible = _hasFocus && mode == FocusHighlightMode.traditional;
    if (visible != _focusVisible && mounted) {
      setState(() => _focusVisible = visible);
    }
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
    setState(() {
      _hasFocus = focused;
      _focusVisible =
          focused &&
          FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    });
    _setExpanded(focused);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) _tapSnapshot = null;
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _expanded) {
      _tapSnapshot = null;
      _tapExpanded = false;
      _setExpanded(false);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space)) {
      _tapSnapshot = null;
      _onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onTap() {
    // Decide on the state the tap started from (the source reads the pre-focus
    // value): collapsed → expand; expanded → onViewAll, else collapse.
    final snapshot = _tapSnapshot;
    final wasExpanded = snapshot?.expanded ?? _expanded;
    _tapSnapshot = null;
    if (!wasExpanded) {
      _tapExpanded =
          snapshot != null && snapshot.pointerType != PointerDeviceKind.mouse;
      _focusNode.requestFocus();
      _setExpanded(true);
    } else if (widget.onViewAll != null) {
      _tapExpanded = false;
      widget.onViewAll!.call();
    } else {
      _tapExpanded = false;
      _setExpanded(false);
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _tapSnapshot = _TapSnapshot(expanded: _expanded, pointerType: event.kind);
  }

  void _onPointerCancel(PointerCancelEvent event) => _tapSnapshot = null;

  void _onTapOutside(PointerDownEvent event) {
    if (!_tapExpanded || !_expanded) return;
    _tapExpanded = false;
    _setExpanded(false);
  }

  // --- measurement ---------------------------------------------------------

  int _signature(double width, List<BeuiNotificationStackItem> visible) {
    final scale = MediaQuery.textScalerOf(context).scale(14);
    return Object.hash(
      width,
      scale,
      Theme.of(context).textTheme.bodyMedium?.fontFamily,
      Object.hashAll(
        visible.map(
          (it) => Object.hash(
            it.id,
            it.title.hashCode,
            it.titleWidget?.hashCode ?? 0,
            it.description?.hashCode ?? 0,
            it.descriptionWidget?.hashCode ?? 0,
            it.trailing?.hashCode ?? 0,
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
          final measured =
              heights != null &&
              heights.length == visible.length &&
              _measuredSig == sig;
          final overflowExtent = measured
              ? heights
                    .skip(1)
                    .fold<double>(
                      0,
                      (extent, height) => extent + height + _cardGap,
                    )
              : 0.0;

          Widget surface;
          if (!measured) {
            surface = _fallback(width, visible, colors);
          } else if (reduce) {
            surface = _surface(
              width,
              contentWidth,
              visible,
              heights,
              _expanded,
              colors,
            );
          } else {
            surface = _surface(
              width,
              contentWidth,
              visible,
              heights,
              _expanded,
              colors,
            );
          }

          // Hidden, non-interactive measuring column at full content width —
          // positioned so it never sizes the stack or takes hit tests.
          final measure = Positioned(
            left: 0,
            top: 0,
            width: contentWidth,
            height: 0,
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minHeight: 0,
              maxHeight: double.infinity,
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
                            child: _card(
                              visible[i],
                              colors,
                              contentVisible: true,
                            ),
                          ),
                      ],
                    ),
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
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: _collapsedSurfaceHeight(heights),
                      child: OverflowBox(
                        alignment: Alignment.bottomCenter,
                        minHeight: 0,
                        maxHeight: double.infinity,
                        child: _pointerSurface(
                          surface,
                          overflowHitTargetOpen:
                              _expanded && overflowExtent > 0,
                        ),
                      ),
                    ),
                    measure,
                  ],
                )
              : Stack(
                  clipBehavior: Clip.none,
                  children: [
                    OverflowBox(
                      fit: OverflowBoxFit.deferToChild,
                      alignment: Alignment.bottomCenter,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      child: _pointerSurface(
                        surface,
                        overflowHitTargetOpen: false,
                      ),
                    ),
                    measure,
                  ],
                );

          return BeuiOverlay(
            open: _expanded && overflowExtent > 0,
            barrier: false,
            trapFocus: false,
            enterDuration: reduce ? Duration.zero : _backgroundDuration,
            exitDuration: reduce ? Duration.zero : _backgroundDuration,
            overlayBuilder: (context, animation, link) => AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final hitHeight =
                    _collapsedSurfaceHeight(heights!) +
                    overflowExtent * animation.value;
                return CompositedTransformFollower(
                  link: link,
                  targetAnchor: Alignment.bottomLeft,
                  followerAnchor: Alignment.bottomLeft,
                  showWhenUnlinked: false,
                  child: ExcludeSemantics(
                    child: SizedBox(
                      width: width,
                      height: hitHeight,
                      child: TapRegion(
                        groupId: _tapRegionGroup,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => _setExpanded(true),
                          onExit: (_) {
                            if (!_hasFocus) {
                              _tapExpanded = false;
                              _setExpanded(false);
                            }
                          },
                          child: Listener(
                            onPointerDown: _onPointerDown,
                            onPointerCancel: _onPointerCancel,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _onTap,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            child: _interactive(
              // Badge + aria report the TOTAL count (source `items.length`), not
              // the capped number of peeking cards.
              widget.items.length,
              host,
            ),
          );
        },
      ),
    );
  }

  // --- interactive wrapper -------------------------------------------------

  Widget _interactive(int count, Widget child) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: _onFocusChange,
      onKeyEvent: _onKey,
      child: child,
    );
  }

  Widget _pointerSurface(Widget child, {required bool overflowHitTargetOpen}) {
    final count = widget.items.length;
    final label = _expanded
        ? '$count notifications. ${widget.expandedLabel}.'
        : '$count notifications. Expand notifications.';
    return Semantics(
      button: true,
      expanded: _expanded,
      focusable: true,
      focused: _hasFocus,
      label: label,
      excludeSemantics: true,
      child: TapRegion(
        groupId: _tapRegionGroup,
        consumeOutsideTaps: _tapExpanded && _expanded,
        onTapOutside: _onTapOutside,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => _setExpanded(true),
          onExit: (_) {
            if (!_hasFocus && !overflowHitTargetOpen) {
              _tapExpanded = false;
              _setExpanded(false);
            }
          },
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerCancel: _onPointerCancel,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onTap,
              child: BeuiFocusRing(
                focused: _focusVisible,
                borderRadius: BorderRadius.circular(_surfaceRadius),
                child: child,
              ),
            ),
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
    return heights.first +
        _footerTopMargin +
        _footerHeight +
        _surfacePadding * 2; // p-3 both sides
  }

  Widget _surface(
    double width,
    double contentWidth,
    List<BeuiNotificationStackItem> visible,
    List<double> heights,
    bool expanded,
    BeuiColors colors,
  ) {
    final n = visible.length;
    var expandedCursor = 0.0;
    final collapsedTops = List<double>.filled(n, 0);
    final expandedTops = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      collapsedTops[i] = i * _stackPeek;
      expandedTops[i] = expandedCursor;
      expandedCursor += heights[i] + _cardGap;
    }
    final expandedStackHeight = expandedCursor - _cardGap;
    final collapsedStackHeight = heights.first;
    final collapsedFooterTop = collapsedStackHeight + _footerTopMargin;
    final expandedFooterTop = expandedStackHeight + _footerTopMargin;
    final collapsedHeight = collapsedFooterTop + _footerHeight;
    final expandedHeight = expandedFooterTop + _footerHeight;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final target = expanded ? 1.0 : 0.0;
    final cardDuration = reduce ? Duration.zero : _cardDuration;
    final bgDuration = reduce ? Duration.zero : _backgroundDuration;

    final children = <Widget>[];
    for (var i = n - 1; i >= 0; i--) {
      children.add(
        AnimatedPositioned(
          duration: cardDuration,
          curve: beuiEaseOut,
          top: expanded ? expandedTops[i] : collapsedTops[i],
          left: expanded ? 0 : i * _stackInset,
          right: expanded ? 0 : i * _stackInset,
          child: _card(visible[i], colors, contentVisible: expanded || i == 0),
        ),
      );
    }
    Widget footerContent = _footer(colors, widget.items.length);
    if (reduce) {
      footerContent = Transform.translate(
        offset: Offset(0, expanded ? expandedFooterTop : collapsedFooterTop),
        child: footerContent,
      );
    } else {
      footerContent = SingleMotionBuilder(
        value: expanded ? expandedFooterTop : collapsedFooterTop,
        motion: beuiSpringLayout,
        builder: (context, footerTop, child) =>
            Transform.translate(offset: Offset(0, footerTop), child: child),
        child: footerContent,
      );
    }
    children.add(
      Positioned(
        top: 0,
        left: 4,
        right: 4,
        height: _footerHeight,
        child: footerContent,
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: target, end: target),
      duration: bgDuration,
      curve: beuiEaseOut,
      builder: (context, progress, _) {
        final height = lerpDouble(collapsedHeight, expandedHeight, progress)!;
        return Container(
          width: width,
          padding: const EdgeInsets.all(_surfacePadding),
          decoration: BoxDecoration(
            color: colors.muted,
            borderRadius: BorderRadius.circular(_surfaceRadius),
          ),
          child: SizedBox(
            width: contentWidth,
            height: height,
            child: Stack(clipBehavior: Clip.none, children: children),
          ),
        );
      },
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
          _card(visible.first, colors, contentVisible: true),
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
    BeuiColors colors, {
    required bool contentVisible,
  }) {
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
      child: Visibility(
        visible: contentVisible,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
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
                    child:
                        item.titleWidget ??
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
              if (item.description != null || item.descriptionWidget != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6), // gap-1.5
                  child:
                      item.descriptionWidget ??
                      Text(
                        item.description!,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.625,
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
