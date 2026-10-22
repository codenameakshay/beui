import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
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
    expect(
      tester.widget<BeuiChartTicker>(find.byType(BeuiChartTicker)).value,
      96,
    );
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
    await tester.pump(const Duration(milliseconds: 220));
    final centerTicker = find.descendant(
      of: find.byType(BeuiDonutCenter),
      matching: find.byType(BeuiChartTicker),
    );
    expect(tester.widget<BeuiChartTicker>(centerTicker).value, 42);
    expect(
      find.descendant(
        of: find.byType(BeuiDonutCenter),
        matching: find.text('Team · 43.8%'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Business'));
    await tester.pump();
    expect(tester.widget<BeuiChartTicker>(centerTicker).value, 31);
    expect(changed, 'business');
    expect(selected, 'business');
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiDonutChart(segments: _segments, activeId: 'enterprise'),
      ),
    );
    await tester.pump();
    expect(tester.widget<BeuiChartTicker>(centerTicker).value, 23);
    expect(
      find.descendant(
        of: find.byType(BeuiDonutCenter),
        matching: find.text('Enterprise · 24.0%'),
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

  testWidgets('hovering legend rows updates the center ticker and caption', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beuiTestApp(const BeuiDonutChart(segments: _segments)),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final team = tester.getCenter(find.text('Team'));
    await mouse.addPointer(location: team);
    await mouse.moveTo(team);
    await tester.pump();
    expect(find.byType(BeuiChartTicker), findsOneWidget);
    final centerTicker = find.descendant(
      of: find.byType(BeuiDonutCenter),
      matching: find.byType(BeuiChartTicker),
    );
    expect(tester.widget<BeuiChartTicker>(centerTicker).value, 42);
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('Team · 43.8%'), findsOneWidget);

    final business = tester.getCenter(find.text('Business'));
    await mouse.moveTo(business);
    await tester.pump();
    expect(tester.widget<BeuiChartTicker>(centerTicker).value, 31);
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('Business · 32.3%'), findsOneWidget);
    await mouse.removePointer();
    semantics.dispose();
  });

  testWidgets('outgoing center caption exits upward without jumping', (
    tester,
  ) async {
    const chartKey = ValueKey('donut');
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiDonutChart(
          key: chartKey,
          segments: _segments,
          activeId: 'team',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 220));
    final outgoingCaption = find.text('Team · 43.8%');
    final originalPosition = tester.getTopLeft(outgoingCaption);

    await tester.pumpWidget(
      beuiTestApp(
        const BeuiDonutChart(
          key: chartKey,
          segments: _segments,
          activeId: 'business',
        ),
      ),
    );
    final startPosition = tester.getTopLeft(outgoingCaption);
    expect(startPosition.dy, closeTo(originalPosition.dy, 1));

    await tester.pump(const Duration(milliseconds: 110));
    final middlePosition = tester.getTopLeft(outgoingCaption);
    expect(middlePosition.dy, lessThan(startPosition.dy));

    await tester.pump(const Duration(milliseconds: 111));
    expect(outgoingCaption, findsNothing);
  });

  testWidgets('reduced motion snaps center ticker to active value', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiDonutChart(segments: _segments, activeId: 'team'),
        reduce: true,
      ),
    );
    await tester.pump();
    final centerTicker = find.descendant(
      of: find.byType(BeuiDonutCenter),
      matching: find.byType(BeuiChartTicker),
    );
    expect(tester.widget<BeuiChartTicker>(centerTicker).value, 42);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('Team · 43.8%'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('reduced motion keeps the ring in its final state', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiDonutChart(segments: _segments), reduce: true),
    );
    await tester.pump();
    expect(
      tester.widget<BeuiChartTicker>(find.byType(BeuiChartTicker)).value,
      96,
    );
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
