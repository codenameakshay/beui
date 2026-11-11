import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderProxyBox;

import '../theme/beui_agent_theme.dart';
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
/// shortest-column lane assignment. The actual
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
/// ## Windowing
///
/// The source uses measured lane positions and mounts only virtual items. This
/// implementation retains each mounted item's measured height by stable key.
///
/// It computes shortest-lane positions from measured heights and mounts only
/// viewport items plus [overscan] * columns around them.
///
/// * **Responsive columns** — `columns = min(maxColumns, max(1,
///   floor((width + gap) / (minColumnWidth + gap))))`, from a [LayoutBuilder]
///   (the Flutter analog of the source's `ResizeObserver`), identical formula.
/// * **Shortest-column-first distribution** — items use measured height when
///   available, then [estimateSize], to choose the next lane.
/// * **Windowed rendering** — only virtual items are mounted, and measurements
///   persist by stable key across scroll windows and column reflow.
/// * **Separate windows** — [overscan] controls rendered items; [prefetch]
///   controls the last-visible-index load trigger.
///
/// **Trade-off:** geometry is recomputed in O(n) per update, while mounted item
/// widgets remain bounded to the viewport and overscan window.
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

  /// Estimated item height for lane assignment until measured at the current
  /// column width. Defaults to `240` (source
  /// `estimateSize = () => 240`).
  final BeuiMasonrySizeEstimator<T>? estimateSize;

  /// Builds a loading skeleton for the tail at `index` (0-based within the tail).
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

  /// Extra rendered items per column before and after the visible range
  /// (source `overscan = 4`). It does not widen the load-more threshold.
  final int overscan;

  /// Loads more when the last visible item is within this many items of the end
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
  ScrollController? _listeningController;
  ScrollController get _controller {
    final controller =
        widget.controller ?? (_internalController ??= ScrollController());
    _bindController(controller);
    return controller;
  }

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
  bool _controllerRebuildScheduled = false;

  final Map<Object, _MeasuredMasonryItem> _measuredItems = {};
  List<_MasonryPlacement> _placements = const [];
  int _firstVisibleIndex = -1;
  int _lastVisibleIndex = -1;
  double _scrollOffset = 0;
  double _contentHeight = 0;
  double _viewportHeight = 0;
  bool _measurementUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    _initialItemCount = widget.items.length;
    final controller = widget.controller;
    if (controller != null) _bindController(controller);
  }

  @override
  void didUpdateWidget(covariant BeuiInfiniteMasonry<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear the pending guard when a load resolves (source's `!loading` effect).
    if (oldWidget.loading && !widget.loading) _loadPending = false;
    if (widget.controller != oldWidget.controller &&
        oldWidget.controller == null) {
      if (identical(_listeningController, _internalController)) {
        _unbindController();
      }
      _internalController?.dispose();
      _internalController = null;
    }
    _bindControllerIfAvailable();
  }

  @override
  void dispose() {
    _unbindController();
    _internalController?.dispose();
    super.dispose();
  }

  void _bindControllerIfAvailable() {
    final controller = widget.controller ?? _internalController;
    if (controller == null) {
      _unbindController();
    } else {
      _bindController(controller);
    }
  }

  void _bindController(ScrollController controller) {
    if (identical(controller, _listeningController)) return;
    _unbindController();
    _listeningController = controller;
    controller.addListener(_handleControllerScroll);
  }

  void _unbindController() {
    _listeningController?.removeListener(_handleControllerScroll);
    _listeningController = null;
  }

  void _handleControllerScroll() {
    final positions = _listeningController?.positions;
    if (positions == null || positions.isEmpty) return;
    for (final position in positions) {
      if (!position.hasContentDimensions) continue;
      final oldFirst = _firstVisibleIndex;
      final oldLast = _lastVisibleIndex;
      _scrollOffset = position.pixels;
      _viewportHeight = position.viewportDimension;
      _updateVisibleRange();
      if ((oldFirst != _firstVisibleIndex || oldLast != _lastVisibleIndex) &&
          mounted &&
          !_controllerRebuildScheduled) {
        _controllerRebuildScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _controllerRebuildScheduled = false;
          if (mounted) setState(() {});
        });
      }
      _maybeLoadMore(position);
    }
  }

  double _estimate(T item, int index) =>
      widget.estimateSize?.call(item, index) ?? 240;

  bool get _hasError => widget.error != null;

  int _columnsFor(double width) {
    final raw = ((width + widget.gap) / (widget.minColumnWidth + widget.gap))
        .floor();
    return math.min(widget.maxColumns, math.max(1, raw));
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth == 0 && notification.metrics.axis == Axis.vertical) {
      _scrollOffset = notification.metrics.pixels;
      _viewportHeight = notification.metrics.viewportDimension;
      final oldFirst = _firstVisibleIndex;
      final oldLast = _lastVisibleIndex;
      _updateVisibleRange();
      if (oldFirst != _firstVisibleIndex || oldLast != _lastVisibleIndex) {
        setState(() {});
      }
    }
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
    if (widget.items.isNotEmpty &&
        _lastVisibleIndex >=
            math.max(0, widget.items.length - widget.prefetch)) {
      _fireLoadMore();
    }
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
      final positions = _controller.positions;
      if (positions.isEmpty) {
        // Source does not auto-load the first page from an empty feed (its fill
        // effect early-returns when items is empty). Only fill an underfilled
        // *non-empty* feed whose scroll view hasn't attached yet.
        if (!_hasError &&
            !widget.loading &&
            widget.hasMore &&
            !_loadPending &&
            widget.items.isNotEmpty) {
          _fireLoadMore();
        }
        return;
      }
      for (final position in positions) {
        if (!position.hasContentDimensions) continue;
        final oldFirst = _firstVisibleIndex;
        final oldLast = _lastVisibleIndex;
        _scrollOffset = position.pixels;
        _viewportHeight = position.viewportDimension;
        _updateVisibleRange();
        if (oldFirst != _firstVisibleIndex || oldLast != _lastVisibleIndex) {
          setState(() {});
        }
        if (_hasError || widget.loading || !widget.hasMore || _loadPending) {
          continue;
        }
        if (widget.items.isNotEmpty &&
            _lastVisibleIndex >=
                math.max(0, widget.items.length - widget.prefetch)) {
          _fireLoadMore();
          return;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
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
              final columns = _columnsFor(width);
              _viewportHeight = constraints.maxHeight;
              final positions = _controller.positions;
              if (positions.isNotEmpty &&
                  positions.first.hasContentDimensions) {
                _scrollOffset = positions.first.pixels;
                _viewportHeight = positions.first.viewportDimension;
              }
              final layout = _layoutItems(columns, width);
              _placements = layout.placements;
              final hasEndState =
                  !widget.hasMore &&
                  widget.items.isNotEmpty &&
                  widget.endState != null;
              _contentHeight = layout.height + (hasEndState ? 48 : 0);
              _updateVisibleRange();
              _scheduleFillCheck();

              return NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: SingleChildScrollView(
                  controller: _controller,
                  padding: const EdgeInsets.all(12), // p-3
                  child: SizedBox(
                    width: width,
                    height: _contentHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final placement in _visiblePlacements(columns))
                          _buildPlacement(
                            placement,
                            width,
                            columns,
                            colors,
                            reduce,
                          ),
                        if (hasEndState)
                          Positioned(
                            left: 0,
                            top: layout.height,
                            width: width,
                            child: Padding(
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
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  _MasonryLayout _layoutItems(int columns, double width) {
    final laneHeights = List<double>.filled(columns, 0);
    final placements = <_MasonryPlacement>[];
    final columnWidth = math.max(
      0.0,
      (width - widget.gap * (columns - 1)) / columns,
    );

    int shortestLane() {
      var shortest = 0;
      for (var lane = 1; lane < columns; lane++) {
        if (laneHeights[lane] < laneHeights[shortest] - 1e-6) shortest = lane;
      }
      return shortest;
    }

    for (var index = 0; index < widget.items.length; index++) {
      final item = widget.items[index];
      final key = widget.getItemKey(item, index);
      final lane = shortestLane();
      final measured = _measuredItems[key];
      final height =
          measured != null && (measured.width - columnWidth).abs() < 0.5
          ? measured.height
          : _estimate(item, index);
      placements.add(
        _MasonryPlacement(
          index: index,
          lane: lane,
          top: laneHeights[lane],
          height: height,
          key: key,
        ),
      );
      laneHeights[lane] += height + widget.gap;
    }

    if (_hasError) {
      final lane = shortestLane();
      const measurementKey = _MasonryTailMeasurementKey(
        isError: true,
        index: 0,
      );
      final measured = _measuredItems[measurementKey];
      final height =
          measured != null && (measured.width - columnWidth).abs() < 0.5
          ? measured.height
          : 144.0;
      placements.add(
        _MasonryPlacement(
          index: widget.items.length,
          lane: lane,
          top: laneHeights[lane],
          height: height,
          isError: true,
          measurementKey: measurementKey,
        ),
      );
      laneHeights[lane] += height + widget.gap;
    } else if (widget.loading) {
      for (var index = 0; index < columns; index++) {
        final lane = shortestLane();
        final measurementKey = _MasonryTailMeasurementKey(
          isError: false,
          index: index,
        );
        final measured = _measuredItems[measurementKey];
        final height =
            measured != null && (measured.width - columnWidth).abs() < 0.5
            ? measured.height
            : 144 + (index % 3) * 36.0;
        placements.add(
          _MasonryPlacement(
            index: widget.items.length + index,
            lane: lane,
            top: laneHeights[lane],
            height: height,
            tailIndex: index,
            measurementKey: measurementKey,
          ),
        );
        laneHeights[lane] += height + widget.gap;
      }
    }

    final height = laneHeights.fold<double>(
      0,
      (largest, laneHeight) => math.max(largest, laneHeight),
    );
    return _MasonryLayout(
      placements: placements,
      height: math.max(0, height - (placements.isEmpty ? 0 : widget.gap)),
    );
  }

  void _updateVisibleRange() {
    final start = math.max(0.0, _scrollOffset - 12);
    final end = _scrollOffset + _viewportHeight - 12;
    final visible = _placements
        .where((placement) => placement.top < end)
        .where((placement) => placement.top + placement.height > start)
        .toList();
    _firstVisibleIndex = visible.isEmpty
        ? -1
        : visible.map((placement) => placement.index).reduce(math.min);
    _lastVisibleIndex = visible.isEmpty
        ? -1
        : visible.map((placement) => placement.index).reduce(math.max);
  }

  List<_MasonryPlacement> _visiblePlacements(int columns) {
    if (_placements.isEmpty) return const [];
    final start = math.max(0.0, _scrollOffset - 12);
    final end = _scrollOffset + _viewportHeight - 12;
    final visible = _placements
        .where(
          (placement) =>
              placement.top < end && placement.top + placement.height > start,
        )
        .toList();
    if (visible.isEmpty) return const [];
    final window = widget.overscan * columns;
    final lower = math.max(0, _firstVisibleIndex - window);
    final upper = _lastVisibleIndex + window;
    return _placements
        .where(
          (placement) => placement.index >= lower && placement.index <= upper,
        )
        .toList();
  }

  Widget _buildPlacement(
    _MasonryPlacement placement,
    double width,
    int columns,
    BeuiColors colors,
    bool reduce,
  ) {
    final columnWidth = math.max(
      0.0,
      (width - widget.gap * (columns - 1)) / columns,
    );
    final left = placement.lane * (columnWidth + widget.gap);
    if (placement.isError) {
      return Positioned(
        key: const ValueKey('masonry-tail-error'),
        left: left,
        top: placement.top,
        width: columnWidth,
        child: _MasonrySizeReporter(
          onSize: (size) => _recordMeasurement(
            placement.measurementKey!,
            columnWidth,
            size.height,
          ),
          child: _ErrorTailCard(
            colors: colors,
            error: widget.error!,
            onRetry: widget.onRetry,
          ),
        ),
      );
    }
    final tailIndex = placement.tailIndex;
    if (tailIndex != null) {
      return Positioned(
        key: ValueKey('masonry-tail-loading-$tailIndex'),
        left: left,
        top: placement.top,
        width: columnWidth,
        child: _MasonrySizeReporter(
          onSize: (size) => _recordMeasurement(
            placement.measurementKey!,
            columnWidth,
            size.height,
          ),
          child:
              widget.renderLoadingItem?.call(tailIndex) ??
              _DefaultLoadingItem(
                index: tailIndex,
                colors: colors,
                reduce: reduce,
              ),
        ),
      );
    }

    final index = placement.index;
    final key = placement.key!;
    final animate =
        widget.animateItems && !reduce && index >= _initialItemCount;
    return Positioned(
      key: ValueKey<BeuiInfiniteMasonryKey>(key),
      left: left,
      top: placement.top,
      width: columnWidth,
      child: _MasonrySizeReporter(
        onSize: (size) => _recordMeasurement(key, columnWidth, size.height),
        child: _MasonryItemReveal(
          key: ValueKey<BeuiInfiniteMasonryKey>(key),
          itemKey: key,
          lane: placement.lane,
          revealedKeys: _revealedKeys,
          animate: animate,
          child: widget.renderItem(widget.items[index], index),
        ),
      ),
    );
  }

  void _recordMeasurement(Object key, double width, double height) {
    final previous = _measuredItems[key];
    if (previous != null &&
        (previous.width - width).abs() < 0.5 &&
        (previous.height - height).abs() < 0.5) {
      return;
    }
    _measuredItems[key] = _MeasuredMasonryItem(width: width, height: height);
    if (_measurementUpdateScheduled) return;
    _measurementUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementUpdateScheduled = false;
      if (mounted) setState(() {});
    });
  }
}

class _MasonryLayout {
  const _MasonryLayout({required this.placements, required this.height});

  final List<_MasonryPlacement> placements;
  final double height;
}

class _MasonryPlacement {
  const _MasonryPlacement({
    required this.index,
    required this.lane,
    required this.top,
    required this.height,
    this.key,
    this.tailIndex,
    this.measurementKey,
    this.isError = false,
  });

  final int index;
  final int lane;
  final double top;
  final double height;
  final BeuiInfiniteMasonryKey? key;
  final int? tailIndex;
  final Object? measurementKey;
  final bool isError;
}

class _MasonryTailMeasurementKey {
  const _MasonryTailMeasurementKey({
    required this.isError,
    required this.index,
  });

  final bool isError;
  final int index;

  @override
  bool operator ==(Object other) =>
      other is _MasonryTailMeasurementKey &&
      other.isError == isError &&
      other.index == index;

  @override
  int get hashCode => Object.hash(isError, index);
}

class _MeasuredMasonryItem {
  const _MeasuredMasonryItem({required this.width, required this.height});

  final double width;
  final double height;
}

class _MasonrySizeReporter extends SingleChildRenderObjectWidget {
  const _MasonrySizeReporter({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMasonrySizeReporter(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMasonrySizeReporter renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _RenderMasonrySizeReporter extends RenderProxyBox {
  _RenderMasonrySizeReporter(this.onSize);

  ValueChanged<Size> onSize;
  Size? _lastReportedSize;

  @override
  void performLayout() {
    super.performLayout();
    if (size != _lastReportedSize) {
      _lastReportedSize = size;
      onSize(size);
    }
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
    final retryLabel = BeuiAgentTheme.of(context).strings.retry;
    return Semantics(
      button: true,
      label: retryLabel,
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
              retryLabel,
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
