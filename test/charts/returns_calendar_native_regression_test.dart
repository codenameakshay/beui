import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

Finder cell(int row, int month) =>
    find.byKey(ValueKey('beui-returns-cell-$row-$month'));
FocusNode node(WidgetTester tester, int row, int month) {
  final target = cell(row, month);
  final ink = find.ancestor(of: target, matching: find.byType(InkWell));
  return tester
      .widget<InkWell>(ink.evaluate().isEmpty ? target : ink)
      .focusNode!;
}

void main() {
  testWidgets('reverse without grid replacement', (t) async {
    Future<void> show(List<int> years) async {
      await t.pumpWidget(
        beuiTestApp(BeuiReturnsCalendar(years: years), reduce: true),
      );
      await t.pumpAndSettle();
    }

    await show([2024, 2025]);
    node(t, 1, 2).requestFocus();
    await t.pumpAndSettle();
    await show([2024, 2030]);
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await t.pumpAndSettle();
    expect(node(t, 0, 12).hasPrimaryFocus, isTrue);
  });
  testWidgets('whole calendar teardown', (t) async {
    await t.pumpWidget(
      beuiTestApp(const BeuiReturnsCalendar(years: [2024, 2025]), reduce: true),
    );
    node(t, 1, 2).requestFocus();
    await t.pumpAndSettle();
    await t.pumpWidget(beuiTestApp(const Text('gone'), reduce: true));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('grid replacement does not delete live registration', (t) async {
    Future<void> show(int key, List<int> years) async {
      await t.pumpWidget(
        beuiTestApp(
          BeuiReturnsCalendar(
            years: years,
            child: BeuiReturnsCalendarGrid(key: ValueKey(key)),
          ),
          reduce: true,
        ),
      );
      await t.pumpAndSettle();
    }

    await show(0, [2024, 2025]);
    await show(1, [2024, 2025]);
    node(t, 1, 2).requestFocus();
    await t.pumpAndSettle();
    await show(1, [2024, 2030]);
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await t.pumpAndSettle();
    expect(node(t, 0, 12).hasPrimaryFocus, isTrue);
    node(t, 1, 2).requestFocus();
    await t.pumpAndSettle();
    await show(1, [2024, 2040]);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pumpAndSettle();
    expect(node(t, 1, 0).hasPrimaryFocus, isTrue);
  });
  testWidgets('global keyed calendar reparent preserves focus', (t) async {
    final key = GlobalKey();
    Future<void> show(bool move) async {
      final cal = BeuiReturnsCalendar(key: key, years: const [2024, 2025]);
      await t.pumpWidget(
        beuiTestApp(
          Column(
            children: [
              if (!move) cal,
              if (move) Padding(padding: EdgeInsets.zero, child: cal),
            ],
          ),
          reduce: true,
        ),
      );
      await t.pumpAndSettle();
    }

    await show(false);
    final old = node(t, 1, 2);
    old.requestFocus();
    await t.pumpAndSettle();
    await show(true);
    expect(node(t, 1, 2), same(old));
    expect(old.hasPrimaryFocus, isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pumpAndSettle();
    expect(node(t, 1, 3).hasPrimaryFocus, isTrue);
    await show(false);
    expect(node(t, 1, 2), same(old));
    expect(node(t, 1, 3).hasPrimaryFocus, isTrue);
  });
  testWidgets('duplicate years have distinct stable occurrence identities', (
    t,
  ) async {
    Future<void> show(List<int> years) async {
      await t.pumpWidget(
        beuiTestApp(BeuiReturnsCalendar(years: years), reduce: true),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    }

    await show([2024, 2024, 2025]);
    final first = node(t, 0, 2);
    final second = node(t, 1, 2);
    expect(first, isNot(same(second)));
    second.requestFocus();
    await t.pumpAndSettle();
    await show([2025, 2024, 2024]);
    expect(node(t, 1, 2), same(first));
    expect(node(t, 2, 2), same(second));
    expect(second.hasPrimaryFocus, isTrue);
    await show([2025, 2024, 2030]);
    expect(second.context?.mounted, isFalse);
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await t.pumpAndSettle();
    expect(node(t, 1, 12).hasPrimaryFocus, isTrue);
    expect(node(t, 1, 2), same(first));
  });
  testWidgets('outside focus is not stolen on row replacement', (t) async {
    final outside = FocusNode();
    addTearDown(outside.dispose);
    Future<void> show(List<int> years) async {
      await t.pumpWidget(
        beuiTestApp(
          Column(
            children: [
              TextButton(
                focusNode: outside,
                onPressed: () {},
                child: const Text('outside'),
              ),
              BeuiReturnsCalendar(years: years),
            ],
          ),
          reduce: true,
        ),
      );
      await t.pumpAndSettle();
    }

    await show([2024, 2025]);
    node(t, 1, 2).requestFocus();
    await t.pumpAndSettle();
    await show([2024, 2030]);
    outside.requestFocus();
    await t.pumpAndSettle();
    await show([2024, 2040]);
    expect(outside.hasPrimaryFocus, isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pumpAndSettle();
    expect(node(t, 0, 0).hasPrimaryFocus, isTrue);
  });

  for (final reduce in [false, true]) {
    testWidgets('year identity and missing months, reduce=$reduce', (
      tester,
    ) async {
      Future<void> show(List<int> years, {bool missing = false}) async {
        await tester.pumpWidget(
          beuiTestApp(
            BeuiReturnsCalendar(
              years: years,
              returns: [
                for (final year in years)
                  List.filled(missing && year == 2025 ? 2 : 12, 4),
              ],
              child: const Column(
                children: [
                  BeuiReturnsCalendarGrid(),
                  BeuiReturnsCalendarTooltip(),
                ],
              ),
            ),
            reduce: reduce,
          ),
        );
        await tester.pumpAndSettle();
      }

      await show([2024, 2025]);
      final march = node(tester, 1, 2);
      march.requestFocus();
      await tester.pumpAndSettle();
      await show([2024, 2025], missing: true);
      expect(node(tester, 1, 2), same(march));
      expect(march.hasPrimaryFocus, isTrue);
      final tip = tester.widget<BeuiChartTooltip>(
        find.ancestor(of: cell(1, 2), matching: find.byType(BeuiChartTooltip)),
      );
      expect(tip.open, isTrue);
      final ticker = (tip.content as Wrap).children
          .whereType<BeuiChartTicker>()
          .single;
      expect(ticker.format(ticker.value), '+0.0%');
      await show([2024, 2030]);
      expect(node(tester, 1, 2), isNot(same(march)));
      expect(march.context?.mounted, isFalse);
      // Browser Tab is verified separately with trusted native input.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final january = node(tester, 1, 0);
      expect(january.hasPrimaryFocus, isTrue);
      await tester.pumpAndSettle();
      await show([2024, 2025]);
      expect(january.context?.mounted, isFalse);
      expect(find.text('Jan 2025'), findsWidgets);
    });

    testWidgets(
      'empty calendar does not restore fixture focus history, reduce=$reduce',
      (tester) async {
        final previous = FocusNode();
        addTearDown(previous.dispose);
        Future<void> show(List<int> years) async {
          await tester.pumpWidget(
            beuiTestApp(
              Column(
                children: [
                  TextButton(
                    focusNode: previous,
                    onPressed: () {},
                    child: const Text('missing'),
                  ),
                  BeuiReturnsCalendar(years: years),
                ],
              ),
              reduce: reduce,
            ),
          );
          await tester.pumpAndSettle();
        }

        await show([2024, 2025]);
        previous.requestFocus();
        await tester.pump();
        node(tester, 0, 2).requestFocus();
        await tester.pumpAndSettle();
        await show([]);
        expect(previous.hasFocus, isFalse);
        expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
      },
    );
  }

  testWidgets(
    'reordering preserves month and annual focus identities and index selection',
    (tester) async {
      BeuiReturnsCalendarSelection? changed;
      const selected = BeuiReturnsCalendarSelection(
        start: BeuiReturnsCalendarCell(year: 0, month: 12),
      );
      Future<void> show(List<int> years) async {
        await tester.pumpWidget(
          beuiTestApp(
            BeuiReturnsCalendar(
              years: years,
              selection: selected,
              onSelectionChange: (value) => changed = value,
            ),
            reduce: true,
          ),
        );
        await tester.pumpAndSettle();
      }

      await show([2024, 2025]);
      final march = node(tester, 1, 2);
      final annual = node(tester, 1, 12);
      annual.requestFocus();
      await tester.pumpAndSettle();
      await show([2025, 2024]);
      expect(node(tester, 0, 2), same(march));
      expect(node(tester, 0, 12), same(annual));
      expect(annual.hasPrimaryFocus, isTrue);
      expect(changed, isNull);
      await tester.tap(cell(1, 12));
      await tester.pumpAndSettle();
      expect(changed?.start, selected.start);
      expect(changed?.end, const BeuiReturnsCalendarCell(year: 1, month: 12));
      node(tester, 1, 12).unfocus();
      await tester.pumpAndSettle();
      bool pressed(int row) => tester
          .widgetList<Semantics>(
            find.ancestor(of: cell(row, 12), matching: find.byType(Semantics)),
          )
          .any((widget) => widget.properties.selected == true);
      expect(pressed(0), isTrue);
      expect(pressed(1), isFalse);
      final removed = node(tester, 1, 12);
      await show([2025]);
      expect(removed.context?.mounted, isFalse);
      expect(node(tester, 0, 12), same(annual));
    },
  );

  testWidgets('global grid moves between owners then replacement', (t) async {
    final grid = GlobalKey();
    Future<void> show(bool moved, List<int> years) async {
      await t.pumpWidget(
        beuiTestApp(
          Column(
            children: [
              BeuiReturnsCalendar(
                key: const ValueKey('a'),
                years: const [2024, 2025],
                child: moved
                    ? const SizedBox()
                    : BeuiReturnsCalendarGrid(key: grid),
              ),
              BeuiReturnsCalendar(
                key: const ValueKey('b'),
                years: years,
                child: moved
                    ? BeuiReturnsCalendarGrid(key: grid)
                    : const SizedBox(),
              ),
            ],
          ),
          reduce: true,
        ),
      );
      await t.pumpAndSettle();
    }

    await show(false, [2024, 2025]);
    final march = node(t, 1, 2);
    march.requestFocus();
    await t.pumpAndSettle();
    await show(true, [2024, 2025]);
    expect(node(t, 1, 2), same(march));
    expect(march.hasPrimaryFocus, true);
    await show(true, [2024, 2030]);
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await t.pumpAndSettle();
    expect(node(t, 0, 12).hasPrimaryFocus, true);
  });
  testWidgets('old owner cannot unfocus moved grid', (t) async {
    final grid = GlobalKey();
    Future<void> show(bool moved, List<int> oldYears) async {
      await t.pumpWidget(
        beuiTestApp(
          Column(
            children: [
              BeuiReturnsCalendar(
                key: const ValueKey('a'),
                years: oldYears,
                child: moved
                    ? const SizedBox()
                    : BeuiReturnsCalendarGrid(key: grid),
              ),
              BeuiReturnsCalendar(
                key: const ValueKey('b'),
                years: const [2024, 2025],
                child: moved
                    ? BeuiReturnsCalendarGrid(key: grid)
                    : const SizedBox(),
              ),
            ],
          ),
          reduce: true,
        ),
      );
      await t.pumpAndSettle();
    }

    await show(false, [2024, 2025]);
    final march = node(t, 1, 2);
    march.requestFocus();
    await t.pumpAndSettle();
    await show(true, [2024, 2025]);
    expect(march.hasPrimaryFocus, true);
    await show(true, [2024, 2030]);
    expect(node(t, 1, 2), same(march));
    expect(march.hasPrimaryFocus, true);
  });
  testWidgets('repeated replacement retains pending position', (t) async {
    Future<void> show(List<int> years) async {
      await t.pumpWidget(
        beuiTestApp(BeuiReturnsCalendar(years: years), reduce: true),
      );
      await t.pumpAndSettle();
    }

    await show([2024, 2025]);
    node(t, 1, 2).requestFocus();
    await t.pumpAndSettle();
    await show([2024, 2030]);
    await show([2024, 2040]);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pumpAndSettle();
    expect(node(t, 1, 0).hasPrimaryFocus, true);
  });
  testWidgets('outside cell focus cancels pending position', (t) async {
    Future<void> show(List<int> years) async {
      await t.pumpWidget(
        beuiTestApp(BeuiReturnsCalendar(years: years), reduce: true),
      );
      await t.pumpAndSettle();
    }

    await show([2024, 2025]);
    node(t, 1, 2).requestFocus();
    await t.pumpAndSettle();
    await show([2024, 2030]);
    node(t, 0, 2).requestFocus();
    await t.pumpAndSettle();
    await show([2024, 2040]);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pumpAndSettle();
    expect(node(t, 0, 3).hasPrimaryFocus, true);
  });
}
