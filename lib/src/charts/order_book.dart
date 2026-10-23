/// Snapshot-driven order-book depth ladder.
library;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_shared.dart';

/// An order-book price level.
@immutable
class BeuiOrderBookLevel {
  /// Creates a price and size pair.
  const BeuiOrderBookLevel({required this.price, required this.size});

  /// Price of the quote.
  final double price;

  /// Base asset size.
  final double size;
}

/// Aggregated depth row with cumulative size.
@immutable
class BeuiOrderBookDepthLevel extends BeuiOrderBookLevel {
  /// Creates a prepared depth level.
  const BeuiOrderBookDepthLevel({
    required super.price,
    required super.size,
    required this.total,
  });

  /// Cumulative size through this row.
  final double total;
}

/// Currently inspected side and price.
@immutable
class BeuiOrderBookActiveLevel {
  /// Creates an active side/price key.
  const BeuiOrderBookActiveLevel({required this.side, required this.price});

  /// Side of the quote.
  final BeuiOrderBookSideKind side;

  /// Exact quote price.
  final double price;

  @override
  bool operator ==(Object other) =>
      other is BeuiOrderBookActiveLevel &&
      other.side == side &&
      other.price == price;

  @override
  int get hashCode => Object.hash(side, price);
}

/// Side of an order-book level.
enum BeuiOrderBookSideKind {
  /// Buy quotes.
  bid,

  /// Sell quotes.
  ask,
}

/// Aggregated totals for an inspected depth range.
@immutable
class BeuiOrderBookDepthSummaryData {
  /// Creates a depth summary.
  const BeuiOrderBookDepthSummaryData({
    required this.side,
    required this.levels,
    required this.size,
    required this.quote,
    required this.averagePrice,
  });

  /// Side summarized.
  final BeuiOrderBookSideKind side;

  /// Number of levels included.
  final int levels;

  /// Base quantity.
  final double size;

  /// Quote value.
  final double quote;

  /// Size-weighted average price.
  final double averagePrice;
}

/// Aggregated bids and asks with spread, depth, and balance summaries.
class BeuiOrderBook extends StatefulWidget {
  /// Creates an order book.
  const BeuiOrderBook({
    required this.bids,
    required this.asks,
    super.key,
    this.levels = 9,
    this.lastPrice,
    this.label = 'Order book',
    this.baseSymbol = '',
    this.quoteSymbol = 'USD',
    this.formatPrice,
    this.formatSize,
    this.activeLevel,
    this.defaultActiveLevel,
    this.onActiveLevelChange,
    this.onLevelSelect,
    this.child,
  });

  /// Buy-side snapshot. Duplicate prices are combined.
  final List<BeuiOrderBookLevel> bids;

  /// Sell-side snapshot. Duplicate prices are combined.
  final List<BeuiOrderBookLevel> asks;

  /// Maximum number of levels displayed on each side.
  final int levels;

  /// Reference price; otherwise the best-level midpoint is used.
  final double? lastPrice;

  /// Accessible name.
  final String label;

  /// Base asset symbol.
  final String baseSymbol;

  /// Quote asset symbol.
  final String quoteSymbol;

  /// Price formatter.
  final String Function(double value)? formatPrice;

  /// Size formatter.
  final String Function(double value)? formatSize;

  /// Controlled inspected side and price; when supplied, selection is controlled.
  final BeuiOrderBookActiveLevel? activeLevel;

  /// Initial inspected side and price for uncontrolled use.
  final BeuiOrderBookActiveLevel? defaultActiveLevel;

  /// Called when the inspected level changes.
  final ValueChanged<BeuiOrderBookActiveLevel?>? onActiveLevelChange;

  /// Called when a price is activated.
  final void Function(
    BeuiOrderBookDepthLevel level,
    BeuiOrderBookSideKind side,
  )?
  onLevelSelect;

  /// Custom composition; defaults to header, asks, spread, bids and balance.
  final Widget? child;

  @override
  State<BeuiOrderBook> createState() => _BeuiOrderBookState();
}

class _BeuiOrderBookState extends State<BeuiOrderBook>
    with BeuiChartInspectorKeys {
  BeuiOrderBookActiveLevel? _internal;
  BeuiOrderBookActiveLevel? get _active => widget.activeLevel ?? _internal;
  @override
  String? get activeId =>
      _active == null ? null : '${_active!.side.name}:${_active!.price}';
  @override
  List<String> get inspectableIds => [
    for (final row in _book.bids) 'bid:${row.price}',
    for (final row in _book.asks) 'ask:${row.price}',
  ];

  @override
  void initState() {
    super.initState();
    _internal = widget.defaultActiveLevel;
  }

  @override
  void setActiveId(String? id) {
    final previous = _active;
    BeuiOrderBookActiveLevel? next;
    if (id != null) {
      final parts = id.split(':');
      if (parts.length == 2) {
        final price = double.tryParse(parts[1]);
        if (price != null) {
          next = BeuiOrderBookActiveLevel(
            side: parts[0] == 'ask'
                ? BeuiOrderBookSideKind.ask
                : BeuiOrderBookSideKind.bid,
            price: price,
          );
        }
      }
    }
    if (widget.activeLevel == null && _internal != next) {
      setState(() => _internal = next);
    }
    if (previous?.side != next?.side || previous?.price != next?.price) {
      widget.onActiveLevelChange?.call(next);
    }
  }

  late _OrderBookData _book;

  @override
  Widget build(BuildContext context) {
    _book = _buildBook(widget.bids, widget.asks, widget.levels);
    final active = _active;
    final sideRows = active?.side == BeuiOrderBookSideKind.bid
        ? _book.bids
        : _book.asks;
    final activeIndex = active == null
        ? -1
        : sideRows.indexWhere((r) => r.price == active.price);
    final summary = activeIndex < 0 || active == null
        ? null
        : _summarize(sideRows.take(activeIndex + 1).toList(), active.side);
    final price =
        widget.lastPrice != null &&
            widget.lastPrice!.isFinite &&
            widget.lastPrice! > 0
        ? widget.lastPrice
        : _book.midpoint;
    final formatPrice =
        widget.formatPrice ??
        (value) => beuiChartFormatNumber(value, maximumFractionDigits: 2);
    final formatSize =
        widget.formatSize ??
        (value) => beuiChartFormatNumber(value, compact: true);
    final scope = _OrderBookScope(
      bids: _book.bids,
      asks: _book.asks,
      maxTotal: _book.maxTotal,
      bidTotal: _book.bidTotal,
      askTotal: _book.askTotal,
      spread: _book.spread,
      midpoint: _book.midpoint,
      price: price,
      active: active,
      summary: summary,
      baseSymbol: widget.baseSymbol,
      quoteSymbol: widget.quoteSymbol,
      formatPrice: formatPrice,
      formatSize: formatSize,
      onActive: setActiveId,
      onInspect: (id, on) {
        if (on || activeId == id) setActiveId(on ? id : null);
      },
      onSelect: widget.onLevelSelect,
      child:
          widget.child ??
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiOrderBookHeader(),
              BeuiOrderBookSide(side: BeuiOrderBookSideKind.ask),
              BeuiOrderBookSpread(),
              BeuiOrderBookSide(side: BeuiOrderBookSideKind.bid),
              BeuiOrderBookBalance(),
            ],
          ),
    );
    return Semantics(container: true, label: widget.label, child: scope);
  }
}

class _OrderBookData {
  const _OrderBookData({
    required this.bids,
    required this.asks,
    required this.bidTotal,
    required this.askTotal,
    required this.maxTotal,
    required this.midpoint,
    required this.spread,
  });
  final List<BeuiOrderBookDepthLevel> bids, asks;
  final double bidTotal, askTotal, maxTotal;
  final double? midpoint, spread;
}

_OrderBookData _buildBook(
  List<BeuiOrderBookLevel> bids,
  List<BeuiOrderBookLevel> asks,
  int limit,
) {
  List<BeuiOrderBookDepthLevel> prepare(
    List<BeuiOrderBookLevel> source,
    bool bid,
  ) {
    final totals = <double, double>{};
    for (final row in source) {
      if (!row.price.isFinite ||
          !row.size.isFinite ||
          row.price <= 0 ||
          row.size <= 0) {
        continue;
      }
      totals.update(
        row.price,
        (size) => size + row.size,
        ifAbsent: () => row.size,
      );
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => bid ? b.key.compareTo(a.key) : a.key.compareTo(b.key));
    var cumulative = 0.0;
    return [
      for (final entry in sorted.take(limit.clamp(0, 100)))
        BeuiOrderBookDepthLevel(
          price: entry.key,
          size: entry.value,
          total: cumulative += entry.value,
        ),
    ];
  }

  final buy = prepare(bids, true), sell = prepare(asks, false);
  final bidTotal = buy.isEmpty ? 0.0 : buy.last.total;
  final askTotal = sell.isEmpty ? 0.0 : sell.last.total;
  final midpoint = buy.isEmpty || sell.isEmpty
      ? null
      : (buy.first.price + sell.first.price) / 2;
  final spread = buy.isEmpty || sell.isEmpty
      ? null
      : sell.first.price - buy.first.price;
  return _OrderBookData(
    bids: buy,
    asks: sell,
    bidTotal: bidTotal,
    askTotal: askTotal,
    maxTotal: bidTotal > askTotal ? bidTotal : askTotal,
    midpoint: midpoint,
    spread: spread,
  );
}

BeuiOrderBookDepthSummaryData _summarize(
  List<BeuiOrderBookDepthLevel> rows,
  BeuiOrderBookSideKind side,
) {
  final size = rows.fold<double>(0, (sum, row) => sum + row.size);
  final quote = rows.fold<double>(0, (sum, row) => sum + row.price * row.size);
  return BeuiOrderBookDepthSummaryData(
    side: side,
    levels: rows.length,
    size: size,
    quote: quote,
    averagePrice: size == 0 ? 0 : quote / size,
  );
}

class _OrderBookScope extends StatelessWidget {
  const _OrderBookScope({
    required this.bids,
    required this.asks,
    required this.maxTotal,
    required this.bidTotal,
    required this.askTotal,
    required this.spread,
    required this.midpoint,
    required this.price,
    required this.active,
    required this.summary,
    required this.baseSymbol,
    required this.quoteSymbol,
    required this.formatPrice,
    required this.formatSize,
    required this.onActive,
    required this.onInspect,
    required this.onSelect,
    required this.child,
  });
  final List<BeuiOrderBookDepthLevel> bids, asks;
  final double maxTotal, bidTotal, askTotal;
  final double? spread, midpoint, price;
  final BeuiOrderBookActiveLevel? active;
  final BeuiOrderBookDepthSummaryData? summary;
  final String baseSymbol, quoteSymbol;
  final String Function(double) formatPrice, formatSize;
  final ValueChanged<String?> onActive;
  final void Function(String, bool) onInspect;
  final void Function(BeuiOrderBookDepthLevel, BeuiOrderBookSideKind)? onSelect;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return _OrderBookInherited(
      scope: this,
      child: Container(
        decoration: BoxDecoration(
          color: BeuiColors.resolve(context).background,
          border: Border.all(color: BeuiColors.resolve(context).border),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _OrderBookInherited extends InheritedWidget {
  const _OrderBookInherited({required this.scope, required super.child});
  final _OrderBookScope scope;
  static _OrderBookScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_OrderBookInherited>()!.scope;
  @override
  bool updateShouldNotify(_OrderBookInherited old) =>
      scope.active != old.scope.active ||
      scope.bids != old.scope.bids ||
      scope.asks != old.scope.asks;
}

/// Column labels for price, size, and cumulative total.
class BeuiOrderBookHeader extends StatelessWidget {
  /// Creates the table header.
  const BeuiOrderBookHeader({super.key});
  @override
  Widget build(BuildContext context) {
    final s = _OrderBookInherited.of(context);
    final colors = BeuiColors.resolve(context);
    return _BookColumns(
      children: [
        'Price${s.quoteSymbol.isEmpty ? '' : ' (${s.quoteSymbol})'}',
        'Size${s.baseSymbol.isEmpty ? '' : ' (${s.baseSymbol})'}',
        'Total',
      ],
      color: colors.mutedForeground,
      header: true,
    );
  }
}

/// Accessible rows for one side of the book.
class BeuiOrderBookSide extends StatelessWidget {
  /// Creates bid or ask rows.
  const BeuiOrderBookSide({required this.side, super.key});

  /// Which side to show.
  final BeuiOrderBookSideKind side;
  @override
  Widget build(BuildContext context) {
    final s = _OrderBookInherited.of(context);
    final colors = BeuiColors.resolve(context);
    final levels = side == BeuiOrderBookSideKind.bid ? s.bids : s.asks;
    final rows = side == BeuiOrderBookSideKind.ask
        ? levels.reversed.toList()
        : levels;
    final tint = side == BeuiOrderBookSideKind.bid
        ? colors.success
        : colors.destructive;
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: Text(
            'No ${side == BeuiOrderBookSideKind.bid ? 'bids' : 'asks'}',
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          _OrderBookDepthRow(
            key: ValueKey('${side.name}:${rows[i].price}'),
            row: rows[i],
            side: side,
            index: i,
            scope: s,
            tint: tint,
          ),
      ],
    );
  }
}

class _OrderBookDepthRow extends StatefulWidget {
  const _OrderBookDepthRow({
    required this.row,
    required this.side,
    required this.index,
    required this.scope,
    required this.tint,
    super.key,
  });
  final BeuiOrderBookDepthLevel row;
  final BeuiOrderBookSideKind side;
  final int index;
  final _OrderBookScope scope;
  final Color tint;
  @override
  State<_OrderBookDepthRow> createState() => _OrderBookDepthRowState();
}

class _OrderBookDepthRowState extends State<_OrderBookDepthRow>
    with SingleTickerProviderStateMixin {
  late final _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  double _flashStart = 0;
  double get _highlight {
    final ms = _flash.value * 280;
    if (ms < 80) {
      return _flashStart + (.1 - _flashStart) * beuiEaseOut.transform(ms / 80);
    }
    return .1 * (1 - beuiEaseOut.transform(((ms - 80) / 200).clamp(0.0, 1.0)));
  }

  @override
  void didUpdateWidget(covariant _OrderBookDepthRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row.size != widget.row.size) {
      _flashStart = _flash.isAnimating ? _highlight : 0;
      _flash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scope;
    final row = widget.row;
    final side = widget.side;
    final tint = widget.tint;
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final active = s.active?.side == side && s.active?.price == row.price;
    final inRange =
        s.active?.side == side &&
        (side == BeuiOrderBookSideKind.bid
            ? row.price >= s.active!.price
            : row.price <= s.active!.price);
    final fraction = s.maxTotal <= 0 ? 0.0 : row.total / s.maxTotal;
    final delay = Duration(milliseconds: widget.index.clamp(0, 8) * 25);
    void inspect(bool on) => s.onInspect('${side.name}:${row.price}', on);
    return Semantics(
      container: true,
      label:
          '${side.name}, ${s.formatPrice(row.price)}, size ${s.formatSize(row.size)}, total ${s.formatSize(row.total)}',
      child: MouseRegion(
        onEnter: (_) => inspect(true),
        onExit: (_) => inspect(false),
        child: BeuiChartTween(
          from: 0,
          value: 1,
          duration: const Duration(milliseconds: 180),
          delay: reduce ? Duration.zero : delay,
          builder: (context, opacity) => Opacity(
            opacity: opacity.clamp(0, 1),
            child: SizedBox(
              height: 32,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: BeuiChartTween(
                              from: fraction * .85,
                              value: fraction,
                              duration: const Duration(milliseconds: 300),
                              delay: delay,
                              motion: beuiSpringPanel,
                              isMovement: true,
                              builder: (_, value) => FractionallySizedBox(
                                widthFactor: value.clamp(0, 1),
                                heightFactor: 1,
                                child: ColoredBox(
                                  key: ValueKey(
                                    'beui-order-bar-${side.name}-${row.price}',
                                  ),
                                  color: tint.withValues(alpha: .12),
                                ),
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _flash,
                            builder: (_, _) => ColoredBox(
                              color: tint.withValues(
                                alpha: reduce || !_flash.isAnimating
                                    ? 0
                                    : _highlight,
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            color: tint.withValues(
                              alpha: inRange
                                  ? .08
                                  : active
                                  ? .05
                                  : 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: s.onSelect == null
                                ? Text(
                                    s.formatPrice(row.price),
                                    style: TextStyle(color: tint),
                                  )
                                : Focus(
                                    canRequestFocus: false,
                                    onFocusChange: inspect,
                                    child: TextButton(
                                      key: ValueKey(
                                        'beui-order-price-${side.name}-${row.price}',
                                      ),
                                      onPressed: () {
                                        inspect(true);
                                        s.onSelect?.call(row, side);
                                      },
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        foregroundColor: tint,
                                      ),
                                      child: Text(s.formatPrice(row.price)),
                                    ),
                                  ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            s.formatSize(row.size),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            s.formatSize(row.total),
                            textAlign: TextAlign.right,
                            style: TextStyle(color: colors.mutedForeground),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookColumns extends StatelessWidget {
  const _BookColumns({
    required this.children,
    required this.color,
    this.header = false,
  });
  final List<String> children;
  final Color color;
  final bool header;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        for (var i = 0; i < children.length; i++)
          Expanded(
            child: Text(
              children[i],
              textAlign: i == 0 ? TextAlign.left : TextAlign.right,
              style: TextStyle(
                fontSize: header ? 10 : 12,
                color: color,
                fontWeight: header ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
      ],
    ),
  );
}

/// Reference price and best-level spread.
class BeuiOrderBookSpread extends StatelessWidget {
  /// Creates the spread line.
  const BeuiOrderBookSpread({super.key});
  @override
  Widget build(BuildContext context) {
    final s = _OrderBookInherited.of(context);
    final colors = BeuiColors.resolve(context);
    final message = s.spread == null
        ? 'Spread unavailable'
        : s.spread! < 0
        ? 'Crossed book'
        : 'Spread ${s.formatPrice(s.spread!)} · ${s.midpoint == 0 ? '—' : (s.spread! / s.midpoint! * 100).toStringAsFixed(3)}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: .45),
        border: Border.symmetric(horizontal: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: s.price == null
                ? const Text('—')
                : BeuiChartTicker(
                    value: s.price!,
                    format: (value) => s.formatPrice(value.toDouble()),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          Text(
            message,
            style: TextStyle(fontSize: 10, color: colors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

/// Polite readout for the inspected range of depth.
class BeuiOrderBookDepthSummary extends StatelessWidget {
  /// Creates the depth readout.
  const BeuiOrderBookDepthSummary({
    super.key,
    this.placeholder = 'Hover a level to inspect depth',
  });

  /// Text shown when no level is inspected.
  final String placeholder;
  @override
  Widget build(BuildContext context) {
    final s = _OrderBookInherited.of(context);
    final summary = s.summary;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: summary == null
            ? Text(
                placeholder,
                style: TextStyle(
                  color: BeuiColors.resolve(context).mutedForeground,
                  fontSize: 11,
                ),
              )
            : Row(
                children: [
                  Text('Avg ${s.formatPrice(summary.averagePrice)}'),
                  const Spacer(),
                  Text(
                    '${s.formatSize(summary.size)}${s.baseSymbol.isEmpty ? '' : ' ${s.baseSymbol}'} · ${s.formatPrice(summary.quote)}${s.quoteSymbol.isEmpty ? '' : ' ${s.quoteSymbol}'}',
                  ),
                ],
              ),
      ),
    );
  }
}

/// Proportion of visible depth on each side.
class BeuiOrderBookBalance extends StatelessWidget {
  /// Creates the visible-depth balance bar.
  const BeuiOrderBookBalance({super.key});
  @override
  Widget build(BuildContext context) {
    final s = _OrderBookInherited.of(context);
    final colors = BeuiColors.resolve(context);
    final total = s.bidTotal + s.askTotal;
    final ratio = total == 0 ? .5 : s.bidTotal / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Bids ${total == 0 ? '—' : '${(ratio * 100).toStringAsFixed(1)}%'}',
                style: TextStyle(fontSize: 10, color: colors.success),
              ),
              const Spacer(),
              Text(
                'Visible depth',
                style: TextStyle(fontSize: 10, color: colors.mutedForeground),
              ),
              const Spacer(),
              Text(
                'Asks ${total == 0 ? '—' : '${((1 - ratio) * 100).toStringAsFixed(1)}%'}',
                style: TextStyle(fontSize: 10, color: colors.destructive),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  ColoredBox(
                    color: colors.destructive.withValues(alpha: .35),
                    child: const SizedBox.expand(),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: BeuiChartSpring(
                      value: ratio,
                      builder: (_, value) => FractionallySizedBox(
                        widthFactor: value,
                        heightFactor: 1,
                        child: ColoredBox(
                          color: colors.success.withValues(alpha: .75),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
