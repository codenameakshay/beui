from pathlib import Path
p=Path('test/motion/availability_scheduler_test.dart')
s=p.read_text().replace("import 'package:flutter/material.dart';","import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';")
idx=s.index('void main()')
s=s[:idx]+"""
BeuiWeekAvailability _fixedWeek() => {
  for (final day in BeuiDayKey.values)
    day: BeuiDayAvailability(
      enabled: day != BeuiDayKey.tue && day != BeuiDayKey.sat,
      ranges: [
        BeuiTimeRange(id: '${day.name}-fixed',
          start: day == BeuiDayKey.mon ? '08:30' : '10:00',
          end: day == BeuiDayKey.mon ? '16:30' : '12:00'),
      ],
    ),
};

bool _focusedWithin(WidgetTester tester, Finder finder) {
  final focus = FocusManager.instance.primaryFocus?.context;
  if (focus == null) return false;
  return finder.evaluate().any((element) {
    var found = element == focus;
    focus.visitAncestorElements((ancestor) {
      if (ancestor == element) found = true;
      return !found;
    });
    return found;
  });
}

Future<void> _tabTo(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 70; i++) {
    if (_focusedWithin(tester, finder)) return;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
  }
  fail('Tab did not reach ${finder.description}');
}

""" + s[idx:]
idx=s.index("  group('BeuiAvailabilityScheduler interaction'")
s=s[:idx]+"""
  group('copy menu keyboard', () {
    for (final reduce in [false, true]) {
      for (final accept in [false, true]) {
        for (final everyDay in [false, true]) {
          for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
            testWidgets('reduce=$reduce accept=$accept all=$everyDay key=${key.keyLabel}', (tester) async {
              final initial = _fixedWeek();
              var displayed = initial;
              final proposals = <BeuiWeekAvailability>[];
              await tester.pumpWidget(StatefulBuilder(builder: (context, setOwner) =>
                beuiTestApp(BeuiAvailabilityScheduler(value: displayed, onChanged: (next) {
                  proposals.add(next);
                  if (accept) setOwner(() => displayed = next);
                }), alignment: Alignment.topCenter, reduce: reduce)));
              await tester.pumpAndSettle();
              final trigger = find.bySemanticsLabel('Copy Monday hours to other days');
              await _tabTo(tester, trigger);
              await tester.sendKeyEvent(LogicalKeyboardKey.enter);
              await tester.pumpAndSettle();
              final first = find.byType(BeuiCheckbox).first;
              await _tabTo(tester, first);
              expect(tester.widget<BeuiCheckbox>(first).value, false);
              await tester.sendKeyEvent(LogicalKeyboardKey.space);
              await tester.pumpAndSettle();
              expect(tester.widget<BeuiCheckbox>(first).value, true);
              await _tabTo(tester, find.text(everyDay ? 'Every day' : 'Apply'));
              await tester.sendKeyEvent(key);
              await tester.pumpAndSettle();
              expect(proposals, hasLength(1));
              final next = proposals.single;
              expect(next.keys.toSet(), initial.keys.toSet());
              for (final day in BeuiDayKey.values) {
                if (day != BeuiDayKey.mon && (everyDay || day == BeuiDayKey.tue)) {
                  expect(next[day]!.enabled, initial[BeuiDayKey.mon]!.enabled);
                  expect(next[day]!.ranges.map((r) => [r.start, r.end]).toList(),
                    initial[BeuiDayKey.mon]!.ranges.map((r) => [r.start, r.end]).toList());
                  expect(next[day]!.ranges.single.id, isNot(initial[day]!.ranges.single.id));
                } else {
                  expect(next[day], initial[day]);
                }
              }
              expect(tester.widget<BeuiAvailabilityScheduler>(find.byType(BeuiAvailabilityScheduler)).value,
                accept ? next : initial);
              expect(find.text('Copy times to'), findsNothing);
              await tester.pump(const Duration(milliseconds: 1300));
              await tester.pumpWidget(const SizedBox());
            });
          }
        }
      }
    }
    testWidgets('pointer once, empty Apply, Escape and reopen policy', (tester) async {
      final proposals = <BeuiWeekAvailability>[];
      await tester.pumpWidget(beuiTestApp(BeuiAvailabilityScheduler(
        value: _fixedWeek(), onChanged: proposals.add), alignment: Alignment.topCenter));
      await tester.pumpAndSettle();
      final trigger = find.bySemanticsLabel('Copy Monday hours to other days');
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(proposals, isEmpty);
      expect(find.text('Copy times to'), findsOneWidget);
      await tester.tap(find.text('Tuesday').last);
      await tester.pumpAndSettle();
      expect(tester.widget<BeuiCheckbox>(find.byType(BeuiCheckbox).first).value, true);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(proposals, isEmpty);
      expect(find.text('Copy times to'), findsNothing);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(tester.widget<BeuiCheckbox>(find.byType(BeuiCheckbox).first).value, true);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(proposals, hasLength(1));
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(tester.widget<BeuiCheckbox>(find.byType(BeuiCheckbox).first).value, false);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpWidget(const SizedBox());
    });
  });
""" + s[idx:]
p.write_text(s)
