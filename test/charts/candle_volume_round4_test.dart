import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const candles = [
  BeuiCandle(
    id: 'a',
    time: '12:00',
    open: 10,
    high: 13,
    low: 9,
    close: 12,
    volume: 40,
  ),
  BeuiCandle(
    id: 'b',
    time: '12:05',
    open: 12,
    high: 14,
    low: 11,
    close: 11,
    volume: 55,
  ),
];
const bins = [
  BeuiVolumeProfileBin.range(id: 'a', priceLow: 10, priceHigh: 11, volume: 20),
  BeuiVolumeProfileBin.range(id: 'b', priceLow: 11, priceHigh: 12, volume: 10),
  BeuiVolumeProfileBin.range(id: 'c', priceLow: 12, priceHigh: 13, volume: 5),
];

void main() {
  testWidgets(
    'candle touch inspects only during movement, not a tap or hover',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(const BeuiCandlestickChart(candles: candles)),
      );
      await tester.pumpAndSettle();
      final plot = tester.getRect(find.byType(BeuiCandlestickPlot));
      final point = Offset(plot.left + 10, plot.top + 40);
      final touch = await tester.startGesture(point);
      await tester.pump();
      expect(find.text('12:05'), findsOneWidget);
      await touch.moveBy(const Offset(1, 0));
      await tester.pump();
      expect(find.text('12:00'), findsOneWidget);
      await touch.up();
      await tester.pump();
      expect(find.text('12:05'), findsOneWidget);
      tester.binding.handlePointerEvent(
        PointerHoverEvent(position: point, kind: PointerDeviceKind.touch),
      );
      await tester.pump();
      expect(find.text('12:05'), findsOneWidget);
      await tester.tapAt(point);
      await tester.pump();
      expect(find.text('12:05'), findsOneWidget);
    },
  );

  testWidgets('candle compact volume keeps source fractional precision', (
    tester,
  ) async {
    for (final entry in <(double, String)>[
      (120.14, '120.1'),
      (1000, '1K'),
      (1249, '1.2K'),
      (999999, '1M'),
    ]) {
      await tester.pumpWidget(
        beuiTestApp(
          BeuiCandlestickChart(
            candles: [
              BeuiCandle(
                id: 'a',
                time: '12:00',
                open: 10,
                high: 13,
                low: 9,
                close: 12,
                volume: entry.$1,
              ),
            ],
          ),
        ),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('candle-legend-Vol')))
            .data,
        entry.$2,
      );
    }
    await tester.pumpAndSettle();
  });

  testWidgets('volume touch release closes the readout but keeps its value', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiVolumeProfile(data: bins, onActiveChange: (id) => selected = id),
      ),
    );
    final plot = tester.getRect(find.byType(BeuiVolumeProfilePlot));
    final touch = await tester.startGesture(
      Offset(plot.center.dx, plot.top + 10),
    );
    await tester.pumpAndSettle();
    expect(selected, 'c');
    expect(tester.widget<BeuiTooltip>(find.byType(BeuiTooltip)).open, isTrue);
    await touch.up();
    await tester.pumpAndSettle();
    expect(selected, 'c');
    expect(tester.widget<BeuiTooltip>(find.byType(BeuiTooltip)).open, isFalse);
  });

  testWidgets('candle source palette, foreground volume, and minus glyph', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(
        beuiTestApp(const BeuiCandlestickChart(candles: candles), dark: dark),
      );
      await tester.pumpAndSettle();
      final value = tester.widget<Text>(
        find.byKey(const ValueKey('candle-legend-O')),
      );
      expect(
        value.style!.color,
        dark ? const Color(0xffff637e) : const Color(0xffec003f),
      );
      expect(find.text('−8.33%'), findsOneWidget);
      final volume = tester.widget<Text>(
        find.byKey(const ValueKey('candle-legend-Vol')),
      );
      expect(
        volume.style!.color,
        dark ? BeuiColors.dark().foreground : BeuiColors.light().foreground,
      );
    }
  });

  testWidgets(
    'last price is static exact 12px source tag and default max decimals',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiCandlestickChart(candles: candles, lastPrice: 12.75),
        ),
      );
      expect(find.byType(BeuiChartTicker), findsNothing);
      final tag = tester.widget<Text>(
        find.byKey(const ValueKey('candle-last-price')),
      );
      expect(tag.data, '12.75');
      expect(tag.style!.fontSize, 12);
      expect(tag.style!.height, 4 / 3);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('candle-legend-O'))).data,
        '12',
      );
    },
  );

  testWidgets('candle keyboard focus ring is absent after native mouse click', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiCandlestickChart(candles: candles)),
    );
    final plot = tester.getRect(find.byType(BeuiCandlestickPlot));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: plot.center);
    await mouse.down(plot.center);
    await mouse.up();
    await tester.pump();
    final detector = tester.widget<FocusableActionDetector>(
      find.descendant(
        of: find.byType(BeuiCandlestickPlot),
        matching: find.byType(FocusableActionDetector),
      ),
    );
    expect(detector.focusNode!.hasFocus, isTrue);
    final ring = find.byKey(const ValueKey('candle-focus-ring'));
    expect(
      (tester.widget<DecoratedBox>(ring).decoration as BoxDecoration).border,
      isNull,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    await tester.pump();
    expect(FocusManager.instance.highlightMode, FocusHighlightMode.traditional);
    expect(detector.focusNode!.hasFocus, isTrue);
    expect(
      (tester.widget<DecoratedBox>(ring).decoration as BoxDecoration).border,
      isNotNull,
    );
    expect(find.text('12:00'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('12:05'), findsOneWidget);
    await mouse.removePointer();
  });

  testWidgets(
    'candle opacity delays every retarget and cancels stale delayed targets',
    (tester) async {
      final many = [
        for (var i = 0; i < 48; i++)
          BeuiCandle(
            id: '$i',
            time: '$i',
            open: 10,
            high: 13,
            low: 9,
            close: 12,
            volume: 40,
          ),
      ];
      String? active;
      late StateSetter update;
      await tester.pumpWidget(
        beuiTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return BeuiCandlestickChart(candles: many, activeId: active);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      double opacity() => tester
          .widget<Opacity>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('47')),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      expect(opacity(), 1);
      update(() => active = '0');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(opacity(), 1);
      await tester.pump(const Duration(milliseconds: 64));
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity(), lessThan(1));
      expect(opacity(), greaterThan(.45));
      final interrupted = opacity();
      update(() => active = '47');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      update(() => active = '0');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 470));
      expect(opacity(), closeTo(interrupted, .001));
      await tester.pumpAndSettle();
      expect(opacity(), closeTo(.45, .001));
    },
  );

  testWidgets('volume summary is fixed total, control, and value area grid', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiVolumeProfile(data: bins, unit: 'BTC'), width: 576),
    );
    expect(find.text('Total volume'), findsOneWidget);
    expect(find.text('35 BTC'), findsOneWidget);
    expect(find.text('Point of control'), findsOneWidget);
    expect(find.text('Value area · 70% target'), findsOneWidget);
    expect(find.text('10 – 11'), findsOneWidget);
    expect(find.text('57.1% of volume'), findsOneWidget);
    final total = tester.getTopLeft(find.text('Total volume'));
    final poc = tester.getTopLeft(find.text('Point of control'));
    final area = tester.getTopLeft(find.text('Value area · 70% target'));
    expect(poc.dy, total.dy);
    expect(area.dy, total.dy);
    expect(poc.dx - total.dx, closeTo(209.333, 1));
  });

  testWidgets('volume narrow summary spans value area across two columns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      beuiTestApp(const BeuiVolumeProfile(data: bins, unit: 'BTC'), width: 343),
    );
    await tester.pumpAndSettle();
    final total = tester.getTopLeft(find.text('Total volume'));
    final control = tester.getTopLeft(find.text('Point of control'));
    final area = tester.getTopLeft(find.text('Value area · 70% target'));
    expect(control.dy, total.dy);
    expect(area.dx, total.dx + 12);
    expect(area.dy, greaterThan(total.dy + 40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('candle reduced opacity retargets without the index delay', (
    tester,
  ) async {
    String? active;
    late StateSetter update;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeuiCandlestickChart(candles: candles, activeId: active);
          },
        ),
        reduce: true,
      ),
    );
    double opacity() => tester
        .widget<Opacity>(
          find
              .descendant(
                of: find.byKey(const ValueKey('b')),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;
    expect(opacity(), 1);
    update(() => active = 'a');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(), lessThan(.9));
    final interrupted = opacity();
    update(() => active = 'b');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(), greaterThan(interrupted));
    await tester.pumpAndSettle();
    expect(opacity(), 1);
  });

  testWidgets(
    'volume tooltip floats without changing plot or summary geometry',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiVolumeProfile(data: bins, unit: 'BTC'),
          width: 576,
        ),
      );
      final plotBefore = tester.getRect(find.byType(BeuiVolumeProfilePlot));
      final summaryBefore = tester.getRect(
        find.byType(BeuiVolumeProfileSummary),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(Offset(plotBefore.center.dx, plotBefore.top + 30));
      await tester.pumpAndSettle();
      expect(find.byType(BeuiTooltip), findsOneWidget);
      expect(find.byType(BeuiChartTooltipCard), findsNothing);
      expect(tester.getRect(find.byType(BeuiVolumeProfilePlot)), plotBefore);
      expect(
        tester.getRect(find.byType(BeuiVolumeProfileSummary)),
        summaryBefore,
      );
      expect(find.text('Volume '), findsNothing);
      expect(find.text('Share '), findsNothing);
      await mouse.removePointer();
    },
  );

  testWidgets(
    'volume reduced entrance keeps 180ms opacity and final geometry',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiVolumeProfile(data: bins),
          width: 576,
          reduce: true,
        ),
      );
      final bar = find.byKey(const ValueKey('volume-bar-a'));
      final before = tester.getRect(bar);
      double alpha() => tester
          .widget<Opacity>(
            find.ancestor(of: bar, matching: find.byType(Opacity)).first,
          )
          .opacity;
      expect(alpha(), 0);
      await tester.pump(const Duration(milliseconds: 90));
      expect(alpha(), greaterThan(0));
      expect(alpha(), lessThan(.9));
      expect(tester.getRect(bar), before);
      await tester.pump(const Duration(milliseconds: 100));
      expect(alpha(), closeTo(.9, .001));
    },
  );

  testWidgets('removed volume ownership does not revive after restoration', (
    tester,
  ) async {
    var data = bins;
    late StateSetter update;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeuiVolumeProfile(data: data, defaultActiveId: 'b');
          },
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(tester.widget<BeuiTooltip>(find.byType(BeuiTooltip)).open, isTrue);
    update(() => data = [bins.first, bins.last]);
    await tester.pump();
    update(() => data = bins);
    await tester.pump();
    expect(tester.widget<BeuiTooltip>(find.byType(BeuiTooltip)).open, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(tester.widget<BeuiTooltip>(find.byType(BeuiTooltip)).open, isTrue);
  });
}
