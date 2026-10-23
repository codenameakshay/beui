/// Volume-by-price profile with point of control and value area.
library;

import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../motion/tooltip.dart';
import '../theme/beui_colors.dart';
import '_shared.dart';

/// One pre-aggregated price bin.
@immutable
class BeuiVolumeProfileBin {
  /// Creates a legacy unit-width bin. Use [BeuiVolumeProfileBin.range] for
  /// stable identity and explicit price geometry.
  const BeuiVolumeProfileBin({
    required double price,
    required this.volume,
    this.buy,
    this.sell,
  }) : id = null,
       priceLow = price - .5,
       priceHigh = price + .5;

  /// Creates a stable, explicitly bounded source price range.
  const BeuiVolumeProfileBin.range({
    required String this.id,
    required this.priceLow,
    required this.priceHigh,
    required this.volume,
    this.buy,
    this.sell,
  });

  /// Stable identity across sessions, reorder, and replacement.
  final String? id;

  /// Inclusive lower price bound.
  final double priceLow;

  /// Upper price bound.
  final double priceHigh;

  /// Representative price for this bin.
  double get price => priceLow + (priceHigh - priceLow) / 2;

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
    this.unit = 'units',
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
    with BeuiChartActiveState<BeuiVolumeProfile> {
  late List<_ProfileBin> bins;
  late int pocIndex, lowArea, highArea;
  late double total, maxVolume;
  final _focus = FocusNode();
  final _anchor = GlobalKey();
  final _anchorLink = LayerLink();
  Offset? _pointer;
  String? _lastPointerId;
  bool _pointerDriven = false;
  bool _keyboard = false;
  bool _showFocus = false;
  bool _tooltipOpen = false;
  String? get inspectedId => _tooltipOpen ? activeId : null;

  void setTooltipOpen(bool open) {
    if (_tooltipOpen != open) setState(() => _tooltipOpen = open);
  }

  void showFocus(bool visible) {
    final show = visible && _keyboard;
    if (_showFocus != show) setState(() => _showFocus = show);
  }

  void hoverBin(String id, Offset pointer) {
    setActiveId(id);
    setState(() {
      _pointer = pointer;
      _keyboard = false;
    });
    if (_lastPointerId != id) setTooltipOpen(true);
    _lastPointerId = id;
  }

  void clearHoveredBin() {
    _lastPointerId = null;
    if (!_focus.hasFocus || _pointerDriven) setTooltipOpen(false);
  }

  @override
  String? get widgetActiveId => widget.activeId;
  @override
  String? get widgetDefaultActiveId => widget.defaultActiveId;
  @override
  ValueChanged<String?>? get widgetOnActiveChange => widget.onActiveChange;
  @override
  Iterable<String> get knownIds => bins.map((b) => b.id);
  String describe(int index) {
    final bin = bins[index].bin;
    final level = index == pocIndex
        ? '. Point of control'
        : lowArea >= 0 && index >= lowArea && index <= highArea
        ? '. Inside value area'
        : '';
    return '${price(bin.priceLow)} to ${price(bin.priceHigh)}. ${volume(bin.volume)} ${widget.unit}. ${(total > 0 ? bin.volume / total * 100 : 0).toStringAsFixed(1)}% of total volume$level';
  }

  bool handleInspectorKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent || bins.isEmpty) {
      return false;
    }
    final key = event.logicalKey;
    _pointerDriven = false;
    _keyboard = true;
    showFocus(true);
    if (key == LogicalKeyboardKey.escape) {
      setTooltipOpen(false);
      return true;
    }
    final current = math.max(0, bins.indexWhere((b) => b.id == activeId));
    final next = switch (key) {
      LogicalKeyboardKey.home => 0,
      LogicalKeyboardKey.end => bins.length - 1,
      LogicalKeyboardKey.arrowUp ||
      LogicalKeyboardKey.arrowRight => math.min(current + 1, bins.length - 1),
      LogicalKeyboardKey.arrowDown ||
      LogicalKeyboardKey.arrowLeft => math.max(current - 1, 0),
      _ => -1,
    };
    if (next < 0) return false;
    setActiveId(bins[next].id);
    setTooltipOpen(true);
    return true;
  }

  String Function(double) get price =>
      widget.formatPrice ??
      (v) => beuiChartFormatNumber(
        v,
        maximumFractionDigits: 2,
      ).replaceFirst(RegExp(r'\.?0+$'), '');
  String Function(double) get volume =>
      widget.formatVolume ??
      (v) => beuiChartFormatNumber(
        v,
        maximumFractionDigits: 2,
      ).replaceFirst(RegExp(r'\.?0+$'), '');
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
      _rebuild();
      if (activeId == null) super.setActiveId(null);
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _rebuild() {
    bins = [
      for (var i = 0; i < widget.data.length; i++)
        _ProfileBin(id: widget.data[i].id ?? '$i', bin: widget.data[i]),
    ]..sort((a, b) => a.bin.priceLow.compareTo(b.bin.priceLow));
    final target = widget.valueArea;
    if (target != false &&
        (target is! num || !target.isFinite || target <= 0 || target > 1)) {
      throw ArgumentError(
        'VolumeProfile: valueArea must be a fraction above 0 and at most 1, or false.',
      );
    }
    final ids = <String>{};
    for (var i = 0; i < bins.length; i++) {
      final bin = bins[i].bin;
      if (!ids.add(bins[i].id)) {
        throw ArgumentError('VolumeProfile: duplicate bin ID "${bins[i].id}".');
      }
      if (!bin.priceLow.isFinite ||
          !bin.priceHigh.isFinite ||
          bin.priceHigh <= bin.priceLow ||
          !bin.volume.isFinite ||
          bin.volume < 0) {
        throw ArgumentError(
          'VolumeProfile: bins need finite increasing price bounds and nonnegative volume.',
        );
      }
      if (i > 0 && bin.priceLow < bins[i - 1].bin.priceHigh) {
        throw ArgumentError('VolumeProfile: price ranges must not overlap.');
      }
    }
    total = bins.fold(
      0,
      (s, b) =>
          s + (b.bin.volume.isFinite && b.bin.volume > 0 ? b.bin.volume : 0),
    );
    maxVolume = bins.fold(0, (m, b) => math.max(m, b.bin.volume));
    pocIndex = -1;
    for (var i = 0; i < bins.length; i++) {
      if (bins[i].bin.volume > (pocIndex < 0 ? 0 : bins[pocIndex].bin.volume)) {
        pocIndex = i;
      }
    }
    lowArea = pocIndex;
    highArea = pocIndex;
    if (!total.isFinite ||
        (bins.isNotEmpty &&
            !(bins.last.bin.priceHigh - bins.first.bin.priceLow).isFinite)) {
      throw ArgumentError(
        'VolumeProfile: the total volume and price span must remain finite.',
      );
    }
    if (target == 1 && total > 0 && pocIndex >= 0) {
      lowArea = 0;
      highArea = bins.length - 1;
    } else if (target is num &&
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
        final takeAbove =
            above > below ||
            (above == below &&
                highArea + 1 - pocIndex <= pocIndex - (lowArea - 1));
        final next = takeAbove ? above : below;
        if (area + next > total * target) break;
        area += next;
        if (takeAbove) {
          highArea++;
        } else {
          lowArea--;
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
              BeuiVolumeProfileTooltip(),
              SizedBox(height: 20),
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
  const BeuiVolumeProfilePlot({super.key, this.height = 320});

  /// Plot height.
  final double height;
  @override
  Widget build(BuildContext context) {
    final state = _ProfileScope.of(context);
    final colors = BeuiColors.resolve(context);
    if (state.bins.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            'No volume data',
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              color: colors.mutedForeground,
            ),
          ),
        ),
      );
    }
    final lo = state.bins.first.bin.priceLow;
    final hi = state.bins.last.bin.priceHigh;
    final span = hi - lo;
    final axisStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: MediaQuery.sizeOf(context).width < 640 ? 10 : 12,
      height: 4 / 3,
      color: colors.mutedForeground,
    );
    final priceTicks = List.generate(5, (i) => state.price(hi - span * i / 4));
    double barTop(int index) =>
        (hi - state.bins[index].bin.priceHigh) / span * height;
    double barHeight(int index) =>
        (state.bins[index].bin.priceHigh - state.bins[index].bin.priceLow) /
        span *
        height;

    int binIndexAt(double y) {
      var closestIndex = 0;
      var closestDistance = double.infinity;
      var visibleIndex = -1;
      for (var i = 0; i < state.bins.length; i++) {
        final top = barTop(i);
        if (y >= top && y <= top + barHeight(i)) visibleIndex = i;
        final distance = (y - top - barHeight(i) / 2).abs();
        if (distance < closestDistance) {
          closestIndex = i;
          closestDistance = distance;
        }
      }
      return visibleIndex < 0 ? closestIndex : visibleIndex;
    }

    final active = state.bins.indexWhere((b) => b.id == state.activeId);
    final index = active < 0 ? 0 : active;
    final barColor = beuiChartColor(
      state.widget.color,
      colors,
      fallback: const Color(0xff6366f1),
    );
    final pocColor = beuiChartColor(
      state.widget.pocColor,
      colors,
      fallback: const Color(0xfff59e0b),
    );
    return SizedBox(
      height: height + 24,
      child: Column(
        children: [
          SizedBox(
            height: height,
            child: Row(
              children: [
                IntrinsicWidth(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Opacity(
                        opacity: 0,
                        child: Column(
                          children: [
                            for (final tick in priceTicks)
                              Text(tick, style: axisStyle),
                          ],
                        ),
                      ),
                      for (var i = 0; i < 5; i++)
                        Positioned(
                          right: 0,
                          top: height * i / 4 - 8,
                          child: Text(priceTicks[i], style: axisStyle),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: height + 8,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (final text in [
                                '0',
                                state.volume(state.maxVolume / 2),
                                state.volume(state.maxVolume),
                              ])
                                Text(text, style: axisStyle),
                            ],
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ProfileLines(
                              color: colors.border.withValues(alpha: .6),
                            ),
                          ),
                        ),
                        for (var i = 0; i < state.bins.length; i++)
                          Builder(
                            builder: (context) {
                              final bin = state.bins[i].bin;
                              final top = barTop(i);
                              final h = barHeight(i);
                              final isPoc = i == state.pocIndex;
                              final inArea =
                                  i >= state.lowArea && i <= state.highArea;
                              final fraction = state.maxVolume <= 0
                                  ? 0.0
                                  : (bin.volume / state.maxVolume).clamp(0, 1);
                              return Positioned(
                                key: ValueKey(state.bins[i].id),
                                top: top,
                                left: 0,
                                right: 0,
                                height: h,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: BeuiChartTween(
                                    from: 0,
                                    value: isPoc || inArea || state.lowArea < 0
                                        ? .9
                                        : .3,
                                    duration: const Duration(milliseconds: 180),
                                    builder: (context, opacity) => Opacity(
                                      opacity: opacity.clamp(0, 1),
                                      child: BeuiChartSpring(
                                        value: constraints.maxWidth * fraction,
                                        builder: (context, w) => Container(
                                          key: ValueKey(
                                            'volume-bar-${state.bins[i].id}',
                                          ),
                                          width: w,
                                          height: math.max(0, h - 2),
                                          decoration: BoxDecoration(
                                            color: isPoc ? pocColor : barColor,
                                            borderRadius:
                                                const BorderRadius.horizontal(
                                                  right: Radius.circular(2),
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        for (var i = 0; i < state.bins.length; i++)
                          Positioned(
                            top: barTop(i),
                            left: 0,
                            right: 0,
                            height: barHeight(i),
                            child: BeuiChartTween(
                              value: state.bins[i].id == state.inspectedId
                                  ? 1
                                  : 0,
                              duration: const Duration(milliseconds: 100),
                              builder: (context, opacity) => ColoredBox(
                                key: ValueKey(
                                  'volume-hover-${state.bins[i].id}',
                                ),
                                color: colors.foreground.withValues(
                                  alpha: .05 * opacity.clamp(0, 1),
                                ),
                              ),
                            ),
                          ),
                        if (state.pocIndex >= 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            top:
                                barTop(state.pocIndex) +
                                barHeight(state.pocIndex) / 2,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CustomPaint(
                                  size: Size(constraints.maxWidth, 1),
                                  painter: _ProfileLines(
                                    color: pocColor,
                                    poc: true,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: -9,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: colors.background,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        'POC',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w500,
                                          fontSize: 10,
                                          height: 1.4,
                                          color: colors.foreground,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Positioned.fill(
                          child: Focus(
                            canRequestFocus: false,
                            onKeyEvent: (_, event) =>
                                state.handleInspectorKey(event)
                                ? KeyEventResult.handled
                                : KeyEventResult.ignored,
                            child: FocusableActionDetector(
                              focusNode: state._focus,
                              includeFocusSemantics: false,
                              onShowFocusHighlight: state.showFocus,
                              onFocusChange: (focused) {
                                if (focused) {
                                  if (!state._pointerDriven) {
                                    state._keyboard = true;
                                    state.setActiveId(state.bins[index].id);
                                    state.setTooltipOpen(true);
                                  }
                                } else {
                                  state._pointerDriven = false;
                                  state.setTooltipOpen(false);
                                }
                              },
                              child: Semantics(
                                slider: true,
                                focusable: true,
                                focused: state._focus.hasFocus,
                                increasedValue: state.describe(
                                  math.min(index + 1, state.bins.length - 1),
                                ),
                                decreasedValue: state.describe(
                                  math.max(index - 1, 0),
                                ),
                                onIncrease: () {
                                  state._keyboard = true;
                                  state.setActiveId(
                                    state
                                        .bins[math.min(
                                          index + 1,
                                          state.bins.length - 1,
                                        )]
                                        .id,
                                  );
                                  state.setTooltipOpen(true);
                                },
                                onDecrease: () {
                                  state._keyboard = true;
                                  state.setActiveId(
                                    state.bins[math.max(index - 1, 0)].id,
                                  );
                                  state.setTooltipOpen(true);
                                },
                                label:
                                    '${state.widget.label}: inspect price level',
                                value: state.describe(index),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.precise,
                                  onEnter: (e) {
                                    if (e.kind != PointerDeviceKind.touch) {
                                      state.hoverBin(
                                        state
                                            .bins[binIndexAt(
                                              e.localPosition.dy,
                                            )]
                                            .id,
                                        e.localPosition,
                                      );
                                    }
                                  },
                                  onHover: (e) {
                                    if (e.kind != PointerDeviceKind.touch) {
                                      state.hoverBin(
                                        state
                                            .bins[binIndexAt(
                                              e.localPosition.dy,
                                            )]
                                            .id,
                                        e.localPosition,
                                      );
                                    }
                                  },
                                  onExit: (e) {
                                    if (e.kind != PointerDeviceKind.touch) {
                                      state.clearHoveredBin();
                                    }
                                  },
                                  child: Listener(
                                    behavior: HitTestBehavior.opaque,
                                    onPointerDown: (e) {
                                      state._pointerDriven = true;
                                      state.showFocus(false);
                                      state._lastPointerId = null;
                                      state.hoverBin(
                                        state
                                            .bins[binIndexAt(
                                              e.localPosition.dy,
                                            )]
                                            .id,
                                        e.localPosition,
                                      );
                                      state._focus.requestFocus();
                                    },
                                    onPointerMove: (e) => state.hoverBin(
                                      state
                                          .bins[binIndexAt(e.localPosition.dy)]
                                          .id,
                                      e.localPosition,
                                    ),
                                    onPointerUp: (_) =>
                                        state._pointerDriven = false,
                                    onPointerCancel: (_) {
                                      state._pointerDriven = false;
                                      state.setTooltipOpen(false);
                                    },
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: !state._keyboard && state._pointer != null
                              ? state._pointer!.dx
                              : constraints.maxWidth *
                                    math.max(
                                      .1,
                                      state.maxVolume == 0
                                          ? 0
                                          : state.bins[index].bin.volume /
                                                state.maxVolume /
                                                2,
                                    ),
                          top: !state._keyboard && state._pointer != null
                              ? state._pointer!.dy
                              : barTop(index) + barHeight(index) / 2,
                          width: 0,
                          height: 0,
                          child: IgnorePointer(
                            child: CompositedTransformTarget(
                              key: state._anchor,
                              link: state._anchorLink,
                              child: const SizedBox.shrink(),
                            ),
                          ),
                        ),
                        if (state._showFocus)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                key: const ValueKey('volume-focus-ring'),
                                painter: _ProfileFocusRing(colors.ring),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLines extends CustomPainter {
  const _ProfileLines({required this.color, this.poc = false});
  final Color color;
  final bool poc;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    if (poc) {
      for (var x = 0.0; x < size.width; x += 6) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(math.min(x + 3, size.width), 0),
          paint,
        );
      }
    } else {
      for (var i = 0; i <= 4; i++) {
        final x = size.width * i / 4;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ProfileLines old) => color != old.color || poc != old.poc;
}

class _ProfileFocusRing extends CustomPainter {
  const _ProfileFocusRing(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawRRect(
    RRect.fromRectAndRadius(
      (Offset.zero & size).inflate(5),
      const Radius.circular(7),
    ),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  @override
  bool shouldRepaint(_ProfileFocusRing old) => old.color != color;
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
    final areaVolume = s.lowArea < 0
        ? 0.0
        : s.bins
              .sublist(s.lowArea, s.highArea + 1)
              .fold<double>(0, (a, b) => a + b.bin.volume);
    final pocText = s.pocIndex < 0
        ? '—'
        : s.price(s.bins[s.pocIndex].bin.price);
    Widget cell(String label, String value, {Color? dot, String? detail}) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (dot != null) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(dimension: 6),
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colors.mutedForeground,
                      fontSize: 12,
                      height: 4 / 3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: colors.foreground,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
                fontSize: 12,
                height: 4 / 3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail,
                style: TextStyle(
                  color: colors.mutedForeground,
                  fontSize: 12,
                  height: 4 / 3,
                ),
              ),
            ],
          ],
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 17),
        child: LayoutBuilder(
          builder: (context, box) {
            final narrow = MediaQuery.sizeOf(context).width < 640;
            final width =
                (box.maxWidth - (narrow ? 16 : 32)) / (narrow ? 2 : 3);
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: width,
                  child: cell(
                    'Total volume',
                    '${s.volume(s.total)} ${s.widget.unit}',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: cell(
                    'Point of control',
                    pocText,
                    dot: beuiChartColor(
                      s.widget.pocColor,
                      colors,
                      fallback: const Color(0xfff59e0b),
                    ),
                  ),
                ),
                if (s.lowArea >= 0)
                  SizedBox(
                    width: narrow ? box.maxWidth : width,
                    child: cell(
                      'Value area · ${((s.widget.valueArea as num) * 100).round()}% target',
                      '${s.price(s.bins[s.lowArea].bin.priceLow)} – ${s.price(s.bins[s.highArea].bin.priceHigh)}',
                      dot: beuiChartColor(
                        s.widget.color,
                        colors,
                        fallback: const Color(0xff6366f1),
                      ),
                      detail:
                          '${(s.total <= 0 ? 0 : areaVolume / s.total * 100).toStringAsFixed(1)}% of volume',
                    ),
                  ),
              ],
            );
          },
        ),
      ),
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
    if (s.bins.isEmpty) return const SizedBox.shrink();
    final found = s.bins.where((b) => b.id == s.activeId).firstOrNull;
    final bin = found?.bin;
    final index = found == null ? -1 : s.bins.indexOf(found);
    final colors = BeuiColors.resolve(context);
    const numberStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      height: 4 / 3,
    );
    Widget number(
      double value,
      String Function(double) format, {
      bool title = false,
    }) => BeuiChartTicker(
      value: value,
      format: (value) => format(value.toDouble()),
      style: numberStyle.copyWith(
        fontWeight: title ? FontWeight.w500 : FontWeight.w400,
      ),
    );
    return BeuiTooltip(
      externalAnchor: s._anchor,
      anchorLink: s._anchorLink,
      side: beuiChartToTooltipSide(side),
      open: s._tooltipOpen && bin != null,
      onOpenChange: (open) {
        if (!open) s.setTooltipOpen(false);
      },
      delay: Duration.zero,
      content: bin == null
          ? const SizedBox.shrink()
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 256),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: 12,
                  height: 4 / 3,
                  color: colors.foreground,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        number(bin.priceLow, s.price, title: true),
                        const SizedBox(width: 4),
                        const Text('–'),
                        const SizedBox(width: 4),
                        number(bin.priceHigh, s.price, title: true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        number(bin.volume, s.volume),
                        const SizedBox(width: 4),
                        Text(s.widget.unit),
                        const SizedBox(width: 4),
                        DefaultTextStyle.merge(
                          style: TextStyle(color: colors.mutedForeground),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('·'),
                              const SizedBox(width: 4),
                              number(
                                s.total > 0 ? bin.volume / s.total * 100 : 0,
                                (v) => '${v.toStringAsFixed(1)}%',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (index == s.pocIndex ||
                        s.lowArea >= 0 &&
                            index >= s.lowArea &&
                            index <= s.highArea) ...[
                      const SizedBox(height: 6),
                      Text(
                        index == s.pocIndex
                            ? 'Point of control'
                            : 'Inside value area',
                        style: TextStyle(color: colors.mutedForeground),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      child: const SizedBox.shrink(),
    );
  }
}
