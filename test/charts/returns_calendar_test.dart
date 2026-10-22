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
      expect(find.text('Jan'), findsOneWidget);
      expect(find.text('Year'), findsWidgets);
      expect(find.text('+214%'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('beui-returns-cell-0-12')),
        findsOneWidget,
      );
    },
  );

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
