import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

List<BeuiExpandableTabsItem> get _items => const [
  BeuiExpandableTabsItem(
    id: 'home',
    label: 'Home',
    icon: LucideIcons.house,
    content: SizedBox(
      width: 240,
      height: 120,
      child: Center(child: Text('Home panel')),
    ),
  ),
  BeuiExpandableTabsItem(
    id: 'search',
    label: 'Search',
    icon: LucideIcons.search,
    content: SizedBox(
      width: 220,
      height: 90,
      child: Center(child: Text('Search panel')),
    ),
  ),
  BeuiExpandableTabsItem(
    id: 'bell',
    label: 'Alerts',
    icon: LucideIcons.bell,
    content: SizedBox(
      width: 200,
      height: 100,
      child: Center(child: Text('Alerts panel')),
    ),
  ),
];

void main() {
  group('BeuiExpandableTabs', () {
    testWidgets('closed bar shows icons only at the bar height', (
      tester,
    ) async {
      await tester.pumpWidget(beuiTestApp(BeuiExpandableTabs(items: _items)));
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.house), findsOneWidget);
      expect(find.byIcon(LucideIcons.search), findsOneWidget);
      expect(find.text('Home panel'), findsNothing);
      final size = tester.getSize(find.byType(BeuiExpandableTabs));
      expect(size.height, moreOrLessEquals(54, epsilon: 2)); // 52 + border
    });

    testWidgets('tapping a tab opens its panel and expands the shell', (
      tester,
    ) async {
      await tester.pumpWidget(beuiTestApp(BeuiExpandableTabs(items: _items)));
      await tester.pumpAndSettle();
      final closed = tester.getSize(find.byType(BeuiExpandableTabs));

      await tester.tap(find.byIcon(LucideIcons.house));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Home panel'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget); // label unfurled
      final open = tester.getSize(find.byType(BeuiExpandableTabs));
      expect(open.height, greaterThan(closed.height + 60));
    });

    testWidgets('tapping the active tab again closes', (tester) async {
      await tester.pumpWidget(beuiTestApp(BeuiExpandableTabs(items: _items)));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.house));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.house));
      await tester.pumpAndSettle();
      expect(find.text('Home panel'), findsNothing);
      final size = tester.getSize(find.byType(BeuiExpandableTabs));
      expect(size.height, moreOrLessEquals(54, epsilon: 2));
    });

    testWidgets('switching tabs swaps panels', (tester) async {
      await tester.pumpWidget(beuiTestApp(BeuiExpandableTabs(items: _items)));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.house));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.search));
      await tester.pumpAndSettle();
      expect(find.text('Search panel'), findsOneWidget);
      expect(find.text('Home panel'), findsNothing);
    });

    testWidgets('tapping outside closes the open panel', (tester) async {
      await tester.pumpWidget(beuiTestApp(BeuiExpandableTabs(items: _items)));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.house));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Home panel'), findsNothing);
    });

    testWidgets('Escape closes the open panel', (tester) async {
      await tester.pumpWidget(beuiTestApp(BeuiExpandableTabs(items: _items)));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.house));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Home panel'), findsNothing);
    });

    testWidgets('controlled value reports through onValueChange', (
      tester,
    ) async {
      final changes = <String?>[];
      await tester.pumpWidget(
        beuiTestApp(
          BeuiExpandableTabs(
            items: _items,
            value: 'search',
            onValueChange: changes.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Search panel'), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.search), warnIfMissed: false);
      await tester.pump();
      expect(changes, [null]); // active tab re-tapped → wants to close
      expect(find.text('Search panel'), findsOneWidget, reason: 'controlled');
    });

    testWidgets('reduced motion opens without blur', (tester) async {
      await tester.pumpWidget(
        beuiTestApp(BeuiExpandableTabs(items: _items), reduce: true),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byIcon(LucideIcons.house), warnIfMissed: false);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(maxBlurSigma(tester), lessThan(0.5));
      }
      expect(find.text('Home panel'), findsOneWidget);
    });
  });
}
