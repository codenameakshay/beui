import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _stages = [
  BeuiFunnelStage(id: 'visit', label: 'Visitors', value: 24000),
  BeuiFunnelStage(id: 'signup', label: 'Signed up', value: 15600),
  BeuiFunnelStage(id: 'paid', label: 'Subscribed', value: 4320),
];

void main() {
  testWidgets('renders ordered stages and overall conversion summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiFunnelChart(stages: _stages)),
    );
    expect(find.text('Visitors'), findsOneWidget);
    expect(find.text('Signed up'), findsOneWidget);
    expect(find.text('Subscribed'), findsOneWidget);
    expect(find.text('18.0%'), findsOneWidget);
  });

  testWidgets(
    'stage controls are keyboard-focusable and expose useful semantics',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiFunnelChart(
            stages: _stages,
            unit: 'visits',
            label: 'Signup funnel',
          ),
        ),
      );
      final semantics = tester.ensureSemantics();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Signup funnel',
        ),
        findsOneWidget,
      );
      final stageSemantics = tester.getSemantics(
        find.byKey(const ValueKey('funnel-stage-visit-semantics')),
      );
      expect(
        stageSemantics.label,
        startsWith('Visitors: 24,000 visits, 100.0%'),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.binding.focusManager.primaryFocus, isNotNull);
      semantics.dispose();
    },
  );

  testWidgets('hovering a stage reveals its animated value and unit', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiFunnelChart(stages: _stages, unit: 'visits')),
    );
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.text('Visitors')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.byType(BeuiChartTicker), findsOneWidget);
    expect(
      tester
          .widget<BeuiChartTicker>(find.byType(BeuiChartTicker))
          .format(24000),
      '24,000 visits',
    );
    await gesture.removePointer();
  });

  testWidgets(
    'horizontal funnel and reduced motion render the same conversion',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiFunnelChart(
            stages: _stages,
            direction: BeuiFunnelDirection.horizontal,
          ),
          reduce: true,
        ),
      );
      expect(find.text('18.0%'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    },
  );

  testWidgets('resting funnel matches its golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(640, 420));
    await tester.pumpWidget(
      beuiTestApp(const BeuiFunnelChart(stages: _stages)),
    );
    await tester.pump();
    await expectLater(
      find.byType(BeuiFunnelChart),
      matchesGoldenFile('goldens/beui_funnel_chart.png'),
    );
    await tester.binding.setSurfaceSize(null);
  });
}
