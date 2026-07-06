import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduce = false}) {
  Widget body = Padding(padding: const EdgeInsets.all(16), child: child);
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

List<BeuiSwipeableListItem> _items({List<String>? log}) => [
  BeuiSwipeableListItem(
    id: 'a',
    title: 'Design review',
    description: 'Figma file updated',
    meta: '2m',
    rightActions: [
      BeuiSwipeAction(
        id: 'archive',
        label: 'Archive',
        icon: LucideIcons.archive,
        onPressed: (item) => log?.add('archive:${item.id}'),
      ),
      BeuiSwipeAction(
        id: 'delete',
        label: 'Delete',
        icon: LucideIcons.trash_2,
        tone: BeuiSwipeActionTone.danger,
        onPressed: (item) => log?.add('delete:${item.id}'),
      ),
    ],
    leftActions: [
      BeuiSwipeAction(
        id: 'pin',
        label: 'Pin',
        icon: LucideIcons.pin,
        onPressed: (item) => log?.add('pin:${item.id}'),
      ),
    ],
  ),
  BeuiSwipeableListItem(
    id: 'b',
    title: 'Deploy finished',
    rightActions: [
      BeuiSwipeAction(id: 'clear', label: 'Clear', icon: LucideIcons.x),
    ],
  ),
];

double _surfaceDx(WidgetTester tester, String title) {
  // The row surface is translated horizontally; read the accumulated
  // transform on the title's ancestors.
  final transforms = tester.widgetList<Transform>(
    find.ancestor(of: find.text(title), matching: find.byType(Transform)),
  );
  return transforms
      .map((t) => t.transform.getTranslation().x)
      .fold<double>(0, (a, b) => a.abs() > b.abs() ? a : b);
}

void main() {
  group('BeuiSwipeableList', () {
    testWidgets('renders row content', (tester) async {
      await tester.pumpWidget(_wrap(BeuiSwipeableList(items: _items())));
      await tester.pumpAndSettle();
      expect(find.text('Design review'), findsOneWidget);
      expect(find.text('Figma file updated'), findsOneWidget);
      expect(find.text('2m'), findsOneWidget);
    });

    testWidgets('swiping left past the threshold reveals right actions', (
      tester,
    ) async {
      final values = <BeuiSwipeableListValue?>[];
      await tester.pumpWidget(
        _wrap(BeuiSwipeableList(items: _items(), onValueChange: values.add)),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.text('Design review'), const Offset(-90, 0));
      await tester.pumpAndSettle();
      expect(values.last?.id, 'a');
      expect(values.last?.side, BeuiSwipeSide.right);
      // Two right actions x 56 = 112 reveal distance.
      expect(
        _surfaceDx(tester, 'Design review'),
        moreOrLessEquals(-112, epsilon: 2),
      );
    });

    testWidgets('a short swipe springs back closed', (tester) async {
      final values = <BeuiSwipeableListValue?>[];
      await tester.pumpWidget(
        _wrap(BeuiSwipeableList(items: _items(), onValueChange: values.add)),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.text('Design review'), const Offset(-20, 0));
      await tester.pumpAndSettle();
      expect(values.last, isNull);
      expect(
        _surfaceDx(tester, 'Design review'),
        moreOrLessEquals(0, epsilon: 1),
      );
    });

    testWidgets('swiping right reveals the left action', (tester) async {
      final values = <BeuiSwipeableListValue?>[];
      await tester.pumpWidget(
        _wrap(BeuiSwipeableList(items: _items(), onValueChange: values.add)),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.text('Design review'), const Offset(90, 0));
      await tester.pumpAndSettle();
      expect(values.last?.side, BeuiSwipeSide.left);
      expect(
        _surfaceDx(tester, 'Design review'),
        moreOrLessEquals(56, epsilon: 2),
      );
    });

    testWidgets('tapping a revealed action fires and closes', (tester) async {
      final log = <String>[];
      final actions = <String>[];
      await tester.pumpWidget(
        _wrap(
          BeuiSwipeableList(
            items: _items(log: log),
            onAction: (item, action, side) =>
                actions.add('${action.id}@${side.name}'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.text('Design review'), const Offset(-130, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.trash_2));
      await tester.pumpAndSettle();
      expect(log, ['delete:a']);
      expect(actions, ['delete@right']);
      // closeOnAction (default) folds the row back.
      expect(
        _surfaceDx(tester, 'Design review'),
        moreOrLessEquals(0, epsilon: 1),
      );
    });

    testWidgets('opening another row closes the first', (tester) async {
      final values = <BeuiSwipeableListValue?>[];
      await tester.pumpWidget(
        _wrap(BeuiSwipeableList(items: _items(), onValueChange: values.add)),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.text('Design review'), const Offset(-130, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Deploy finished'), const Offset(-90, 0));
      await tester.pumpAndSettle();
      expect(values.last?.id, 'b');
      expect(
        _surfaceDx(tester, 'Design review'),
        moreOrLessEquals(0, epsilon: 1),
      );
      expect(
        _surfaceDx(tester, 'Deploy finished'),
        moreOrLessEquals(-56, epsilon: 2),
      );
    });

    testWidgets('controlled value opens the row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiSwipeableList(
            items: _items(),
            value: const BeuiSwipeableListValue(
              id: 'a',
              side: BeuiSwipeSide.right,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        _surfaceDx(tester, 'Design review'),
        moreOrLessEquals(-112, epsilon: 2),
      );
    });

    testWidgets('disabled rows cannot be swiped', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiSwipeableList(
            items: [
              BeuiSwipeableListItem(
                id: 'x',
                title: 'Locked row',
                disabled: true,
                rightActions: [
                  BeuiSwipeAction(id: 'a', label: 'A', icon: LucideIcons.x),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.text('Locked row'), const Offset(-90, 0));
      await tester.pumpAndSettle();
      expect(_surfaceDx(tester, 'Locked row'), moreOrLessEquals(0, epsilon: 1));
    });

    testWidgets('reduced motion snaps open instantly on release', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(BeuiSwipeableList(items: _items()), reduce: true),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.drag(find.text('Design review'), const Offset(-90, 0));
      await tester.pump(); // one frame, no spring settle needed
      expect(
        _surfaceDx(tester, 'Design review'),
        moreOrLessEquals(-112, epsilon: 2),
      );
    });
  });
}
