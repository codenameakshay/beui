import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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

  testWidgets('shortcut leaves another editable focused but opens externally', (
    tester,
  ) async {
    final otherFocus = FocusNode();
    final otherText = TextEditingController();
    addTearDown(otherFocus.dispose);
    addTearDown(otherText.dispose);
    await tester.pumpWidget(
      beuiTestApp(
        Column(
          children: [
            TextField(focusNode: otherFocus, controller: otherText),
            BeuiMorphingSearch(items: entries),
          ],
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(find.text('Project Folder'), findsNothing);
    expect(otherFocus.hasFocus, isTrue);
    await tester.enterText(find.byType(TextField), 'f');
    expect(otherText.text, 'f');

    otherFocus.unfocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(find.text('Project Folder'), findsOneWidget);
  });

  for (final controlled in [false, true]) {
    testWidgets('focused Escape closes once controlled=$controlled', (
      tester,
    ) async {
      var open = false;
      final changes = <bool>[];
      final queries = <String>[];
      await tester.pumpWidget(
        beuiTestApp(
          StatefulBuilder(
            builder: (context, setState) => BeuiMorphingSearch(
              items: entries,
              open: controlled ? open : null,
              onOpenChange: (value) {
                changes.add(value);
                if (controlled) setState(() => open = value);
              },
              onQueryChange: queries.add,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'folder');
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(changes, [true, false]);
      expect(queries, ['', 'folder', '']);
      expect(find.text('Project Folder'), findsNothing);

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(find.text('Motion components'), findsOneWidget);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '',
      );
    });
  }

  testWidgets(
    'arrow navigation reveals the last result and Enter selects its ID',
    (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(
        beuiTestApp(
          BeuiMorphingSearch(
            items: [
              for (var i = 0; i < 30; i++)
                BeuiMorphingSearchItem(
                  id: 'result-$i',
                  title: 'Result $i',
                  description: i.isEven ? 'Description $i' : null,
                ),
            ],
            onSelect: (item) => selected.add(item.id),
          ),
        ),
      );
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      final initialOffset = tester.getTopLeft(find.text('Result 0'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Result 0')), initialOffset);
      for (var i = 0; i < 28; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      expect(find.text('Result 29').hitTestable(), findsOneWidget);
      final row = tester.getRect(
        find
            .ancestor(
              of: find.text('Result 29'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      final list = tester.getRect(find.byType(ListView));
      expect(row.bottom, lessThanOrEqualTo(list.bottom));
      expect(row.top, greaterThanOrEqualTo(list.top));
      await tester.enterText(find.byType(TextField), 'Result');
      await tester.pumpAndSettle();
      expect(find.text('Result 0').hitTestable(), findsOneWidget);
      for (var i = 0; i < 29; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      }
      await tester.pumpAndSettle();
      expect(find.text('Result 29').hitTestable(), findsOneWidget);
      for (var i = 0; i < 29; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      }
      await tester.pumpAndSettle();
      expect(find.text('Result 0').hitTestable(), findsOneWidget);
      for (var i = 0; i < 29; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      }
      await tester.pumpAndSettle();
      expect(find.text('Result 29').hitTestable(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, ['result-29']);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(find.text('Result 0').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('bottom-right panel stays inside the viewport and accepts taps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final selected = <String>[];
    await tester.pumpWidget(
      beuiTestApp(
        Padding(
          padding: const EdgeInsets.all(16),
          child: BeuiMorphingSearch(
            items: entries,
            iconOnly: true,
            onSelect: (item) => selected.add(item.id),
          ),
        ),
        alignment: Alignment.bottomRight,
      ),
    );
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    final panel = tester.getRect(
      find.byKey(const ValueKey('beui-morphing-search-panel')),
    );
    expect(panel.left, greaterThanOrEqualTo(16));
    expect(panel.top, greaterThanOrEqualTo(16));
    expect(panel.right, lessThanOrEqualTo(384));
    expect(panel.bottom, lessThanOrEqualTo(284));
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'folder');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Project Folder'));
    await tester.pumpAndSettle();
    expect(selected, ['folder']);
  });

  testWidgets(
    'reduced motion reaches final panel size on the first open frame',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          BeuiMorphingSearch(items: entries, iconOnly: true),
          reduce: true,
        ),
      );
      await tester.tap(find.byType(OutlinedButton));
      await tester.pump();
      await tester.pump();
      final panel = find.byKey(const ValueKey('beui-morphing-search-panel'));
      final firstSize = tester.getSize(panel);
      expect(firstSize, const Size(448, 159));
      expect(find.text('Motion components').hitTestable(), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.getSize(panel), firstSize);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(tester.getSize(panel), const Size(48, 48));
      expect(find.text('Motion components').hitTestable(), findsNothing);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('opening grows the panel and reveals the results list', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(BeuiMorphingSearch(items: entries)));
    final triggerSize = tester.getSize(
      find.byKey(const ValueKey('beui-morphing-search-trigger')),
    );
    await tester.tap(find.text('Search'));
    await tester.pump();
    await tester.pump();
    final panel = find.byKey(const ValueKey('beui-morphing-search-panel'));
    expect(tester.getSize(panel), triggerSize);
    expect(tester.getSize(find.byType(ListView)).width, 448);
    expect(find.text('Project Folder').hitTestable(), findsNothing);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getSize(panel).width, greaterThan(triggerSize.width));
    expect(tester.getSize(panel).width, lessThan(448));
    await tester.pumpAndSettle();

    final panelSize = tester.getSize(
      find.byKey(const ValueKey('beui-morphing-search-panel')),
    );
    expect(panelSize.height, greaterThan(triggerSize.height));
    expect(find.text('Project Folder'), findsOneWidget);
    expect(find.text('Motion components'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty results recover after query retry and item replacement', (
    tester,
  ) async {
    final selected = <String>[];
    var items = entries;
    late StateSetter update;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeuiMorphingSearch(
              items: items,
              onSelect: (item) => selected.add(item.id),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No results found.'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(selected, isEmpty);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('Project Folder').hitTestable(), findsOneWidget);

    update(() => items = []);
    await tester.pumpAndSettle();
    expect(find.text('No results found.'), findsOneWidget);
    update(
      () => items = [
        const BeuiMorphingSearchItem(id: 'replacement', title: 'Replacement'),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Replacement').hitTestable(), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, ['replacement']);
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Replacement'), findsNothing);
    expect(find.byType(OutlinedButton).hitTestable(), findsOneWidget);
  });

  testWidgets('hover updates the result selected by the focused input', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiMorphingSearch(
          items: entries,
          onSelect: (item) => selected.add(item.id),
        ),
      ),
    );
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Motion components')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, ['motion']);
    final trigger = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(trigger.focusNode!.hasFocus, isTrue);
    expect(find.byType(OutlinedButton).hitTestable(), findsOneWidget);
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

  testWidgets('icon-only trigger opens on tap', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(BeuiMorphingSearch(items: entries, iconOnly: true)),
    );
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    expect(find.text('Project Folder'), findsOneWidget);
  });

  testWidgets('reduced motion keeps the icon-only search usable', (
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
