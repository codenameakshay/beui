import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beui/src/motion/sortable_list.dart';
import 'package:beui/src/theme/beui_colors.dart';
import 'package:beui/src/theme/beui_text_theme.dart';

const _items = [
  (id: 'alpha', label: 'Collect references'),
  (id: 'beta', label: 'Explore the visual system'),
  (id: 'gamma', label: 'Build the prototype'),
];

Widget _app({
  List<({String id, String label})>? items,
  ValueChanged<List<({String id, String label})>>? onItemsChange,
  bool disabled = false,
  bool reduce = false,
}) {
  final child = BeuiSortableList<({String id, String label})>(
    getItemId: (item) => item.id,
    getItemLabel: (item) => item.label,
    defaultItems: _items,
    items: items,
    onItemsChange: onItemsChange,
    disabled: disabled,
    children: (current) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BeuiSortableListGroup(
          children: [
            for (final item in current)
              BeuiSortableListItem(
                id: item.id,
                child: Row(
                  children: [
                    const BeuiSortableListHandle(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: BeuiSortableListItemContent(
                        child: Text(item.label),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const BeuiSortableListUndo(),
      ],
    ),
  );
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(
      body: Center(
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: SizedBox(width: 420, child: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('keyboard moves item and announces its new position', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    List<({String id, String label})>? changed;
    await tester.pumpWidget(_app(onItemsChange: (value) => changed = value));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(changed?.map((item) => item.id), ['beta', 'alpha', 'gamma']);
    expect(
      find.bySemanticsLabel('Collect references moved to position 2 of 3.'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('undo restores the prior order', (tester) async {
    await tester.pumpWidget(_app());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo reorder'));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Collect references')).dy,
      lessThan(tester.getTopLeft(find.text('Explore the visual system')).dy),
    );
  });

  testWidgets('pointer drag reorders from the explicit handle', (tester) async {
    List<({String id, String label})>? changed;
    await tester.pumpWidget(_app(onItemsChange: (value) => changed = value));
    await tester.drag(
      find.byTooltip('Reorder Collect references'),
      const Offset(0, 250),
    );
    await tester.pumpAndSettle();

    expect(changed?.map((item) => item.id), ['beta', 'gamma', 'alpha']);
  });

  testWidgets('controlled list reports order without mutating its input', (
    tester,
  ) async {
    List<({String id, String label})>? changed;
    await tester.pumpWidget(
      _app(items: _items, onItemsChange: (value) => changed = value),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();

    expect(changed?.map((item) => item.id), ['beta', 'gamma', 'alpha']);
    expect(_items.map((item) => item.id), ['alpha', 'beta', 'gamma']);
  });

  testWidgets('disabled handles cannot move items', (tester) async {
    List<({String id, String label})>? changed;
    await tester.pumpWidget(
      _app(disabled: true, onItemsChange: (value) => changed = value),
    );
    await tester.tap(
      find.byTooltip('Reorder Collect references'),
      warnIfMissed: false,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(changed, isNull);
    expect(find.byTooltip('Reorder Collect references'), findsOneWidget);
  });

  testWidgets('reduced motion removes the drag lift scale', (tester) async {
    await tester.pumpWidget(_app(reduce: true));
    final handle = find.byTooltip('Reorder Collect references');
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(0, 90));
    await tester.pump(const Duration(milliseconds: 80));
    final scaled = find.byWidgetPredicate(
      (widget) =>
          widget is Transform && widget.transform.getMaxScaleOnAxis() > 1.01,
    );
    expect(scaled, findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiSortableList<({String id, String label})>),
      matchesGoldenFile('goldens/beui_sortable_list.png'),
    );
  });
}
