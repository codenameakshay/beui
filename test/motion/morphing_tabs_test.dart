import 'dart:ui' show PointerDeviceKind;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

List<BeuiMorphingTabsItem> _items({bool disabledSearch = false}) => [
  BeuiMorphingTabsItem(
    id: 'one',
    label: 'One',
    icon: LucideIcons.house,
    content: const SizedBox(
      height: 256,
      child: Center(child: Text('One panel')),
    ),
  ),
  BeuiMorphingTabsItem(
    id: 'two',
    label: 'Two',
    icon: LucideIcons.search,
    disabled: disabledSearch,
    content: const SizedBox(
      height: 256,
      child: Center(child: Text('Two panel')),
    ),
  ),
  BeuiMorphingTabsItem(
    id: 'three',
    label: 'Three',
    icon: LucideIcons.archive,
    content: const SizedBox(
      height: 256,
      child: Center(child: Text('Three panel')),
    ),
  ),
];

void main() {
  group('BeuiMorphingTabs', () {
    testWidgets('fits equal width slots before sacrificing the source gap', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          SizedBox(width: 528, child: BeuiMorphingTabs(items: _items())),
        ),
      );
      final tabs = find.descendant(
        of: find.byType(BeuiMorphingTabs),
        matching: find.byType(InkWell),
      );
      expect(tabs, findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        expect(tester.getSize(tabs.at(i)).width, 154);
      }
      expect(
        tester.getTopLeft(tabs.at(1)).dx - tester.getTopLeft(tabs.at(0)).dx,
        170,
      );
    });

    testWidgets('panel content determines the root height', (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          SizedBox(
            width: 528,
            child: BeuiMorphingTabs(
              items: const [
                BeuiMorphingTabsItem(
                  id: 'tall',
                  label: 'Tall',
                  content: SizedBox(height: 420),
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(BeuiMorphingTabs)).height, 500);
    });

    testWidgets('short content does not shrink the shared panel width', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          SizedBox(
            width: 528,
            child: BeuiMorphingTabs(
              items: const [
                BeuiMorphingTabsItem(
                  id: 'short',
                  label: 'Short',
                  content: SizedBox(width: 100, height: 100),
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.getSize(find.bySemanticsLabel('Short panel')).width, 496);
    });

    testWidgets('renders tabs and selects the first item by default', (
      tester,
    ) async {
      await tester.pumpWidget(beuiTestApp(BeuiMorphingTabs(items: _items())));
      await tester.pumpAndSettle();
      expect(find.text('One'), findsOneWidget);
      expect(find.text('One panel'), findsOneWidget);
      expect(find.bySemanticsLabel('Tabs'), findsOneWidget);
    });

    testWidgets('tap selects another tab', (tester) async {
      await tester.pumpWidget(beuiTestApp(BeuiMorphingTabs(items: _items())));
      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(find.text('Two panel'), findsOneWidget);
    });

    testWidgets('arrow keys wrap between enabled tabs', (tester) async {
      await tester.pumpWidget(
        beuiTestApp(BeuiMorphingTabs(items: _items(disabledSearch: true))),
      );
      await tester.tap(find.text('One'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('Three panel'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('One panel'), findsOneWidget);
    });

    testWidgets('Alt+arrow reorders and reports the completed order', (
      tester,
    ) async {
      final orders = <List<String>>[];
      await tester.pumpWidget(
        beuiTestApp(
          BeuiMorphingTabs(items: _items(), onOrderChange: orders.add),
        ),
      );
      await tester.tap(find.text('One'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(orders, [
        <String>['two', 'one', 'three'],
      ]);
    });

    testWidgets('pointer drag reorders and notifies once on release', (
      tester,
    ) async {
      final orders = <List<String>>[];
      await tester.pumpWidget(
        beuiTestApp(
          SizedBox(
            width: 680,
            child: BeuiMorphingTabs(items: _items(), onOrderChange: orders.add),
          ),
        ),
      );
      await tester.drag(find.text('One'), const Offset(140, 0));
      await tester.pumpAndSettle();
      expect(orders, [
        <String>['two', 'one', 'three'],
      ]);
    });

    testWidgets('close button delegates removal to its owner', (tester) async {
      final closed = <String>[];
      await tester.pumpWidget(
        beuiTestApp(BeuiMorphingTabs(items: _items(), onClose: closed.add)),
      );
      await tester.tap(find.byTooltip('Close Two'));
      expect(closed, ['two']);
      expect(find.text('Two'), findsOneWidget);
    });

    testWidgets('controlled value does not change internally', (tester) async {
      final values = <String?>[];
      await tester.pumpWidget(
        beuiTestApp(
          BeuiMorphingTabs(
            items: _items(),
            value: 'two',
            onValueChange: values.add,
          ),
        ),
      );
      expect(find.text('Two panel'), findsOneWidget);
      await tester.tap(find.text('Three'));
      await tester.pumpAndSettle();
      expect(values, ['three']);
      expect(find.text('Two panel'), findsOneWidget);
    });

    testWidgets('disabled item is skipped by keyboard navigation', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(BeuiMorphingTabs(items: _items(disabledSearch: true))),
      );
      await tester.tap(find.text('One'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Three panel'), findsOneWidget);
    });

    testWidgets('reduced motion snaps active shape and fades content', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(BeuiMorphingTabs(items: _items()), reduce: true),
      );
      await tester.tap(find.text('Two'));
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('Two panel'), findsOneWidget);
      expect(maxBlurSigma(tester), lessThan(0.5));
    });

    testWidgets('chrome is charcoal and the selected surface is cream', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          SizedBox(width: 640, child: BeuiMorphingTabs(items: _items())),
          width: 680,
        ),
      );
      await tester.pumpAndSettle();
      final boxes = tester.widgetList<Container>(find.byType(Container));
      expect(
        boxes.any(
          (box) =>
              box.decoration is BoxDecoration &&
              (box.decoration as BoxDecoration).color ==
                  const Color(0xFF292929),
        ),
        isTrue,
      );
      expect(
        boxes.any(
          (box) =>
              box.decoration is BoxDecoration &&
              (box.decoration as BoxDecoration).color ==
                  const Color(0xFFFAFAF8),
        ),
        isTrue,
      );
    });

    testWidgets('selected tab keeps the same slot width as inactive tabs', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          SizedBox(width: 640, child: BeuiMorphingTabs(items: _items())),
          width: 680,
        ),
      );
      await tester.pumpAndSettle();
      final one = tester.getTopLeft(find.text('One'));
      final two = tester.getTopLeft(find.text('Two'));
      final three = tester.getTopLeft(find.text('Three'));
      expect(two.dx - one.dx, 192);
      expect(three.dx - two.dx, 192);
      expect(one.dx, lessThan(160));
      Size tabSize(String label) => tester.getSize(
        find
            .ancestor(of: find.text(label), matching: find.byType(MouseRegion))
            .first,
      );
      expect(tabSize('One').width, tabSize('Two').width);
    });

    testWidgets('shrunk tabs stay inside the rail in a narrow parent', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          SizedBox(width: 170, child: BeuiMorphingTabs(items: _items())),
          width: 210,
        ),
      );
      await tester.pumpAndSettle();

      final rail = tester.getRect(find.byType(BeuiMorphingTabs));
      final tabRects = [
        for (final label in ['One', 'Two', 'Three'])
          tester.getRect(
            find
                .ancestor(
                  of: find.text(label),
                  matching: find.byType(MouseRegion),
                )
                .first,
          ),
      ];
      expect(tabRects.last.right, lessThanOrEqualTo(rail.right - 16));
    });

    testWidgets('inactive tab paints a hover fill', (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          SizedBox(width: 640, child: BeuiMorphingTabs(items: _items())),
          width: 680,
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(find.text('Two')));
      await gesture.moveTo(tester.getCenter(find.text('Two')));
      await tester.pump();
      final fills = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(
        fills.any((box) {
          final decoration = box.decoration;
          return decoration is BoxDecoration &&
              decoration.color == const Color(0x0FFFFFFF);
        }),
        isTrue,
      );
      await gesture.removePointer();
    });

    testWidgets('rest state matches the reference golden', (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          SizedBox(
            width: 640,
            child: BeuiMorphingTabs(items: _items(), defaultValue: 'one'),
          ),
          width: 680,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(BeuiMorphingTabs),
        matchesGoldenFile('goldens/beui_morphing_tabs.png'),
      );
    });
  });
}
