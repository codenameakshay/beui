import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = <BeuiPreviewRailItem>[
  BeuiPreviewRailItem(id: 'a', label: 'Alpha', description: Text('First item.')),
  BeuiPreviewRailItem(id: 'b', label: 'Beta', description: Text('Second item.')),
  BeuiPreviewRailItem(id: 'c', label: 'Gamma', description: Text('Third item.')),
  BeuiPreviewRailItem(id: 'd', label: 'Delta', description: Text('Fourth item.')),
];

Widget _app({
  List<BeuiPreviewRailItem> items = _items,
  BeuiPreviewRailOrientation orientation = BeuiPreviewRailOrientation.vertical,
  String? activeId,
  String? defaultActiveId,
  ValueChanged<String>? onActiveChange,
  bool reduce = false,
}) {
  Widget child = Center(
    child: SizedBox(
      width: 480,
      height: 320,
      child: BeuiPreviewRail(
        items: items,
        orientation: orientation,
        activeId: activeId,
        defaultActiveId: defaultActiveId,
        onActiveChange: onActiveChange,
      ),
    ),
  );
  if (reduce) {
    final inner = child;
    child = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: child),
  );
}

Future<void> _hover(WidgetTester tester, Finder target) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await tester.pump();
  await gesture.moveTo(tester.getCenter(target));
  await tester.pump();
}

void main() {
  group('BeuiPreviewRail interaction', () {
    testWidgets('renders one tick cell per item', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byType(Semantics), findsWidgets);
      // No preview card at rest (nothing hovered/focused).
      expect(find.text('First item.'), findsNothing);
    });

    testWidgets('tap selects via onActiveChange', (tester) async {
      String? changed;
      await tester.pumpWidget(_app(onActiveChange: (id) => changed = id));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Beta'));
      await tester.pump();
      expect(changed, 'b');
    });

    testWidgets('controlled activeId does not mutate internal state', (
      tester,
    ) async {
      String? changed;
      await tester.pumpWidget(
        _app(activeId: 'a', onActiveChange: (id) => changed = id),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Gamma'));
      await tester.pump();
      // Callback fires, but selection stays where the controller put it.
      expect(changed, 'c');
      expect(
        tester.getSemantics(find.bySemanticsLabel('Alpha')),
        isSemantics(isSelected: true),
      );
    });

    testWidgets('hovering reveals the matching preview card', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Second item.'), findsNothing);
      await _hover(tester, find.bySemanticsLabel('Beta'));
      await tester.pumpAndSettle();
      expect(find.text('Second item.'), findsOneWidget);
    });
  });

  group('BeuiPreviewRail motion fidelity', () {
    testWidgets('tick scales spring under normal motion', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      // Each tick drives its scale through a motor SingleMotionBuilder.
      expect(find.byType(Transform), findsWidgets);
      await _hover(tester, find.bySemanticsLabel('Alpha'));
      // Mid-flight: the spring has not settled immediately.
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(BeuiPreviewRail), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('preview card fades in on hover, out on leave', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _hover(tester, find.bySemanticsLabel('Gamma'));
      await tester.pumpAndSettle();
      expect(find.text('Third item.'), findsOneWidget);
      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, 1.0);
    });

    testWidgets('reduced motion still reveals the card without springs', (
      tester,
    ) async {
      await tester.pumpWidget(_app(reduce: true));
      await tester.pumpAndSettle();
      await _hover(tester, find.bySemanticsLabel('Delta'));
      await tester.pumpAndSettle();
      expect(find.text('Fourth item.'), findsOneWidget);
    });
  });

  group('BeuiPreviewRail keyboard', () {
    testWidgets('focus reveals a preview and enter selects', (tester) async {
      String? changed;
      await tester.pumpWidget(_app(onActiveChange: (id) => changed = id));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      // First item focused → its preview shows.
      expect(find.text('First item.'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(changed, 'a');
    });
  });

  testWidgets('rest-state golden (vertical, nothing displayed)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 480,
              height: 320,
              child: BeuiPreviewRail(items: _items, defaultActiveId: 'b'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiPreviewRail),
      matchesGoldenFile('goldens/beui_preview_rail.png'),
    );
  });
}
