import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart' show SingleMotionBuilder;

/// The identity of a masonry item — a `String` or `int` returned by
/// [BeuiInfiniteMasonry.getItemKey].
///
/// Mirrors the source's `InfiniteMasonryKey = string | number | bigint`. Dart
/// has no untyped union, so this is [Object]; use a `String` or `int` whose
/// `==`/`hashCode` are stable across rebuilds (keys drive per-item reveal
/// bookkeeping and element identity).
typedef BeuiInfiniteMasonryKey = Object;

/// Returns the stable [BeuiInfiniteMasonryKey] for [item] at [index].
typedef BeuiMasonryKeyBuilder<T> =
    BeuiInfiniteMasonryKey Function(T item, int index);

/// Builds the widget for [item] at [index].
typedef BeuiMasonryItemBuilder<T> = Widget Function(T item, int index);

/// Estimates the pixel height of [item] at [index] before layout, used only for
/// shortest-column lane assignment and the prefetch trigger distance. The actual
/// rendered height is measured by Flutter — see [BeuiInfiniteMasonry].
typedef BeuiMasonrySizeEstimator<T> = double Function(T item, int index);

/// A columned, infinite-scroll masonry feed — the Flutter port of beUI's
/// `infinite-masonry` block.
///
/// Items flow into a responsive number of columns (shortest-column-first), the
/// feed auto-loads more as you approach the end, and it renders empty / loading
/// / end / error tail states. New items (those appended after the initial batch)
/// reveal with a per-lane-staggered spring rise + fade.
///
/// ## Virtualization simplification (read this)
///
/// The source uses `@tanstack/react-virtual` (`useVirtualizer` with
/// `lanes = columns`) for **windowed** virtualization: it positions every item
/// absolutely from *measured* heights and only mounts the DOM nodes inside the
/// scroll viewport + `overscan`. Flutter has no equivalent — neither `SliverGrid`
/// nor `flutter_staggered_grid_view` does windowed, variable-height masonry with
/// dynamic measurement, and doing it faithfully requires a bespoke `RenderSliver`
/// with a measurement feedback loop (which risks layout jitter and never-settling
/// tests).
///
/// This port therefore implements a **correct, eager masonry** rather than true
/// windowing, matching the *observable* behavior and API:
///
/// * **Responsive columns** — `columns = min(maxColumns, max(1,
///   floor((width + gap) / (minColumnWidth + gap))))`, from a [LayoutBuilder]
///   (the Flutter analog of the source's `ResizeObserver`), identical formula.
/// * **Shortest-column-first distribution** — items are assigned to the currently
///   shortest lane using [estimateSize], exactly as react-virtual assigns lanes
///   from estimates *before* measurement. Each column is a real Flutter [Column],
///   so items lay out at their **true measured heights** — no overlap, no
///   estimate-driven position drift (a fidelity improvement over absolute
///   estimate positioning).
/// * **Lazy at the feed level** — the "infinite" behavior lives in [onLoadMore]:
///   more items are fetched on demand as you scroll near the end. Per-item DOM
///   windowing is *not* replicated; all currently-loaded items are built.
/// * **[overscan] / [estimateSize] are threaded through, not dropped** —
///   [estimateSize] drives lane assignment and the prefetch distance; [overscan]
///   widens the prefetch trigger window (its react-virtual role of enlarging the
///   render window has no analog in an eager build, so it is repurposed to the
///   nearest observable effect and documented here).
///
/// **Trade-off:** memory and build cost grow with the total number of loaded
/// items. For very long feeds, consumers should cap the retained [items]
/// (windowing their own data), just as they would page a `ListView`.
///
/// ## Motion
///
/// Items with index `>= items.length at mount` reveal (unless [animateItems] is
/// false or reduced motion is on): `y: 12 → 0` on [beuiSpringPanel] plus
/// `opacity: 0 → 1` over 200ms [beuiEaseOut], both delayed by
/// `min(lane, 3) * 0.04s`. Each key reveals **once** — re-layout (e.g. a column
/// count change) never re-triggers it. Reduced motion drops the reveal entirely
/// (the source's `useReducedMotion()` branch).
///
/// ## Layout
///
/// This is a scrollable feed and expects a **bounded height** from its parent
/// (wrap it in a `SizedBox`/`Expanded`), like any vertical scroll view.
class BeuiInfiniteMasonry<T> extends StatefulWidget {
  /// Creates an infinite masonry feed.
  const BeuiInfiniteMasonry({
    required this.items,
    required this.getItemKey,
    required this.renderItem,
    required this.onLoadMore,
    required this.hasMore,
    this.loading = false,
    this.error,
    this.onRetry,
    this.estimateSize,
    this.renderLoadingItem,
    this.emptyState,
    this.endState,
    this.minColumnWidth = 208,
    this.maxColumns = 4,
    this.gap = 12,
    this.overscan = 4,
    this.prefetch = 3,
    this.animateItems = true,
    this.ariaLabel = 'Infinite masonry feed',
    this.controller,
    super.key,
  }) : assert(maxColumns >= 1, 'maxColumns must be >= 1'),
       assert(minColumnWidth > 0, 'minColumnWidth must be > 0'),
       assert(gap >= 0, 'gap must be >= 0');

  /// The currently loaded items, in feed order.
  final List<T> items;

  /// Returns the stable key for an item (source `getItemKey`).
  final BeuiMasonryKeyBuilder<T> getItemKey;

  /// Builds an item's card (source `renderItem`).
  final BeuiMasonryItemBuilder<T> renderItem;

  /// Called to fetch the next page when the feed nears its end. May be async;
  /// the feed guards against overlapping calls (source `onLoadMore`).
  final FutureOr<void> Function() onLoadMore;

  /// Whether more items remain to load (source `hasMore`).
  final bool hasMore;

  /// Whether a load is in flight — drives the pulsing skeleton tail (source
  /// `loading`).
  final bool loading;

  /// When non-null, renders an error tail card (with [onRetry]) instead of the
  /// loading skeletons (source `error`).
  final Widget? error;

  /// Retry callback shown on the error tail card (source `onRetry`).
  final VoidCallback? onRetry;

  /// Estimated item height for lane assignment and the prefetch distance. The
  /// real height is measured at layout. Defaults to `240` (source
  /// `estimateSize = () => 240`).
  final BeuiMasonrySizeEstimator<T>? estimateSize;

  /// Builds a loading skeleton for the tail at [index] (0-based within the tail).
  /// Defaults to a pulsing placeholder card (source `renderLoadingItem`).
  final Widget Function(int index)? renderLoadingItem;

  /// Shown when the feed is empty and no more will load. Defaults to an Inbox
  /// glyph + copy (source `emptyState`).
  final Widget? emptyState;

  /// Footer shown below the grid once everything has loaded (`!hasMore`) and the
  /// feed is non-empty (source `endState`).
  final Widget? endState;

  /// Minimum column width; smaller viewports collapse to fewer columns (source
  /// `minColumnWidth = 208`).
  final double minColumnWidth;

  /// Hard cap on the responsive column count (source `maxColumns = 4`).
  final int maxColumns;

  /// Gap between columns and between items, in px (source `gap = 12`).
  final double gap;

  /// Extra prefetch window depth. Threaded through to widen the load-more
  /// trigger distance (source `overscan = 4`; see the class docs on how its
  /// react-virtual role maps here).
  final int overscan;

  /// Loads more when the feed scrolls within roughly this many items of the end
  /// (source `prefetch = 3`).
  final int prefetch;

  /// Whether newly appended items reveal with the stagger spring. Ignored under
  /// reduced motion (source `animateItems = true`).
  final bool animateItems;

  /// Accessibility label for the feed region (source `ariaLabel`).
  final String ariaLabel;

  /// Optional external scroll controller. When null, an internal one is created
  /// and disposed.
  final ScrollController? controller;

  @override
  State<BeuiInfiniteMasonry<T>> createState() => _BeuiInfiniteMasonryState<T>();
}

class _BeuiInfiniteMasonryState<T> extends State<BeuiInfiniteMasonry<T>> {
  ScrollController? _internalController;
  ScrollController get _controller =>
      widget.controller ?? (_internalController ??= ScrollController());

  /// Keys revealed at least once — a reveal never fires twice for the same item
  /// (the source's `revealedKeysRef`).
  final Set<BeuiInfiniteMasonryKey> _revealedKeys = <BeuiInfiniteMasonryKey>{};

  /// Item count captured at mount; only later arrivals reveal (source
  /// `initialItemCountRef`).
  late int _initialItemCount;

  /// Guards against overlapping [BeuiInfiniteMasonry.onLoadMore] calls (source
  /// `loadPendingRef`).
  bool _loadPending = false;

  bool _postFrameScheduled = false;

  // Cached per-build geometry the scroll callback reads.
  int _columns = 1;
  double _triggerInset = 320;

  @override
  void initState() {
    super.initState();
    _initialItemCount = widget.items.length;
  }

  @override
  void didUpdateWidget(covariant BeuiInfiniteMasonry<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear the pending guard when a load resolves (source's `!loading` effect).
    if (oldWidget.loading && !widget.loading) _loadPending = false;
    if (widget.controller != oldWidget.controller &&
        oldWidget.controller == null) {
      _internalController?.dispose();
      _internalController = null;
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  double _estimate(T item, int index) =>
      widget.estimateSize?.call(item, index) ?? 240;

  bool get _hasError => widget.error != null;

  int _columnsFor(double width) {
    final raw = ((width + widget.gap) / (widget.minColumnWidth + widget.gap))
        .floor();
    return math.min(widget.maxColumns, math.max(1, raw));
  }

  /// Prefetch trigger distance in px from the bottom. Derived from [prefetch] +
  /// [overscan] converted to vertical rows via the column count and the mean
  /// estimated item height — so [estimateSize], [overscan], [prefetch] and
  /// [gap] all feed the load-more window (see class docs).
  double _computeTriggerInset(int columns) {
    final items = widget.items;
    final n = items.length;
    double avg;
    if (n == 0) {
      avg = 240;
    } else {
      final sample = math.min(n, 12);
      var sum = 0.0;
      for (var i = n - sample; i < n; i++) {
        sum += _estimate(items[i], i);
      }
      avg = sum / sample;
    }
    final rows = (widget.prefetch + widget.overscan) / columns;
    return math.max(avg, rows * (avg + widget.gap));
  }

  bool _onScrollNotification(ScrollNotification notification) {
    _maybeLoadMore(notification.metrics);
    return false;
  }

  void _maybeLoadMore(ScrollMetrics metrics) {
    if (_hasError ||
        widget.loading ||
        !widget.hasMore ||
        _loadPending ||
        !metrics.hasContentDimensions) {
      return;
    }
    final remaining = metrics.maxScrollExtent - metrics.pixels;
    if (remaining <= _triggerInset) _fireLoadMore();
  }

  void _fireLoadMore() {
    _loadPending = true;
    final result = widget.onLoadMore();
    Future<void>.value(result).whenComplete(() {
      if (mounted) _loadPending = false;
    });
  }

  /// After layout, if the content does not fill the viewport (nothing to scroll)
  /// but more remains, load the next page — mirroring the source firing when the
  /// last item is already visible.
  void _scheduleFillCheck() {
    if (_postFrameScheduled) return;
    _postFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _postFrameScheduled = false;
      if (!mounted) return;
      if (_hasError || widget.loading || !widget.hasMore || _loadPending) {
        return;
      }
      final positions = _controller.positions;
      if (positions.isEmpty) {
        // Source does not auto-load the first page from an empty feed (its fill
        // effect early-returns when items is empty). Only fill an underfilled
        // *non-empty* feed whose scroll view hasn't attached yet.
        if (widget.items.isNotEmpty) _fireLoadMore();
        return;
      }
      for (final position in positions) {
        if (!position.hasContentDimensions) continue;
        final remaining = position.maxScrollExtent - position.pixels;
        if (remaining <= _triggerInset) {
          _fireLoadMore();
          return;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);

    final radius = BorderRadius.circular(24); // rounded-3xl

    // Empty state: nothing loaded and nothing more coming.
    if (widget.items.isEmpty &&
        !widget.hasMore &&
        !widget.loading &&
        !_hasError) {
      return Semantics(
        container: true,
        label: widget.ariaLabel,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: radius,
            border: Border.all(color: colors.border),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: widget.emptyState ?? _DefaultEmptyState(colors: colors),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: widget.ariaLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: radius,
          border: Border.all(color: colors.border),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = math.max(0.0, constraints.maxWidth - 24); // p-3
              _columns = _columnsFor(width);
              _triggerInset = _computeTriggerInset(_columns);
              _scheduleFillCheck();

              final cols = _distribute(_columns, colors, reduce);

              return NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: SingleChildScrollView(
                  controller: _controller,
                  padding: const EdgeInsets.all(12), // p-3
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MasonryRow(columns: cols, gap: widget.gap),
                      if (!widget.hasMore &&
                          widget.items.isNotEmpty &&
                          widget.endState != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: DefaultTextStyle.merge(
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.mutedForeground,
                            ),
                            child: Center(child: widget.endState!),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Distributes real items (+ the loading/error tail) into [columns] lane
  /// buckets, shortest-lane-first by estimated height.
  List<List<Widget>> _distribute(int columns, BeuiColors colors, bool reduce) {
    final laneHeights = List<double>.filled(columns, 0);
    final buckets = List<List<Widget>>.generate(columns, (_) => <Widget>[]);

    int shortest() {
      var idx = 0;
      for (var c = 1; c < columns; c++) {
        if (laneHeights[c] < laneHeights[idx] - 1e-6) idx = c;
      }
      return idx;
    }

    final items = widget.items;
    for (var i = 0; i < items.length; i++) {
      final lane = shortest();
      final key = widget.getItemKey(items[i], i);
      final animate = widget.animateItems && !reduce && i >= _initialItemCount;
      buckets[lane].add(
        _MasonryItemReveal(
          key: ValueKey<BeuiInfiniteMasonryKey>(key),
          itemKey: key,
          lane: lane,
          revealedKeys: _revealedKeys,
          animate: animate,
          child: widget.renderItem(items[i], i),
        ),
      );
      laneHeights[lane] += _estimate(items[i], i) + widget.gap;
    }

    // Tail: an error card takes precedence over loading skeletons (source
    // `tailCount = hasError ? 1 : loading ? columns : 0`).
    if (_hasError) {
      final lane = shortest();
      buckets[lane].add(
        _ErrorTailCard(
          key: const ValueKey('masonry-tail-error'),
          colors: colors,
          error: widget.error!,
          onRetry: widget.onRetry,
        ),
      );
    } else if (widget.loading) {
      for (var i = 0; i < columns; i++) {
        final lane = shortest();
        buckets[lane].add(
          widget.renderLoadingItem?.call(i) ??
              _DefaultLoadingItem(
                key: ValueKey('masonry-tail-loading-$i'),
                index: i,
                colors: colors,
                reduce: reduce,
              ),
        );
        laneHeights[lane] += (144 + (i % 3) * 36) + widget.gap;
      }
    }

    return buckets;
  }
}

/// A [Row] of gap-separated, equal-width lane [Column]s.
class _MasonryRow extends StatelessWidget {
  const _MasonryRow({required this.columns, required this.gap});

  final List<List<Widget>> columns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var c = 0; c < columns.length; c++) {
      if (c > 0) children.add(SizedBox(width: gap));
      children.add(
        Expanded(
          child: _MasonryColumn(items: columns[c], gap: gap),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _MasonryColumn extends StatelessWidget {
  const _MasonryColumn({required this.items, required this.gap});

  final List<Widget> items;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) children.add(SizedBox(height: gap));
      children.add(items[i]);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// Reveals a newly-appended item: `y: 12 → 0` on [beuiSpringPanel] + a 200ms
/// [beuiEaseOut] opacity fade, staggered by `min(lane, 3) * 0.04s`. When
/// [animate] is false (initial batch, [BeuiInfiniteMasonry.animateItems] off, or
/// reduced motion) the child renders immediately. Each key reveals only once.
class _MasonryItemReveal extends StatefulWidget {
  const _MasonryItemReveal({
    required this.itemKey,
    required this.lane,
    required this.revealedKeys,
    required this.animate,
    required this.child,
    super.key,
  });

  final BeuiInfiniteMasonryKey itemKey;
  final int lane;
  final Set<BeuiInfiniteMasonryKey> revealedKeys;
  final bool animate;
  final Widget child;

  @override
  State<_MasonryItemReveal> createState() => _MasonryItemRevealState();
}

class _MasonryItemRevealState extends State<_MasonryItemReveal> {
  late final bool _reveal;
  bool _shown = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _reveal = widget.animate && !widget.revealedKeys.contains(widget.itemKey);
    widget.revealedKeys.add(widget.itemKey);
    if (!_reveal) {
      _shown = true;
    } else {
      final delayMs = math.min(widget.lane, 3) * 40; // min(lane,3) * 0.04s
      _timer = Timer(Duration(milliseconds: delayMs), () {
        _timer = null;
        if (mounted) setState(() => _shown = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_reveal) return widget.child;
    return SingleMotionBuilder(
      value: _shown ? 0.0 : 12.0,
      from: 12.0,
      motion: beuiSpringPanel,
      builder: (context, y, child) =>
          Transform.translate(offset: Offset(0, y), child: child),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        curve: beuiEaseOut,
        opacity: _shown ? 1.0 : 0.0,
        child: widget.child,
      ),
    );
  }
}

/// Default pulsing loading skeleton (source `DefaultLoadingItem`): a rounded
/// card of `144 + (index % 3) * 36` min height with three bar placeholders. The
/// `animate-pulse` opacity loop runs unless reduced motion is on.
class _DefaultLoadingItem extends StatefulWidget {
  const _DefaultLoadingItem({
    required this.index,
    required this.colors,
    required this.reduce,
    super.key,
  });

  final int index;
  final BeuiColors colors;
  final bool reduce;

  @override
  State<_DefaultLoadingItem> createState() => _DefaultLoadingItemState();
}

class _DefaultLoadingItemState extends State<_DefaultLoadingItem>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    if (!widget.reduce) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final minHeight = 144.0 + (widget.index % 3) * 36.0;
    Widget card = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16), // rounded-2xl
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _bar(colors, widthFactor: 2 / 3, height: 12),
          const SizedBox(height: 12),
          _bar(colors, widthFactor: 1, height: 8),
          const SizedBox(height: 8),
          _bar(colors, widthFactor: 4 / 5, height: 8),
        ],
      ),
    );

    if (_pulse != null) {
      card = FadeTransition(
        opacity: Tween<double>(
          begin: 1,
          end: 0.5,
        ).animate(CurvedAnimation(parent: _pulse!, curve: beuiEaseInOut)),
        child: card,
      );
    }
    return ExcludeSemantics(child: card);
  }

  Widget _bar(
    BeuiColors colors, {
    required double widthFactor,
    required double height,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: colors.muted,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

/// The error tail card (source's `hasError` tail): an alert row, the [error]
/// body, and an optional retry button.
class _ErrorTailCard extends StatelessWidget {
  const _ErrorTailCard({
    required this.colors,
    required this.error,
    required this.onRetry,
    super.key,
  });

  final BeuiColors colors;
  final Widget error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final destructive = colors.destructive;
    return Container(
      constraints: const BoxConstraints(minHeight: 144), // min-h-36
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: destructive.withValues(alpha: 0.05), // bg-destructive/5
        borderRadius: BorderRadius.circular(16), // rounded-2xl
        border: Border.all(
          color: destructive.withValues(alpha: 0.20), // border-destructive/20
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.circle_alert, size: 16, color: destructive),
              const SizedBox(width: 8),
              // Flex so the label wraps within a narrow column instead of
              // overflowing (columns can be as narrow as ~208px).
              Expanded(
                child: Text(
                  "Couldn't load more",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: destructive,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: 12,
              height: 5 / 3, // leading-5 on text-xs
              color: colors.mutedForeground,
            ),
            child: error,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            _RetryButton(colors: colors, onRetry: onRetry!),
          ],
        ],
      ),
    );
  }
}

/// The "Try again" pill on the error card, with a hover fill.
class _RetryButton extends StatefulWidget {
  const _RetryButton({required this.colors, required this.onRetry});

  final BeuiColors colors;
  final VoidCallback onRetry;

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Semantics(
      button: true,
      label: 'Try again',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onRetry,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: beuiEaseOut,
            constraints: const BoxConstraints(minHeight: 40), // min-h-10
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hovered ? colors.muted : colors.background,
              borderRadius: BorderRadius.circular(999), // rounded-full
              border: Border.all(color: colors.border),
            ),
            child: Text(
              'Try again',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Default empty state (source `DefaultEmptyState`): an Inbox glyph over a
/// title and supporting copy, centered.
class _DefaultEmptyState extends StatelessWidget {
  const _DefaultEmptyState({required this.colors});

  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 256), // min-h-64
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.inbox, size: 32, color: colors.mutedForeground),
          const SizedBox(height: 12),
          Text(
            'No items yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320), // max-w-xs
            child: Text(
              'New items will appear here when they become available.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 5 / 3, // leading-5
                color: colors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
