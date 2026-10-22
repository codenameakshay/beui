import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beui/beui.dart';
import '../support.dart';

void main() {
  final entries = [
    const BeuiMorphingSearchItem(
      id: 'folder',
      title: 'Project Folder',
      description: 'Files and previews',
      keywords: ['overlay'],
    ),
    const BeuiMorphingSearchItem(
      id: 'motion',
      title: 'Motion components',
      keywords: ['animation'],
    ),
  ];

  testWidgets('closed rest state matches golden', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: BeuiMorphingSearch(items: entries),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiMorphingSearch),
      matchesGoldenFile('goldens/beui_morphing_search.png'),
    );
  });

  testWidgets('single-key shortcut opens the results', (tester) async {
    await tester.pumpWidget(beuiTestApp(BeuiMorphingSearch(items: entries)));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Project Folder'), findsOneWidget);
  });

  testWidgets('filters by title, description, and keywords', (tester) async {
    await tester.pumpWidget(beuiTestApp(BeuiMorphingSearch(items: entries)));
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'overlay');
    await tester.pump();
    expect(find.text('Project Folder'), findsOneWidget);
    expect(find.text('Motion components'), findsNothing);
  });

  testWidgets('Escape closes the modal search surface', (tester) async {
    await tester.pumpWidget(beuiTestApp(BeuiMorphingSearch(items: entries)));
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Project Folder'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Project Folder'), findsNothing);
  });

  testWidgets('Enter selects the active result and Escape dismisses', (
    tester,
  ) async {
    final selected = <String>[];
    final items = [
      BeuiMorphingSearchItem(
        id: 'one',
        title: 'One',
        onSelect: () => selected.add('one'),
      ),
      BeuiMorphingSearchItem(
        id: 'two',
        title: 'Two',
        onSelect: () => selected.add('two'),
      ),
    ];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiMorphingSearch(
          items: items,
          onSelect: (_) => selected.add('callback'),
        ),
      ),
    );
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected, ['two', 'callback']);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Two'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  });

  testWidgets('icon-only trigger opens and reduced motion stays usable', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        BeuiMorphingSearch(items: entries, iconOnly: true),
        reduce: true,
      ),
    );
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    expect(find.text('Project Folder'), findsOneWidget);
  });
}
