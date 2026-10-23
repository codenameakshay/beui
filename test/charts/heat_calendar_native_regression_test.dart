import 'dart:ui' show PointerDeviceKind;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

Widget chart({int endDay = 23, bool reduce = false}) => beuiTestApp(
  BeuiHeatCalendar(
    weeks: 4,
    endDate: DateTime.utc(2026, 10, endDay),
    values: List.generate(4, (_) => [0, .2, .4, .6, .8, 1, 0]),
  ),
  reduce: reduce,
);

Finder legend(int level) =>
    find.bySemanticsLabel('Filter activity level $level');
Finder cell(int week, int day) =>
    find.byKey(ValueKey('beui-heat-cell-$week-$day'));
bool selected(WidgetTester tester, int level) =>
    tester.widget<Semantics>(legend(level)).properties.selected!;

Widget continuationChart({
  int endDay = 23,
  Widget? child,
  BeuiHeatCalendarSelection? selection,
  ValueChanged<BeuiHeatCalendarSelection?>? onSelectionChange,
}) => beuiTestApp(
  Column(
    children: [
      TextButton(onPressed: () {}, child: const Text('before')),
      BeuiHeatCalendar(
        weeks: 4,
        endDate: DateTime.utc(2026, 10, endDay),
        selection: selection,
        onSelectionChange: onSelectionChange,
        child: child,
      ),
      TextButton(onPressed: () {}, child: const Text('after')),
    ],
  ),
);

bool daySelected(WidgetTester tester, int week, int day) => tester
    .widget<Semantics>(
      find.ancestor(
        of: cell(week, day),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label?.contains('commits on') ?? false),
        ),
      ),
    )
    .properties
    .selected!;

Future<void> removeFocusedDay(WidgetTester tester, {Widget? child}) async {
  await tester.pumpWidget(continuationChart(child: child));
  await tester.tap(cell(3, 4));
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
  await tester.pumpWidget(continuationChart(endDay: 19, child: child));
  await tester.pumpAndSettle();
  expect(find.text('commits'), findsNothing);
  expect(tester.widget<InkWell>(cell(3, 0)).focusNode!.hasFocus, isFalse);
}

void main() {
  testWidgets('invalid locked range clears before the next anchor', (
    tester,
  ) async {
    await tester.pumpWidget(continuationChart());
    await tester.tap(cell(0, 0));
    await tester.tap(cell(3, 4));
    await tester.pumpAndSettle();
    await tester.pumpWidget(continuationChart(endDay: 19));
    await tester.pumpAndSettle();
    expect(daySelected(tester, 0, 0), isFalse);
    await tester.pumpWidget(continuationChart());
    await tester.pumpAndSettle();
    expect(daySelected(tester, 0, 0), isFalse);
    await tester.tap(cell(1, 0));
    await tester.pumpAndSettle();
    expect(daySelected(tester, 1, 0), isTrue);
    expect(daySelected(tester, 0, 0), isFalse);
  });
  testWidgets('removed focus waits for forward Tab before legend', (
    tester,
  ) async {
    await removeFocusedDay(tester);
    expect(selected(tester, 0), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(selected(tester, 0), isTrue);
    expect(find.text('commits'), findsNothing);
  });
  for (final custom in [false, true]) {
    testWidgets(
      'removed focus reverse Tab reaches final valid day custom=$custom',
      (tester) async {
        await removeFocusedDay(
          tester,
          child: custom ? const BeuiHeatCalendarGrid() : null,
        );
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(tester.widget<InkWell>(cell(3, 0)).focusNode!.hasFocus, isTrue);
      },
    );
  }
  testWidgets('custom grid without legend continues to following control', (
    tester,
  ) async {
    await removeFocusedDay(tester, child: const BeuiHeatCalendarGrid());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text('after'))).hasFocus, isTrue);
  });
  testWidgets(
    'custom composition continues to intervening control before legend',
    (tester) async {
      await removeFocusedDay(
        tester,
        child: Column(
          children: [
            const BeuiHeatCalendarGrid(),
            TextButton(onPressed: () {}, child: const Text('middle')),
            const BeuiHeatCalendarLegend(),
          ],
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(Focus.of(tester.element(find.text('middle'))).hasFocus, isTrue);
      expect(selected(tester, 0), isFalse);
    },
  );
  testWidgets('outside focus cancels removal continuation', (tester) async {
    await removeFocusedDay(tester);
    Focus.of(tester.element(find.text('after'))).requestFocus();
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text('after'))).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text('before'))).hasFocus, isTrue);
    expect(selected(tester, 0), isFalse);
  });

  testWidgets(
    'invalid controlled range remains owner driven without update callback',
    (tester) async {
      const selection = BeuiHeatCalendarSelection(
        start: BeuiHeatCalendarCell(week: 0, day: 0),
        end: BeuiHeatCalendarCell(week: 3, day: 4),
      );
      final changes = <BeuiHeatCalendarSelection?>[];
      await tester.pumpWidget(
        continuationChart(selection: selection, onSelectionChange: changes.add),
      );
      await tester.pumpWidget(
        continuationChart(
          endDay: 19,
          selection: selection,
          onSelectionChange: changes.add,
        ),
      );
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      expect(daySelected(tester, 0, 0), isFalse);
      await tester.tap(cell(1, 0));
      await tester.pumpAndSettle();
      expect(changes, [
        const BeuiHeatCalendarSelection(
          start: BeuiHeatCalendarCell(week: 1, day: 0),
        ),
      ]);
      expect(daySelected(tester, 0, 0), isFalse);
      await tester.pumpWidget(
        continuationChart(selection: selection, onSelectionChange: changes.add),
      );
      await tester.pumpAndSettle();
      expect(daySelected(tester, 0, 0), isTrue);
    },
  );

  for (final reduce in [false, true]) {
    testWidgets(
      'legend pointer entry filters and scale exit clears ($reduce)',
      (tester) async {
        await tester.pumpWidget(chart(reduce: reduce));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(legend(2)));
        await tester.pumpAndSettle();
        expect(selected(tester, 2), isTrue);
        await mouse.down(tester.getCenter(legend(2)));
        await mouse.up();
        await tester.pumpAndSettle();
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        expect(selected(tester, 2), isFalse);
        await mouse.removePointer();
      },
    );

    testWidgets('pointer exit clears a clicked legend filter ($reduce)', (
      tester,
    ) async {
      await tester.pumpWidget(chart(reduce: reduce));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(legend(2)));
      await tester.pumpAndSettle();
      await mouse.down(tester.getCenter(legend(2)));
      await mouse.up();
      await tester.pumpAndSettle();
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(selected(tester, 2), isFalse);
      await mouse.removePointer();
    });

    testWidgets(
      'Tab after final day filters legend and next Tab changes level ($reduce)',
      (tester) async {
        await tester.pumpWidget(chart(reduce: reduce));
        await tester.tap(cell(3, 4));
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(selected(tester, 0), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(selected(tester, 0), isFalse);
        expect(selected(tester, 1), isTrue);
      },
    );

    testWidgets('removing inspected future day clears readout ($reduce)', (
      tester,
    ) async {
      await tester.pumpWidget(chart(reduce: reduce));
      await tester.tap(cell(3, 4));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.pumpWidget(chart(endDay: 19, reduce: reduce));
      await tester.pumpAndSettle();
      expect(find.text('commits'), findsNothing);
      expect(cell(3, 4), findsNothing);
    });
  }

  testWidgets('removal does not restore a previously focused day readout', (
    tester,
  ) async {
    await tester.pumpWidget(chart());
    await tester.tap(cell(0, 6));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(cell(3, 4));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.pumpWidget(chart(endDay: 19));
    await tester.pumpAndSettle();
    expect(find.text('commits'), findsNothing);
    expect(tester.widget<InkWell>(cell(0, 6)).focusNode!.hasFocus, isFalse);
  });

  testWidgets(
    'semantic traversal visits days chronologically before the legend',
    (tester) async {
      await tester.pumpWidget(chart());
      final labels = <String>[];
      void visit(SemanticsNode node) {
        final label = node.getSemanticsData().label;
        if (label.contains('commits on') ||
            label.startsWith('Filter activity')) {
          labels.add(label);
        }
        for (final child in node.debugListChildrenInOrder(
          DebugSemanticsDumpOrder.traversalOrder,
        )) {
          visit(child);
        }
      }

      visit(tester.getSemantics(find.byType(BeuiHeatCalendar)));
      expect(labels.take(3), [
        '0 commits on Mon, Sep 28',
        '3 commits on Tue, Sep 29',
        '6 commits on Wed, Sep 30',
      ]);
      expect(labels[25], '11 commits on Fri, Oct 23');
      expect(labels[26], 'Filter activity level 0');
    },
  );
}
