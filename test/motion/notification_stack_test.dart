import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduce = false}) {
  Widget body = Align(alignment: Alignment.topCenter, child: child);
  if (reduce) {
    final inner = body;
    body = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: body),
  );
}

const List<BeuiNotificationStackItem> _items = [
  BeuiNotificationStackItem(
    id: 'a',
    title: 'Deploy finished',
    description: 'Build 4821 shipped to prod',
    trailing: Text('2m'),
  ),
  BeuiNotificationStackItem(
    id: 'b',
    title: 'New comment',
    description: 'Alex replied to your pull request',
  ),
  BeuiNotificationStackItem(
    id: 'c',
    title: 'Weekly summary',
    description: 'Your activity report is ready',
  ),
];

void main() {
  group('BeuiNotificationStack', () {
    testWidgets('renders items and the collapsed footer label', (tester) async {
      await tester.pumpWidget(
        _wrap(const BeuiNotificationStack(items: _items)),
      );
      await tester.pumpAndSettle();

      // Primary title is rendered (once in the surface, once in the hidden
      // measuring column).
      expect(find.text('Deploy finished'), findsAtLeastNWidgets(1));
      // Footer starts on the collapsed label with the item count badge.
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('View all'), findsNothing);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('tapping expands and rolls the footer label', (tester) async {
      await tester.pumpWidget(
        _wrap(const BeuiNotificationStack(items: _items)),
      );
      await tester.pumpAndSettle();
      final collapsed = tester.getSize(find.byType(BeuiNotificationStack));

      await tester.tap(find.byType(BeuiNotificationStack));
      await tester.pumpAndSettle();

      expect(find.text('View all'), findsOneWidget);
      expect(find.text('Notifications'), findsNothing);
      final expanded = tester.getSize(find.byType(BeuiNotificationStack));
      expect(
        expanded.height,
        greaterThan(collapsed.height),
        reason: 'the fanned list is taller than the collapsed stack',
      );
    });

    testWidgets('Escape collapses an expanded stack', (tester) async {
      await tester.pumpWidget(
        _wrap(const BeuiNotificationStack(items: _items)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BeuiNotificationStack));
      await tester.pumpAndSettle();
      expect(find.text('View all'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('View all'), findsNothing);
    });

    testWidgets('fires onViewAll when tapped while already expanded', (
      tester,
    ) async {
      var viewAll = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiNotificationStack(
            items: _items,
            defaultExpanded: true,
            onViewAll: () => viewAll++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('View all'), findsOneWidget);

      await tester.tap(find.byType(BeuiNotificationStack));
      await tester.pumpAndSettle();
      expect(viewAll, 1);
      // onViewAll took priority, so it stays expanded.
      expect(find.text('View all'), findsOneWidget);
    });

    testWidgets('controlled expansion reports through onExpandedChange', (
      tester,
    ) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        _wrap(
          BeuiNotificationStack(
            items: _items,
            expanded: false,
            onExpandedChange: changes.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BeuiNotificationStack));
      await tester.pumpAndSettle();

      // Requested expansion, but the controlled value stayed false.
      expect(changes, contains(true));
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('View all'), findsNothing);
    });

    testWidgets('renders the empty resting state', (tester) async {
      await tester.pumpWidget(_wrap(const BeuiNotificationStack(items: [])));
      await tester.pumpAndSettle();

      expect(find.text('All caught up'), findsOneWidget);
      expect(find.byIcon(LucideIcons.bell_off), findsOneWidget);
      expect(find.text('Notifications'), findsNothing);
    });

    testWidgets('reduced motion still expands on tap without blur', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const BeuiNotificationStack(items: _items), reduce: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);

      await tester.tap(find.byType(BeuiNotificationStack));
      await tester.pumpAndSettle();
      expect(find.text('View all'), findsOneWidget);
    });
  });
}
