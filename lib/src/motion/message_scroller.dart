import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'message.dart';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Optional message-navigation mode for [BeuiMessageScroller]
/// (source `navigation`).
enum BeuiMessageScrollerNavigation {
  /// Compact equalizer-style rail for jumping between message anchors
  /// (source `navigation="rail"`).
  rail,
}

/// One navigable entry for the optional message rail
/// (source rail items derived from `[data-slot="message"]` rows).
///
/// Prefer wrapping each message with [BeuiMessageScrollerAnchor] so the
/// scroller can measure and scroll-to targets. Explicit
/// [BeuiMessageScroller.railItems] override
/// auto-collected anchors when provided.
@immutable
class BeuiMessageScrollerRailItem {
  /// Creates a rail item.
  const BeuiMessageScrollerRailItem({
    required this.id,
    required this.label,
    this.description,
    this.from,
  });

  /// Stable identity — must match a descendant [BeuiMessageScrollerAnchor.id]
  /// for scroll-to to work.
  final String id;

  /// Primary preview title (source rail `label`).
  final String label;

  /// Optional supporting copy (source rail `description`).
  final String? description;

  /// Optional author — used for accessible labels.
  final BeuiMessageFrom? from;
}

// ---------------------------------------------------------------------------
// Anchor registration (Flutter stand-in for DOM `[data-slot="message"]` scan)
// ---------------------------------------------------------------------------

class _AnchorEntry {
  _AnchorEntry({
    required this.id,
    required this.key,
    this.label,
    this.description,
    this.from,
  });

  final String id;
  final GlobalKey key;
  String? label;
  String? description;
  BeuiMessageFrom? from;
}

/// Ambient registry so [BeuiMessageScrollerAnchor] can register with the
/// nearest [BeuiMessageScroller].
class _ScrollerScope extends InheritedWidget {
  const _ScrollerScope({
    required this.register,
    required this.unregister,
    required this.updateMeta,
    required super.child,
  });

  final void Function(_AnchorEntry entry) register;
  final void Function(String id) unregister;
  final void Function(
    String id, {
    String? label,
    String? description,
    BeuiMessageFrom? from,
  })
  updateMeta;

  static _ScrollerScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ScrollerScope>();

  @override
  bool updateShouldNotify(_ScrollerScope oldWidget) => false;
}

/// Marks a descendant of [BeuiMessageScroller] as a navigable message for the
/// optional rail and for scroll-to.
///
/// The source discovers messages via `[data-slot="message"]` DOM queries; Flutter
/// has no equivalent, so consumers wrap each row (typically a [BeuiMessage])
/// with an anchor. When [BeuiMessageScroller.railItems] is omitted, the scroller
/// builds rail entries from registered anchors.
class BeuiMessageScrollerAnchor extends StatefulWidget {
  /// Creates an anchor around a message row.
  const BeuiMessageScrollerAnchor({
    required this.id,
    required this.child,
    this.label,
    this.description,
    this.from,
    super.key,
  });

  /// Stable identity used by the rail and [BeuiMessageScrollerState.scrollToId].
  final String id;

  /// Message content — usually a [BeuiMessage].
  final Widget child;

  /// Preview title for the rail. Falls back to a generic label when null.
  final String? label;

  /// Optional supporting rail copy.
  final String? description;

  /// Author for accessible rail labels.
  final BeuiMessageFrom? from;

  @override
  State<BeuiMessageScrollerAnchor> createState() =>
      _BeuiMessageScrollerAnchorState();
}

class _BeuiMessageScrollerAnchorState extends State<BeuiMessageScrollerAnchor> {
  final GlobalKey _key = GlobalKey();
  _ScrollerScope? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = _ScrollerScope.maybeOf(context);
    if (scope == _scope) return;
    _scope?.unregister(widget.id);
    _scope = scope;
    _scope?.register(
      _AnchorEntry(
        id: widget.id,
        key: _key,
        label: widget.label,
        description: widget.description,
        from: widget.from,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant BeuiMessageScrollerAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _scope?.unregister(oldWidget.id);
      _scope?.register(
        _AnchorEntry(
          id: widget.id,
          key: _key,
          label: widget.label,
          description: widget.description,
          from: widget.from,
        ),
      );
    } else {
      _scope?.updateMeta(
        widget.id,
        label: widget.label,
        description: widget.description,
        from: widget.from,
      );
    }
  }

  @override
  void dispose() {
    _scope?.unregister(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

// ---------------------------------------------------------------------------
// BeuiMessageScroller
// ---------------------------------------------------------------------------

/// A reader-aware conversation viewport that follows streamed output at the
/// live edge and releases control when the reader scrolls away — the Flutter
/// port of beUI's `MessageScroller`.
///
/// **Follow behaviour** (source `followOutput` / `followThreshold` / `smooth`):
/// while [followOutput] is true and the reader remains within
/// [followThreshold] px of the end, content growth (new messages, streaming
/// text) keeps the viewport pinned to the live edge. Scrolling away past the
/// threshold releases control; returning to the bottom re-attaches. Smooth
/// follows use a short ease-out glide (~320ms, matching the source's
/// programmatic-scroll lock window); reduced motion and `smooth: false` jump.
///
/// **API mapping** (source → Flutter):
/// * `followOutput` → [followOutput] (stick-to-bottom)
/// * `followThreshold` → [followThreshold]
/// * `smooth` → [smooth]
/// * `onFollowChange` → [onFollowChange] (stick-change callback)
/// * `label` / `busy` → [label] / [busy]
/// * `navigation="rail"` → [navigation] = [BeuiMessageScrollerNavigation.rail]
/// * children → [child]
/// * DOM message scan → [BeuiMessageScrollerAnchor] + optional [railItems]
///
/// Wheel / drag / ArrowUp / PageUp / Home clear the programmatic-scroll guard
/// so the next user scroll can leave the live edge (source `leaveLiveEdge`).
class BeuiMessageScroller extends StatefulWidget {
  /// Creates a message scroller.
  const BeuiMessageScroller({
    required this.child,
    this.controller,
    this.followOutput = true,
    this.followThreshold = 56,
    this.smooth = true,
    this.onFollowChange,
    this.label = 'Conversation',
    this.busy = false,
    this.navigation,
    this.navigationLabel = 'Message navigation',
    this.railItems,
    this.padding,
    this.scrollPhysics,
    super.key,
  });

  /// Transcript content — typically a [BeuiMessageGroup] of anchored messages.
  final Widget child;

  /// Optional external scroll controller. When null an internal one is created.
  final ScrollController? controller;

  /// Keep streamed output pinned while the reader remains near the end
  /// (source `followOutput`, default `true`). Stick-to-bottom behaviour.
  final bool followOutput;

  /// Distance from the end (logical px) that still counts as following
  /// (source `followThreshold`, default `56`).
  final double followThreshold;

  /// Smoothly follow growing content (source `smooth`, default `true`).
  /// Ignored under reduced motion.
  final bool smooth;

  /// Reports when the reader leaves or returns to the live edge
  /// (source `onFollowChange`).
  final ValueChanged<bool>? onFollowChange;

  /// Accessible label for the scrollable transcript (source `label`).
  final String label;

  /// Marks the transcript as waiting for more streamed content
  /// (source `busy` → `aria-busy`).
  final bool busy;

  /// Optional compact rail for navigating between message anchors
  /// (source `navigation`).
  final BeuiMessageScrollerNavigation? navigation;

  /// Accessible label for the optional navigation rail
  /// (source `navigationLabel`).
  final String navigationLabel;

  /// Explicit rail entries. When null and [navigation] is rail, entries are
  /// built from registered [BeuiMessageScrollerAnchor]s.
  final List<BeuiMessageScrollerRailItem>? railItems;

  /// Padding inside the scroll viewport (source `viewportClassName` px-3 py-4
  /// equivalent is supplied by the consumer / demo).
  final EdgeInsetsGeometry? padding;

  /// Scroll physics for the viewport. Defaults to platform clamping physics.
  final ScrollPhysics? scrollPhysics;

  @override
  State<BeuiMessageScroller> createState() => BeuiMessageScrollerState();
}

/// Public state so tests and hosts can call [scrollToEnd] / [scrollToId] and
/// read [isFollowing].
class BeuiMessageScrollerState extends State<BeuiMessageScroller> {
  ScrollController? _internalController;
  ScrollController get _controller =>
      widget.controller ?? (_internalController ??= ScrollController());

  final Map<String, _AnchorEntry> _anchors = <String, _AnchorEntry>{};
  final List<String> _anchorOrder = <String>[];

  bool _following = true;
  bool _programmatic = false;
  Timer? _programmaticClear;
  String _activeRailId = '';
  double _lastMaxExtent = 0;
  bool _postFramePending = false;

  /// Whether the scroller currently tracks the live edge.
  bool get isFollowing => widget.followOutput && _following;

  @override
  void initState() {
    super.initState();
    _following = widget.followOutput;
    if (widget.followOutput) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) scrollToEnd(smooth: false);
      });
    }
  }

  @override
  void didUpdateWidget(covariant BeuiMessageScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller &&
        oldWidget.controller == null) {
      _internalController?.dispose();
      _internalController = null;
    }
    if (widget.followOutput && !oldWidget.followOutput) {
      _following = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) scrollToEnd(smooth: false);
      });
    } else if (!widget.followOutput && oldWidget.followOutput) {
      _following = false;
    }
    // Content rebuild (streaming / append) — re-pin when following.
    if (isFollowing) _scheduleFollowIfNeeded();
  }

  @override
  void dispose() {
    _programmaticClear?.cancel();
    _internalController?.dispose();
    super.dispose();
  }

  void _setFollowing(bool next) {
    if (_following == next) return;
    setState(() => _following = next);
    widget.onFollowChange?.call(next);
  }

  void _register(_AnchorEntry entry) {
    final existing = _anchors[entry.id];
    if (existing != null) {
      existing.label = entry.label;
      existing.description = entry.description;
      existing.from = entry.from;
      // Keep the live key if the anchor remounted.
      if (existing.key != entry.key) {
        _anchors[entry.id] = entry;
      }
    } else {
      _anchors[entry.id] = entry;
      _anchorOrder.add(entry.id);
    }
    _scheduleRailSync();
  }

  void _unregister(String id) {
    if (_anchors.remove(id) != null) {
      _anchorOrder.remove(id);
      _scheduleRailSync();
    }
  }

  void _updateMeta(
    String id, {
    String? label,
    String? description,
    BeuiMessageFrom? from,
  }) {
    final entry = _anchors[id];
    if (entry == null) return;
    entry.label = label;
    entry.description = description;
    entry.from = from;
    _scheduleRailSync();
  }

  void _scheduleRailSync() {
    if (widget.navigation != BeuiMessageScrollerNavigation.rail) return;
    if (_postFramePending) return;
    _postFramePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _postFramePending = false;
      if (!mounted) return;
      _updateActiveRailItem();
      setState(() {});
    });
  }

  void _scheduleFollowIfNeeded() {
    if (!isFollowing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !isFollowing) return;
      if (!_controller.hasClients) return;
      final max = _controller.position.maxScrollExtent;
      if ((max - _controller.offset).abs() > 0.5 || max != _lastMaxExtent) {
        _lastMaxExtent = max;
        scrollToEnd(smooth: widget.smooth);
      }
    });
  }

  /// Scrolls to the live edge. Public for hosts/tests.
  void scrollToEnd({bool? smooth}) {
    if (!_controller.hasClients) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final useSmooth = (smooth ?? widget.smooth) && !reduce;
    final max = _controller.position.maxScrollExtent;
    _programmatic = true;
    _programmaticClear?.cancel();
    if (useSmooth) {
      _controller
          .animateTo(
            max,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
          )
          .whenComplete(() {
            _programmatic = false;
          });
      // Source clears the guard after ~320ms even if animation is interrupted.
      _programmaticClear = Timer(const Duration(milliseconds: 320), () {
        _programmatic = false;
      });
    } else {
      _controller.jumpTo(max);
      _programmatic = false;
    }
    _lastMaxExtent = max;
  }

  /// Scrolls so the anchor with [id] is centered in the viewport.
  /// Selecting the last item re-attaches follow (source rail last-item path).
  void scrollToId(String id) {
    final items = _resolvedRailItems();
    if (items.isEmpty) return;
    final lastId = items.last.id;
    if (id == lastId) {
      _setFollowing(true);
      scrollToEnd(smooth: widget.smooth);
      setState(() => _activeRailId = id);
      return;
    }

    final entry = _anchors[id];
    final ctx = entry?.key.currentContext;
    if (ctx == null) return;

    _setFollowing(false);
    setState(() => _activeRailId = id);
    _programmatic = true;
    _programmaticClear?.cancel();

    final reduce = MediaQuery.disableAnimationsOf(context);
    final useSmooth = widget.smooth && !reduce;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: useSmooth ? const Duration(milliseconds: 320) : Duration.zero,
      curve: Curves.easeOut,
    ).whenComplete(() {
      _programmatic = false;
    });
    if (useSmooth) {
      _programmaticClear = Timer(const Duration(milliseconds: 320), () {
        _programmatic = false;
      });
    } else {
      _programmatic = false;
    }
  }

  List<BeuiMessageScrollerRailItem> _resolvedRailItems() {
    final explicit = widget.railItems;
    if (explicit != null) return explicit;

    final out = <BeuiMessageScrollerRailItem>[];
    for (final id in _anchorOrder) {
      final a = _anchors[id];
      if (a == null) continue;
      out.add(
        BeuiMessageScrollerRailItem(
          id: a.id,
          label: a.label ?? 'Message',
          description: a.description,
          from: a.from,
        ),
      );
    }
    return out;
  }

  bool _isOverflowing() {
    if (!_controller.hasClients) return false;
    return _controller.position.maxScrollExtent > 1;
  }

  void _updateActiveRailItem() {
    if (widget.navigation != BeuiMessageScrollerNavigation.rail) return;
    if (!_controller.hasClients) return;

    final items = _resolvedRailItems();
    if (items.isEmpty) return;

    final pos = _controller.position;
    if (pos.pixels <= widget.followThreshold) {
      final first = items.first.id;
      if (_activeRailId != first) setState(() => _activeRailId = first);
      return;
    }

    final distance = pos.maxScrollExtent - pos.pixels;
    if (distance <= widget.followThreshold) {
      final last = items.last.id;
      if (_activeRailId != last) setState(() => _activeRailId = last);
      return;
    }

    // Nearest message center to viewport center (source updateActiveRailItem).
    final viewportBox =
        _controller.position.context.notificationContext?.findRenderObject()
            as RenderBox?;
    if (viewportBox == null || !viewportBox.hasSize) return;

    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    final viewportCenter = viewportTop + viewportBox.size.height / 2;

    String nearestId = items.first.id;
    var nearestDistance = double.infinity;
    for (final item in items) {
      final entry = _anchors[item.id];
      final box = entry?.key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final messageCenter =
          box.localToGlobal(Offset.zero).dy + box.size.height / 2;
      final d = (messageCenter - viewportCenter).abs();
      if (d < nearestDistance) {
        nearestDistance = d;
        nearestId = item.id;
      }
    }
    if (_activeRailId != nearestId) {
      setState(() => _activeRailId = nearestId);
    }
  }

  void _leaveLiveEdge() {
    _programmatic = false;
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;

    if (notification is UserScrollNotification) {
      if (notification.direction != ScrollDirection.idle) {
        _leaveLiveEdge();
      }
    }

    if (_programmatic) return false;

    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      final metrics = notification.metrics;
      if (metrics.axis != Axis.vertical) return false;
      final distance = metrics.maxScrollExtent - metrics.pixels;
      if (widget.followOutput) {
        _setFollowing(distance <= widget.followThreshold);
      }
      _updateActiveRailItem();
    }
    return false;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.home) {
      _leaveLiveEdge();
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final railItems = _resolvedRailItems();
    final showRail =
        widget.navigation == BeuiMessageScrollerNavigation.rail &&
        _isOverflowing() &&
        railItems.length > 1;

    final viewport = Focus(
      onKeyEvent: _onKey,
      child: Semantics(
        label: widget.label,
        liveRegion: true,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: !showRail, overscroll: false),
            child: SingleChildScrollView(
              controller: _controller,
              physics: widget.scrollPhysics,
              padding: widget.padding,
              // Source `[overflow-anchor:none]` — Flutter has no CSS overflow
              // anchor; programmatic follow replaces browser anchoring.
              child: Semantics(
                container: true,
                liveRegion: true,
                explicitChildNodes: true,
                child: _ContentSizeReporter(
                  onSize: (size) {
                    if (!isFollowing) return;
                    if ((size.height - _lastMaxExtent).abs() < 0.5 &&
                        _controller.hasClients &&
                        (_controller.position.maxScrollExtent -
                                    _controller.offset)
                                .abs() <
                            0.5) {
                      return;
                    }
                    _scheduleFollowIfNeeded();
                  },
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final scoped = _ScrollerScope(
      register: _register,
      unregister: _unregister,
      updateMeta: _updateMeta,
      child: viewport,
    );

    // Source exposes `aria-busy={busy}`. Flutter's Semantics has no `busy`
    // flag on this SDK — surface the state in the region label when set.
    final body = widget.busy
        ? Semantics(
            label: '${widget.label}, busy',
            container: true,
            liveRegion: true,
            child: scoped,
          )
        : scoped;

    if (widget.navigation != BeuiMessageScrollerNavigation.rail) {
      return body;
    }

    // Source: PreviewRail wraps the viewport; rail is absolute on the right.
    // BeuiPreviewRail is content-sized (n × track) and left-aligned, so this
    // port embeds a compact right-side rail that matches the message-scroller
    // layout (ticks origin-right, preview card to the left).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(right: showRail ? 40 : 0),
            child: body,
          ),
        ),
        if (showRail)
          Positioned(
            top: 12,
            bottom: 12,
            right: 4,
            width: 28,
            child: _MessageRail(
              label: widget.navigationLabel,
              items: railItems,
              activeId: _activeRailId.isEmpty
                  ? (railItems.isNotEmpty ? railItems.last.id : '')
                  : _activeRailId,
              onSelect: scrollToId,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Content size reporter (source ResizeObserver on content)
// ---------------------------------------------------------------------------

class _ContentSizeReporter extends SingleChildRenderObjectWidget {
  const _ContentSizeReporter({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderContentSizeReporter(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderContentSizeReporter renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _RenderContentSizeReporter extends RenderProxyBox {
  _RenderContentSizeReporter(this.onSize);

  ValueChanged<Size> onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    final s = size;
    if (_last != s) {
      _last = s;
      // Defer so callers can safely touch scroll positions.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onSize(s);
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Compact right-side message rail (source PreviewRail customisation)
// ---------------------------------------------------------------------------

/// One grid row per rail tick (source `<PreviewRail itemSize={14} …>`).
const double _railItemSize = 14;

class _MessageRail extends StatefulWidget {
  const _MessageRail({
    required this.label,
    required this.items,
    required this.activeId,
    required this.onSelect,
  });

  final String label;
  final List<BeuiMessageScrollerRailItem> items;
  final String activeId;
  final ValueChanged<String> onSelect;

  @override
  State<_MessageRail> createState() => _MessageRailState();
}

class _MessageRailState extends State<_MessageRail> {
  String? _hoveredId;
  String? _focusedId;

  String? get _displayedId => _hoveredId ?? _focusedId;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, Theme.of(context).brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final items = widget.items;
    final n = items.length;
    if (n == 0) return const SizedBox.shrink();

    final displayedId = _displayedId;
    final displayedIndex = displayedId == null
        ? -1
        : items.indexWhere((i) => i.id == displayedId);
    // Source `highlightActive` is on, so with no pointer the *active* item is
    // the highlighted one (`highlightedId = displayedId || selectedId`) — the
    // rail rests as a taper around the live edge, not a row of uniform stubs.
    final highlightedIndex = displayedIndex >= 0
        ? displayedIndex
        : items.indexWhere((i) => i.id == widget.activeId);

    // Source message-scroller ticks: origin-right, w-4, h-px, one fixed
    // `itemSize={14}` grid row each, `content-center` inside the rail box.
    return Semantics(
      label: widget.label,
      container: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const track = _railItemSize;
          final ticks = <Widget>[
            for (var i = 0; i < n; i++)
              _MessageRailTick(
                item: items[i],
                selected: items[i].id == widget.activeId,
                highlighted: i == highlightedIndex,
                scale: _scaleFor(i, highlightedIndex),
                track: track,
                reduce: reduce,
                activeColor: colors.foreground,
                inactiveColor: colors.mutedForeground,
                onHover: (hover) {
                  setState(() => _hoveredId = hover ? items[i].id : null);
                },
                onFocus: (focus) {
                  setState(() => _focusedId = focus ? items[i].id : null);
                },
                onTap: () => widget.onSelect(items[i].id),
              ),
          ];

          final preview = displayedIndex >= 0
              ? _MessageRailPreview(
                  item: items[displayedIndex],
                  colors: colors,
                  reduce: reduce,
                )
              : null;

          // `content-center`: the n×14 block is centred in the rail box, and
          // the source's `overflow-hidden` clips it when it is taller.
          final blockTop = math.max(
            0.0,
            (constraints.maxHeight - n * track) / 2,
          );

          return MouseRegion(
            onExit: (_) => setState(() => _hoveredId = null),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerRight,
              children: [
                // Preview card sits to the left of the ticks (source
                // previewSide="before", previewContainer left-3 right-8).
                if (preview != null)
                  Positioned(
                    right: 32,
                    left: null,
                    width: 256,
                    top: math.max(
                      0.0,
                      blockTop + (displayedIndex + 0.5) * track - 40,
                    ),
                    child: preview,
                  ),
                ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerRight,
                    maxHeight: double.infinity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: ticks,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  double _scaleFor(int index, int highlightedIndex) {
    if (highlightedIndex < 0) return 0.25;
    final distance = (index - highlightedIndex).abs();
    if (distance == 0) return 1.0;
    if (distance == 1) return 0.68;
    if (distance == 2) return 0.44;
    return 0.25;
  }
}

class _MessageRailTick extends StatelessWidget {
  const _MessageRailTick({
    required this.item,
    required this.selected,
    required this.highlighted,
    required this.scale,
    required this.track,
    required this.reduce,
    required this.activeColor,
    required this.inactiveColor,
    required this.onHover,
    required this.onFocus,
    required this.onTap,
  });

  final BeuiMessageScrollerRailItem item;
  final bool selected;
  final bool highlighted;
  final double scale;
  final double track;
  final bool reduce;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<bool> onHover;
  final ValueChanged<bool> onFocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const length = 16.0; // source w-4
    const thickness = 1.0; // source h-px

    final line = Container(
      width: length,
      height: thickness,
      // Source tints only the highlighted tick (`highlighted ? text-foreground`).
      color: highlighted ? activeColor : inactiveColor,
    );

    Widget scaled(double value) => Transform(
      alignment: Alignment.centerRight,
      transform: Matrix4.diagonal3Values(value, 1.0, 1.0),
      child: line,
    );

    final motion = motionFor(context, beuiSpringLayout, isMovement: true);
    final animated = reduce
        ? scaled(scale)
        : SingleMotionBuilder(
            value: scale,
            motion: motion,
            builder: (context, value, _) => scaled(value),
          );

    final sender = item.from == BeuiMessageFrom.user
        ? 'user'
        : item.from == BeuiMessageFrom.assistant
        ? 'assistant'
        : 'conversation';

    return Semantics(
      button: true,
      selected: selected,
      label: 'Go to $sender message: ${item.label}',
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
              width: 28,
              height: track,
              child: Align(alignment: Alignment.centerRight, child: animated),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageRailPreview extends StatelessWidget {
  const _MessageRailPreview({
    required this.item,
    required this.colors,
    required this.reduce,
  });

  final BeuiMessageScrollerRailItem item;
  final BeuiColors colors;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    // source DefaultPreview: `bg-card text-card-foreground shadow-sm
    // border-border rounded-2xl`, sized by the scroller's
    // `[&_[data-slot=preview-rail-card]]:h-20 … :p-3 … :overflow-hidden`.
    // `h-20` is the *card* box (border-box, padding included) — putting the
    // 80 inside the padding made the card 106 tall.
    final card = SizedBox(
      height: 80, // h-20
      child: Material(
        color: colors.card,
        elevation: 1, // shadow-sm
        shadowColor: colors.foreground.withValues(alpha: 0.12),
        clipBehavior: Clip.antiAlias, // overflow-hidden
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // rounded-2xl
          side: BorderSide(color: colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12), // p-3
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w500,
                  color: colors.cardForeground,
                ),
              ),
              if (item.description != null) ...[
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    item.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // Source preview enter: opacity + 4px rise + σ3 unblur over 180ms EASE_OUT.
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(item.id),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 180),
        curve: beuiEaseOut,
        builder: (context, t, child) {
          if (reduce) {
            return Opacity(opacity: t, child: child);
          }
          final blur = 3.0 * (1 - t);
          Widget out = Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 4 * (1 - t)),
              child: child,
            ),
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
        child: card,
      ),
    );
  }
}
