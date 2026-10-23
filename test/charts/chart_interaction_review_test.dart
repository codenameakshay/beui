import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _periods = [
  BeuiStatusBarDatum(
    id: 'a',
    label: 'Monday',
    status: 'operational',
    description: 'Monday detail',
  ),
  BeuiStatusBarDatum(
    id: 'b',
    label: 'Tuesday',
    status: 'degraded',
    description: 'Tuesday detail',
  ),
  BeuiStatusBarDatum(
    id: 'c',
    label: 'Wednesday',
    status: 'operational',
    description: 'Wednesday detail',
  ),
];

const _targets = [
  BeuiPriceTarget(key: 'High', price: 140, analysts: 9),
  BeuiPriceTarget(key: 'Mean', price: 120, analysts: 34),
  BeuiPriceTarget(key: 'Low', price: 80, analysts: 7),
];

void main() {
  for (final dark in [false, true]) {
    testWidgets('review controlled tooltip owns visibility in dark=$dark', (
      tester,
    ) async {
      late StateSetter update;
      var open = false;
      await tester.pumpWidget(
        beuiTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return BeuiChartTooltip(
                open: open,
                content: const Text('Owned readout'),
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Chart trigger'),
                ),
              );
            },
          ),
          dark: dark,
          reduce: true,
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Chart trigger')));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('Chart trigger'), findsOneWidget);
      expect(find.text('Owned readout'), findsNothing);
      update(() => open = true);
      await tester.pumpAndSettle();
      expect(find.text('Owned readout'), findsOneWidget);
      await mouse.moveTo(Offset.zero);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Owned readout'), findsOneWidget);
      update(() => open = false);
      await tester.pumpAndSettle();
      expect(find.text('Owned readout'), findsNothing);
      await mouse.removePointer();
    });
  }

  testWidgets(
    'review status dismiss reenter drag cancel and keyboard ownership',
    (tester) async {
      final changes = <String?>[];
      await tester.pumpWidget(
        beuiTestApp(
          BeuiStatusBar(data: _periods, onActiveChange: changes.add),
          width: 480,
          reduce: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('Monday detail'), findsOneWidget);
      final plot = tester.getRect(find.byType(BeuiStatusBarPlot));
      final a = plot.topLeft + const Offset(80, 22);
      final b = plot.topLeft + const Offset(240, 22);
      final c = plot.topLeft + const Offset(400, 22);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(b);
      await tester.pumpAndSettle();
      expect(find.text('Tuesday detail'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await mouse.moveTo(b + const Offset(1, 0));
      await tester.pumpAndSettle();
      expect(find.text('Tuesday detail'), findsNothing);
      await mouse.moveTo(Offset.zero);
      await mouse.moveTo(b);
      await tester.pumpAndSettle();
      expect(find.text('Tuesday detail'), findsOneWidget);
      await mouse.down(b);
      await tester.pump();
      await mouse.moveTo(c);
      await tester.pumpAndSettle();
      expect(find.text('Wednesday detail'), findsOneWidget);
      await mouse.cancel();
      await tester.pumpAndSettle();
      expect(find.text('Wednesday detail'), findsNothing);
      await mouse.moveTo(a);
      await tester.pumpAndSettle();
      expect(find.text('Monday detail'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(find.text('Wednesday detail'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(find.text('Wednesday detail'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(find.text('Monday detail'), findsOneWidget);
      expect(changes, ['a', 'b', 'c', 'a', 'c', 'a']);
      await mouse.removePointer();
    },
  );

  testWidgets('review status mouse click does not acquire focus-visible ring', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiStatusBar(data: _periods),
        width: 480,
        reduce: true,
      ),
    );
    await tester.pumpAndSettle();
    final plot = tester.getRect(find.byType(BeuiStatusBarPlot));
    final b = plot.topLeft + const Offset(240, 22);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(b);
    await mouse.down(b);
    await mouse.up();
    await tester.pumpAndSettle();
    expect(find.text('Tuesday detail'), findsOneWidget);
    expect(find.byKey(const ValueKey('status-focus-outline')), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Wednesday detail'), findsOneWidget);
    expect(find.byKey(const ValueKey('status-focus-outline')), findsOneWidget);
    await mouse.removePointer();
  });

  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
    testWidgets(
      'review fan ${key.keyLabel} toggles focused target off then on',
      (tester) async {
        final changes = <BeuiPriceTargetFanActive?>[];
        await tester.pumpWidget(
          beuiTestApp(
            BeuiPriceTargetFan(
              current: 100,
              targets: _targets,
              onActiveChange: changes.add,
            ),
            reduce: true,
          ),
        );
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(find.text('High target'), findsNWidgets(2));
        expect(find.text('Analysts'), findsOneWidget);
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        expect(changes.last, isNull);
        expect(find.text('High target'), findsNothing);
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        expect(changes.last, const BeuiPriceTargetFanActive.target('High'));
        expect(find.text('High target'), findsNWidgets(2));
      },
    );
  }

  testWidgets('review fan second touch toggles the target off', (tester) async {
    final changes = <BeuiPriceTargetFanActive?>[];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiPriceTargetFan(
          current: 100,
          targets: _targets,
          onActiveChange: changes.add,
        ),
        reduce: true,
      ),
    );
    await tester.pumpAndSettle();
    final high = find.byKey(const ValueKey('price-target-target-High'));
    await tester.tap(high);
    await tester.pumpAndSettle();
    expect(changes.last, const BeuiPriceTargetFanActive.target('High'));
    await tester.tap(high);
    await tester.pumpAndSettle();
    expect(changes.last, isNull);
    expect(find.text('Analysts'), findsNothing);
  });

  testWidgets(
    'review fan nearest projection clears the overlap and now zones',
    (tester) async {
      BeuiPriceTargetFanActive? active;
      await tester.pumpWidget(
        beuiTestApp(
          BeuiPriceTargetFan(
            current: 100,
            targets: _targets,
            history: const [
              BeuiPriceHistoryPoint(date: '2026-10-01', price: 90),
              BeuiPriceHistoryPoint(date: '2026-10-03', price: 95),
            ],
            onActiveChange: (value) => active = value,
          ),
          reduce: true,
        ),
      );
      await tester.pumpAndSettle();
      final origin = tester.getTopLeft(find.byType(BeuiPriceTargetSvg));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      for (final (point, expected) in [
        (const Offset(350, 80), const BeuiPriceTargetFanActive.target('High')),
        (const Offset(350, 115), const BeuiPriceTargetFanActive.target('Mean')),
        (const Offset(350, 190), const BeuiPriceTargetFanActive.target('Low')),
        (const Offset(293, 190), null),
        (const Offset(294, 190), const BeuiPriceTargetFanActive.target('Low')),
        (const Offset(246.56, 190), null),
        (
          const Offset(240, 30),
          const BeuiPriceTargetFanActive.history('2026-10-03'),
        ),
        (const Offset(241, 30), null),
      ]) {
        await mouse.moveTo(origin + point);
        await tester.pumpAndSettle();
        expect(active, expected, reason: 'pointer at $point');
      }
      await mouse.removePointer();
    },
  );

  testWidgets('review status removed identity does not revive on reinsertion', (
    tester,
  ) async {
    Widget chart(List<BeuiStatusBarDatum> data) => beuiTestApp(
      BeuiStatusBar(data: data, defaultActiveId: 'b'),
      width: 480,
      reduce: true,
    );
    await tester.pumpWidget(chart(_periods));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.text('Tuesday detail'), findsOneWidget);
    await tester.pumpWidget(chart([_periods.first, _periods.last]));
    await tester.pumpAndSettle();
    expect(find.text('Tuesday detail'), findsNothing);
    await tester.pumpWidget(chart(_periods));
    await tester.pumpAndSettle();
    expect(find.text('Tuesday detail'), findsNothing);
  });

  testWidgets('review donut digits reverse from the displayed value', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    late StateSetter update;
    var active = 'large';
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeuiDonutChart(
              segments: const [
                BeuiDonutSegment(id: 'small', label: 'Small', value: 10),
                BeuiDonutSegment(id: 'large', label: 'Large', value: 30),
              ],
              activeId: active,
              child: const BeuiDonutCenter(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byType(BeuiDigitSwap)).label,
      contains('30'),
    );
    update(() => active = 'small');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    final one = find.descendant(
      of: find.byType(BeuiDigitSwap),
      matching: find.text('1'),
    );
    final clip = find.ancestor(of: one, matching: find.byType(ClipRect)).first;
    expect(tester.getCenter(one).dy, lessThan(tester.getCenter(clip).dy));
    update(() => active = 'large');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    final three = find
        .descendant(of: find.byType(BeuiDigitSwap), matching: find.text('3'))
        .last;
    final threeClip = find
        .ancestor(of: three, matching: find.byType(ClipRect))
        .first;
    expect(
      tester.getCenter(three).dy,
      greaterThan(tester.getCenter(threeClip).dy),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byType(BeuiDigitSwap)).label,
      contains('30'),
    );
    expect(find.text('Large · 75.0%'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('review controlled donut keeps the destination focus readout', (
    tester,
  ) async {
    final changes = <String?>[];
    String? active = 'first';
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) => BeuiDonutChart(
            segments: const [
              BeuiDonutSegment(id: 'first', label: 'First', value: 10),
              BeuiDonutSegment(id: 'second', label: 'Second', value: 20),
              BeuiDonutSegment(id: 'third', label: 'Third', value: 30),
            ],
            activeId: active,
            onActiveChange: (id) {
              changes.add(id);
              setState(() => active = id);
            },
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [BeuiDonutCenter(), BeuiDonutLegend()],
            ),
          ),
        ),
        reduce: true,
        width: 480,
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.text('First · 16.7%'), findsOneWidget);
    for (final (key, caption, id) in [
      (LogicalKeyboardKey.arrowDown, 'Second · 33.3%', 'second'),
      (LogicalKeyboardKey.arrowUp, 'First · 16.7%', 'first'),
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect(active, id, reason: changes.toString());
      expect(find.text(caption), findsOneWidget);
    }
  });
}
