import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Root chart tests exercise the gallery without a dependency on its package.
// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/volume_profile_demo.dart';
import '../support.dart';

Widget _volumeDemo() => beuiTestApp(
  Builder(
    builder: (context) =>
        SizedBox(width: 672, child: volumeProfileDemo(context)),
  ),
  reduce: true,
);

const _heatmapSnapshots = [
  BeuiLiquiditySnapshot(
    id: 't1',
    label: '14:00',
    price: 100.5,
    levels: [
      BeuiLiquidityLevel(price: 101, size: 20),
      BeuiLiquidityLevel(price: 100, size: 40),
    ],
  ),
  BeuiLiquiditySnapshot(
    id: 't2',
    label: '14:02',
    price: 100,
    levels: [
      BeuiLiquidityLevel(price: 101, size: 50),
      BeuiLiquidityLevel(price: 99, size: 10),
    ],
  ),
];

Widget _heatmap() => beuiTestApp(
  SizedBox(
    width: 640,
    child: BeuiLiquidityHeatmap(
      snapshots: _heatmapSnapshots,
      maxSize: 60,
      unit: 'SOL',
      formatPrice: (price) => price.toStringAsFixed(2),
    ),
  ),
  reduce: true,
);

double _orderBookFlashAlpha(WidgetTester tester, String side, double price) {
  final row = find.bySemanticsLabel(
    RegExp('^$side, ${price.toStringAsFixed(2)},'),
  );
  final colors = tester
      .widgetList<ColoredBox>(
        find.descendant(of: row, matching: find.byType(ColoredBox)),
      )
      .map((box) => box.color)
      .where((color) => color.a <= .1)
      .toList();
  expect(colors, hasLength(1));
  return colors.single.a;
}

String? _activeHeatmapTitle(WidgetTester tester) {
  final active = tester
      .widgetList<BeuiChartTooltip>(find.byType(BeuiChartTooltip))
      .where((tooltip) => tooltip.open == true);
  if (active.isEmpty) return null;
  return (active.single.content as BeuiChartTooltipCard).title;
}

Path _heatmapTracePath(WidgetTester tester) {
  final trace = find.descendant(
    of: find.byType(BeuiLiquidityPlot),
    matching: find.byType(CustomPaint),
  );
  final canvas = TestRecordingCanvas();
  final paint = tester.widget<CustomPaint>(trace);
  paint.painter!.paint(canvas, tester.getSize(trace));
  return canvas.invocations
          .firstWhere((call) => call.invocation.memberName == #drawPath)
          .invocation
          .positionalArguments
          .first
      as Path;
}

void main() {
  // Upstream contract: components/previews/charts/volume-profile.preview.tsx
  // at 57-110 (tab ArrowLeft/Right wrap, Home/End, selected trigger and panel).
  testWidgets('volume preview tabs wrap focus, selection, and profile data', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_volumeDemo());

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(tester.takeException(), isNull);
    final profile = tester.widget<BeuiVolumeProfile>(
      find.byType(BeuiVolumeProfile),
    );
    // Week is the upstream preview's last session (source lines 33-49).
    expect(profile.data.first.id, 'price-64000');
    expect(profile.data.first.volume, 75);
    expect(profile.data[11].volume, 1182);
    expect(
      tester.getSemantics(find.text('Week')),
      isSemantics(isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('Today')),
      isSemantics(isButton: true, isSelected: false),
    );
    expect(
      find.bySemanticsLabel('BTC volume profile: inspect price level'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('BTC volume profile'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    final home = tester.widget<BeuiVolumeProfile>(
      find.byType(BeuiVolumeProfile),
    );
    expect(home.data.first.volume, 18);
    expect(
      tester.getSemantics(find.text('Today')),
      isSemantics(isButton: true, isSelected: true),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    final end = tester.widget<BeuiVolumeProfile>(
      find.byType(BeuiVolumeProfile),
    );
    expect(end.data[11].volume, 1182);
    expect(
      tester.getSemantics(find.text('Week')),
      isSemantics(isButton: true, isSelected: true),
    );

    // The source also wraps forward from the final tab back to Today.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(tester.takeException(), isNull);
    final today = tester.widget<BeuiVolumeProfile>(
      find.byType(BeuiVolumeProfile),
    );
    expect(today.data.first.volume, 18);
    expect(today.data.last.volume, 5);
    expect(
      tester.getSemantics(find.text('Today')),
      isSemantics(isButton: true, isSelected: true),
    );
    semantics.dispose();
  });

  // Upstream contract: components/charts/liquidity-heatmap.tsx at 145-192.
  // Cells are named buttons; arrows traverse the flattened grid and Escape
  // dismisses the selected-cell tooltip.
  testWidgets('heatmap four arrows traverse named cells and Escape cancels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_heatmap());

    final first = find.bySemanticsLabel('14:00, 101.00: 20 SOL');
    expect(first, findsOneWidget);
    expect(
      tester.getSemantics(first),
      isSemantics(isButton: true, label: '14:00, 101.00: 20 SOL'),
    );
    await tester.tap(first);
    await tester.pump();
    expect(_activeHeatmapTitle(tester), '14:00 · 101.00');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_activeHeatmapTitle(tester), '14:02 · 101.00');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_activeHeatmapTitle(tester), '14:02 · 100.00');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(_activeHeatmapTitle(tester), '14:00 · 100.00');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(_activeHeatmapTitle(tester), '14:00 · 101.00');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_activeHeatmapTitle(tester), isNull);
    semantics.dispose();
  });

  testWidgets('heatmap arrow keys clamp at the first and last cells', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_heatmap());

    await tester.tap(find.bySemanticsLabel('14:00, 101.00: 20 SOL'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(_activeHeatmapTitle(tester), '14:00 · 101.00');

    await tester.tap(find.bySemanticsLabel('14:02, 99.00: 10 SOL'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_activeHeatmapTitle(tester), '14:02 · 99.00');
    semantics.dispose();
  });

  testWidgets('heatmap default prices omit insignificant fraction digits', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiLiquidityHeatmap(snapshots: _heatmapSnapshots, unit: 'SOL'),
        reduce: true,
      ),
    );
    final first = find.bySemanticsLabel('14:00, 101: 20 SOL');
    expect(first, findsOneWidget);
    await tester.tap(first);
    await tester.pump();
    expect(_activeHeatmapTitle(tester), '14:00 · 101');
    semantics.dispose();
  });

  testWidgets('reduced motion places the heatmap market trace at its target', (
    tester,
  ) async {
    var snapshots = _heatmapSnapshots;
    late StateSetter update;
    final heatmap = StatefulBuilder(
      builder: (context, setState) {
        update = setState;
        return SizedBox(
          width: 640,
          child: BeuiLiquidityHeatmap(
            snapshots: snapshots,
            maxSize: 60,
            unit: 'SOL',
            child: const BeuiLiquidityPlot(),
          ),
        );
      },
    );
    await tester.pumpWidget(beuiTestApp(heatmap, reduce: true));
    final trace = find.descendant(
      of: find.byType(BeuiLiquidityPlot),
      matching: find.byType(CustomPaint),
    );
    final traceSize = tester.getSize(trace);
    update(() {
      snapshots = const [
        BeuiLiquiditySnapshot(
          id: 't1',
          label: '14:00',
          price: 99.5,
          levels: [
            BeuiLiquidityLevel(price: 101, size: 20),
            BeuiLiquidityLevel(price: 100, size: 40),
            BeuiLiquidityLevel(price: 99, size: 0),
          ],
        ),
        BeuiLiquiditySnapshot(
          id: 't2',
          label: '14:02',
          price: 99,
          levels: [
            BeuiLiquidityLevel(price: 101, size: 50),
            BeuiLiquidityLevel(price: 100, size: 0),
            BeuiLiquidityLevel(price: 99, size: 10),
          ],
        ),
      ];
    });
    await tester.pump();
    final tracePath = _heatmapTracePath(tester);
    final end = tracePath
        .computeMetrics()
        .single
        .getTangentForOffset(tracePath.computeMetrics().single.length)!
        .position;
    expect(end.dx, closeTo(traceSize.width * .75, .001));
    expect(end.dy, closeTo(traceSize.height * 5 / 6, .001));
  });

  // Upstream contract: components/charts/order-book/depth-row.tsx at 42-64.
  // A changed row rises to 0.1 opacity in 80ms, fades over 200ms, and a new
  // snapshot retargets from the current flash instead of restarting at zero.
  testWidgets(
    'order-book bid and ask flashes retarget across rapid snapshots',
    (tester) async {
      const initialBids = [
        BeuiOrderBookLevel(price: 99, size: 2),
        BeuiOrderBookLevel(price: 98, size: 3),
      ];
      const initialAsks = [
        BeuiOrderBookLevel(price: 101, size: 4),
        BeuiOrderBookLevel(price: 102, size: 6),
      ];
      var bids = initialBids;
      var asks = initialAsks;
      late StateSetter update;

      await tester.pumpWidget(
        beuiTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return BeuiOrderBook(
                bids: bids,
                asks: asks,
                baseSymbol: 'SOL',
                quoteSymbol: 'USD',
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BeuiOrderBookSide(side: BeuiOrderBookSideKind.ask),
                    BeuiOrderBookSide(side: BeuiOrderBookSideKind.bid),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      update(() {
        bids = const [
          BeuiOrderBookLevel(price: 99, size: 2),
          BeuiOrderBookLevel(price: 98, size: 5),
        ];
        asks = const [
          BeuiOrderBookLevel(price: 101, size: 7),
          BeuiOrderBookLevel(price: 102, size: 6),
        ];
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final bidAt40ms = _orderBookFlashAlpha(tester, 'bid', 98);
      final askAt40ms = _orderBookFlashAlpha(tester, 'ask', 101);
      expect(bidAt40ms, inExclusiveRange(0, .1));
      expect(askAt40ms, inExclusiveRange(0, .1));

      update(() {
        bids = const [
          BeuiOrderBookLevel(price: 99, size: 2),
          BeuiOrderBookLevel(price: 98, size: 6),
        ];
        asks = const [
          BeuiOrderBookLevel(price: 101, size: 8),
          BeuiOrderBookLevel(price: 102, size: 6),
        ];
      });
      await tester.pump();
      expect(_orderBookFlashAlpha(tester, 'bid', 98), closeTo(bidAt40ms, .001));
      expect(
        _orderBookFlashAlpha(tester, 'ask', 101),
        closeTo(askAt40ms, .001),
      );

      await tester.pump(const Duration(milliseconds: 40));
      expect(
        _orderBookFlashAlpha(tester, 'bid', 98),
        inExclusiveRange(bidAt40ms, .1),
      );
      expect(
        _orderBookFlashAlpha(tester, 'ask', 101),
        inExclusiveRange(askAt40ms, .1),
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(_orderBookFlashAlpha(tester, 'bid', 98), closeTo(.1, .001));
      expect(_orderBookFlashAlpha(tester, 'ask', 101), closeTo(.1, .001));
      await tester.pump(const Duration(milliseconds: 100));
      final bidDuringFade = _orderBookFlashAlpha(tester, 'bid', 98);
      final askDuringFade = _orderBookFlashAlpha(tester, 'ask', 101);
      expect(bidDuringFade, inExclusiveRange(0, .1));
      expect(askDuringFade, inExclusiveRange(0, .1));
      await tester.pump(const Duration(milliseconds: 280));
      expect(_orderBookFlashAlpha(tester, 'bid', 98), 0);
      expect(_orderBookFlashAlpha(tester, 'ask', 101), 0);
    },
  );

  testWidgets('reduced motion suppresses order-book snapshot flashes', (
    tester,
  ) async {
    var bids = const [
      BeuiOrderBookLevel(price: 99, size: 2),
      BeuiOrderBookLevel(price: 98, size: 3),
    ];
    var asks = const [
      BeuiOrderBookLevel(price: 101, size: 4),
      BeuiOrderBookLevel(price: 102, size: 6),
    ];
    late StateSetter update;

    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeuiOrderBook(
              bids: bids,
              asks: asks,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BeuiOrderBookSide(side: BeuiOrderBookSideKind.ask),
                  BeuiOrderBookSide(side: BeuiOrderBookSideKind.bid),
                ],
              ),
            );
          },
        ),
        reduce: true,
      ),
    );

    update(() {
      bids = const [
        BeuiOrderBookLevel(price: 99, size: 2),
        BeuiOrderBookLevel(price: 98, size: 5),
      ];
      asks = const [
        BeuiOrderBookLevel(price: 101, size: 7),
        BeuiOrderBookLevel(price: 102, size: 6),
      ];
    });
    await tester.pump();
    expect(_orderBookFlashAlpha(tester, 'bid', 98), 0);
    expect(_orderBookFlashAlpha(tester, 'ask', 101), 0);
  });

  testWidgets('price target defaults name the source chart without history', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiPriceTargetFan(
          current: 178.52,
          targets: [
            BeuiPriceTarget(key: 'High', price: 232, analysts: 9),
            BeuiPriceTarget(key: 'Mean', price: 205, analysts: 34),
            BeuiPriceTarget(key: 'Low', price: 168, analysts: 6),
          ],
        ),
        reduce: true,
      ),
    );
    expect(
      find.bySemanticsLabel(
        'Price target · 12 months: mean \$205.00, now \$178.52',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('price-target-history-slider')),
      findsNothing,
    );
    expect(find.text('Mean target'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'price history End selects the latest target-free history point',
    (tester) async {
      final changes = <BeuiPriceTargetFanActive?>[];
      await tester.pumpWidget(
        beuiTestApp(
          BeuiPriceTargetFan(
            current: 178.52,
            targets: [
              BeuiPriceTarget(key: 'High', price: 232, analysts: 9),
              BeuiPriceTarget(key: 'Mean', price: 205, analysts: 34),
              BeuiPriceTarget(key: 'Low', price: 168, analysts: 6),
            ],
            history: [
              BeuiPriceHistoryPoint(date: '2025-09-14', price: 158.4),
              BeuiPriceHistoryPoint(date: '2025-10-14', price: 164.2),
              BeuiPriceHistoryPoint(date: '2025-11-14', price: 160.8),
            ],
            onActiveChange: changes.add,
          ),
          reduce: true,
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('price-target-history-2025-09-14')),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(
        changes.last,
        const BeuiPriceTargetFanActive.history('2025-09-14'),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(
        changes.last,
        const BeuiPriceTargetFanActive.history('2025-11-14'),
      );
      expect(find.text('Fri, Nov 14'), findsWidgets);
    },
  );
}
