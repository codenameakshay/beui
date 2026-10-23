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
  group('copy menu keyboard', () {
    for (final reduce in [false, true]) {
      for (final accept in [false, true]) {
        for (final everyDay in [false, true]) {
          for (final key in [
            LogicalKeyboardKey.enter,
            LogicalKeyboardKey.space,
          ]) {
            testWidgets(
              'reduce=$reduce accept=$accept all=$everyDay key=${key.keyLabel}',
              (tester) async {
                await tester.binding.setSurfaceSize(const Size(1000, 1200));
                addTearDown(() => tester.binding.setSurfaceSize(null));
                final initial = _fixedWeek();
                var displayed = initial;
                final proposals = <BeuiWeekAvailability>[];
                await tester.pumpWidget(
                  StatefulBuilder(
                    builder: (context, setOwner) => beuiTestApp(
                      BeuiAvailabilityScheduler(
                        value: displayed,
                        onChanged: (next) {
                          proposals.add(next);
                          if (accept) setOwner(() => displayed = next);
                        },
                      ),
                      alignment: Alignment.topCenter,
                      reduce: reduce,
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                final trigger = find.bySemanticsLabel(
                  'Copy Monday hours to other days',
                );
                await _tabTo(tester, trigger);
                await tester.sendKeyEvent(LogicalKeyboardKey.enter);
                await tester.pumpAndSettle();
                if (!everyDay) {
                  final first = find.byType(BeuiCheckbox).first;
                  await _tabTo(tester, first);
                  expect(tester.widget<BeuiCheckbox>(first).value, false);
                  await tester.sendKeyEvent(LogicalKeyboardKey.space);
                  await tester.pumpAndSettle();
                  expect(tester.widget<BeuiCheckbox>(first).value, true);
                }
                await _tabTo(
                  tester,
                  find.ancestor(
                    of: find.text(everyDay ? 'Every day' : 'Apply'),
                    matching: find.byType(FocusableActionDetector),
                  ),
                );
                await tester.sendKeyEvent(key);
                await tester.pumpAndSettle();
                expect(proposals, hasLength(1));
                final next = proposals.single;
                expect(next.keys.toSet(), initial.keys.toSet());
                for (final day in BeuiDayKey.values) {
                  if (day != BeuiDayKey.mon &&
                      (everyDay || day == BeuiDayKey.tue)) {
                    expect(
                      next[day]!.enabled,
                      initial[BeuiDayKey.mon]!.enabled,
                    );
                    expect(
                      next[day]!.ranges.map((r) => [r.start, r.end]).toList(),
                      initial[BeuiDayKey.mon]!.ranges
                          .map((r) => [r.start, r.end])
                          .toList(),
                    );
                    expect(
                      next[day]!.ranges.single.id,
                      isNot(initial[day]!.ranges.single.id),
                    );
                  } else {
                    expect(next[day], initial[day]);
                  }
                }
                expect(
                  tester
                      .widget<BeuiAvailabilityScheduler>(
                        find.byType(BeuiAvailabilityScheduler),
                      )
                      .value,
                  accept ? next : initial,
                );
                expect(find.text('Copy times to'), findsNothing);
                await tester.pump(const Duration(milliseconds: 1300));
                await tester.pumpWidget(const SizedBox());
              },
            );
          }
        }
      }
    }
    testWidgets('pointer once, empty Apply, Escape and reopen policy', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final proposals = <BeuiWeekAvailability>[];
      await tester.pumpWidget(
        beuiTestApp(
          BeuiAvailabilityScheduler(
            value: _fixedWeek(),
            onChanged: proposals.add,
          ),
          alignment: Alignment.topCenter,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.copy).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(proposals, isEmpty);
      expect(find.text('Copy times to'), findsOneWidget);
      await tester.tap(
        find
            .ancestor(
              of: find.byType(BeuiCheckbox).first,
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<BeuiCheckbox>(find.byType(BeuiCheckbox).first).value,
        true,
      );
      // Browser pointer activation can leave focus outside the popup.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(proposals, isEmpty);
      expect(find.text('Copy times to'), findsNothing);
      await tester.tap(find.byIcon(LucideIcons.copy).first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<BeuiCheckbox>(find.byType(BeuiCheckbox).first).value,
        true,
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(proposals, hasLength(1));
      await tester.tap(find.byIcon(LucideIcons.check).first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<BeuiCheckbox>(find.byType(BeuiCheckbox).first).value,
        false,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpWidget(const SizedBox());
    });
  });
  group('BeuiAvailabilityScheduler interaction', () {
    testWidgets('renders one toggle per weekday', (tester) async {
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();
      expect(find.byType(BeuiSwitch), findsNWidgets(7));
    });

    testWidgets('default week marks the weekend unavailable', (tester) async {
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();
      // Sat + Sun are off in the default week.
      expect(find.text('Unavailable'), findsNWidgets(2));
    });

    testWidgets('disabling a day adds an Unavailable line', (tester) async {
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();
      // Monday is the first switch; toggle it off.
      await tester.tap(find.byType(BeuiSwitch).first);
      await tester.pumpAndSettle();
      expect(find.text('Unavailable'), findsNWidgets(3));
    });

    testWidgets('add button appends a range to the day', (tester) async {
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();
      // Each of Mon–Fri has one range → five range separators.
      expect(find.text('–'), findsNWidgets(5));
      await tester.tap(find.byIcon(LucideIcons.plus).first);
      await tester.pumpAndSettle();
      expect(find.text('–'), findsNWidgets(6));
    });

    testWidgets('removing the only range marks the day unavailable', (
      tester,
    ) async {
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();
      // Remove Monday's single range.
      await tester.tap(find.byIcon(LucideIcons.x).first);
      await tester.pumpAndSettle();
      expect(find.text('Unavailable'), findsNWidgets(3));
    });
  });

  group('BeuiAvailabilityScheduler motion fidelity', () {
    testWidgets('a newly added range blurs in under normal motion', (
      tester,
    ) async {
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.plus).first);
      // One frame into the enter spring: the slot is mid-blur.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.descendant(
          of: find.byType(BeuiAvailabilityScheduler),
          matching: find.byType(ImageFiltered),
        ),
        findsWidgets,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion drops the range blur', (tester) async {
      await tester.pumpWidget(const _Harness(reduce: true));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.plus).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.descendant(
          of: find.byType(BeuiAvailabilityScheduler),
          matching: find.byType(ImageFiltered),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
    });
  });

  testWidgets('rest-state golden (default week)', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        Padding(
          padding: const EdgeInsets.all(16),
          child: BeuiAvailabilityScheduler(
            value: beuiDefaultWeek(),
            onChanged: (_) {},
          ),
        ),
        alignment: Alignment.topCenter,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiAvailabilityScheduler),
      matchesGoldenFile('goldens/beui_availability_scheduler.png'),
    );
  });
}
