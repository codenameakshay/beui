import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beui/beui.dart';
import '../support.dart';

void main() {
  Finder searchBar() => find
      .ancestor(
        of: find.byType(TextField),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container && widget.constraints?.minHeight == 56,
        ),
      )
      .first;

  Finder panel() => find
      .ancestor(of: find.text('Recent'), matching: find.byType(ClipRRect))
      .first;

  testWidgets('panel tracks the expanding centered bar without covering it', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiMorphingSearchChips(defaultRecents: ['first'])),
    );
    expect(tester.getSize(searchBar()).width, 400);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      expect(
        tester.getRect(panel()).bottom,
        lessThanOrEqualTo(tester.getRect(searchBar()).top - 8),
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    final barRect = tester.getRect(searchBar());
    final panelRect = tester.getRect(panel());
    expect(barRect.width, closeTo(560, .1));
    expect(panelRect.left, closeTo(barRect.left, .1));
    expect(panelRect.bottom, lessThanOrEqualTo(barRect.top - 8));
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'typed');
    await tester.pumpAndSettle();
    expect(find.text('typed'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('panel tracks ancestor scrolling while remaining above the bar', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      beuiTestApp(
        SizedBox(
          height: 500,
          child: SingleChildScrollView(
            controller: scroll,
            child: const Column(
              children: [
                SizedBox(height: 300),
                BeuiMorphingSearchChips(
                  defaultOpen: true,
                  defaultRecents: ['first'],
                ),
                SizedBox(height: 600),
              ],
            ),
          ),
        ),
        reduce: true,
      ),
    );
    await tester.pumpAndSettle();
    final before = tester.getRect(panel());
    scroll.jumpTo(40);
    await tester.pumpAndSettle();
    final after = tester.getRect(panel());
    final barRect = tester.getRect(searchBar());
    expect(after.top, closeTo(before.top - 40, .1));
    expect(after.left, closeTo(barRect.left, .1));
    expect(after.bottom, closeTo(barRect.top - 8, .1));
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
  });

  testWidgets('Escape clears the query before closing the panel once', (
    tester,
  ) async {
    final changes = <bool>[];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiMorphingSearchChips(
          defaultQuery: 'typed',
          defaultRecents: const ['first'],
          onOpenChange: changes.add,
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(find.text('Recent'), findsOneWidget);
    expect(changes, [true]);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Recent'), findsNothing);
    expect(changes, [true, false]);
  });

  testWidgets('Escape on an empty query closes exactly once', (tester) async {
    final changes = <bool>[];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiMorphingSearchChips(
          defaultRecents: const ['first'],
          onOpenChange: changes.add,
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('Recent'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Recent'), findsNothing);
    expect(changes, [true, false]);
  });

  for (final viaTab in [true, false]) {
    testWidgets('${viaTab ? 'Tab' : 'requestFocus'} opens recent terms', (
      tester,
    ) async {
      final before = FocusNode();
      addTearDown(before.dispose);
      await tester.pumpWidget(
        beuiTestApp(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                focusNode: before,
                onPressed: () {},
                child: const Text('Before'),
              ),
              const BeuiMorphingSearchChips(defaultRecents: ['first']),
            ],
          ),
        ),
      );
      expect(find.text('Recent'), findsNothing);
      if (viaTab) {
        before.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      } else {
        tester
            .widget<TextField>(find.byType(TextField))
            .focusNode!
            .requestFocus();
      }
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('first'), findsOneWidget);
    });
  }

  testWidgets('external chip removal resets the marked Backspace target', (
    tester,
  ) async {
    var chips = <String>['first', 'second'];
    late StateSetter update;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeuiMorphingSearchChips(
              chips: chips,
              onChipsChange: (value) => update(() => chips = value),
            );
          },
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    update(() => chips = ['first']);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(Chip), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(chips, isEmpty);
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('controlled query updates retain and clamp the caret', (
    tester,
  ) async {
    var query = 'abcdef';
    late StateSetter update;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeuiMorphingSearchChips(query: query);
          },
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'abcdef',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    await tester.pump();
    update(() => query = 'abc');
    await tester.pump();
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    expect(controller.text, 'abc');
    expect(controller.selection, const TextSelection.collapsed(offset: 2));
    update(() => query = 'a');
    await tester.pump();
    expect(controller.selection, const TextSelection.collapsed(offset: 1));
  });

  testWidgets('ArrowDown opening a closed panel selects the first recent', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiMorphingSearchChips(defaultRecents: ['first', 'second']),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(tester.widget<Chip>(find.byType(Chip)).label, isA<Text>());
    expect(
      find.descendant(of: find.byType(Chip), matching: find.text('first')),
      findsOneWidget,
    );
  });

  testWidgets('reopening resets the active recent row', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiMorphingSearchChips(defaultRecents: ['first', 'second']),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, 'second')).selected,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(Chip), matching: find.text('first')),
      findsOneWidget,
    );
  });

  testWidgets('empty and loading content can retry then select a recent', (
    tester,
  ) async {
    var loading = false;
    var recents = <String>[];
    late StateSetter update;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeuiMorphingSearchChips(
              loading: loading,
              recents: recents,
              emptyState: TextButton(
                onPressed: () => update(() => loading = true),
                child: const Text('Retry'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Retry').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Searching…'), findsOneWidget);
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    update(() {
      loading = false;
      recents = ['recovered'];
    });
    await tester.pumpAndSettle();
    expect(find.text('Searching…'), findsNothing);
    expect(find.text('Retry'), findsNothing);
    await tester.tap(find.text('recovered'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(Chip), matching: find.text('recovered')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('controlled reopening resets the active recent row', (
    tester,
  ) async {
    var open = true;
    late StateSetter update;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeuiMorphingSearchChips(
              open: open,
              defaultRecents: const ['first', 'second'],
            );
          },
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, 'second')).selected,
      isTrue,
    );
    update(() => open = false);
    await tester.pumpAndSettle();
    expect(find.text('Recent'), findsNothing);
    update(() => open = true);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(Chip), matching: find.text('first')),
      findsOneWidget,
    );
  });

  testWidgets(
    'overlay Escape dismissal still works when the field loses focus',
    (tester) async {
      final elsewhere = FocusNode();
      addTearDown(elsewhere.dispose);
      final changes = <bool>[];
      await tester.pumpWidget(
        beuiTestApp(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                focusNode: elsewhere,
                onPressed: () {},
                child: const Text('Elsewhere'),
              ),
              BeuiMorphingSearchChips(
                defaultRecents: const ['first'],
                onOpenChange: changes.add,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      elsewhere.requestFocus();
      await tester.pumpAndSettle();
      expect(find.text('Recent'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Recent'), findsNothing);
      expect(changes, [true, false]);
    },
  );

  testWidgets('closed rest state matches golden', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiMorphingSearchChips(
          defaultChips: ['onboarding'],
          placeholder: 'Search inspiration',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('onboarding'), findsOneWidget);
    expect(find.text('Search inspiration'), findsOneWidget);
    expect(find.text('Recent'), findsNothing);
    await expectLater(
      find.byType(BeuiMorphingSearchChips),
      matchesGoldenFile('goldens/beui_morphing_search_chips.png'),
    );
  });

  testWidgets('focus opens recents and Clear removes them', (tester) async {
    final changes = <List<String>>[];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiMorphingSearchChips(
          defaultRecents: const ['dashboards', 'pricing pages'],
          onRecentsChange: changes.add,
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('dashboards'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('dashboards'), findsNothing);
    expect(changes, [<String>[]]);
  });

  testWidgets('Enter adds a query chip and Backspace removes it in two steps', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiMorphingSearchChips(defaultRecents: ['dashboards']),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'pricing');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('pricing'), findsWidgets);
    await tester.enterText(find.byType(TextField), '');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('docked field stays hittable while recents are open', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiMorphingSearchChips(
          defaultChips: ['existing'],
          defaultRecents: ['dashboards'],
          maxChips: 2,
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('Recent'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'da');
    await tester.pumpAndSettle();
    expect(find.text('dashboards'), findsWidgets);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('suggestion panel stays in a short viewport and can scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final suggestions = List<String>.generate(8, (index) => 'result $index');
    await tester.pumpWidget(
      beuiTestApp(
        BeuiMorphingSearchChips(
          defaultOpen: true,
          defaultQuery: 'result',
          suggestions: suggestions,
          maxSuggestions: 8,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final header = tester.getRect(find.text('Suggestions'));
    expect(header.top, greaterThanOrEqualTo(0));
    expect(header.bottom, lessThanOrEqualTo(300));

    final lastResult = find.text('result 7');
    await tester.ensureVisible(lastResult);
    await tester.pumpAndSettle();
    expect(tester.getRect(lastResult).bottom, lessThanOrEqualTo(300));
    await tester.tap(lastResult);
    await tester.pump();
    expect(find.text('result 7'), findsWidgets);
  });

  testWidgets('keyboard navigation scrolls the last suggestion into view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final changes = <List<String>>[];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiMorphingSearchChips(
          defaultOpen: true,
          defaultQuery: 'result',
          suggestions: List.generate(8, (index) => 'result$index'),
          maxSuggestions: 8,
          onChipsChange: changes.add,
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    for (var index = 0; index < 8; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    final last = find.widgetWithText(ListTile, 'result7');
    expect(tester.widget<ListTile>(last).selected, isTrue);
    expect(last.hitTestable(), findsOneWidget);
    expect(tester.getRect(last).top, greaterThanOrEqualTo(0));
    expect(tester.getRect(last).bottom, lessThanOrEqualTo(300));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(changes, [
      <String>['result7'],
    ]);
    expect(
      find.descendant(of: find.byType(Chip), matching: find.text('result7')),
      findsOneWidget,
    );
  });

  for (final reset in ['typed query', 'controlled query', 'reopening']) {
    testWidgets('$reset returns the active suggestion into view', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var query = 'result';
      var open = true;
      late StateSetter update;
      final changes = <List<String>>[];
      await tester.pumpWidget(
        beuiTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return BeuiMorphingSearchChips(
                open: open,
                query: reset == 'controlled query' ? query : null,
                defaultQuery: 'result',
                suggestions: List.generate(8, (index) => 'result$index'),
                maxSuggestions: 8,
                onChipsChange: changes.add,
              );
            },
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      for (var index = 0; index < 8; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      }
      // Start at the bottom even before keyboard-driven scrolling is fixed.
      await tester.ensureVisible(find.text('result7'));
      await tester.pumpAndSettle();
      expect(find.text('result7').hitTestable(), findsOneWidget);
      if (reset == 'typed query') {
        await tester.enterText(find.byType(TextField), 'res');
      } else if (reset == 'controlled query') {
        update(() => query = 'res');
      } else {
        update(() => open = false);
        await tester.pump(const Duration(milliseconds: 16));
        update(() => open = true);
      }
      await tester.pumpAndSettle();
      final expected = reset == 'reopening' ? 'result' : 'res';
      final first = find.widgetWithText(ListTile, expected);
      expect(tester.widget<ListTile>(first).selected, isTrue);
      expect(first.hitTestable(), findsOneWidget);
      expect(tester.getRect(first).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(first).bottom, lessThanOrEqualTo(300));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(changes, [
        <String>[expected],
      ]);
    });
  }

  testWidgets('shows matching suggestions and honors maxChips', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiMorphingSearchChips(
          defaultChips: ['existing'],
          maxChips: 1,
          suggestions: ['dark mode', 'dashboards'],
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'dark');
    await tester.pumpAndSettle();
    expect(find.text('dark mode'), findsOneWidget);
    final title = tester.widget<Text>(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.textSpan is TextSpan &&
                (widget.textSpan! as TextSpan).children != null,
          )
          .first,
    );
    final spans = (title.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(
      spans.any(
        (span) =>
            span.text == 'dark' && span.style?.fontWeight == FontWeight.w700,
      ),
      isTrue,
    );
    await tester.tap(find.text('dark mode'));
    await tester.pump();
    expect(find.byType(Chip), findsOneWidget);
  });

  testWidgets('recent terms persist in process by storageKey', (tester) async {
    const key = 'morph-search-test-recent-store';
    await tester.pumpWidget(
      beuiTestApp(const BeuiMorphingSearchChips(storageKey: key)),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'shared term');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pumpWidget(beuiTestApp(const SizedBox.shrink()));
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiMorphingSearchChips(storageKey: key, defaultOpen: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('shared term'), findsOneWidget);
  });

  testWidgets('reduced motion preserves add and remove interactions', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiMorphingSearchChips(defaultRecents: ['empty states']),
        reduce: true,
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('empty states'), findsOneWidget);
    await tester.tap(find.text('empty states'));
    await tester.pump();
    expect(find.byType(Chip), findsOneWidget);
  });
}
