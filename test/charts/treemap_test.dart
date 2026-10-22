import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _nodes = [
  BeuiTreemapNode.group(
    id: 'tech',
    label: 'Technology',
    color: '#3454b5',
    children: [
      BeuiTreemapNode.leaf(id: 'aapl', label: 'AAPL', value: 210000),
      BeuiTreemapNode.leaf(id: 'msft', label: 'MSFT', value: 190000),
    ],
  ),
  BeuiTreemapNode.leaf(
    id: 'energy',
    label: 'Energy',
    value: 80000,
    color: '#a35318',
  ),
];

String _formatValueForTest(double value) => '\$${(value / 1000).round()}K';

Widget _app({
  String? activeId,
  String? defaultActiveId,
  ValueChanged<String?>? onActiveChange,
  bool reduce = false,
}) {
  return beuiTestApp(
    SizedBox(
      width: 480,
      child: BeuiTreemap(
        data: _nodes,
        label: 'Portfolio allocation',
        activeId: activeId,
        defaultActiveId: defaultActiveId,
        onActiveChange: onActiveChange,
      ),
    ),
    reduce: reduce,
    width: 520,
  );
}

void main() {
  group('BeuiTreemap', () {
    testWidgets('renders leaf labels and the group legend', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      expect(find.text('AAPL'), findsOneWidget);
      expect(find.text('MSFT'), findsOneWidget);
      expect(find.text('Energy'), findsWidgets);
      expect(find.text('Technology'), findsOneWidget);
    });

    testWidgets('large tiles show formatted values at rest', (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const SizedBox(
            width: 480,
            child: BeuiTreemap(data: _nodes, formatValue: _formatValueForTest),
          ),
          width: 520,
        ),
      );
      await tester.pump();
      expect(find.text(r'$210K'), findsOneWidget);
      expect(find.text(r'$190K'), findsOneWidget);
      expect(find.text(r'$80K'), findsOneWidget);
    });

    testWidgets('uncontrolled defaultActiveId seeds the active tile', (
      tester,
    ) async {
      String? active = 'sentinel';
      await tester.pumpWidget(
        _app(defaultActiveId: 'aapl', onActiveChange: (id) => active = id),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(active, isNull);
    });

    testWidgets('controlled activeId reports changes', (tester) async {
      String? active;
      await tester.pumpWidget(
        _app(activeId: null, onActiveChange: (id) => active = id),
      );
      await tester.pump();
      await tester.tap(find.text('AAPL'));
      await tester.pump();
      expect(active, 'aapl');
    });

    testWidgets('hovering AAPL shows its animated formatted value and share', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      String? activeId;
      await tester.pumpWidget(
        beuiTestApp(
          StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 480,
              child: BeuiTreemap(
                data: _nodes,
                formatValue: _formatValueForTest,
                activeId: activeId,
                onActiveChange: (id) => setState(() => activeId = id),
              ),
            ),
          ),
          width: 520,
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      final aapl = tester.getCenter(find.text('AAPL'));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(aapl);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(activeId, 'aapl');
      final tooltip = tester
          .widgetList<BeuiChartTooltip>(find.byType(BeuiChartTooltip))
          .singleWhere(
            (tooltip) =>
                (tooltip.content as BeuiChartTooltipCard).title == 'AAPL',
          );
      final tickers = (tooltip.content as BeuiChartTooltipCard).details!
          .whereType<BeuiChartTicker>();
      expect(tickers.map((ticker) => ticker.format(ticker.value)), [
        r'$210K',
        '43.8%',
      ]);
      await mouse.removePointer();
      semantics.dispose();
    });

    testWidgets('arrow keys move to a neighbouring tile', (tester) async {
      String? active;
      await tester.pumpWidget(
        _app(defaultActiveId: 'aapl', onActiveChange: (id) => active = id),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(active, isNotNull);
      expect(active, isNot('aapl'));
    });

    testWidgets('reduced motion still paints tiles', (tester) async {
      await tester.pumpWidget(_app(reduce: true));
      await tester.pump();
      expect(find.text('AAPL'), findsOneWidget);
      expect(find.byType(BeuiTreemapPlot), findsOneWidget);
    });

    testWidgets('exposes an accessible name', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      await tester.pump();
      expect(find.bySemanticsLabel('Portfolio allocation'), findsWidgets);
      handle.dispose();
    });

    testWidgets('rest-state golden', (tester) async {
      await tester.binding.setSurfaceSize(const Size(640, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        beuiTestApp(
          const SizedBox(
            width: 560,
            child: BeuiTreemap(data: _nodes, label: 'Portfolio allocation'),
          ),
          width: 600,
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(BeuiTreemap),
        matchesGoldenFile('goldens/beui_treemap.png'),
      );
    });
  });
}
