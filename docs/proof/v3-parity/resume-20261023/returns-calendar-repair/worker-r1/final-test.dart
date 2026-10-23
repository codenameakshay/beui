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
}
