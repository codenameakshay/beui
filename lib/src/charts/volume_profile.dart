/// Volume-by-price profile with point of control and value area.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/beui_colors.dart';
import '_shared.dart';

/// One pre-aggregated price bin.
@immutable
class BeuiVolumeProfileBin {
  /// Creates a price bin.
  const BeuiVolumeProfileBin({
    required this.price,
    required this.volume,
    this.buy,
    this.sell,
  });

  /// Representative price for this bin.
  final double price;

  /// Executed volume.
  final double volume;

  /// Optional buy-side volume.
  final double? buy;

  /// Optional sell-side volume.
  final double? sell;
}

/// Composable volume profile chart.
class BeuiVolumeProfile extends StatefulWidget {
  /// Creates a volume profile.
  const BeuiVolumeProfile({
    required this.data,
    super.key,
    this.label = 'Volume profile',
    this.unit = '',
    this.formatPrice,
    this.formatVolume,
    this.valueArea = .7,
    this.color,
    this.pocColor,
    this.activeId,
    this.defaultActiveId,
    this.onActiveChange,
    this.child,
  });

  /// Already-aggregated bins, in price order.
  final List<BeuiVolumeProfileBin> data;

  /// Accessible chart name.
  final String label;

  /// Unit displayed in the summary.
  final String unit;

  /// Price formatter.
  final String Function(double price)? formatPrice;

  /// Volume formatter.
  final String Function(double volume)? formatVolume;

  /// Target fraction for the contiguous value area, or false to disable it.
  final Object valueArea;

  /// Bar color override.
  final String? color;

  /// Point of control color override.
  final String? pocColor;

  /// Controlled active bin identity.
  final String? activeId;

  /// Initial active bin identity.
  final String? defaultActiveId;

  /// Active bin callback.
  final ValueChanged<String?>? onActiveChange;

  /// Custom composition.
  final Widget? child;
  @override
  State<BeuiVolumeProfile> createState() => _BeuiVolumeProfileState();
}

class _BeuiVolumeProfileState extends State<BeuiVolumeProfile>
    with BeuiChartActiveState<BeuiVolumeProfile>, BeuiChartInspectorKeys {
  late List<_ProfileBin> bins;
  late int pocIndex, lowArea, highArea;
  late double total, maxVolume;
  String? _hoveredId;
  String? get inspectedId => _hoveredId ?? activeId;
  void hoverBin(String id) {
    if (_hoveredId != id) setState(() => _hoveredId = id);
  }

  void clearHoveredBin() {
    if (_hoveredId != null) setState(() => _hoveredId = null);
  }

  @override
  String? get widgetActiveId => widget.activeId;
  @override
  String? get widgetDefaultActiveId => widget.defaultActiveId;
  @override
  ValueChanged<String?>? get widgetOnActiveChange => widget.onActiveChange;
  @override
  Iterable<String> get knownIds => bins.map((b) => b.id);
  @override
  List<String> get inspectableIds => bins.map((b) => b.id).toList();
  String Function(double) get price =>
      widget.formatPrice ??
      (v) => beuiChartFormatNumber(v, maximumFractionDigits: 2);
  String Function(double) get volume =>
      widget.formatVolume ?? (v) => beuiChartFormatNumber(v, compact: true);
  @override
  void initState() {
    super.initState();
    initActive();
    _rebuild();
  }

  @override
  void didUpdateWidget(BeuiVolumeProfile old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data || old.valueArea != widget.valueArea) {
      if (old.data != widget.data) _hoveredId = null;
      _rebuild();
    }
  }

  void _rebuild() {
    bins = [
      for (var i = 0; i < widget.data.length; i++)
        _ProfileBin(id: '$i', bin: widget.data[i]),
    ]..sort((a, b) => a.bin.price.compareTo(b.bin.price));
    total = bins.fold(
      0,
      (s, b) =>
          s + (b.bin.volume.isFinite && b.bin.volume > 0 ? b.bin.volume : 0),
    );
    maxVolume = bins.fold(0, (m, b) => math.max(m, b.bin.volume));
    pocIndex = -1;
    for (var i = 0; i < bins.length; i++) {
      if (pocIndex < 0 || bins[i].bin.volume > bins[pocIndex].bin.volume) {
        pocIndex = i;
      }
    }
    lowArea = pocIndex;
    highArea = pocIndex;
    final target = widget.valueArea;
    if (target is num &&
        target > 0 &&
        target <= 1 &&
        total > 0 &&
        pocIndex >= 0) {
      var area = bins[pocIndex].bin.volume;
      while (area < total * target &&
          (lowArea > 0 || highArea < bins.length - 1)) {
        final below = lowArea > 0 ? bins[lowArea - 1].bin.volume : -1.0;
        final above = highArea < bins.length - 1
            ? bins[highArea + 1].bin.volume
            : -1.0;
        if (above >= below) {
          highArea++;
          area += above;
        } else {
          lowArea--;
          area += below;
        }
      }
    } else {
      lowArea = -1;
      highArea = -1;
    }
  }

  @override
  Widget build(BuildContext context) => _ProfileScope(
    state: this,
    child: BeuiChartFrame(
      label: widget.label,
      child:
          widget.child ??
          const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BeuiVolumeProfilePlot(),
              SizedBox(height: 12),
              BeuiVolumeProfileTooltip(),
              SizedBox(height: 12),
              BeuiVolumeProfileSummary(),
            ],
          ),
    ),
  );
}

@immutable
class _ProfileBin {
  const _ProfileBin({required this.id, required this.bin});
  final String id;
  final BeuiVolumeProfileBin bin;
}

class _ProfileScope extends InheritedWidget {
  const _ProfileScope({required this.state, required super.child});
  final _BeuiVolumeProfileState state;
  static _BeuiVolumeProfileState of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<_ProfileScope>();
    assert(s != null, 'Volume profile parts must be inside BeuiVolumeProfile.');
    return s!.state;
  }

  @override
  bool updateShouldNotify(_ProfileScope old) => true;
}

/// Interactive horizontal volume bars with a vertical keyboard inspector.
class BeuiVolumeProfilePlot extends StatelessWidget {
  /// Creates the plot.
  const BeuiVolumeProfilePlot({super.key, this.height = 300});

  /// Plot height.
  final double height;
  @override
  Widget build(BuildContext context) {
    final state = _ProfileScope.of(context);
    final colors = BeuiColors.resolve(context);
    if (state.bins.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('No volume data')),
      );
    }
    final prices = state.bins.map((b) => b.bin.price).toList();
    final lo = prices.reduce(math.min);
    final hi = prices.reduce(math.max);
    final span = math.max(hi - lo, 1.0);
    final barHeight = math.max(2.0, height / state.bins.length);
    double barTop(int index) {
      final top = state.bins.length == 1
          ? 0.0
          : ((hi - prices[index]) / span).clamp(0.0, 1.0) * height;
      return top.clamp(0, math.max(0, height - barHeight));
    }

    int binIndexAt(double y) {
      var closestIndex = 0;
      var closestDistance = double.infinity;
      var visibleIndex = -1;
      for (var i = 0; i < state.bins.length; i++) {
        final top = barTop(i);
        if (y >= top && y <= top + barHeight) visibleIndex = i;
        final distance = (y - top - barHeight / 2).abs();
        if (distance <= closestDistance) {
          closestIndex = i;
          closestDistance = distance;
        }
      }
      return visibleIndex < 0 ? closestIndex : visibleIndex;
    }

    final active = state.bins.indexWhere((b) => b.id == state.inspectedId);
    final index = active < 0
        ? state.pocIndex.clamp(0, state.bins.length - 1)
        : active;
    final barColor = beuiChartColor(
      state.widget.color,
      colors,
      fallback: colors.primary,
    );
    final pocColor = beuiChartColor(
      state.widget.pocColor,
      colors,
      fallback: colors.warning,
    );
    return SizedBox(
      height: height,
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  state.price(hi),
                  style: TextStyle(fontSize: 10, color: colors.mutedForeground),
                ),
                Text(
                  state.price(lo),
                  style: TextStyle(fontSize: 10, color: colors.mutedForeground),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < state.bins.length; i++)
                    Builder(
                      builder: (context) {
                        final bin = state.bins[i].bin;
                        final top = barTop(i);
                        final h = barHeight;
                        final isPoc = i == state.pocIndex;
                        final inArea =
                            i >= state.lowArea && i <= state.highArea;
                        final fraction = state.maxVolume <= 0
                            ? 0.0
                            : (bin.volume / state.maxVolume).clamp(0, 1);
                        return Positioned(
                          top: top,
                          left: 0,
                          right: 0,
                          height: h,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: BeuiChartSpring(
                              value: constraints.maxWidth * fraction,
                              builder: (context, w) => Container(
                                width: w,
                                height: math.max(1, h - 1),
                                decoration: BoxDecoration(
                                  color: isPoc
                                      ? pocColor
                                      : barColor.withValues(
                                          alpha: inArea || state.lowArea < 0
                                              ? .82
                                              : .3,
                                        ),
                                  borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(3),
                                  ),
                                  border: state.bins[i].id == state.inspectedId
                                      ? Border.all(
                                          color: colors.foreground,
                                          width: 1.5,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  Positioned.fill(
                    child: MouseRegion(
                      onHover: (event) {
                        state.hoverBin(
                          state.bins[binIndexAt(event.localPosition.dy)].id,
                        );
                      },
                      onExit: (_) => state.clearHoveredBin(),
                      child: Focus(
                        autofocus: true,
                        onKeyEvent: (_, event) =>
                            state.handleInspectorKey(event)
                            ? KeyEventResult.handled
                            : KeyEventResult.ignored,
                        child: Semantics(
                          slider: true,
                          focusable: true,
                          label: '${state.widget.label}: inspect price level',
                          value: state.price(state.bins[index].bin.price),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (e) {
                              state.setActiveId(
                                state.bins[binIndexAt(e.localPosition.dy)].id,
                              );
                            },
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.volume(state.maxVolume),
                  style: TextStyle(fontSize: 10, color: colors.mutedForeground),
                ),
                Text(
                  'Volume ${state.widget.unit}',
                  style: TextStyle(fontSize: 10, color: colors.mutedForeground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary of the active bin and control levels.
class BeuiVolumeProfileSummary extends StatelessWidget {
  /// Creates the summary.
  const BeuiVolumeProfileSummary({super.key});
  @override
  Widget build(BuildContext context) {
    final s = _ProfileScope.of(context);
    final colors = BeuiColors.resolve(context);
    if (s.bins.isEmpty) return const SizedBox.shrink();
    final selected = s.bins.where((b) => b.id == s.inspectedId).firstOrNull;
    final bin =
        selected?.bin ??
        (s.pocIndex < 0 ? s.bins.first.bin : s.bins[s.pocIndex].bin);
    final areaVolume = s.lowArea < 0
        ? 0.0
        : s.bins
              .sublist(s.lowArea, s.highArea + 1)
              .fold<double>(0, (a, b) => a + b.bin.volume);
    final pocText = s.pocIndex < 0
        ? '—'
        : s.price(s.bins[s.pocIndex].bin.price);
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        Text(
          'POC $pocText',
          style: TextStyle(color: colors.warning, fontSize: 12),
        ),
        if (s.lowArea >= 0)
          Text(
            'Value area ${s.price(s.bins[s.lowArea].bin.price)} – ${s.price(s.bins[s.highArea].bin.price)} (${s.total <= 0 ? '0%' : beuiChartPercent(areaVolume / s.total)})',
            style: TextStyle(color: colors.mutedForeground, fontSize: 12),
          ),
        Text(
          '${s.price(bin.price)} · ${s.volume(bin.volume)} ${s.widget.unit}',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

/// Tooltip content for the active price bin.
class BeuiVolumeProfileTooltip extends StatelessWidget {
  /// Creates the tooltip slot.
  const BeuiVolumeProfileTooltip({
    super.key,
    this.side = BeuiChartTooltipSide.top,
  });

  /// Preferred placement.
  final BeuiChartTooltipSide side;
  @override
  Widget build(BuildContext context) {
    final s = _ProfileScope.of(context);
    final found = s.bins.where((b) => b.id == s.inspectedId).firstOrNull;
    if (found == null) return const SizedBox.shrink();
    final bin = found.bin;
    final index = s.bins.indexOf(found);
    final low = index == 0
        ? bin.price -
              (s.bins.length > 1 ? (s.bins[1].bin.price - bin.price) / 2 : 0)
        : (s.bins[index - 1].bin.price + bin.price) / 2;
    final high = index == s.bins.length - 1
        ? bin.price +
              (s.bins.length > 1
                  ? (bin.price - s.bins[index - 1].bin.price) / 2
                  : 0)
        : (bin.price + s.bins[index + 1].bin.price) / 2;
    final share = s.total > 0 ? bin.volume / s.total : 0.0;
    const tickerStyle = TextStyle(fontSize: 11);
    return Semantics(
      liveRegion: true,
      label: '${s.price(bin.price)}, volume ${s.volume(bin.volume)}',
      child: BeuiChartTooltipCard(
        title: '${s.price(low)} – ${s.price(high)}',
        titleWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BeuiChartTicker(
              value: low,
              format: (value) => s.price(value.toDouble()),
              style: tickerStyle,
            ),
            const Text(' – '),
            BeuiChartTicker(
              value: high,
              format: (value) => s.price(value.toDouble()),
              style: tickerStyle,
            ),
          ],
        ),
        details: [
          _profileTickerRow(
            'Volume',
            bin.volume,
            (value) => '${s.volume(value.toDouble())} ${s.widget.unit}',
          ),
          if (bin.buy != null) Text('Buy ${s.volume(bin.buy!)}'),
          if (bin.sell != null) Text('Sell ${s.volume(bin.sell!)}'),
          _profileTickerRow(
            'Share',
            share * 100,
            (value) => '${value.toStringAsFixed(1)}%',
          ),
          if (index == s.pocIndex) const Text('Point of control'),
          if (s.lowArea >= 0 && index >= s.lowArea && index <= s.highArea)
            const Text('Value area'),
        ],
      ),
    );
  }
}

Widget _profileTickerRow(
  String label,
  num value,
  String Function(num) format,
) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text('$label '),
    BeuiChartTicker(value: value, format: format),
  ],
);
