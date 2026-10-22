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
      await tester.drag(find.text('One'), const Offset(320, 0));
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
