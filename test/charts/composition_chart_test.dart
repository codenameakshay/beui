import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _periods = ['Jan', 'Feb', 'Mar'];
const _series = [
  BeuiCompositionSeries(
    id: 'a',
    name: 'Organic',
    color: '#2563eb',
    values: [60, 40, null],
  ),
  BeuiCompositionSeries(
    id: 'b',
    name: 'Direct',
    color: '#0d9488',
    values: [40, 60, 10],
  ),
];

void main() {
  testWidgets('renders stacked chart and series legend', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiCompositionChart(series: _series, periods: _periods),
      ),
    );
    expect(find.text('Jan'), findsOneWidget);
    expect(find.text('Organic'), findsOneWidget);
    expect(find.text('Direct'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('period range responds to keyboard and reports selected period', (
    tester,
  ) async {
    String? changed;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiCompositionChart(
          series: _series,
          periods: _periods,
          defaultPeriod: 'Jan',
          onPeriodChange: (period) => changed = period,
        ),
      ),
    );
    await tester.tap(find.byType(Slider));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changed, 'Feb');
    expect(tester.widget<Slider>(find.byType(Slider)).value, 1);
  });

  testWidgets('controlled period remains fixed and legend exposes pin state', (
    tester,
  ) async {
    String? changed;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiCompositionChart(
          series: _series,
          periods: _periods,
          period: 'Jan',
          onPeriodChange: (period) => changed = period,
        ),
      ),
    );
    await tester.tap(find.byType(Slider));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changed, 'Feb');
    expect(find.text('Organic: 60 (60.0%)'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
    await tester.tap(find.text('Organic'));
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.toggled == true,
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'area view preserves missing periods as a gap and reduced motion renders',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiCompositionChart(
            series: _series,
            periods: _periods,
            view: BeuiCompositionView.area,
            defaultPeriod: 'Mar',
          ),
          reduce: true,
        ),
      );
      expect(find.text('Mar · No data'), findsOneWidget);
      expect(find.text('No composition data'), findsNothing);
    },
  );

  testWidgets('resting composition chart matches its golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(640, 420));
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiCompositionChart(series: _series, periods: _periods),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(BeuiCompositionChart),
      matchesGoldenFile('goldens/beui_composition_chart.png'),
    );
    await tester.binding.setSurfaceSize(null);
  });
}
