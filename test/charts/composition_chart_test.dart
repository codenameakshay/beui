import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _periods = ['Jan', 'Feb', 'Mar'];
const _series = [
  BeuiCompositionSeries(
    id: 'a',
    name: 'Organic',
    color: '#2563eb',
    values: [60, 40, null],
  ),
  BeuiCompositionSeries(
    id: 'b',
    name: 'Direct',
    color: '#0d9488',
    values: [40, 60, 10],
  ),
];

void main() {
  testWidgets(
    'pointer exit then consumed keyboard input reopens chart tooltip',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiCompositionChart(series: _series, periods: _periods),
        ),
      );
      final plot = find.byType(BeuiCompositionPlot);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(plot));
      await tester.tapAt(tester.getCenter(plot));
      await tester.pumpAndSettle();
      expect(tester.widget<BeuiTooltip>(find.byType(BeuiTooltip)).open, isTrue);
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(
        tester.widget<BeuiTooltip>(find.byType(BeuiTooltip)).open,
        isFalse,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(tester.widget<BeuiTooltip>(find.byType(BeuiTooltip)).open, isTrue);
      final values = tester
          .widgetList<BeuiChartTicker>(find.byType(BeuiChartTicker))
          .map((ticker) => ticker.format(ticker.value));
      expect(values, containsAll(['60', '60.0%', '40', '40.0%']));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        tester.widget<BeuiTooltip>(find.byType(BeuiTooltip)).open,
        isFalse,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(tester.widget<BeuiTooltip>(find.byType(BeuiTooltip)).open, isTrue);
      expect(find.text('Mar · No data'), findsOneWidget);
      await mouse.removePointer();
    },
  );
  testWidgets('renders stacked chart and series legend', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiCompositionChart(series: _series, periods: _periods),
      ),
    );
    expect(find.text('Jan'), findsWidgets);
    expect(find.text('Organic'), findsOneWidget);
    expect(find.text('Direct'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('period range responds to keyboard and reports selected period', (
    tester,
  ) async {
    String? changed;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiCompositionChart(
          series: _series,
          periods: _periods,
          defaultPeriod: 'Jan',
          onPeriodChange: (period) => changed = period,
        ),
      ),
    );
    final plot = tester.getRect(find.byType(BeuiCompositionPlot));
    await tester.tapAt(Offset(plot.left + plot.width / 6, plot.center.dy));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changed, 'Feb');
    expect(
      tester.widget<Slider>(find.byType(Slider, skipOffstage: false)).value,
      1,
    );
  });

  testWidgets('keyboard navigation advances from the tapped first period', (
    tester,
  ) async {
    final changed = <String>[];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiCompositionChart(
          series: _series,
          periods: _periods,
          defaultPeriod: 'Jan',
          onPeriodChange: changed.add,
        ),
      ),
    );

    final plot = tester.getRect(find.byType(BeuiCompositionPlot));
    await tester.tapAt(Offset(plot.left + plot.width / 6, plot.center.dy));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changed, ['Feb']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changed, ['Feb', 'Mar']);
  });

  testWidgets('tapping the plot takes keyboard focus from another control', (
    tester,
  ) async {
    final changed = <String>[];
    final otherFocus = FocusNode();
    addTearDown(otherFocus.dispose);
    await tester.pumpWidget(
      beuiTestApp(
        Column(
          children: [
            TextField(focusNode: otherFocus),
            BeuiCompositionChart(
              series: _series,
              periods: _periods,
              defaultPeriod: 'Jan',
              onPeriodChange: changed.add,
            ),
          ],
        ),
      ),
    );
    otherFocus.requestFocus();
    await tester.pump();
    expect(otherFocus.hasFocus, isTrue);

    final plot = tester.getRect(find.byType(BeuiCompositionPlot));
    await tester.tapAt(Offset(plot.left + plot.width / 6, plot.center.dy));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changed, ['Feb']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changed, ['Feb', 'Mar']);
  });

  testWidgets('Tab enters the composition plot keyboard controls', (
    tester,
  ) async {
    final changed = <String>[];
    final otherFocus = FocusNode();
    addTearDown(otherFocus.dispose);
    await tester.pumpWidget(
      beuiTestApp(
        Column(
          children: [
            TextField(focusNode: otherFocus),
            BeuiCompositionChart(
              series: _series,
              periods: _periods,
              defaultPeriod: 'Jan',
              onPeriodChange: changed.add,
            ),
          ],
        ),
      ),
    );
    otherFocus.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(changed, ['Feb']);
  });

  testWidgets('keyboard inspection opens tooltip and exposes period values', (
    tester,
  ) async {
    final otherFocus = FocusNode();
    final changed = <String>[];
    addTearDown(otherFocus.dispose);
    await tester.pumpWidget(
      beuiTestApp(
        Column(
          children: [
            TextField(focusNode: otherFocus),
            BeuiCompositionChart(
              series: _series,
              periods: _periods,
              defaultPeriod: 'Jan',
              onPeriodChange: changed.add,
            ),
          ],
        ),
      ),
    );
    otherFocus.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('Feb'), findsWidgets);
    expect(find.text('Organic'), findsWidgets);
    final organicRow = find
        .ancestor(of: find.text('Organic '), matching: find.byType(Row))
        .first;
    final visibleValues = tester
        .widgetList<BeuiChartTicker>(
          find.descendant(
            of: organicRow,
            matching: find.byType(BeuiChartTicker),
          ),
        )
        .map((ticker) => ticker.format(ticker.value))
        .toList();
    expect(visibleValues, ['40', '40.0%']);
    final semantics = tester.getSemantics(
      find.descendant(
        of: find.byType(BeuiCompositionPlot),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label?.contains('Organic: 40 (40.0%)') == true,
        ),
      ),
    );
    expect(semantics.label, contains('Feb'));
    expect(
      semantics.getSemanticsData().hasAction(SemanticsAction.increase),
      isTrue,
    );
    expect(
      semantics.getSemanticsData().hasAction(SemanticsAction.decrease),
      isTrue,
    );
    semantics.owner!.performAction(semantics.id, SemanticsAction.increase);
    await tester.pump();
    expect(changed, ['Feb', 'Mar']);
  });

  testWidgets('controlled period remains fixed and legend exposes pin state', (
    tester,
  ) async {
    String? changed;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiCompositionChart(
          series: _series,
          periods: _periods,
          period: 'Jan',
          onPeriodChange: (period) => changed = period,
        ),
      ),
    );
    final plot = tester.getRect(find.byType(BeuiCompositionPlot));
    await tester.tapAt(Offset(plot.left + plot.width / 6, plot.center.dy));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changed, 'Feb');
    expect(find.text('Organic'), findsOneWidget);
    expect(
      tester.widget<Slider>(find.byType(Slider, skipOffstage: false)).value,
      0,
    );
    await tester.tap(find.text('Organic'));
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.toggled == true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('hovering a period shows per-series value and share tickers', (
    tester,
  ) async {
    const series = [
      BeuiCompositionSeries(
        id: 'a',
        name: 'Organic',
        color: '#2563eb',
        values: [12.4, 25.5, null],
      ),
      BeuiCompositionSeries(
        id: 'b',
        name: 'Direct',
        color: '#0d9488',
        values: [87.6, 74.5, 10],
      ),
    ];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiCompositionChart(
          series: series,
          periods: _periods,
          formatValue: (value) => value.toStringAsFixed(1),
        ),
      ),
    );
    final canvas = tester.getRect(
      find.descendant(
        of: find.byType(BeuiCompositionPlot),
        matching: find.byType(CustomPaint),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final position = Offset(canvas.left + canvas.width / 6, canvas.center.dy);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(position);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('Jan'), findsWidgets);
    expect(find.byType(BeuiChartTicker), findsNWidgets(4));
    expect(find.text('Organic'), findsWidgets);
    expect(
      tester
          .widgetList<BeuiChartTicker>(find.byType(BeuiChartTicker))
          .map((ticker) => ticker.format(ticker.value))
          .toList(),
      ['12.4', '12.4%', '87.6', '87.6%'],
    );

    await mouse.moveTo(
      Offset(canvas.left + canvas.width / 2, canvas.center.dy),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Feb'), findsWidgets);
    expect(
      tester
          .widgetList<BeuiChartTicker>(find.byType(BeuiChartTicker))
          .map((ticker) => ticker.format(ticker.value))
          .toList(),
      ['25.5', '25.5%', '74.5', '74.5%'],
    );
  });

  testWidgets('keyboard inspection wins over a stationary pointer hover', (
    tester,
  ) async {
    final changed = <String>[];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiCompositionChart(
          series: _series,
          periods: _periods,
          onPeriodChange: changed.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BeuiChartTooltipCard), findsNothing);

    final plot = tester.getRect(find.byType(BeuiCompositionPlot));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final position = Offset(plot.left + plot.width / 6, plot.center.dy);
    await mouse.addPointer(location: position);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(position);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    await mouse.down(position);
    await mouse.up();
    await tester.pump();
    expect(changed, ['Jan']);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    final organicRow = find
        .ancestor(of: find.text('Organic '), matching: find.byType(Row))
        .first;
    final visibleValues = tester
        .widgetList<BeuiChartTicker>(
          find.descendant(
            of: organicRow,
            matching: find.byType(BeuiChartTicker),
          ),
        )
        .map((ticker) => ticker.format(ticker.value))
        .toList();
    expect(find.text('Feb'), findsWidgets);
    expect(find.text('Jan'), findsNothing);
    expect(visibleValues, ['40', '40.0%']);
    expect(changed, ['Jan', 'Feb']);
  });

  testWidgets(
    'area view preserves missing periods as a gap and reduced motion renders',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiCompositionChart(
            series: _series,
            periods: _periods,
            view: BeuiCompositionView.area,
            defaultPeriod: 'Mar',
          ),
          reduce: true,
        ),
      );
      expect(find.text('Mar · No data'), findsOneWidget);
      expect(find.text('No composition data'), findsNothing);
    },
  );

  testWidgets('resting composition chart matches its golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(640, 420));
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiCompositionChart(series: _series, periods: _periods),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(BeuiCompositionChart),
      matchesGoldenFile('goldens/beui_composition_chart.png'),
    );
    await tester.binding.setSurfaceSize(null);
  });
}
