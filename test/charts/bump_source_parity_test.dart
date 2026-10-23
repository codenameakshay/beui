import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

const rows = [
  BeuiBumpSeries(id: 'studio', name: 'Studio', ranks: [4, 3, 1]),
  BeuiBumpSeries(id: 'canvas', name: 'Canvas', ranks: [1, null, 2]),
  BeuiBumpSeries(id: 'layers', name: 'Layers', ranks: [3, 2, 3]),
  BeuiBumpSeries(id: 'orbit', name: 'Orbit', ranks: [2, 4, 4]),
  BeuiBumpSeries(id: 'frame', name: 'Frame', ranks: [5, 5, 5]),
];
Widget surface({
  List<BeuiBumpSeries> series = rows,
  ValueChanged<String?>? onActive,
  String? defaultActive,
  Widget? child,
  bool reduce = true,
}) => beuiTestApp(
  SizedBox(
    width: 592,
    child: BeuiBumpChart(
      periods: const ['Apr', 'May', 'Jun'],
      series: series,
      defaultActive: defaultActive,
      onActiveChange: onActive,
      child: child,
    ),
  ),
  reduce: reduce,
);
Finder legend(String id) => find.byKey(ValueKey('bump-legend-$id'));
Finder dot(String id, int period) =>
    find.byKey(ValueKey('bump-node-$id-$period'));
bool pinned(WidgetTester tester, String id) =>
    tester.widget<Semantics>(legend(id)).properties.toggled!;

void main() {
  testWidgets(
    'source legend has rank change grid geometry and viewport breakpoint',
    (tester) async {
      await tester.pumpWidget(surface());
      final studio = tester.getRect(legend('studio'));
      final canvas = tester.getRect(legend('canvas'));
      final orbit = tester.getRect(legend('orbit'));
      expect(studio.size, const Size(184, 36));
      expect(canvas.left - studio.right, 20);
      expect(orbit.top - studio.bottom, 4);
      expect(find.text('↑3'), findsOneWidget);
      expect(find.text('↓1'), findsOneWidget);
      expect(find.text('↓2'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
      expect(
        studio.top - tester.getBottomLeft(find.byType(BeuiBumpPlot)).dy,
        20,
      );
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(surface());
      expect(
        tester.getRect(legend('layers')).top -
            tester.getRect(legend('studio')).bottom,
        4,
      );
      expect(
        tester.getRect(legend('canvas')).top,
        tester.getRect(legend('studio')).top,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'native Tab is plot then row-major rank dots, not geometric rank order',
    (tester) async {
      final changes = <String?>[];
      await tester.pumpWidget(surface(onActive: changes.add));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('No previous rank'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('No previous rank'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('Previously #4 in Apr'), findsOneWidget);
      for (final key in [
        LogicalKeyboardKey.home,
        LogicalKeyboardKey.end,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowRight,
      ]) {
        await tester.sendKeyEvent(key);
        await tester.pump();
      }
      expect(changes, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(changes, ['studio']);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(changes, ['studio']);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(changes, ['studio', null]);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(changes, ['studio', null, null]);
      expect(find.text('Previously #4 in Apr'), findsNothing);
    },
  );
  testWidgets(
    'legend click acquires native focus and Tab changes focus without pinning',
    (tester) async {
      final changes = <String?>[];
      await tester.pumpWidget(surface(onActive: changes.add));
      await tester.tap(legend('studio'));
      await tester.pumpAndSettle();
      expect(pinned(tester, 'studio'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(changes, ['studio']);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(changes, ['studio', 'canvas']);
      expect(pinned(tester, 'canvas'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(pinned(tester, 'canvas'), isFalse);
    },
  );
  testWidgets(
    'removed uncontrolled pinned identity does not revive after reinsertion',
    (tester) async {
      await tester.pumpWidget(surface(defaultActive: 'studio'));
      expect(pinned(tester, 'studio'), isTrue);
      await tester.pumpWidget(
        surface(series: rows.sublist(1), defaultActive: 'studio'),
      );
      await tester.pumpWidget(surface(defaultActive: 'studio'));
      expect(pinned(tester, 'studio'), isFalse);
    },
  );
  testWidgets(
    'empty and all-missing source models render empty plot with surviving legend',
    (tester) async {
      await tester.pumpWidget(surface(series: const []));
      expect(find.text('No rankings yet'), findsOneWidget);
      expect(tester.getSize(find.byType(BeuiBumpPlot)).height, 148);
      await tester.pumpWidget(
        surface(
          series: const [BeuiBumpSeries(id: 'x', name: 'Missing', ranks: [])],
        ),
      );
      expect(find.text('No rankings yet'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
      expect(dot('x', 0), findsNothing);
    },
  );
  testWidgets(
    'touch toggles rank readout, mouse click dismisses and keyboard reopens at destination',
    (tester) async {
      await tester.pumpWidget(surface());
      await tester.tap(dot('studio', 0));
      await tester.pumpAndSettle();
      expect(find.text('No previous rank'), findsOneWidget);
      await tester.tap(dot('studio', 0));
      await tester.pumpAndSettle();
      expect(find.text('No previous rank'), findsNothing);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(dot('studio', 0)));
      await tester.pump(const Duration(milliseconds: 61));
      await tester.pumpAndSettle();
      expect(find.text('No previous rank'), findsOneWidget);
      await mouse.down(tester.getCenter(dot('studio', 0)));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.text('No previous rank'), findsNothing);
      await mouse.moveTo(Offset.zero);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('Previously #4 in Apr'), findsOneWidget);
    },
  );
}
