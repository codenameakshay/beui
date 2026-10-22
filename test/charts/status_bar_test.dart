import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  testWidgets('renders status segments, labels, and count legend', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiStatusBar(data: _data, statuses: _statuses)),
    );
    expect(find.text('Aug 21'), findsOneWidget);
    expect(find.text('Aug 23'), findsOneWidget);
    expect(find.text('Operational'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiStatusBar(
          data: _data,
          statuses: _statuses,
          child: Column(children: [BeuiStatusBarLegend(showCounts: true)]),
        ),
      ),
    );
    expect(find.text('2'), findsOneWidget);
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
    await tester.tap(find.byType(Slider));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changed, 'b');
    expect(tester.getSemantics(find.byType(BeuiStatusBarPlot)), isNotNull);
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
    await tester.tap(find.byType(Slider));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changed, 'b');
    expect(find.text('Aug 21 · Operational'), findsOneWidget);
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
            widget.properties.label?.startsWith('Aug 22, Degraded') == true,
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
