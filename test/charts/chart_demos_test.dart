// The root tests exercise gallery demos without depending on the example app.
// ignore_for_file: avoid_relative_lib_imports

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../example/lib/demos/bump_chart_demo.dart';
import '../../example/lib/demos/candlestick_chart_demo.dart';
import '../../example/lib/demos/donut_chart_demo.dart';
import '../../example/lib/demos/liquidity_heatmap_demo.dart';
import '../../example/lib/demos/order_book_demo.dart';
import '../../example/lib/demos/status_bar_demo.dart';
import '../../example/lib/demos/volume_profile_demo.dart';
import '../support.dart';

Widget _demo(WidgetBuilder builder) => beuiTestApp(
  Builder(builder: (context) => SizedBox(width: 672, child: builder(context))),
  reduce: true,
);

void main() {
  testWidgets('candlestick Step advances trades and opens the eighth candle', (
    tester,
  ) async {
    await tester.pumpWidget(_demo(candlestickChartDemo));
    expect(find.text('Pause'), findsOneWidget);
    final original = tester
        .widget<BeuiCandlestickChart>(find.byType(BeuiCandlestickChart))
        .candles;
    expect(original.first.id, '43200');
    expect(original.last.id, '57300');
    await tester.tap(find.text('Step'));
    await tester.pump();
    expect(find.text('Resume'), findsOneWidget);
    var current = tester
        .widget<BeuiCandlestickChart>(find.byType(BeuiCandlestickChart))
        .candles;
    expect(current.length, 48);
    expect(current.last.id, '57300');
    expect(current.last.volume, greaterThan(original.last.volume));
    for (var i = 1; i < 8; i++) {
      await tester.tap(find.text('Step'));
      await tester.pump();
    }
    current = tester
        .widget<BeuiCandlestickChart>(find.byType(BeuiCandlestickChart))
        .candles;
    expect(current.first.id, '43500');
    expect(current.last.id, '57600');
    expect(current.last.time, '16:00');
    expect(current.last.volume, 0);
    expect(current.last.open, current.last.close);
  });

  testWidgets(
    'donut selection reports the selected plan and clears on repeat',
    (tester) async {
      await tester.pumpWidget(_demo(donutChartDemo));
      await tester.tap(find.text('Business'));
      await tester.pump();
      expect(find.text('Filtering by Business'), findsOneWidget);
      expect(
        tester.widget<BeuiDonutChart>(find.byType(BeuiDonutChart)).selectedId,
        'business',
      );
      await tester.tap(find.text('Business'));
      await tester.pump();
      expect(find.text('Select a plan to filter'), findsOneWidget);
    },
  );

  testWidgets('volume sessions use the exact source observation arrays', (
    tester,
  ) async {
    await tester.pumpWidget(_demo(volumeProfileDemo));
    await tester.tap(find.text('Previous'));
    await tester.pump();
    var profile = tester.widget<BeuiVolumeProfile>(
      find.byType(BeuiVolumeProfile),
    );
    expect(profile.data.map((bin) => bin.volume).toList(), <double>[
      6,
      9,
      13,
      18,
      27,
      40,
      56,
      74,
      95,
      114,
      146,
      188,
      242,
      286,
      253,
      208,
      165,
      126,
      92,
      65,
      42,
      30,
      21,
      14,
    ]);
    await tester.tap(find.text('Week'));
    await tester.pump();
    profile = tester.widget<BeuiVolumeProfile>(find.byType(BeuiVolumeProfile));
    expect(profile.data.first.volume, 75);
    expect(profile.data.last.volume, 84);
    expect(profile.data[11].volume, 1182);
  });

  testWidgets('status incident changes only the final API observations', (
    tester,
  ) async {
    await tester.pumpWidget(_demo(statusBarDemo));
    await tester.tap(find.text('Simulate incident'));
    await tester.pump();
    final charts = tester
        .widgetList<BeuiStatusBar>(find.byType(BeuiStatusBar))
        .toList();
    expect(charts, hasLength(2));
    expect(charts.first.data.skip(45).map((d) => d.status).toList(), [
      'degraded',
      'outage',
      'degraded',
    ]);
    expect(charts.last.data.every((d) => d.status == 'operational'), isTrue);
    final previousKey = charts.first.key;
    await tester.tap(find.text('Replay'));
    await tester.pump();
    expect(
      tester.widgetList<BeuiStatusBar>(find.byType(BeuiStatusBar)).first.key,
      isNot(previousKey),
    );
    await tester.tap(find.text('Resolve incident'));
    await tester.pump();
    expect(
      tester
          .widgetList<BeuiStatusBar>(find.byType(BeuiStatusBar))
          .first
          .data
          .last
          .status,
      'operational',
    );
  });

  testWidgets('bump shuffle keeps each period a complete rank permutation', (
    tester,
  ) async {
    await tester.pumpWidget(_demo(bumpChartDemo));
    await tester.tap(find.text('Shuffle rankings'));
    await tester.pump();
    final chart = tester.widget<BeuiBumpChart>(find.byType(BeuiBumpChart));
    for (var column = 0; column < 6; column++) {
      expect(chart.series.map((row) => row.ranks[column]).toSet(), {
        1,
        2,
        3,
        4,
        5,
      });
    }
  });

  testWidgets(
    'liquidity demo uses source phase zero and resimulates stable ids',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_demo(liquidityHeatmapDemo));
      final original = tester
          .widget<BeuiLiquidityHeatmap>(find.byType(BeuiLiquidityHeatmap))
          .snapshots;
      expect(original.first.price, 245.5);
      await tester.tap(find.text('Resimulate'));
      await tester.pump();
      final next = tester
          .widget<BeuiLiquidityHeatmap>(find.byType(BeuiLiquidityHeatmap))
          .snapshots;
      expect(
        next.map((s) => s.id).toList(),
        original.map((s) => s.id).toList(),
      );
      expect(next.first.price, closeTo(245.96730201077038, .000000001));
      expect(
        next.first.levels.first.size,
        isNot(original.first.levels.first.size),
      );
    },
  );

  testWidgets(
    'order book Step changes depth without changing quote identities',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_demo(orderBookDemo));
      final original = tester.widget<BeuiOrderBook>(find.byType(BeuiOrderBook));
      await tester.tap(find.text('Step'));
      await tester.pump();
      final next = tester.widget<BeuiOrderBook>(find.byType(BeuiOrderBook));
      expect(find.text('Resume'), findsOneWidget);
      expect(
        next.bids.map((l) => l.price).toList(),
        original.bids.map((l) => l.price).toList(),
      );
      expect(next.bids[2].size, isNot(original.bids[2].size));
      expect(next.bids[0].size, original.bids[0].size);
    },
  );
}
