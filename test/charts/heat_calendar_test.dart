import 'dart:ui' show PointerDeviceKind;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  for (final viewportWidth in [200.0, 640.0]) {
    testWidgets(
      viewportWidth == 200
          ? 'short-grid legend wraps within 200px and filters cells'
          : 'short-grid legend stays packed with ample width and filters cells',
      (tester) async {
        tester.view.physicalSize = Size(viewportWidth, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          beuiTestApp(
            BeuiHeatCalendar(
              weeks: 8,
              endDate: DateTime.utc(2026, 10, 22),
              values: List.generate(
                8,
                (_) => [0.2, 0.8, 0.2, 0.2, 0.2, 0.2, 0.2],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final range = find.text('Aug 31 – Oct 22');
        final less = find.text('less');
        final more = find.text('more');
        final levels = [
          for (var level = 0; level < 5; level++)
            find.bySemanticsLabel('Filter activity level $level'),
        ];
        for (final part in [range, less, ...levels, more]) {
          expect(part, findsOneWidget);
          final rect = tester.getRect(part);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(viewportWidth));
        }
        final rangeRect = tester.getRect(range);
        final lessRect = tester.getRect(less);
        expect(tester.getTopLeft(more).dy, lessRect.top);
        if (viewportWidth == 200) {
          expect(rangeRect.bottom, lessThanOrEqualTo(lessRect.top));
          expect(
            tester.getSize(find.byType(BeuiHeatCalendarLegend)).width,
            lessThanOrEqualTo(200),
          );
        } else {
          expect(lessRect.top, rangeRect.top);
          expect(lessRect.left - rangeRect.right, closeTo(16, 0.01));
        }

        double paintedCellOpacity(int day) {
          final cell = find.byKey(ValueKey('beui-heat-cell-0-$day'));
          final paint = tester.renderObject<RenderDecoratedBox>(
            find.descendant(
              of: cell,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is DecoratedBox &&
                    widget.decoration is BoxDecoration &&
                    (widget.decoration as BoxDecoration).color != null,
              ),
            ),
          );
          expect(tester.getSize(cell), const Size(16, 16));
          expect(paint.size, const Size(16, 16));
          var opacity = 1.0;
          for (RenderObject? node = paint; node != null; node = node.parent) {
            if (node is RenderOpacity) opacity *= node.opacity;
          }
          return opacity;
        }

        expect(paintedCellOpacity(0), 1);
        expect(paintedCellOpacity(1), 1);
        await tester.tap(levels[1]);
        await tester.pumpAndSettle();
        expect(tester.widget<Semantics>(levels[1]).properties.selected, isTrue);
        expect(paintedCellOpacity(0), 1);
        expect(paintedCellOpacity(1), 0.25);
        await tester.tap(levels[1]);
        await tester.pumpAndSettle();
        expect(
          tester.widget<Semantics>(levels[1]).properties.selected,
          isFalse,
        );
        expect(paintedCellOpacity(0), 1);
        expect(paintedCellOpacity(1), 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

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
