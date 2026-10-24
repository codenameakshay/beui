import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

/// A controlled harness that holds the week and feeds it back on change, so
/// interaction tests observe the real re-render.
class _Harness extends StatefulWidget {
  const _Harness({this.reduce = false});

  final bool reduce;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  BeuiWeekAvailability _week = beuiDefaultWeek();

  @override
  Widget build(BuildContext context) => beuiTestApp(
    BeuiAvailabilityScheduler(
      value: _week,
      onChanged: (next) => setState(() => _week = next),
    ),
    alignment: Alignment.topCenter,
    reduce: widget.reduce,
  );
}

BeuiWeekAvailability _fixedWeek() => {
  for (final day in BeuiDayKey.values)
    day: BeuiDayAvailability(
      enabled: day != BeuiDayKey.tue && day != BeuiDayKey.sat,
      ranges: [
        BeuiTimeRange(
          id: '${day.name}-fixed',
          start: day == BeuiDayKey.mon ? '08:30' : '10:00',
          end: day == BeuiDayKey.mon ? '16:30' : '12:00',
        ),
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
  fail('Tab did not reach ${finder.describeMatch(Plurality.one)}');
}

void main() {
  for (final mode in ['external', 'same', 'pending']) {
    for (final every in [false, true]) {
      testWidgets('r2 owner focus $mode every=$every', (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final owner = FocusNode();
        addTearDown(owner.dispose);
        var calls = 0;
        await tester.pumpWidget(beuiTestApp(Column(children: [
          TextButton(focusNode: owner, onPressed: () {}, child: const Text('Owner')),
          BeuiAvailabilityScheduler(value: _fixedWeek(), onChanged: (_) {
            calls++;
            owner.requestFocus();
          }),
        ]), alignment: Alignment.topCenter));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(LucideIcons.copy).first);
        await tester.pumpAndSettle();
        if (!every) {
          await tester.tap(find.byType(BeuiCheckbox).first, warnIfMissed: false);
          await tester.pumpAndSettle();
        }
        if (mode != 'external') {
          owner.requestFocus();
          if (mode == 'same') await tester.pump();
        }
        await tester.tap(find.text(every ? 'Every day' : 'Apply'));
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(owner.hasPrimaryFocus, true);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('r2 multiple menus Escape teardown and independent picks', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final calls = <BeuiWeekAvailability>[];
    await tester.pumpWidget(beuiTestApp(BeuiAvailabilityScheduler(value: _fixedWeek(), onChanged: calls.add), alignment: Alignment.topCenter));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.copy).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BeuiCheckbox).first, warnIfMissed: false);
    await tester.pumpAndSettle();
    final secondTrigger = find.bySemanticsLabel('Copy Tuesday hours to other days');
    final focus = Focus.of(tester.element(find.descendant(of: secondTrigger, matching: find.byType(Icon)).first));
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Copy times to'), findsNWidgets(2));
    await _tabTo(tester, find.byType(BeuiCheckbox).last);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Copy times to'), findsOneWidget);
    expect(tester.widget<BeuiCheckbox>(find.byType(BeuiCheckbox).first).value, true);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Copy times to'), findsNothing);
    expect(calls, isEmpty);
    await tester.tap(find.byIcon(LucideIcons.copy).at(1));
    await tester.pumpAndSettle();
    expect(tester.widget<BeuiCheckbox>(find.byType(BeuiCheckbox).first).value, false);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(tester.takeException(), isNull);
  });
}
