import 'package:beui/beui.dart';
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
}) => beuiTestApp(
  SizedBox(
    width: 640,
    height: 420,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BeuiBumpChart(
          series: _series,
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

  testWidgets('Home and Escape inspect and clear series from focused dot', (
    tester,
  ) async {
    String? changed;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_surface(onActive: (id) => changed = id));
    await tester.tap(find.bySemanticsLabel('Canvas, Jun, rank 2'));
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
