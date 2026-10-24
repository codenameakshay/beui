import 'dart:ui' show PointerDeviceKind;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

BeuiReturnsCalendar _chart({
  BeuiReturnsCalendarSelection? selection,
  ValueChanged<BeuiReturnsCalendarSelection?>? onSelectionChange,
}) => BeuiReturnsCalendar(
  years: const [2024, 2025],
  returns: const [
    [10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10],
    [-4, 2, 1, -3, 2, 1, 0, -1, 2, 3, -2, 4],
  ],
  selection: selection,
  onSelectionChange: onSelectionChange,
);

void main() {
  testWidgets(
    'renders month labels, gain/loss cells, and compounded year totals',
    (tester) async {
      await tester.pumpWidget(beuiTestApp(_chart()));
      expect(find.text('J'), findsWidgets);
      expect(find.text('Year'), findsWidgets);
      expect(find.text('+214%'), findsOneWidget);
      expect(find.text('10'), findsWidgets);
      expect(
        find.byKey(const ValueKey('beui-returns-cell-0-12')),
        findsOneWidget,
      );
    },
  );

  testWidgets('half-away month labels follow JS Math.round', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiReturnsCalendar(
          years: [2022],
          returns: [
            [0, 0, -4.5, 0, 0, 0, 0, 0, 0, 0, 0, 0],
          ],
        ),
      ),
    );
    expect(find.text('−4'), findsOneWidget);
    expect(find.text('−5'), findsNothing);
  });

  testWidgets('formats short numeric years with a two-digit label', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiReturnsCalendar(
          years: [99],
          returns: [
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
          ],
        ),
      ),
    );
    expect(find.text("'99"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uncontrolled range selection toggles cells', (tester) async {
    await tester.pumpWidget(beuiTestApp(_chart()));
    await tester.tap(find.byKey(const ValueKey('beui-returns-cell-0-0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('beui-returns-cell-0-1')));
    await tester.pump();
    expect(
      tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.selected == true)
          .length,
      2,
    );
  });

  testWidgets('hovering a month reveals and settles its signed ticker', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(_chart()));
    final cell = find.byKey(const ValueKey('beui-returns-cell-1-0'));
    await tester.ensureVisible(cell);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(cell));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.byType(BeuiChartTicker), findsOneWidget);
    final ticker = tester.widget<BeuiChartTicker>(find.byType(BeuiChartTicker));
    expect(ticker.value, 4);
    expect(ticker.format(ticker.value), '−4.0%');
    await gesture.removePointer();
  });

  testWidgets('month tooltips use unambiguous month names', (tester) async {
    await tester.pumpWidget(beuiTestApp(_chart()));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);

    for (final (month, name) in [(0, 'Jan'), (5, 'Jun'), (6, 'Jul')]) {
      final cell = find.byKey(ValueKey('beui-returns-cell-0-$month'));
      await tester.ensureVisible(cell);
      await gesture.moveTo(tester.getCenter(cell));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      final tooltip = tester.widget<BeuiChartTooltip>(
        find.ancestor(of: cell, matching: find.byType(BeuiChartTooltip)),
      );
      expect(
        ((tooltip.content as Wrap).children.first as Text).data,
        '$name 2024',
      );
      expect(find.byType(BeuiChartTicker), findsOneWidget);
    }

    await gesture.removePointer();
  });

  testWidgets(
    'controlled selection reports selection and keyboard Escape clears',
    (tester) async {
      BeuiReturnsCalendarSelection? changed;
      const selected = BeuiReturnsCalendarSelection(
        start: BeuiReturnsCalendarCell(year: 0, month: 0),
      );
      await tester.pumpWidget(
        beuiTestApp(
          _chart(selection: selected, onSelectionChange: (v) => changed = v),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('beui-returns-cell-0-1')));
      expect(changed?.end, const BeuiReturnsCalendarCell(year: 0, month: 1));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(changed, isNull);
    },
  );

  testWidgets('reduced motion rest state matches golden', (tester) async {
    tester.view.physicalSize = const Size(640, 480);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(beuiTestApp(_chart(), reduce: true));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(BeuiReturnsCalendar),
      matchesGoldenFile('goldens/beui_returns_calendar.png'),
    );
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
