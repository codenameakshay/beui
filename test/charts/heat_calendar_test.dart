import 'dart:ui' show PointerDeviceKind;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

BeuiHeatCalendar _chart({
  BeuiHeatCalendarSelection? selection,
  BeuiHeatCalendarSelection? defaultSelection,
  ValueChanged<BeuiHeatCalendarSelection?>? onSelectionChange,
}) => BeuiHeatCalendar(
  weeks: 4,
  maxCount: 14,
  endDate: DateTime.utc(2026, 10, 21),
  values: List.generate(4, (w) => List.generate(7, (d) => ((w + d) % 5) / 4)),
  selection: selection,
  defaultSelection: defaultSelection,
  onSelectionChange: onSelectionChange,
);

void main() {
  testWidgets('renders Monday-first cells and exposes count/date semantics', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(_chart()));
    expect(find.byKey(const ValueKey('beui-heat-cell-0-0')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'commits, Oct')), findsWidgets);
    expect(find.text('more'), findsOneWidget);
    expect(find.text('Oct'), findsWidgets);
  });

  testWidgets('uncontrolled clicks anchor and lock a selected range', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(_chart()));
    await tester.tap(find.byKey(const ValueKey('beui-heat-cell-0-0')));
    await tester.pump();
    expect(
      tester
          .widgetList<Semantics>(find.byType(Semantics))
          .any((s) => s.properties.selected == true),
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('beui-heat-cell-0-2')));
    await tester.pump();
    expect(
      tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.selected == true)
          .length,
      2,
    );
  });

  testWidgets('hovering a cell reveals its animated count and date', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(_chart()));
    final cell = find.byKey(const ValueKey('beui-heat-cell-0-2'));
    await tester.ensureVisible(cell);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(cell));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.byType(BeuiChartTicker), findsWidgets);
    expect(
      tester.widget<BeuiChartTicker>(find.byType(BeuiChartTicker).first).value,
      7,
    );
    expect(find.text('commits'), findsWidgets);
    expect(find.textContaining('Sep 30, 2026'), findsWidgets);
    await gesture.removePointer();
  });

  testWidgets(
    'controlled selection reports range changes without taking ownership',
    (tester) async {
      BeuiHeatCalendarSelection? changed;
      const controlled = BeuiHeatCalendarSelection(
        start: BeuiHeatCalendarCell(week: 0, day: 0),
      );
      await tester.pumpWidget(
        beuiTestApp(
          _chart(
            selection: controlled,
            onSelectionChange: (value) => changed = value,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('beui-heat-cell-0-2')));
      await tester.pump();
      expect(changed?.end, const BeuiHeatCalendarCell(week: 0, day: 2));
    },
  );

  testWidgets('keyboard inspector advances selection and Escape clears', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(_chart()));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(
      tester
          .widgetList<Semantics>(find.byType(Semantics))
          .any((s) => s.properties.selected == true),
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(
      tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.selected == true),
      isEmpty,
    );
  });

  testWidgets(
    'legend spans a 16-week grid with the date range opposite less/more',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          BeuiHeatCalendar(
            weeks: 16,
            maxCount: 14,
            endDate: DateTime.utc(2026, 10, 22),
            values: List.generate(16, (w) => List.generate(7, (d) => 0.2)),
          ),
        ),
      );
      final grid = tester.getSize(find.byType(BeuiHeatCalendarGrid));
      final legend = tester.getSize(find.byType(BeuiHeatCalendarLegend));
      expect(legend.width, closeTo(grid.width, 0.5));
      expect(find.text('Jul 6 – Oct 22'), findsOneWidget);
      expect(find.text('less'), findsOneWidget);
      expect(find.text('more'), findsOneWidget);
      final range = tester.getTopLeft(find.text('Jul 6 – Oct 22'));
      final more = tester.getTopLeft(find.text('more'));
      expect(more.dx, greaterThan(range.dx + 80));
    },
  );

  testWidgets('reduced motion renders a stable rest state and golden', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 480);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(beuiTestApp(_chart(), reduce: true));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(BeuiHeatCalendar),
      matchesGoldenFile('goldens/beui_heat_calendar.png'),
    );
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
