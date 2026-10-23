import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _statuses = [
  BeuiStatusBarStatus(
    id: 'operational',
    label: 'Operational',
    color: '#059669',
  ),
  BeuiStatusBarStatus(id: 'degraded', label: 'Degraded', color: '#d97706'),
];
const _data = [
  BeuiStatusBarDatum(
    id: 'a',
    label: 'Aug 21',
    status: 'operational',
    description: 'All checks passed.',
  ),
  BeuiStatusBarDatum(
    id: 'b',
    label: 'Aug 22',
    status: 'degraded',
    duration: Duration(minutes: 12),
  ),
  BeuiStatusBarDatum(id: 'c', label: 'Aug 23', status: 'operational'),
];

void main() {
  testWidgets('Tab opens the first range period and Escape retains its value', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiStatusBar(data: _data, statuses: _statuses)),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.text('All checks passed.'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('All checks passed.'), findsNothing);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Status history: inspect period'))
          .value,
      'Aug 21. Operational. All checks passed.',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(find.text('Aug 22'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('All checks passed.'), findsOneWidget);
  });

  testWidgets(
    'pointer exit then native keyboard reopens without generic fallback',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(const BeuiStatusBar(data: _data, statuses: _statuses)),
      );
      await tester.pumpAndSettle();
      final plot = tester.getRect(find.byType(BeuiStatusBarPlot));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(Offset(plot.center.dx, plot.top + 22));
      await tester.pumpAndSettle();
      expect(find.text('Aug 22'), findsOneWidget);
      await mouse.moveTo(Offset(plot.right + 20, plot.top));
      await tester.pumpAndSettle();
      expect(find.text('Aug 22'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('Aug 22'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Aug 22'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Aug 23'), findsNWidgets(2));
      await mouse.removePointer();
    },
  );

  testWidgets(
    'focused range survives exit and same-period hover respects dismissal',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(const BeuiStatusBar(data: _data, statuses: _statuses)),
      );
      await tester.pumpAndSettle();
      final plot = tester.getRect(find.byType(BeuiStatusBarPlot));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      final b = Offset(plot.center.dx, plot.top + 22);
      await mouse.moveTo(b);
      await mouse.down(b);
      await mouse.up();
      await tester.pumpAndSettle();
      await mouse.moveTo(Offset(plot.right + 20, plot.top));
      await tester.pumpAndSettle();
      expect(find.text('Aug 22'), findsOneWidget);
      await mouse.moveTo(b);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await mouse.moveTo(b + const Offset(1, 0));
      await tester.pumpAndSettle();
      expect(find.text('Aug 22'), findsNothing);
      await mouse.moveTo(Offset(plot.left + plot.width / 6, plot.top + 22));
      await tester.pumpAndSettle();
      expect(find.text('All checks passed.'), findsOneWidget);
      await mouse.removePointer();
    },
  );

  testWidgets('source active ring lies outside bars with four pixel gaps', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiStatusBar(data: _data, statuses: _statuses)),
    );
    await tester.pumpAndSettle();
    Finder fill(String id) => find.descendant(
      of: find.byKey(ValueKey(id)),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            (widget.decoration as BoxDecoration).color != null,
      ),
    );
    final first = tester.getRect(fill('a'));
    final second = tester.getRect(fill('b'));
    expect(second.left - first.right, 4);
    final ring = find.descendant(
      of: find.byKey(const ValueKey('a')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            (widget.decoration as BoxDecoration).border != null,
      ),
    );
    final bounds = tester.getRect(ring);
    expect(bounds.left, first.left - 3);
    expect(bounds.top, closeTo(first.top - 3, .001));
    expect(bounds.height, closeTo(38, .001));
  });

  testWidgets('renders status segments, labels, and count legend', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiStatusBar(data: _data, statuses: _statuses)),
    );
    expect(find.text('Aug 21'), findsOneWidget);
    expect(find.text('Aug 23'), findsOneWidget);
    expect(find.text('Operational'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Status history: inspect period'),
      findsOneWidget,
    );
    expect(find.byType(Slider), findsNothing);
    expect(
      tester.getSize(find.byType(BeuiStatusBarPlot)).height,
      lessThan(80),
      reason: 'source range input is opacity-0 over the 44px bar',
    );
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiStatusBar(
          data: _data,
          statuses: _statuses,
          child: Column(children: [BeuiStatusBarLegend(showCounts: true)]),
        ),
      ),
    );
    expect(find.text('(2)'), findsOneWidget);
  });

  testWidgets('uncontrolled selection responds to keyboard and calls back', (
    tester,
  ) async {
    String? changed;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiStatusBar(
          data: _data,
          statuses: _statuses,
          defaultActiveId: 'a',
          onActiveChange: (id) => changed = id,
        ),
      ),
    );
    final plot = tester.getRect(find.byType(BeuiStatusBarPlot));
    await tester.tapAt(Offset(plot.left + plot.width / 6, plot.center.dy));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changed, 'b');
    expect(tester.getSemantics(find.byType(BeuiStatusBarPlot)), isNotNull);
  });

  testWidgets('keyboard navigation advances from the tapped first period', (
    tester,
  ) async {
    final changed = <String>[];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiStatusBar(
          data: _data,
          statuses: _statuses,
          defaultActiveId: 'a',
          onActiveChange: (id) {
            if (id != null) changed.add(id);
          },
        ),
      ),
    );

    final plot = tester.getRect(find.byType(BeuiStatusBarPlot));
    await tester.tapAt(Offset(plot.left + plot.width / 6, plot.center.dy));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changed, ['b']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changed, ['b', 'c']);
  });

  testWidgets('tapping the periods takes keyboard focus from another control', (
    tester,
  ) async {
    final changed = <String>[];
    final otherFocus = FocusNode();
    addTearDown(otherFocus.dispose);
    await tester.pumpWidget(
      beuiTestApp(
        Column(
          children: [
            TextField(focusNode: otherFocus),
            BeuiStatusBar(
              data: _data,
              statuses: _statuses,
              defaultActiveId: 'a',
              onActiveChange: (id) {
                if (id != null) changed.add(id);
              },
            ),
          ],
        ),
      ),
    );
    otherFocus.requestFocus();
    await tester.pump();
    expect(otherFocus.hasFocus, isTrue);

    final plot = tester.getRect(find.byType(BeuiStatusBarPlot));
    await tester.tapAt(Offset(plot.left + plot.width / 6, plot.center.dy));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changed, ['b']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changed, ['b', 'c']);
  });

  testWidgets('Tab enters the status periods keyboard controls', (
    tester,
  ) async {
    final changed = <String>[];
    final otherFocus = FocusNode();
    addTearDown(otherFocus.dispose);
    await tester.pumpWidget(
      beuiTestApp(
        Column(
          children: [
            TextField(focusNode: otherFocus),
            BeuiStatusBar(
              data: _data,
              statuses: _statuses,
              defaultActiveId: 'a',
              onActiveChange: (id) {
                if (id != null) changed.add(id);
              },
            ),
          ],
        ),
      ),
    );
    otherFocus.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(changed, ['b']);
  });

  testWidgets('hovering a period shows its static status tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiStatusBar(data: _data, statuses: _statuses)),
    );
    final plot = tester.getRect(find.byType(BeuiStatusBarPlot));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final position = Offset(plot.left + plot.width * .5, plot.top + 22);
    await mouse.addPointer(location: position);
    await mouse.moveTo(position);
    await tester.pumpAndSettle();

    expect(find.text('Aug 22'), findsWidgets);
    expect(find.text('Degraded'), findsWidgets);
    expect(find.text('Duration: 12 minutes'), findsNothing);
    expect(find.byType(BeuiNumberTicker), findsNothing);
    await mouse.removePointer();
  });

  testWidgets('leaving the status periods clears the hover tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiStatusBar(data: _data, statuses: _statuses)),
    );
    final plot = tester.getRect(find.byType(BeuiStatusBarPlot));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(Offset(plot.left + plot.width * .1, plot.top + 22));
    await tester.pumpAndSettle();
    expect(find.text('Aug 21'), findsWidgets);

    await mouse.moveTo(Offset(plot.left + plot.width * .5, plot.top + 22));
    await tester.pumpAndSettle();
    expect(find.text('Aug 22'), findsWidgets);
    expect(find.text('Aug 22'), findsOneWidget);

    await mouse.moveTo(Offset(plot.right + 20, plot.bottom + 20));
    await tester.pumpAndSettle();

    expect(find.text('Aug 22'), findsNothing);
    await mouse.removePointer();
  });

  testWidgets('leaving status periods hides tooltip but retains selection', (
    tester,
  ) async {
    final changes = <String?>[];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiStatusBar(
          data: _data,
          statuses: _statuses,
          defaultActiveId: 'a',
          onActiveChange: changes.add,
        ),
      ),
    );
    final plot = tester.getRect(find.byType(BeuiStatusBarPlot));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(Offset(plot.left + plot.width * .5, plot.top + 22));
    await tester.pumpAndSettle();
    expect(find.text('Aug 22'), findsOneWidget);

    await mouse.moveTo(Offset(plot.right + 20, plot.bottom + 20));
    await tester.pumpAndSettle();

    expect(find.text('Aug 22'), findsNothing);
    expect(changes, ['b']);
    expect(
      tester
          .getSemantics(
            find
                .byWidgetPredicate(
                  (widget) =>
                      widget is Semantics &&
                      widget.properties.label ==
                          'Status history: inspect period',
                )
                .first,
          )
          .value,
      'Aug 22. Degraded',
    );
    await mouse.removePointer();
  });

  testWidgets('transparent status range remains adjustable to semantics', (
    tester,
  ) async {
    final changed = <String?>[];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiStatusBar(
          data: _data,
          statuses: _statuses,
          defaultActiveId: 'a',
          onActiveChange: changed.add,
        ),
      ),
    );
    final semantics = tester.getSemantics(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Status history: inspect period',
      ),
    );

    expect(semantics.value, 'Aug 21. Operational. All checks passed.');
    expect(
      semantics.getSemanticsData().hasAction(SemanticsAction.increase),
      isTrue,
    );
    expect(
      semantics.getSemanticsData().hasAction(SemanticsAction.decrease),
      isTrue,
    );
    semantics.owner!.performAction(semantics.id, SemanticsAction.increase);
    await tester.pump();
    expect(changed, ['b']);
  });

  testWidgets('controlled selection does not move without a parent update', (
    tester,
  ) async {
    String? changed;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiStatusBar(
          data: _data,
          statuses: _statuses,
          activeId: 'a',
          onActiveChange: (id) => changed = id,
        ),
      ),
    );
    final plot = tester.getRect(find.byType(BeuiStatusBarPlot));
    await tester.tapAt(Offset(plot.left + plot.width / 6, plot.center.dy));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changed, 'b');
    expect(find.text('Aug 21'), findsWidgets);
    expect(find.text('Operational'), findsWidgets);
  });

  testWidgets('reduced motion and chart semantics render', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiStatusBar(
          data: _data,
          statuses: _statuses,
          label: 'API status',
        ),
        reduce: true,
      ),
    );
    final semantics = tester.ensureSemantics();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'API status',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'API status: inspect period' &&
            widget.properties.slider == true,
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('resting status history matches its golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(640, 420));
    await tester.pumpWidget(
      beuiTestApp(const BeuiStatusBar(data: _data, statuses: _statuses)),
    );
    await tester.pump();
    expect(
      find.byType(BeuiStatusBar),
      matchesGoldenFile('goldens/beui_status_bar.png'),
    );
    await tester.binding.setSurfaceSize(null);
  });
}
