import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _series = [
  BeuiBumpSeries(id: 'studio', name: 'Studio', ranks: [2, 1, 3]),
  BeuiBumpSeries(id: 'canvas', name: 'Canvas', ranks: [1, null, 2]),
];

Widget _surface({
  String? active,
  String? defaultActive,
  ValueChanged<String?>? onActive,
  bool reduce = false,
  List<BeuiBumpSeries> series = _series,
}) => beuiTestApp(
  SizedBox(
    width: 640,
    height: 420,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BeuiBumpChart(
          series: series,
          periods: const ['Apr', 'May', 'Jun'],
          active: active,
          defaultActive: defaultActive,
          onActiveChange: onActive,
          label: 'Product ranking',
        ),
      ),
    ),
  ),
  reduce: reduce,
);

void main() {
  testWidgets(
    'renders ranks, period labels and missing-period break in accessible plot',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_surface());
      expect(find.text('Apr'), findsOneWidget);
      expect(find.text('Jun'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Canvas, Jun, rank 2')),
        isNotNull,
      );
      expect(find.bySemanticsLabel('Canvas, May, rank'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets('legend updates uncontrolled state and controlled callback', (
    tester,
  ) async {
    String? changed;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_surface(onActive: (id) => changed = id));
    await tester.tap(find.text('Studio').last);
    await tester.pump();
    expect(changed, 'studio');
    expect(find.bySemanticsLabel('Studio'), findsWidgets);
    semantics.dispose();
  });

  testWidgets('hovering a legend series highlights it and dims the others', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_surface());
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.text('Studio').last));
    await tester.pump();
    final studio = tester.widget<BeuiChartLegendItem>(
      find.byWidgetPredicate(
        (widget) => widget is BeuiChartLegendItem && widget.label == 'Studio',
      ),
    );
    final canvas = tester.widget<BeuiChartLegendItem>(
      find.byWidgetPredicate(
        (widget) => widget is BeuiChartLegendItem && widget.label == 'Canvas',
      ),
    );
    expect(studio.selected, isTrue);
    expect(canvas.dimmed, isTrue);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Studio, Apr, rank 2'))
          .flagsCollection
          .isSelected
          .toString(),
      contains('True'),
    );
    await gesture.removePointer();
    semantics.dispose();
  });

  testWidgets('hovering another legend preserves a pinned series selection', (
    tester,
  ) async {
    await tester.pumpWidget(_surface());
    await tester.tap(find.text('Studio').last);
    await tester.pump();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.text('Canvas').last));
    await tester.pump();
    await gesture.moveTo(Offset.zero);
    await tester.pump();

    final studio = tester.widget<BeuiChartLegendItem>(
      find.byWidgetPredicate(
        (widget) => widget is BeuiChartLegendItem && widget.label == 'Studio',
      ),
    );
    expect(studio.selected, isTrue);
    await gesture.removePointer();
  });

  testWidgets('keyboard focus does not replace or clear pinned selection', (
    tester,
  ) async {
    final changes = <String?>[];
    await tester.pumpWidget(_surface(onActive: changes.add));
    await tester.tap(find.text('Studio').last);
    await tester.pump();
    expect(changes, ['studio']);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(changes, ['studio']);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(changes, ['studio', 'canvas']);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(changes, ['studio', 'canvas']);
  });

  testWidgets('removing a hovered series does not restore stale highlight', (
    tester,
  ) async {
    await tester.pumpWidget(_surface());
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.text('Studio').last));
    await tester.pump();
    await tester.pumpWidget(_surface(series: const []));
    await tester.pumpWidget(_surface());

    final studio = tester.widget<BeuiChartLegendItem>(
      find.byWidgetPredicate(
        (widget) => widget is BeuiChartLegendItem && widget.label == 'Studio',
      ),
    );
    expect(studio.selected, isFalse);
    await gesture.removePointer();
  });

  testWidgets(
    'controlled selection follows its owner and reduced-motion golden matches',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_surface(active: 'canvas', reduce: true));
      await tester.pump();
      expect(find.bySemanticsLabel('Canvas'), findsWidgets);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/beui_bump_chart.png'),
      );
      semantics.dispose();
    },
  );

  testWidgets('hovering a rank node reveals an animated rank ticker', (
    tester,
  ) async {
    await tester.pumpWidget(_surface());
    final node = find.byKey(const ValueKey('bump-node-studio-0'));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(node));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.byType(BeuiChartTicker), findsWidgets);
    final ticker = tester.widget<BeuiChartTicker>(
      find.byType(BeuiChartTicker).first,
    );
    expect(ticker.value, 2);
    expect(ticker.format(ticker.value), '#2');
  });

  testWidgets('Home and Escape inspect and clear series from focused dot', (
    tester,
  ) async {
    String? changed;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_surface(onActive: (id) => changed = id));
    await tester.tap(find.byKey(const ValueKey('bump-node-canvas-2')));
    await tester.pump();
    expect(changed, 'canvas');
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(changed, 'studio');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(changed, isNull);
    semantics.dispose();
  });
}
