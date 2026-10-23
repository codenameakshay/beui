import 'dart:ui' as ui;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _series = [
  BeuiCompositionSeries(
    id: 'a',
    name: 'A',
    color: '#ff0000',
    values: [25, null, 75],
  ),
  BeuiCompositionSeries(
    id: 'b',
    name: 'B',
    color: '#0000ff',
    values: [75, null, 25],
  ),
];
const _stages = [
  BeuiFunnelStage(id: 'a', label: 'A', value: 100, color: '#ff0000'),
  BeuiFunnelStage(id: 'b', label: 'B', value: 20, color: '#0000ff'),
  BeuiFunnelStage(id: 'c', label: 'C', value: 80, color: '#00ff00'),
];

Finder _paint(String name) => find.byWidgetPredicate(
  (widget) =>
      widget is CustomPaint && widget.painter.runtimeType.toString() == name,
);

Future<Color> _pixel(WidgetTester tester, Offset global) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('pixels')),
  );
  final point = boundary.globalToLocal(global);
  final image = (await tester.runAsync(() => boundary.toImage()))!;
  final data = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  ))!;
  final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
  final raw = Color.fromARGB(
    data.getUint8(offset + 3),
    data.getUint8(offset),
    data.getUint8(offset + 1),
    data.getUint8(offset + 2),
  );
  image.dispose();
  return Color.alphaBlend(raw, Colors.white);
}

void main() {
  for (final reduce in [false, true]) {
    testWidgets(
      'funnel hover tint follows the source 150ms curve, reduce=$reduce',
      (tester) async {
        await tester.pumpWidget(
          beuiTestApp(
            const RepaintBoundary(
              key: ValueKey('pixels'),
              child: BeuiFunnelChart(stages: _stages),
            ),
            width: 600,
            reduce: reduce,
          ),
        );
        await tester.pumpAndSettle();
        final plot = tester.getRect(_paint('_FunnelPainter').first);
        final point = plot.topLeft + const Offset(5, 20);
        expect(await _pixel(tester, point), Colors.white);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(point);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 75));
        expect((await _pixel(tester, point)).toARGB32(), 0xfff5f5f5);
        await tester.pump(const Duration(milliseconds: 75));
        expect((await _pixel(tester, point)).toARGB32(), 0xfff3f3f3);
        await mouse.moveTo(Offset.zero);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        expect(await _pixel(tester, point), Colors.white);
        await mouse.removePointer();
      },
    );
  }

  test('funnel formats finite extremes and decimal ties without overflow', () {
    const chart = BeuiFunnelChart(stages: []);
    expect(chart.format(0), '0');
    expect(chart.format(1.005), '1.01');
    expect(chart.format(9.995), '10');
    expect(chart.format(1e-308), '0');
    expect(chart.format(1e308).replaceAll(',', ''), '1${'0' * 308}');
  });

  testWidgets('composition draws the keyboard outline outside the plot', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const RepaintBoundary(
          key: ValueKey('pixels'),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: BeuiCompositionChart(
              series: _series,
              periods: ['Jan', 'Feb', 'Mar'],
            ),
          ),
        ),
        width: 600,
        reduce: true,
      ),
    );
    await tester.pumpAndSettle();
    final plot = tester.getRect(_paint('_CompositionPainter').first);
    final point = Offset(plot.left - 5, plot.center.dy);
    expect(await _pixel(tester, point), Colors.white);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect((await _pixel(tester, point)).toARGB32(), 0xffe1e1e1);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect((await _pixel(tester, point)).toARGB32(), 0xffe1e1e1);
    await tester.tapAt(plot.center);
    await tester.pumpAndSettle();
    expect(await _pixel(tester, point), Colors.white);
  });

  testWidgets(
    'composition touch-down, drag, and keyboard continue from the same selected period',
    (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(
        beuiTestApp(
          BeuiCompositionChart(
            series: _series,
            periods: const ['Jan', 'Feb', 'Mar'],
            onPeriodChange: changes.add,
          ),
        ),
      );
      final rect = tester.getRect(_paint('_CompositionPainter').first);
      final touch = await tester.startGesture(
        Offset(rect.left + rect.width * .1, rect.center.dy),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();
      expect(
        tester.widget<Slider>(find.byType(Slider, skipOffstage: false)).value,
        0,
      );
      await touch.moveTo(Offset(rect.left + rect.width * .9, rect.center.dy));
      await tester.pump();
      expect(
        tester.widget<Slider>(find.byType(Slider, skipOffstage: false)).value,
        2,
      );
      await touch.up();
      await tester.pumpAndSettle();
      expect(
        tester.widget<BeuiTooltip>(find.byType(BeuiTooltip)).open,
        isFalse,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(changes, ['Jan', 'Mar', 'Feb']);
      expect(find.text('Feb · No data'), findsOneWidget);
      expect(find.text('No complete data for this period.'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Slider>(find.byType(Slider, skipOffstage: false)).value,
        1,
      );
    },
  );

  testWidgets('composition empty plot retains the source minimum height', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiCompositionChart(series: [], periods: []),
        width: 600,
      ),
    );
    expect(tester.getSize(find.byType(BeuiCompositionPlot)).height, 256);
    expect(find.text('No composition data'), findsOneWidget);
  });

  testWidgets(
    'funnel zero and increasing data retain inspectable stages and undefined conversions',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiFunnelChart(
            stages: [
              BeuiFunnelStage(id: 'zero', label: 'Zero', value: 0),
              BeuiFunnelStage(id: 'large', label: 'Large', value: 100),
              BeuiFunnelStage(id: 'next', label: 'Next', value: 200),
            ],
          ),
        ),
      );
      expect(find.text('0 → 200 people'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(4));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        tester.widget<BeuiChartTicker>(find.byType(BeuiChartTicker)).format(0),
        '0 people',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BeuiChartTicker>(find.byType(BeuiChartTicker))
            .format(100),
        '100 people',
      );
      expect(find.text('100 gained'), findsOneWidget);
      expect(find.text('— from previous stage'), findsOneWidget);
    },
  );
  testWidgets('composition area uses the source duration-only ease-out fade', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const RepaintBoundary(
          key: ValueKey('pixels'),
          child: BeuiCompositionChart(
            series: _series,
            periods: ['Jan', 'Feb', 'Mar'],
            view: BeuiCompositionView.area,
          ),
        ),
        width: 600,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final plot = tester.getRect(_paint('_CompositionPainter').first);
    final pixel = await _pixel(tester, plot.topLeft + const Offset(15, 280));
    expect(pixel.r, 1);
    expect(pixel.b, closeTo(.384, .015));
  });

  testWidgets(
    'funnel mouse focus continues to the next stage and follows stable IDs',
    (tester) async {
      var stages = _stages;
      late StateSetter update;
      await tester.pumpWidget(
        beuiTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return BeuiFunnelChart(stages: stages);
            },
          ),
          reduce: true,
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(
        tester.getCenter(
          find.byKey(const ValueKey('funnel-stage-a-semantics')),
        ),
      );
      await mouse.down(
        tester.getCenter(
          find.byKey(const ValueKey('funnel-stage-a-semantics')),
        ),
      );
      await mouse.up();
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        tester.widget<BeuiChartTicker>(find.byType(BeuiChartTicker)).format(20),
        '20 people',
      );
      final focused = FocusManager.instance.primaryFocus;
      update(() => stages = [_stages[0], _stages[2], _stages[1]]);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, same(focused));
      expect(
        tester.widget<BeuiChartTicker>(find.byType(BeuiChartTicker)).format(20),
        '20 people',
      );
      await mouse.removePointer();
    },
  );

  testWidgets(
    'composition bar geometry springs from its displayed rect and reduced motion snaps',
    (tester) async {
      Widget chart(int value, {bool reduce = false}) => beuiTestApp(
        BeuiCompositionChart(
          periods: const ['Jan'],
          series: [
            BeuiCompositionSeries(
              id: 'a',
              name: 'A',
              color: '#ff0000',
              values: [value],
            ),
            BeuiCompositionSeries(
              id: 'b',
              name: 'B',
              color: '#0000ff',
              values: [100 - value],
            ),
          ],
        ),
        width: 600,
        reduce: reduce,
      );
      Rect rect() => tester.getRect(
        find
            .descendant(
              of: find.byKey(const ValueKey('Jan/a')),
              matching: find.byType(ColoredBox),
            )
            .last,
      );
      await tester.pumpWidget(chart(25));
      await tester.pumpAndSettle();
      final initial = rect();
      expect(initial.height, 80);
      await tester.pumpWidget(chart(75));
      expect(rect().height, 80);
      await tester.pump(const Duration(milliseconds: 70));
      expect(rect().height, inExclusiveRange(80, 240));
      final interrupted = rect().height;
      await tester.pumpWidget(chart(25));
      expect(rect().height, closeTo(interrupted, .01));
      await tester.pumpAndSettle();
      expect(rect().height, closeTo(80, .01));
      await tester.pumpWidget(chart(75, reduce: true));
      expect(rect().height, 240);
    },
  );

  testWidgets(
    'funnel path retargets at 280ms and suppresses geometric movement under reduced motion',
    (tester) async {
      Widget chart(int value, {bool reduce = false}) => beuiTestApp(
        BeuiFunnelChart(
          stages: [
            const BeuiFunnelStage(id: 'a', label: 'A', value: 100),
            BeuiFunnelStage(id: 'b', label: 'B', value: value),
          ],
        ),
        width: 600,
        reduce: reduce,
      );
      double center() =>
          ((tester.widget<CustomPaint>(_paint('_FunnelPainter').last).painter
                      as dynamic)
                  .points
              as List<double>)[8];
      await tester.pumpWidget(chart(20));
      await tester.pumpAndSettle();
      expect(center(), closeTo(.592, .0001));
      await tester.pumpWidget(chart(80));
      expect(center(), closeTo(.592, .0001));
      await tester.pump(const Duration(milliseconds: 70));
      expect(center(), inExclusiveRange(.592, .868));
      final interrupted = center();
      await tester.pumpWidget(chart(20));
      expect(center(), closeTo(interrupted, .0001));
      await tester.pump(const Duration(milliseconds: 280));
      expect(center(), closeTo(.592, .0001));
      await tester.pumpWidget(chart(80, reduce: true));
      await tester.pump();
      expect(center(), closeTo(.868, .0001));
    },
  );
  testWidgets(
    'composition uses the last period and 256px below the viewport breakpoint',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiCompositionChart(
            series: _series,
            periods: ['Jan', 'Feb', 'Mar'],
          ),
        ),
      );
      expect(
        tester.widget<Slider>(find.byType(Slider, skipOffstage: false)).value,
        2,
      );
      expect(tester.getSize(_paint('_CompositionPainter').first).height, 256);
      tester.view.physicalSize = const Size(640, 900);
      await tester.pumpAndSettle();
      expect(tester.getSize(_paint('_CompositionPainter').first).height, 320);
    },
  );

  testWidgets(
    'isolated composition area samples occupy the full column and leave a real gap',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const RepaintBoundary(
            key: ValueKey('pixels'),
            child: BeuiCompositionChart(
              series: _series,
              periods: ['Jan', 'Feb', 'Mar'],
              view: BeuiCompositionView.area,
            ),
          ),
          width: 600,
          reduce: true,
        ),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(_paint('_CompositionPainter').first);
      expect(
        (await _pixel(tester, rect.topLeft + const Offset(15, 280))).r,
        greaterThan(.85),
      );
      expect(
        (await _pixel(tester, rect.topLeft + const Offset(185, 280))).r,
        greaterThan(.85),
      );
      expect(
        (await _pixel(tester, rect.topLeft + const Offset(300, 280))).r,
        greaterThan(.85),
      );
      expect(
        (await _pixel(tester, rect.topLeft + const Offset(300, 280))).b,
        greaterThan(.85),
      );
    },
  );

  testWidgets(
    'funnel preserves a later valid duplicate after an invalid count',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiFunnelChart(
            stages: [
              BeuiFunnelStage(id: 'a', label: 'Invalid', value: double.nan),
              BeuiFunnelStage(id: 'a', label: 'Valid', value: 100),
              BeuiFunnelStage(id: 'b', label: 'Last', value: 25),
            ],
          ),
        ),
      );
      expect(find.text('Valid'), findsOneWidget);
      expect(find.text('25.0%'), findsWidgets);
      expect(find.text('100 → 25 people'), findsOneWidget);
    },
  );

  testWidgets(
    'funnel curves encode the stage center, not only shared boundaries',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        beuiTestApp(
          const RepaintBoundary(
            key: ValueKey('pixels'),
            child: BeuiFunnelChart(stages: _stages),
          ),
          width: 600,
        ),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(_paint('_FunnelPainter').first);
      expect(rect.height, 320);
      final outsideCenter = await _pixel(
        tester,
        Offset(rect.left + 200, rect.top + rect.height / 2),
      );
      expect(outsideCenter.r, greaterThan(.85));
      expect(outsideCenter.g, greaterThan(.85));
      expect(outsideCenter.b, greaterThan(.85));
      final insideCenter = await _pixel(
        tester,
        Offset(rect.left + 260, rect.top + rect.height / 2),
      );
      expect(insideCenter.b, greaterThan(.9));
      expect(insideCenter.r, lessThan(.1));
    },
  );

  testWidgets(
    'horizontal funnel keeps 110px stages and 300px plot in a narrow viewport',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiFunnelChart(
            stages: _stages,
            direction: BeuiFunnelDirection.horizontal,
          ),
          width: 250,
        ),
      );
      final rect = tester.getRect(_paint('_FunnelPainter').first);
      expect(rect.size, const Size(330, 300));
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    },
  );
}
