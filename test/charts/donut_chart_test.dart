import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

const _segments = [
  BeuiDonutSegment(id: 'team', label: 'Team', value: 42, color: '#2563eb'),
  BeuiDonutSegment(
    id: 'business',
    label: 'Business',
    value: 31,
    color: '#38bdf8',
  ),
  BeuiDonutSegment(
    id: 'enterprise',
    label: 'Enterprise',
    value: 23,
    color: '#0d9488',
  ),
];

void main() {
  testWidgets('renders ring, center total and legend', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiDonutChart(segments: _segments, label: 'Revenue by plan'),
      ),
    );
    await tester.pump();
    expect(find.byType(BeuiDonutPlot), findsOneWidget);
    expect(find.byType(BeuiDonutLegend), findsOneWidget);
    expect(find.text('96'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Revenue by plan',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('supports controlled and uncontrolled active ids and selection', (
    tester,
  ) async {
    String? changed;
    String? selected;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiDonutChart(
          segments: _segments,
          defaultActiveId: 'team',
          onActiveChange: (id) => changed = id,
          onSelect: (id) => selected = id,
        ),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(BeuiDonutCenter),
        matching: find.text('Team'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Business'));
    await tester.pump();
    expect(changed, 'business');
    expect(selected, 'business');
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiDonutChart(segments: _segments, activeId: 'enterprise'),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(BeuiDonutCenter),
        matching: find.text('Enterprise'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('legend arrows move the active segment', (tester) async {
    String? changed;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiDonutChart(
          segments: _segments,
          onActiveChange: (id) => changed = id,
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changed, 'team');
  });

  testWidgets('reduced motion keeps the ring in its final state', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiDonutChart(segments: _segments), reduce: true),
    );
    await tester.pump();
    expect(find.text('96'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(640, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      beuiTestApp(
        const RepaintBoundary(
          child: BeuiDonutChart(segments: _segments, label: 'Donut chart'),
        ),
        width: 640,
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(BeuiDonutChart),
      matchesGoldenFile('goldens/beui_donut-chart.png'),
    );
  });
}
