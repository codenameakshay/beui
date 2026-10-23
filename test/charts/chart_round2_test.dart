import 'dart:ui' as ui;

import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/donut_chart_demo.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/funnel_chart_demo.dart';
import '../support.dart';

const _boundary = ValueKey('round2-candles');
const _original = [
  BeuiCandle(
    id: 'moving',
    time: 'A',
    open: 40,
    high: 70,
    low: 30,
    close: 60,
    volume: 20,
  ),
  BeuiCandle(
    id: 'anchor',
    time: 'B',
    open: 0,
    high: 100,
    low: 0,
    close: 100,
    volume: 100,
  ),
];
const _updated = [
  BeuiCandle(
    id: 'moving',
    time: 'A',
    open: 45,
    high: 90,
    low: 10,
    close: 70,
    volume: 80,
  ),
  BeuiCandle(
    id: 'anchor',
    time: 'B',
    open: 0,
    high: 100,
    low: 0,
    close: 100,
    volume: 100,
  ),
];

Widget _candles(List<BeuiCandle> candles, {bool reduce = false}) => beuiTestApp(
  BeuiCandlestickChart(
    candles: candles,
    child: const RepaintBoundary(
      key: _boundary,
      child: SizedBox(width: 400, child: BeuiCandlestickPlot()),
    ),
  ),
  reduce: reduce,
);

Future<(int, int, int)> _candleInk(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    int firstInk(int x, int from, int to) {
      for (var y = from; y < to; y++) {
        final offset = (y * image.width + x) * 4;
        if (bytes.getUint8(offset + 1) > bytes.getUint8(offset) * 2 + 10 &&
            bytes.getUint8(offset + 1) > bytes.getUint8(offset + 2) * 1.2 &&
            bytes.getUint8(offset + 3) > 20) {
          return y;
        }
      }
      return -1;
    }

    final bounds = (
      firstInk(84, 0, 254),
      firstInk(100, 0, 254),
      firstInk(100, 263, 320),
    );
    image.dispose();
    return bounds;
  }))!;
}

Future<int> _columnInk(WidgetTester tester, Key key, int x) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    var sum = 0;
    for (var y = 80; y < 250; y++) {
      final offset = (y * image.width + x) * 4;
      sum +=
          bytes.getUint8(offset) +
          bytes.getUint8(offset + 1) +
          bytes.getUint8(offset + 2);
    }
    image.dispose();
    return sum;
  }))!;
}

void main() {
  testWidgets(
    'non-last candle wick body and volume spring independently and reverse',
    (tester) async {
      await tester.pumpWidget(_candles(_original));
      await tester.pumpAndSettle();
      final before = await _candleInk(tester);
      expect(before.$1, inInclusiveRange(82, 85));
      expect(before.$2, inInclusiveRange(104, 107));
      expect(before.$3, inInclusiveRange(307, 310));
      await tester.pumpWidget(_candles(_updated));
      await tester.pump(const Duration(milliseconds: 48));
      final moving = await _candleInk(tester);
      expect(moving.$1, greaterThan(40));
      expect(moving.$1, lessThan(before.$1));
      expect(moving.$2, greaterThan(84));
      expect(moving.$2, lessThan(before.$2));
      expect(moving.$3, greaterThan(274));
      expect(moving.$3, lessThan(before.$3));
      await tester.pumpWidget(_candles(_original));
      await tester.pump(const Duration(milliseconds: 16));
      final reversed = await _candleInk(tester);
      expect(reversed.$1, isNot(before.$1));
      await tester.pumpAndSettle();
      expect(await _candleInk(tester), before);
    },
  );

  testWidgets(
    'reduced candle geometry reaches all new targets without intermediate motion',
    (tester) async {
      await tester.pumpWidget(_candles(_original, reduce: true));
      await tester.pumpWidget(_candles(_updated, reduce: true));
      final target = await _candleInk(tester);
      expect(target.$1, inInclusiveRange(38, 41));
      expect(target.$2, inInclusiveRange(82, 85));
      expect(target.$3, inInclusiveRange(273, 276));
      await tester.pump(const Duration(milliseconds: 48));
      expect(await _candleInk(tester), target);
    },
  );

  testWidgets('candle entrance fades the second candle 12ms after the first', (
    tester,
  ) async {
    await tester.pumpWidget(_candles(_original));
    double opacity(String id) => tester
        .widget<Opacity>(
          find
              .descendant(
                of: find.byKey(ValueKey(id)),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;
    expect(opacity('moving'), 0);
    expect(opacity('anchor'), 0);
    await tester.pump(const Duration(milliseconds: 6));
    expect(opacity('moving'), greaterThan(0));
    expect(opacity('anchor'), 0);
    await tester.pump(const Duration(milliseconds: 12));
    await tester.pump(const Duration(milliseconds: 6));
    expect(opacity('anchor'), greaterThan(0));
    expect(opacity('anchor'), lessThan(opacity('moving')));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'bump dots and endpoint labels follow an interrupted rank spring',
    (tester) async {
      Widget surface(List<int> ranks, {bool reduce = false}) => beuiTestApp(
        SizedBox(
          width: 560,
          child: BeuiBumpChart(
            periods: const ['Apr', 'May'],
            series: [
              BeuiBumpSeries(id: 'one', name: 'One', ranks: ranks),
              const BeuiBumpSeries(id: 'anchor', name: 'Anchor', ranks: [1, 5]),
            ],
          ),
        ),
        reduce: reduce,
      );
      final dot = find.byKey(const ValueKey('bump-node-one-1'));
      await tester.pumpWidget(surface([2, 2]));
      await tester.pumpAndSettle();
      final start = tester.getCenter(dot);
      await tester.pumpWidget(surface([4, 4]));
      await tester.pump(const Duration(milliseconds: 48));
      final moving = tester.getCenter(dot);
      expect(moving.dy, greaterThan(start.dy));
      expect(moving.dy, lessThan(start.dy + 88));
      final label = tester.getRect(find.text('One').first);
      expect(label.top, closeTo(moving.dy - 8, .01));
      await tester.pumpWidget(surface([2, 2]));
      await tester.pumpAndSettle();
      expect((tester.getCenter(dot) - start).distance, lessThan(.01));
      await tester.pumpWidget(surface([4, 4], reduce: true));
      expect(tester.getCenter(dot).dy, closeTo(start.dy + 88, .01));
    },
  );

  testWidgets(
    'bump hover scales a dot without pinning and exits to pinned series',
    (tester) async {
      final changes = <String?>[];
      await tester.pumpWidget(
        beuiTestApp(
          SizedBox(
            width: 560,
            child: BeuiBumpChart(
              periods: const ['Apr', 'May'],
              defaultActive: 'anchor',
              onActiveChange: changes.add,
              series: const [
                BeuiBumpSeries(id: 'one', name: 'One', ranks: [2, 1]),
                BeuiBumpSeries(id: 'anchor', name: 'Anchor', ranks: [1, 2]),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dot = find.byKey(const ValueKey('bump-node-one-1'));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(dot));
      await tester.pumpAndSettle();
      final scales = tester
          .widgetList<Transform>(
            find.descendant(of: dot, matching: find.byType(Transform)),
          )
          .map((w) => w.transform.storage[0]);
      expect(scales.any((v) => (v - 1.12).abs() < .01), isTrue);
      expect(changes, isEmpty);
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BeuiChartLegendItem>(
              find.byWidgetPredicate(
                (w) => w is BeuiChartLegendItem && w.label == 'Anchor',
              ),
            )
            .selected,
        isTrue,
      );
      await mouse.removePointer();
    },
  );

  testWidgets(
    'bump path hover highlights without pinning and restores on exit',
    (tester) async {
      final changes = <String?>[];
      await tester.pumpWidget(
        beuiTestApp(
          SizedBox(
            width: 560,
            child: BeuiBumpChart(
              periods: const ['Apr', 'May'],
              onActiveChange: changes.add,
              series: const [
                BeuiBumpSeries(id: 'one', name: 'One', ranks: [2, 2]),
                BeuiBumpSeries(id: 'anchor', name: 'Anchor', ranks: [5, 5]),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final start = tester.getCenter(
        find.byKey(const ValueKey('bump-node-one-0')),
      );
      final end = tester.getCenter(
        find.byKey(const ValueKey('bump-node-one-1')),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(Offset((start.dx + end.dx) / 2, start.dy));
      await tester.pumpAndSettle();
      BeuiChartLegendItem legend() => tester.widget<BeuiChartLegendItem>(
        find.byWidgetPredicate(
          (w) => w is BeuiChartLegendItem && w.label == 'One',
        ),
      );
      expect(legend().selected, isTrue);
      expect(changes, isEmpty);
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(legend().selected, isFalse);
      await mouse.removePointer();
    },
  );

  testWidgets('donut root and demo stack below the source 640px breakpoint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      beuiTestApp(Builder(builder: donutChartDemo), reduce: true),
    );
    final plot = tester.getRect(find.byType(BeuiDonutPlot));
    final legend = tester.getRect(find.byType(BeuiDonutLegend));
    expect(legend.top, greaterThanOrEqualTo(plot.bottom + 24));
    expect(legend.right, lessThanOrEqualTo(390));
    expect(plot.width, 256);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiDonutChart(
          segments: [BeuiDonutSegment(id: 'a', label: 'A', value: 10)],
        ),
        reduce: true,
      ),
    );
    final rootPlot = tester.getRect(find.byType(BeuiDonutPlot));
    expect(rootPlot.width, 256);
    expect(
      tester.getRect(find.byType(BeuiDonutLegend)).top,
      greaterThanOrEqualTo(rootPlot.bottom + 24),
    );
  });

  testWidgets(
    'donut entrance waits for forty percent visibility and does not replay',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        beuiTestApp(
          SizedBox(
            height: 400,
            child: SingleChildScrollView(
              controller: scroll,
              child: const Column(
                children: [
                  SizedBox(height: 500),
                  BeuiDonutChart(
                    segments: [
                      BeuiDonutSegment(id: 'a', label: 'A', value: 10),
                    ],
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: BeuiDonutPlot(),
                    ),
                  ),
                  SizedBox(height: 500),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final ring = find.byKey(const ValueKey('donut-ring-entrance'));
      expect(ring, findsNothing);
      scroll.jumpTo(170);
      await tester.pump();
      expect(ring, findsNothing);
      scroll.jumpTo(190);
      await tester.pump();
      expect(ring, findsOneWidget);
      await tester.pumpAndSettle();
      scroll.jumpTo(0);
      await tester.pump();
      scroll.jumpTo(190);
      await tester.pump();
      expect(
        tester
            .widgetList<Opacity>(
              find.descendant(
                of: find.byType(BeuiDonutPlot),
                matching: find.byType(Opacity),
              ),
            )
            .every((o) => o.opacity == 1),
        isTrue,
      );
    },
  );

  testWidgets(
    'profile ranges retain identity, hit unequal geometry, and validate input',
    (tester) async {
      const low = BeuiVolumeProfileBin.range(
        id: 'low',
        priceLow: 0,
        priceHigh: 10,
        volume: 10,
      );
      const high = BeuiVolumeProfileBin.range(
        id: 'high',
        priceLow: 20,
        priceHigh: 50,
        volume: 20,
      );
      final selected = <String?>[];
      Widget surface(List<BeuiVolumeProfileBin> bins) => beuiTestApp(
        BeuiVolumeProfile(
          data: bins,
          onActiveChange: selected.add,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiVolumeProfilePlot(height: 300),
              BeuiVolumeProfileTooltip(),
            ],
          ),
        ),
        reduce: true,
      );
      await tester.pumpWidget(surface([high, low]));
      final plot = tester.getRect(find.byType(BeuiVolumeProfilePlot));
      expect(tester.getRect(find.byKey(const ValueKey('high'))).height, 180);
      expect(tester.getRect(find.byKey(const ValueKey('low'))).height, 60);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(Offset(plot.right - 10, plot.top + 200));
      await tester.pump();
      expect(selected.last, 'low');
      await mouse.moveTo(Offset(plot.right - 10, plot.top + 100));
      await tester.pump();
      expect(selected.last, 'high');
      await tester.pumpWidget(
        surface([
          low,
          const BeuiVolumeProfileBin.range(
            id: 'high',
            priceLow: 20,
            priceHigh: 50,
            volume: 30,
          ),
        ]),
      );
      expect(find.byType(BeuiChartTooltipCard), findsOneWidget);
      expect(
        tester
            .widget<BeuiChartTooltipCard>(find.byType(BeuiChartTooltipCard))
            .title,
        '20.00 – 50.00',
      );
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(find.byType(BeuiChartTooltipCard), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(selected.last, 'high');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(selected.last, 'high');
      expect(find.byType(BeuiChartTooltipCard), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(selected.last, 'low');
      await mouse.removePointer();
      await tester.pumpWidget(surface([high]));
      expect(find.byType(BeuiChartTooltipCard), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      for (final invalid in <List<BeuiVolumeProfileBin>>[
        [low, low],
        [
          low,
          const BeuiVolumeProfileBin.range(
            id: 'overlap',
            priceLow: 9,
            priceHigh: 20,
            volume: 1,
          ),
        ],
        [
          const BeuiVolumeProfileBin.range(
            id: 'reversed',
            priceLow: 2,
            priceHigh: 1,
            volume: 1,
          ),
        ],
        [
          const BeuiVolumeProfileBin.range(
            id: 'nan',
            priceLow: 0,
            priceHigh: 1,
            volume: double.nan,
          ),
        ],
        [
          const BeuiVolumeProfileBin.range(
            id: 'negative',
            priceLow: 0,
            priceHigh: 1,
            volume: -1,
          ),
        ],
      ]) {
        await tester.pumpWidget(surface(invalid));
        expect(tester.takeException(), isArgumentError);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'composition default plot height is 320 and cursor moves with inspected period',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const SizedBox(
            width: 400,
            child: BeuiCompositionChart(
              periods: ['A', 'B'],
              series: [
                BeuiCompositionSeries(
                  id: 'one',
                  name: 'One',
                  color: '#2563eb',
                  values: [20, 30],
                ),
              ],
              child: RepaintBoundary(
                key: ValueKey('round2-composition'),
                child: BeuiCompositionPlot(),
              ),
            ),
          ),
          reduce: true,
        ),
      );
      final plot = tester.widget<BeuiCompositionPlot>(
        find.byType(BeuiCompositionPlot),
      );
      expect(plot.height, 320);
      await tester.tap(find.byType(BeuiCompositionPlot));
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(find.text('A'), findsWidgets);
      const boundary = ValueKey('round2-composition');
      expect(
        await _columnInk(tester, boundary, 100),
        lessThan(await _columnInk(tester, boundary, 300) - 500),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(find.text('B'), findsWidgets);
      expect(
        await _columnInk(tester, boundary, 300),
        lessThan(await _columnInk(tester, boundary, 100) - 500),
      );
    },
  );

  testWidgets(
    'funnel source buttons change direction and canonical cohort counts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        beuiTestApp(Builder(builder: funnelChartDemo), reduce: true),
      );
      expect(find.text('Product conversion · Sample cohorts'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      await tester.tap(find.text('Horizontal'));
      await tester.pump();
      expect(
        tester.widget<BeuiFunnelChart>(find.byType(BeuiFunnelChart)).direction,
        BeuiFunnelDirection.horizontal,
      );
      await tester.tap(find.text('Next cohort'));
      await tester.pump();
      expect(
        tester
            .widget<BeuiFunnelChart>(find.byType(BeuiFunnelChart))
            .stages
            .map((s) => s.value),
        [28000, 18200, 13650, 9100, 6370],
      );
    },
  );
}
