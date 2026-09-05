import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../theme/beui_agent_strings.dart';
import '../theme/beui_agent_theme.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import '_focus_ring.dart';
import '_hit_target.dart';
import '_transcript.dart';
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
///
/// ## Announcements
///
/// The scroller owns the conversation's **single** live region. Descendant
/// streaming surfaces push whole sentences into it rather than opening live
/// regions of their own — see [BeuiStreamingResponse.announce], which resolves
/// to false by default when a scroller is above it. Set [announce] to false to
/// silence the transcript entirely (for a preview, or when the host app owns
/// announcements).
///
/// ## Long transcripts
///
/// The default constructor lays every message out eagerly, which re-measures
/// the whole transcript on each streamed token. Past a few dozen turns use
/// [BeuiMessageScroller.builder], which builds rows lazily through a
/// [ListView.builder] and keeps token cadence O(visible rows).
class BeuiMessageScroller extends StatefulWidget {
  /// Creates a message scroller over an eagerly built transcript.
  const BeuiMessageScroller({
    required Widget this.child,
    this.controller,
    this.followOutput = true,
    this.followThreshold = 56,
    this.smooth = true,
    this.onFollowChange,
    this.label,
    this.busy = false,
    this.announce = true,
    this.navigation,
    this.navigationLabel,
    this.railItems,
    this.padding,
    this.scrollPhysics,
    this.showJumpToLatest = true,
    this.jumpToLatestLabel,
    this.onUnreadCountChange,
    super.key,
  }) : itemCount = null,
       itemBuilder = null;

  /// Creates a message scroller over a **lazily built** transcript.
  ///
  /// Rows are built on demand, so a thousand-turn conversation costs the same
  /// per streamed token as a ten-turn one. Everything else — follow behaviour,
  /// the rail, the jump-to-latest pill, announcements — is identical.
  ///
  /// Rail anchors still register through [BeuiMessageScrollerAnchor], but only
  /// rows that have been built are registered, so supply [railItems]
  /// explicitly when using the rail with a lazy transcript.
  ///
  /// ```dart
  /// BeuiMessageScroller.builder(
  ///   itemCount: messages.length,
  ///   itemBuilder: (context, i) => BeuiMessage(...),
  /// )
  /// ```
  const BeuiMessageScroller.builder({
    required int this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
    this.controller,
    this.followOutput = true,
    this.followThreshold = 56,
    this.smooth = true,
    this.onFollowChange,
    this.label,
    this.busy = false,
    this.announce = true,
    this.navigation,
    this.navigationLabel,
    this.railItems,
    this.padding,
    this.scrollPhysics,
    this.showJumpToLatest = true,
    this.jumpToLatestLabel,
    this.onUnreadCountChange,
    super.key,
  }) : child = null,
       assert(itemCount >= 0);

  /// Transcript content — typically a [BeuiMessageGroup] of anchored messages.
  ///
  /// Null when built through [BeuiMessageScroller.builder].
  final Widget? child;

  /// Row count for [BeuiMessageScroller.builder]. Null for the eager
  /// constructor.
  final int? itemCount;

  /// Row builder for [BeuiMessageScroller.builder]. Null for the eager
  /// constructor.
  final IndexedWidgetBuilder? itemBuilder;

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
  /// Defaults to [BeuiAgentStrings.conversation].
  final String? label;

  /// Marks the transcript as waiting for more streamed content
  /// (source `busy` → `aria-busy`).
  final bool busy;

  /// Whether the transcript speaks streamed text through its single live
  /// region (default true).
  ///
  /// This is the *only* live region in a conversation. Descendant
  /// [BeuiStreamingResponse]s detect the scroller and stay quiet, pushing whole
  /// sentences here instead, so a reader hears the answer once rather than
  /// hearing the transcript re-read on every token.
  final bool announce;

  /// Optional compact rail for navigating between message anchors
  /// (source `navigation`).
  final BeuiMessageScrollerNavigation? navigation;

  /// Accessible label for the optional navigation rail
  /// (source `navigationLabel`). Defaults to
  /// [BeuiAgentStrings.messageNavigation].
  final String? navigationLabel;

  /// Explicit rail entries. When null and [navigation] is rail, entries are
  /// built from registered [BeuiMessageScrollerAnchor]s.
  final List<BeuiMessageScrollerRailItem>? railItems;

  /// Padding inside the scroll viewport.
  ///
  /// Defaults to the theme's `layout.conversationGutter` when it has been set,
  /// otherwise to the source's own `px-3 py-4`. Prior to the UX pass this
  /// defaulted to zero and *every* call site in the repo overrode it, which is
  /// the definition of a wrong default.
  final EdgeInsetsGeometry? padding;

  /// Scroll physics for the viewport. Defaults to platform clamping physics.
  final ScrollPhysics? scrollPhysics;

  /// Shows the built-in "jump to latest" pill when the reader has scrolled
  /// away from the live edge (default true).
  ///
  /// The pill carries an unread count of messages that arrived while detached.
  /// Set false to render nothing and drive your own affordance from
  /// [onFollowChange] / [onUnreadCountChange] + [BeuiMessageScrollerState.scrollToEnd].
  final bool showJumpToLatest;

  /// Accessible label and tooltip for the jump-to-latest pill. Overrides
  /// [BeuiAgentStrings.jumpToLatest] for this scroller.
  final String? jumpToLatestLabel;

  /// Reports the number of messages that have arrived since the reader left
  /// the live edge. Fires with 0 when the reader returns.
  final ValueChanged<int>? onUnreadCountChange;

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

  /// Guards the programmatic-scroll flag against a stale timer or a settled
  /// animation belonging to an earlier follow. Every [scrollToEnd] /
  /// [scrollToId] bumps it; late callbacks compare and bail.
  int _scrollToken = 0;

  /// True while a smooth follow glide is in flight. A second growth arriving
  /// inside that window is the signal that the stream is outpacing the 320ms
  /// animation, and the next follow jumps instead.
  bool _animatingFollow = false;

  /// Messages registered since the reader left the live edge.
  int _unread = 0;

  final GlobalKey<BeuiTranscriptLiveRegionState> _liveRegionKey =
      GlobalKey<BeuiTranscriptLiveRegionState>();

  /// Whether the scroller currently tracks the live edge.
  bool get isFollowing => widget.followOutput && _following;

  /// Messages that arrived while the reader was away from the live edge.
  /// Resets to 0 the moment following resumes.
  int get unreadCount => _unread;

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
    setState(() {
      _following = next;
      // Returning to the live edge clears the backlog — the reader has now
      // seen everything.
      if (next && _unread != 0) {
        _unread = 0;
        widget.onUnreadCountChange?.call(0);
      }
    });
    widget.onFollowChange?.call(next);
  }

  /// Counts one newly registered message toward the unread badge.
  ///
  /// Anchors register from `didChangeDependencies`, i.e. inside the build
  /// phase, so the state change is deferred to the next frame rather than
  /// calling `setState` mid-build.
  void _bumpUnread() {
    if (isFollowing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || isFollowing) return;
      setState(() => _unread++);
      widget.onUnreadCountChange?.call(_unread);
    });
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
      _bumpUnread();
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
  ///
  /// Pass `smooth: false` to force a jump. Otherwise the choice is made here:
  /// a discrete append glides, a stream jumps. See [_followDuration].
  void scrollToEnd({bool? smooth}) {
    if (!_controller.hasClients) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    var useSmooth = (smooth ?? widget.smooth) && !reduce;

    // The discriminator is cadence, not distance: if the previous glide has
    // not finished, this growth is part of a stream, so jump — restarting a
    // 320ms `animateTo` on every token would never let one complete. A
    // discrete append (a whole message arriving, seconds apart) still glides.
    if (useSmooth && _animatingFollow) useSmooth = false;

    final max = _controller.position.maxScrollExtent;
    final token = ++_scrollToken;
    _programmaticClear?.cancel();
    _programmatic = true;

    if (useSmooth) {
      _animatingFollow = true;
      _controller
          .animateTo(max, duration: _followDuration, curve: Curves.easeOut)
          .whenComplete(() => _clearProgrammatic(token));
      // Source clears the guard after ~320ms even if animation is interrupted.
      // Token-gated so a *later* follow's guard is never cleared by an earlier
      // timer — the re-arm loop the audit found.
      _programmaticClear = Timer(
        _followDuration,
        () => _clearProgrammatic(token),
      );
    } else {
      _animatingFollow = false;
      _controller.jumpTo(max);
      _clearProgrammatic(token);
    }
    _lastMaxExtent = max;
  }

  /// Live-edge glide duration, matching the source's programmatic-scroll lock.
  static const Duration _followDuration = Duration(milliseconds: 320);

  /// Releases the programmatic guard if [token] is still the current scroll.
  void _clearProgrammatic(int token) {
    if (token != _scrollToken) return;
    _animatingFollow = false;
    _programmatic = false;
    _programmaticClear?.cancel();
    _programmaticClear = null;
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
    final token = ++_scrollToken;
    _programmaticClear?.cancel();
    _programmatic = true;

    final reduce = MediaQuery.disableAnimationsOf(context);
    final useSmooth = widget.smooth && !reduce;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: useSmooth ? _followDuration : Duration.zero,
      curve: Curves.easeOut,
    ).whenComplete(() => _clearProgrammatic(token));
    if (useSmooth) {
      _programmaticClear = Timer(
        _followDuration,
        () => _clearProgrammatic(token),
      );
    } else {
      _clearProgrammatic(token);
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
    // Invalidate any in-flight follow so its completion callback cannot
    // re-assert the guard over the reader's own scroll.
    _scrollToken++;
    _animatingFollow = false;
    _programmatic = false;
    _programmaticClear?.cancel();
    _programmaticClear = null;
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

  /// The viewport padding, with a real default.
  ///
  /// `BeuiAgentLayout.conversationGutter` ships as `EdgeInsets.zero`, so before
  /// this fallback the scroller rendered messages flush against its own edges
  /// and every demo in the repo passed `padding:` to undo it.
  EdgeInsetsGeometry _resolvedPadding(BuildContext context) {
    final explicit = widget.padding;
    if (explicit != null) return explicit;
    final gutter = BeuiAgentTheme.of(context).layout.conversationGutter;
    if (gutter != EdgeInsets.zero) return gutter;
    // Source `viewportClassName="px-3 py-4"`.
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 16);
  }

  Widget _buildScrollable(BuildContext context, {required bool showRail}) {
    final padding = _resolvedPadding(context);
    final behavior = ScrollConfiguration.of(
      context,
    ).copyWith(scrollbars: !showRail, overscroll: false);

    // The lazy path builds only the rows in (and near) the viewport, so a
    // streamed token re-measures a screenful rather than the whole transcript.
    final itemBuilder = widget.itemBuilder;
    if (itemBuilder != null) {
      return ScrollConfiguration(
        behavior: behavior,
        child: ListView.builder(
          controller: _controller,
          physics: widget.scrollPhysics,
          padding: padding,
          itemCount: widget.itemCount ?? 0,
          itemBuilder: itemBuilder,
        ),
      );
    }

    return ScrollConfiguration(
      behavior: behavior,
      child: SingleChildScrollView(
        controller: _controller,
        physics: widget.scrollPhysics,
        padding: padding,
        // Source `[overflow-anchor:none]` — Flutter has no CSS overflow
        // anchor; programmatic follow replaces browser anchoring.
        child: _ContentSizeReporter(
          onSize: (size) {
            if (!isFollowing) return;
            if ((size.height - _lastMaxExtent).abs() < 0.5 &&
                _controller.hasClients &&
                (_controller.position.maxScrollExtent - _controller.offset)
                        .abs() <
                    0.5) {
              return;
            }
            _scheduleFollowIfNeeded();
          },
          child: widget.child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final railItems = _resolvedRailItems();
    final isOverflowing =
        _controller.hasClients && _controller.position.maxScrollExtent > 1;
    final showRail =
        widget.navigation == BeuiMessageScrollerNavigation.rail &&
        isOverflowing &&
        railItems.length > 1;

    // The transcript is a real, *visible* tab stop. Before this the
    // keyboard escape hatch (ArrowUp / PageUp / Home releasing follow) sat
    // behind a bare `Focus` with no indicator, so a keyboard reader had to Tab
    // into something invisible before it worked.
    // Every user-facing default in this widget resolves through the theme
    // role, so a non-English app relabels the transcript once instead of at
    // every call site.
    final strings = BeuiAgentTheme.of(context).strings;
    final transcriptLabel = widget.label ?? strings.conversation;

    final viewport = _ScrollerFocus(
      onKey: _onKey,
      label: transcriptLabel,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: _buildScrollable(context, showRail: showRail),
      ),
    );

    final scoped = _ScrollerScope(
      register: _register,
      unregister: _unregister,
      updateMeta: _updateMeta,
      child: viewport,
    );

    // One live region for the whole conversation, mounted here, above the
    // transcript. It replaces the three-to-five nested regions the audit found
    // — all with constant labels, so none of them ever announced the streamed
    // text they were wrapping. Descendant streaming surfaces detect this scope
    // and push whole sentences into it instead of opening their own.
    //
    // Source exposes `aria-busy={busy}`; Flutter's Semantics has no busy flag
    // on this SDK, so the state rides the *static* container label — which is
    // safe precisely because it is no longer a live region.
    Widget body = BeuiTranscriptLiveRegion(
      key: _liveRegionKey,
      label: widget.busy ? '$transcriptLabel, busy' : transcriptLabel,
      enabled: widget.announce,
      child: scoped,
    );

    if (widget.showJumpToLatest) {
      body = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: body),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 12,
            child: Align(
              child: _JumpToLatest(
                visible: widget.followOutput && !isFollowing,
                label: widget.jumpToLatestLabel ?? strings.jumpToLatest,
                unread: _unread,
                colors: colors,
                onTap: () {
                  _setFollowing(true);
                  scrollToEnd(smooth: true);
                },
              ),
            ),
          ),
        ],
      );
    }

    if (widget.navigation != BeuiMessageScrollerNavigation.rail) {
      return body;
    }

    // Source: PreviewRail wraps the viewport; rail is absolute on the trailing
    // edge. BeuiPreviewRail is content-sized (n × track) and start-aligned, so
    // this port embeds a compact trailing rail that matches the message-scroller
    // layout (ticks origin-end, preview card before them).
    return LayoutBuilder(
      builder: (context, constraints) {
        final hostWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _railPreviewWidth + 64;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsetsDirectional.only(end: showRail ? 40 : 0),
                child: body,
              ),
            ),
            if (showRail)
              PositionedDirectional(
                top: 12,
                bottom: 12,
                end: 4,
                width: 28,
                child: _MessageRail(
                  label: widget.navigationLabel ?? strings.messageNavigation,
                  items: railItems,
                  maxPreviewWidth: hostWidth,
                  activeId: _activeRailId.isEmpty
                      ? (railItems.isNotEmpty ? railItems.last.id : '')
                      : _activeRailId,
                  onSelect: scrollToId,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The transcript's focusable viewport.
///
/// A keyboard reader can Tab to the transcript, see that it has focus, and use
/// ArrowUp / PageUp / Home to leave the live edge. The ring is painted outside
/// layout so taking focus does not reflow the conversation.
class _ScrollerFocus extends StatefulWidget {
  const _ScrollerFocus({
    required this.onKey,
    required this.label,
    required this.child,
  });

  final KeyEventResult Function(FocusNode, KeyEvent) onKey;
  final String label;
  final Widget child;

  @override
  State<_ScrollerFocus> createState() => _ScrollerFocusState();
}

class _ScrollerFocusState extends State<_ScrollerFocus> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      focusable: true,
      focused: _focused,
      child: Focus(
        onKeyEvent: widget.onKey,
        onFocusChange: (v) {
          if (_focused == v) return;
          setState(() => _focused = v);
        },
        child: BeuiFocusRing(
          focused: _focused,
          borderRadius: BorderRadius.circular(
            BeuiAgentTheme.of(context).shapes.cardRadius,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Jump-to-latest pill
// ---------------------------------------------------------------------------

/// Pill exit — deliberately faster than the spring entrance, per the repo
/// motion rules.
const _jumpExitMotion = CurvedMotion(Duration(milliseconds: 140), beuiEaseOut);

/// Reduced-motion cross-fade for the pill: no travel, no scale, keep opacity.
const _jumpReduceMotion = CurvedMotion(
  Duration(milliseconds: 120),
  beuiEaseOut,
);

/// "Jump to latest" affordance shown while the reader is away from the live
/// edge.
///
/// The scroller already computed everything this needs — `_following`,
/// `onFollowChange`, `scrollToEnd()` — and rendered nothing, so a reader who
/// scrolled up during a stream had no way back other than dragging.
///
/// Visual language: a muted pill with a hairline edge, matching
/// [BeuiMessageMarker]. It springs in (opacity + 8px rise + 0.92→1 scale) and
/// leaves on a 140ms fade.
class _JumpToLatest extends StatefulWidget {
  const _JumpToLatest({
    required this.visible,
    required this.label,
    required this.unread,
    required this.colors,
    required this.onTap,
  });

  final bool visible;
  final String label;
  final int unread;
  final BeuiColors colors;
  final VoidCallback onTap;

  @override
  State<_JumpToLatest> createState() => _JumpToLatestState();
}

class _JumpToLatestState extends State<_JumpToLatest> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final agent = BeuiAgentTheme.of(context);
    final colors = widget.colors;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final unread = widget.unread;
    final label = unread > 0
        ? '${widget.label}, $unread new ${unread == 1 ? 'message' : 'messages'}'
        : widget.label;

    // The slop wrapper is outermost, and that placement is
    // load-bearing — an ancestor RenderBox rejects a pointer outside
    // its own box before any child's hitTest runs, so a nested
    // BeuiMinHitTarget is dead weight.
    final pill = BeuiMinHitTarget(
      child: Semantics(
        button: true,
        label: label,
        child: Tooltip(
          message: widget.label,
          // The Semantics label above already names this control; a
          // Tooltip that also contributes semantics makes a reader say it twice.
          excludeFromSemantics: true,
          child: FocusableActionDetector(
            mouseCursor: SystemMouseCursors.click,
            onShowHoverHighlight: (v) => setState(() => _hovered = v),
            onShowFocusHighlight: (v) => setState(() => _focused = v),
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            },
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  widget.onTap();
                  return null;
                },
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: widget.onTap,
              child: BeuiFocusRing(
                focused: _focused,
                borderRadius: BorderRadius.circular(999),
                child: SingleMotionBuilder(
                  // 0.97 is this library's press scale.
                  value: (_pressed && !reduce) ? 0.97 : 1.0,
                  motion: motionFor(context, beuiSpringPress, isMovement: true),
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _hovered ? colors.secondary : colors.muted,
                      borderRadius: agent.shapes.pill,
                      border: Border.all(
                        color: colors.borderStrong,
                        width: agent.structure.borderWidth,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.foreground.withValues(alpha: 0.10),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        10,
                        6,
                        12,
                        6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.arrow_down,
                            size: 14,
                            color: colors.foreground,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.label,
                            style: agent.typography.action.copyWith(
                              color: colors.foreground,
                            ),
                          ),
                          if (unread > 0) ...[
                            const SizedBox(width: 6),
                            _UnreadBadge(count: unread, colors: colors),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final target = widget.visible ? 1.0 : 0.0;
    final base = widget.visible ? beuiSpringSwap : _jumpExitMotion;

    if (reduce) {
      // Movement dropped, opacity kept — per channel, per the project rule.
      return SingleMotionBuilder(
        value: target,
        motion: motionFor(context, _jumpReduceMotion, isMovement: false),
        builder: (context, t, child) {
          final v = t.clamp(0.0, 1.0);
          if (v <= 0.001) return const SizedBox.shrink();
          return IgnorePointer(
            ignoring: !widget.visible,
            child: ExcludeSemantics(
              excluding: !widget.visible,
              child: Opacity(opacity: v, child: child),
            ),
          );
        },
        child: pill,
      );
    }

    return SingleMotionBuilder(
      value: target,
      motion: motionFor(context, base, isMovement: true),
      builder: (context, t, child) {
        final v = t.clamp(0.0, 1.0);
        if (v <= 0.001) return const SizedBox.shrink();
        return IgnorePointer(
          ignoring: !widget.visible,
          child: ExcludeSemantics(
            excluding: !widget.visible,
            child: Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - v)),
                child: Transform.scale(scale: 0.92 + 0.08 * v, child: child),
              ),
            ),
          ),
        );
      },
      child: pill,
    );
  }
}

/// Count of messages that landed while the reader was away.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.colors});

  final int count;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minWidth: 18),
        height: 18,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: colors.foreground,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: TextStyle(
            fontSize: 11,
            height: 1,
            letterSpacing: 0,
            fontWeight: FontWeight.w600,
            color: colors.background,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
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

/// Floor for the compressed rail pitch.
///
/// The source's fixed 14px pitch clips silently past ~28 messages in a 400px
/// rail — the ticks for older turns are simply not rendered, with no scroll,
/// no fade, and no cue that they exist. The rail now compresses toward this
/// floor instead, which fits ~66 turns in the same 400px, and only becomes
/// scrollable beyond that.
const double _railMinItemSize = 6;

/// Height of the fade at each end of a scrollable rail.
const double _railFadeExtent = 12;

/// Preview card geometry (source `[&_[data-slot=preview-rail-card]]:h-20`).
const double _railPreviewHeight = 80;
const double _railPreviewWidth = 256;

/// Gap the preview card leaves between itself and the transcript's edge.
const double _railPreviewMargin = 8;

class _MessageRail extends StatefulWidget {
  const _MessageRail({
    required this.label,
    required this.items,
    required this.activeId,
    required this.onSelect,
    required this.maxPreviewWidth,
  });

  final String label;
  final List<BeuiMessageScrollerRailItem> items;
  final String activeId;
  final ValueChanged<String> onSelect;

  /// Width of the transcript the rail overlays — the ceiling for the preview
  /// card.
  final double maxPreviewWidth;

  @override
  State<_MessageRail> createState() => _MessageRailState();
}

class _MessageRailState extends State<_MessageRail> {
  String? _hoveredId;
  String? _focusedId;
  final ScrollController _railScroll = ScrollController();

  /// The rail's scroll offset, which only the preview card's position needs.
  /// A `ValueNotifier` so scrolling the rail doesn't rebuild the whole rail
  /// (ticks, hover/focus state, and all) on every scroll tick — only the
  /// `ValueListenableBuilder` around the preview card does.
  final ValueNotifier<double> _railOffset = ValueNotifier(0);

  String? get _displayedId => _hoveredId ?? _focusedId;

  @override
  void initState() {
    super.initState();
    _railScroll.addListener(_onRailScroll);
  }

  @override
  void dispose() {
    _railScroll
      ..removeListener(_onRailScroll)
      ..dispose();
    _railOffset.dispose();
    super.dispose();
  }

  void _onRailScroll() {
    // The preview card is positioned against tick geometry, so it has to track
    // the rail's own scroll or it detaches from the tick it describes.
    _railOffset.value = _railScroll.offset;
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
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

    // Source message-scroller ticks: origin-end, w-4, h-px, one fixed
    // `itemSize={14}` grid row each, `content-center` inside the rail box.
    return Semantics(
      label: widget.label,
      container: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : n * _railItemSize;

          // Compress the pitch before clipping anything. Only when even
          // the floor overflows does the rail become scrollable — and then it
          // says so, with a fade at each end.
          var track = _railItemSize;
          if (n * track > available && n > 0) {
            track = (available / n).clamp(_railMinItemSize, _railItemSize);
          }
          final blockHeight = n * track;
          final scrollable = blockHeight > available + 0.5;

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

          final column = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: ticks,
          );

          // `content-center`: the n×track block is centred in the rail box
          // while it fits; once it scrolls it starts at the top. The
          // scrolled case is read inside the preview's ValueListenableBuilder
          // below, off the live `_railOffset` rather than this static value.
          final restBlockTop = math.max(0.0, (available - blockHeight) / 2);

          Widget stack;
          if (scrollable) {
            stack = ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false, overscroll: false),
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) {
                  final fade = (_railFadeExtent / bounds.height).clamp(
                    0.0,
                    0.4,
                  );
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [
                      Colors.transparent,
                      Colors.black,
                      Colors.black,
                      Colors.transparent,
                    ],
                    stops: [0.0, fade, 1 - fade, 1.0],
                  ).createShader(bounds);
                },
                child: SingleChildScrollView(
                  controller: _railScroll,
                  child: column,
                ),
              ),
            );
          } else {
            stack = ClipRect(
              child: OverflowBox(
                alignment: AlignmentDirectional.centerEnd,
                maxHeight: double.infinity,
                child: column,
              ),
            );
          }

          Widget? preview;
          if (displayedIndex >= 0) {
            preview = _MessageRailPreview(
              item: items[displayedIndex],
              colors: colors,
              reduce: reduce,
            );
          }

          return MouseRegion(
            onExit: (_) => setState(() => _hoveredId = null),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: AlignmentDirectional.centerEnd,
              children: [
                // Preview card sits before the ticks (source
                // previewSide="before", previewContainer left-3 right-8).
                if (preview != null)
                  ValueListenableBuilder<double>(
                    valueListenable: _railOffset,
                    child: preview,
                    builder: (context, railOffset, child) {
                      final blockTop = scrollable ? -railOffset : restBlockTop;
                      return PositionedDirectional(
                        end: 32,
                        // The card is 256px wide and used to be pinned there
                        // regardless of how much room existed — below about
                        // 290px of component width it painted outside its own
                        // bounds and over the neighbouring UI. It now takes
                        // whatever the transcript can spare, down to a
                        // readable floor.
                        width: math.min(
                          _railPreviewWidth,
                          math.max(
                            120.0,
                            widget.maxPreviewWidth - 32 - _railPreviewMargin,
                          ),
                        ),
                        top:
                            (blockTop +
                                    (displayedIndex + 0.5) * track -
                                    _railPreviewHeight / 2)
                                .clamp(
                                  0.0,
                                  math.max(0.0, available - _railPreviewHeight),
                                ),
                        child: child!,
                      );
                    },
                  ),
                Positioned.fill(child: stack),
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

    // Directional origin: ticks grow from the trailing edge, which is the
    // right in LTR and the left in RTL — `Transform` resolves the geometry
    // against the ambient `Directionality`.
    Widget scaled(double value) => Transform(
      alignment: AlignmentDirectional.centerEnd,
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
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: animated,
              ),
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
    final agent = BeuiAgentTheme.of(context);
    final card = SizedBox(
      height: _railPreviewHeight, // h-20
      child: Material(
        color: colors.card,
        elevation: 1, // shadow-sm
        shadowColor: colors.foreground.withValues(alpha: 0.12),
        clipBehavior: Clip.antiAlias, // overflow-hidden
        shape: RoundedRectangleBorder(
          borderRadius: agent.shapes.card,
          side: BorderSide(
            color: colors.border,
            width: agent.structure.borderWidth,
          ),
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
                style: agent.typography.action.copyWith(
                  height: 16 / 12,
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
                    style: agent.typography.status.copyWith(
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
          final blur = beuiBlurSigma(6) * (1 - t);
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
