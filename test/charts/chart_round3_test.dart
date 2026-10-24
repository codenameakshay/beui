import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _levels = [
  BeuiLiquidityLevel(price: 110, size: 10),
  BeuiLiquidityLevel(price: 100, size: 20),
  BeuiLiquidityLevel(price: 90, size: 30),
];

Widget _liquidity(double price, {bool reduce = false}) => beuiTestApp(
  BeuiLiquidityHeatmap(
    snapshots: [
      BeuiLiquiditySnapshot(id: 'a', label: 'A', price: price, levels: _levels),
      const BeuiLiquiditySnapshot(
        id: 'b',
        label: 'B',
        price: 100,
        levels: _levels,
      ),
    ],
    child: const BeuiLiquidityPlot(),
  ),
  reduce: reduce,
);

double _traceY(WidgetTester tester) {
  final canvas = TestRecordingCanvas();
  final plot = find.descendant(
    of: find.byType(BeuiLiquidityPlot),
    matching: find.byType(CustomPaint),
  );
  tester.widget<CustomPaint>(plot).painter!.paint(canvas, tester.getSize(plot));
  final path =
      canvas.invocations
              .firstWhere((call) => call.invocation.memberName == #drawPath)
              .invocation
              .positionalArguments
              .first
          as Path;
  return path.computeMetrics().first.getTangentForOffset(0)!.position.dy;
}

void main() {
  testWidgets('returns keeps the source 480px width inside a wider host', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const Center(
          child: BeuiReturnsCalendar(
            years: [2021],
            returns: [
              [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(BeuiReturnsCalendarGrid)).width, 480);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'fan whole plot hover selects nearest curve and clears the now gap',
    (tester) async {
      BeuiPriceTargetFanActive? active;
      await tester.pumpWidget(
        beuiTestApp(
          BeuiPriceTargetFan(
            current: 100,
            targets: const [
              BeuiPriceTarget(key: 'High', price: 140),
              BeuiPriceTarget(key: 'Mean', price: 120),
              BeuiPriceTarget(key: 'Low', price: 80),
            ],
            history: const [
              BeuiPriceHistoryPoint(date: '2026-10-01', price: 90),
              BeuiPriceHistoryPoint(date: '2026-10-03', price: 95),
            ],
            onActiveChange: (value) => active = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final plot = tester.getTopLeft(find.byType(BeuiPriceTargetSvg));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(plot + const Offset(380, 10));
      await tester.pump();
      expect(active?.key, 'High');
      await mouse.moveTo(plot + const Offset(380, 210));
      await tester.pump();
      expect(active?.key, 'Low');
      await mouse.moveTo(plot + const Offset(246.56, 10));
      await tester.pump();
      expect(active, isNull);
      await mouse.moveTo(plot + const Offset(100, 210));
      await tester.pump();
      expect(active?.date, '2026-10-01');
      await mouse.moveTo(plot + const Offset(550, 10));
      await tester.pumpAndSettle();
      expect(active, isNull);
      await mouse.removePointer();
    },
  );

  testWidgets('heat sorts reversed range labels and omits a one-day span', (
    tester,
  ) async {
    Widget chart(int start, int end) => beuiTestApp(
      BeuiHeatCalendar(
        weeks: 1,
        endDate: DateTime.utc(2026, 10, 4),
        values: const [
          [1, 0, 1, 0, 0, 0, 0],
        ],
        selection: BeuiHeatCalendarSelection(
          start: BeuiHeatCalendarCell(week: 0, day: start),
          end: BeuiHeatCalendarCell(week: 0, day: end),
        ),
      ),
    );
    await tester.pumpWidget(chart(2, 0));
    await tester.pumpAndSettle();
    expect(find.text('Sep 28 – Sep 30'), findsOneWidget);
    expect(find.text('3 days'), findsOneWidget);
    await tester.pumpWidget(chart(0, 0));
    await tester.pumpAndSettle();
    expect(find.text('Mon, Sep 28'), findsOneWidget);
    expect(find.text('1 days'), findsNothing);
  });

  testWidgets('order depth springs and quantity tint retarget in flight', (
    tester,
  ) async {
    Widget book(double size, {bool reduce = false}) => beuiTestApp(
      SizedBox(
        width: 400,
        child: BeuiOrderBook(
          bids: [
            BeuiOrderBookLevel(price: 99, size: size),
            const BeuiOrderBookLevel(price: 98, size: 8),
          ],
          asks: const [BeuiOrderBookLevel(price: 101, size: 10)],
        ),
      ),
      reduce: reduce,
    );
    final bar = find.byKey(const ValueKey('beui-order-bar-bid-99.0'));
    await tester.pumpWidget(book(2));
    await tester.pumpAndSettle();
    final width = tester.getSize(bar).width;
    await tester.pumpWidget(book(8));
    expect(tester.getSize(bar).width, closeTo(width, .001));
    await tester.pump(const Duration(milliseconds: 40));
    final moving = tester.getSize(bar).width;
    expect(moving, greaterThan(width));
    final flashes = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .where((box) => box.color.a > .001 && box.color.a < .1);
    expect(flashes, isNotEmpty);
    await tester.pumpWidget(book(2));
    expect(tester.getSize(bar).width, closeTo(moving, .001));
    await tester.pumpAndSettle();
    expect(tester.getSize(bar).width, closeTo(78, .1));
    await tester.pumpWidget(book(8, reduce: true));
    expect(tester.getSize(bar).width, greaterThan(width));
    final reducedWidth = tester.getSize(bar).width;
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.getSize(bar).width, reducedWidth);
  });

  testWidgets(
    'fan history reveals before the delayed fan and reduced motion snaps',
    (tester) async {
      const fan = BeuiPriceTargetFan(
        current: 100,
        targets: [
          BeuiPriceTarget(key: 'High', price: 140),
          BeuiPriceTarget(key: 'Mean', price: 120),
          BeuiPriceTarget(key: 'Low', price: 80),
        ],
        history: [
          BeuiPriceHistoryPoint(date: '2026-10-01', price: 90),
          BeuiPriceHistoryPoint(date: '2026-10-03', price: 95),
        ],
      );
      double fanWidth() => tester
          .widget<ClipRect>(
            find
                .descendant(
                  of: find.byType(BeuiPriceTargetTargets),
                  matching: find.byType(ClipRect),
                )
                .first,
          )
          .clipper!
          .getClip(const Size(520, 236))
          .width;
      double historyLength() {
        final painter = tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(BeuiPriceTargetHistory),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!;
        final canvas = TestRecordingCanvas();
        painter.paint(canvas, const Size(520, 236));
        final path =
            canvas.invocations
                    .firstWhere(
                      (call) => call.invocation.memberName == #drawPath,
                    )
                    .invocation
                    .positionalArguments
                    .first
                as Path;
        return path.computeMetrics().fold(
          0.0,
          (total, metric) => total + metric.length,
        );
      }

      await tester.pumpWidget(beuiTestApp(fan));
      expect(historyLength(), 0);
      expect(fanWidth(), 0);
      await tester.pump(const Duration(milliseconds: 400));
      final historyMoving = historyLength();
      expect(historyMoving, greaterThan(0));
      expect(fanWidth(), 0);
      await tester.pump(const Duration(milliseconds: 451));
      await tester.pump(const Duration(milliseconds: 100));
      expect(fanWidth(), inExclusiveRange(0, 273.44));
      await tester.pumpAndSettle();
      expect(historyLength(), greaterThan(historyMoving));
      expect(fanWidth(), closeTo(273.44, .001));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(beuiTestApp(fan, reduce: true));
      expect(fanWidth(), closeTo(273.44, .001));
      expect(historyLength(), greaterThan(historyMoving));
    },
  );

  testWidgets('liquidity owns two-dimensional focus and reopens after exit', (
    tester,
  ) async {
    await tester.pumpWidget(_liquidity(110));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(
      tester.getCenter(find.bySemanticsLabel('A, 110.00: 10 units')),
    );
    await tester.pump();
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('A · 100.00'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(find.text('B · 100.00'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(find.text('A · 100.00'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('A · 100.00'), findsNothing);
    await mouse.removePointer();
  });

  testWidgets('liquidity trace interpolates for 280ms and reverses in flight', (
    tester,
  ) async {
    await tester.pumpWidget(_liquidity(110));
    expect(_traceY(tester), closeTo(13, .001));
    await tester.pumpWidget(_liquidity(90));
    await tester.pump(const Duration(milliseconds: 100));
    final moving = _traceY(tester);
    expect(moving, inExclusiveRange(13, 65));
    await tester.pumpWidget(_liquidity(110));
    expect(_traceY(tester), closeTo(moving, .001));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_traceY(tester), inExclusiveRange(13, moving));
    await tester.pump(const Duration(milliseconds: 180));
    expect(_traceY(tester), closeTo(13, .001));
    await tester.pumpWidget(_liquidity(90, reduce: true));
    expect(_traceY(tester), closeTo(65, .001));
  });

  testWidgets(
    'returns native focus ignores arrows and previews compounded spans',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiReturnsCalendar(
            years: [2024],
            returns: [
              [10, 10, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('Jan 2024'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Jan 2024'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('beui-returns-cell-0-0')));
      await tester.pump();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('beui-returns-cell-0-2'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Jan 2024 – Mar 2024'), findsOneWidget);
      expect(find.text('3 months'), findsOneWidget);
      final ticker = tester.widget<BeuiChartTicker>(
        find.byType(BeuiChartTicker),
      );
      expect(ticker.format(ticker.value), '+33.1%');
      await mouse.removePointer();
    },
  );

  testWidgets(
    'heat uses UTC dates without a year and chronological native Tab',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          BeuiHeatCalendar(
            weeks: 1,
            endDate: DateTime.parse('2026-10-01T01:00:00+05:30'),
            values: const [
              [0, .5, 1, 0, 0, 0, 0],
            ],
            maxCount: 10,
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('Mon, Sep 28'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Mon, Sep 28'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('Tue, Sep 29'), findsOneWidget);
      expect(find.textContaining('2026'), findsNothing);
      expect(
        tester.widget<BeuiChartTicker>(find.byType(BeuiChartTicker)).value,
        5,
      );
    },
  );

  testWidgets(
    'status distributes entrance delays and reduces to simultaneous fade',
    (tester) async {
      const data = [
        BeuiStatusBarDatum(id: 's1', label: 'A', status: 'operational'),
        BeuiStatusBarDatum(id: 's2', label: 'B', status: 'degraded'),
      ];
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
      await tester.pumpWidget(beuiTestApp(const BeuiStatusBar(data: data)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(opacity('s1'), greaterThan(0));
      expect(opacity('s2'), 0);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        beuiTestApp(const BeuiStatusBar(data: data), reduce: true),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(opacity('s1'), inExclusiveRange(0, 1));
      expect(opacity('s2'), closeTo(opacity('s1'), .001));
      await tester.pump(const Duration(milliseconds: 75));
      expect(opacity('s2'), 1);
      expect(find.byType(BeuiNumberTicker), findsNothing);
    },
  );

  testWidgets('fan has one history slider and static tooltip metrics', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiPriceTargetFan(
          current: 100,
          targets: [
            BeuiPriceTarget(key: 'High', price: 140),
            BeuiPriceTarget(key: 'Mean', price: 120),
            BeuiPriceTarget(key: 'Low', price: 80),
          ],
          history: [
            BeuiPriceHistoryPoint(date: '2026-10-01', price: 90),
            BeuiPriceHistoryPoint(date: '2026-10-03', price: 95),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.slider == true),
      hasLength(1),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.text('Sat, Oct 3'), findsOneWidget);
    expect(find.text(r'$95.00'), findsOneWidget);
    expect(find.byType(BeuiChartTicker), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(find.text('Thu, Oct 1'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text(r'$95.00'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text(r'$95.00'), findsNothing);
  });
}
