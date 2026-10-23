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
  for (final reduce in [false, true]) {
    testWidgets('r2 disabled next Tab Escape reopen reduce=$reduce', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final proposals = <BeuiWeekAvailability>[];
      await tester.pumpWidget(beuiTestApp(BeuiAvailabilityScheduler(value: _fixedWeek(), onChanged: proposals.add), reduce: reduce, alignment: Alignment.topCenter));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.copy).first);
      await tester.pumpAndSettle();
      final box = find.byType(BeuiCheckbox).first;
      await _tabTo(tester, box);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(tester.widget<BeuiCheckbox>(box).value, true);
      final apply = find.ancestor(of: find.text('Apply'), matching: find.byType(FocusableActionDetector));
      await _tabTo(tester, apply);
      // A pointer removes the final selection while Apply owns keyboard focus.
      await tester.tap(box, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.widget<BeuiCheckbox>(box).value, false);
      expect(tester.widget<FocusableActionDetector>(apply).enabled, false);
      expect(find.text('Copy times to'), findsOneWidget);
      expect(_focusedWithin(tester, apply), false);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      print('Proposals after Enter: ${proposals.length}');
      if (proposals.isNotEmpty) {
        print('Friday enabled: ${proposals.single[BeuiDayKey.fri]!.enabled}, ranges: ${proposals.single[BeuiDayKey.fri]!.ranges.length}');
      }
      expect(proposals, isEmpty, reason: 'Disabling Apply must not route activation to a background Remove time range button while the menu remains open');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_focusedWithin(tester, box), true);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Copy times to'), findsNothing);
      expect(proposals, isEmpty);
      await tester.tap(find.byIcon(LucideIcons.copy).first);
      await tester.pumpAndSettle();
      expect(tester.widget<BeuiCheckbox>(box).value, false);
      await tester.tap(box, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.widget<BeuiCheckbox>(box).value, true);
      await _tabTo(tester, apply);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(proposals, hasLength(1));
      expect(proposals.single[BeuiDayKey.tue]!.ranges.single.start, '08:30');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  }
  for (final remove in [false, true]) {
    testWidgets('independent owner focus takes precedence and dispose=$remove', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final ownerFocus = FocusNode();
      addTearDown(ownerFocus.dispose);
      var visible = true;
      var calls = 0;
      await tester.pumpWidget(StatefulBuilder(builder: (context, setOwner) => beuiTestApp(Column(children: [
        TextButton(focusNode: ownerFocus, onPressed: () {}, child: const Text('Owner target')),
        if (visible) BeuiAvailabilityScheduler(value: _fixedWeek(), onChanged: (_) {
          calls++;
          ownerFocus.requestFocus();
          if (remove) setOwner(() => visible = false);
        }),
      ]), alignment: Alignment.topCenter)));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.copy).first);
      await tester.pumpAndSettle();
      await _tabTo(tester, find.ancestor(of: find.text('Every day'), matching: find.byType(FocusableActionDetector)));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(ownerFocus.hasPrimaryFocus, true);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('independent reparent open menu and latest disabled source data', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final schedulerKey = GlobalKey();
    var moved = false;
    var week = _fixedWeek();
    late StateSetter update;
    final proposals = <BeuiWeekAvailability>[];
    await tester.pumpWidget(StatefulBuilder(builder: (context, setOwner) {
      update = setOwner;
      final scheduler = BeuiAvailabilityScheduler(key: schedulerKey, value: week, onChanged: proposals.add);
      return beuiTestApp(Column(children: [
        if (!moved) scheduler else const SizedBox(),
        if (moved) Padding(padding: const EdgeInsets.only(top: 8), child: scheduler) else const SizedBox(),
      ]), alignment: Alignment.topCenter);
    }));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.copy).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BeuiCheckbox).first, warnIfMissed: false);
    await tester.pumpAndSettle();
    update(() {
      moved = true;
      week = {...week, BeuiDayKey.mon: const BeuiDayAvailability(enabled: false, ranges: [])};
    });
    await tester.pumpAndSettle();
    expect(find.text('Copy times to'), findsOneWidget);
    expect(tester.widget<BeuiCheckbox>(find.byType(BeuiCheckbox).first).value, true);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(proposals, hasLength(1));
    expect(proposals.single[BeuiDayKey.mon], same(week[BeuiDayKey.mon]));
    expect(proposals.single[BeuiDayKey.tue]!.enabled, false);
    expect(proposals.single[BeuiDayKey.tue]!.ranges, isEmpty);
    expect(proposals.single[BeuiDayKey.wed], same(week[BeuiDayKey.wed]));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(tester.takeException(), isNull);
  });
}
