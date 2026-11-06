import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beui/beui.dart';
import '../support.dart';

void main() {
  testWidgets('forced-top short bounds keep the field usable through morph', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiMorphingSearchChips(defaultRecents: ['first']),
        alignment: Alignment.topCenter,
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }
    await tester.enterText(find.byType(TextField), 'near top');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Chip, 'near top'), findsOneWidget);
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
  });

  testWidgets('uncontrolled recents survive remount under a nonempty key', (
    tester,
  ) async {
    const key = 'v31-morph-search-remount';
    await tester.pumpWidget(
      beuiTestApp(const BeuiMorphingSearchChips(storageKey: key)),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'durable term');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('durable term'), findsWidgets);

    await tester.pumpWidget(beuiTestApp(const SizedBox.shrink()));
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiMorphingSearchChips(storageKey: key, defaultOpen: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('durable term'), findsOneWidget);
  });

  testWidgets('an empty storageKey behaves like no storage key', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiMorphingSearchChips(storageKey: '')),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'session only');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    await tester.pumpWidget(beuiTestApp(const SizedBox.shrink()));
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiMorphingSearchChips(storageKey: '', defaultOpen: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('session only'), findsNothing);
  });

  testWidgets(
    'changing storageKey hydrates the new key without clearing defaults',
    (tester) async {
      const keyA = 'v31-morph-search-key-a';
      const keyB = 'v31-morph-search-key-b';
      await tester.pumpWidget(
        beuiTestApp(const BeuiMorphingSearchChips(storageKey: keyB)),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'key b term');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      var currentKey = keyA;
      await tester.pumpWidget(
        beuiTestApp(
          StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BeuiMorphingSearchChips(
                  storageKey: currentKey,
                  defaultOpen: true,
                  defaultRecents: const ['default stays'],
                ),
                TextButton(
                  onPressed: () => setState(() => currentKey = keyB),
                  child: const Text('change storage key'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('default stays'), findsOneWidget);
      await tester.tap(find.text('change storage key'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text('key b term'), findsOneWidget);
    },
  );

  testWidgets(
    'controlled recents call back but are not internally changed or stored',
    (tester) async {
      const key = 'v31-morph-search-controlled';
      final changes = <List<String>>[];
      await tester.pumpWidget(
        beuiTestApp(
          BeuiMorphingSearchChips(
            storageKey: key,
            recents: const ['fixed recent'],
            onRecentsChange: changes.add,
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'candidate');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(changes, [
        ['candidate', 'fixed recent'],
      ]);
      expect(find.text('fixed recent'), findsOneWidget);

      await tester.pumpWidget(beuiTestApp(const SizedBox.shrink()));
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiMorphingSearchChips(storageKey: key, defaultOpen: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('candidate'), findsNothing);
    },
  );

  testWidgets('controlled-to-uncontrolled recents resume their default state', (
    tester,
  ) async {
    const key = 'v31-morph-search-controlled-transition';
    List<String>? controlledRecents = const ['controlled recent'];
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiMorphingSearchChips(
                storageKey: key,
                recents: controlledRecents,
                defaultRecents: const ['uncontrolled default'],
                defaultOpen: true,
              ),
              TextButton(
                onPressed: () => setState(() => controlledRecents = null),
                child: const Text('release recents'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('controlled recent'), findsOneWidget);

    await tester.tap(find.text('release recents'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(find.text('uncontrolled default'), findsOneWidget);
    expect(find.text('controlled recent'), findsNothing);
  });

  testWidgets('maxRecents caps UI-added terms and rehydrates the same cap', (
    tester,
  ) async {
    const key = 'v31-morph-search-max';
    var maxRecents = 3;
    Finder recent(String term) =>
        find.descendant(of: find.byType(ListTile), matching: find.text(term));
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiMorphingSearchChips(
                storageKey: key,
                maxRecents: maxRecents,
                defaultOpen: true,
              ),
              TextButton(
                onPressed: () => setState(() => maxRecents = 2),
                child: const Text('limit recents'),
              ),
            ],
          ),
        ),
      ),
    );
    for (final term in ['first', 'second', 'third']) {
      await tester.enterText(find.byType(TextField), term);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
    }
    expect(recent('third'), findsOneWidget);
    expect(recent('second'), findsOneWidget);
    expect(recent('first'), findsOneWidget);

    await tester.tap(find.text('limit recents'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(recent('third'), findsOneWidget);
    expect(recent('second'), findsOneWidget);
    expect(recent('first'), findsNothing);

    await tester.pumpWidget(beuiTestApp(const SizedBox.shrink()));
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiMorphingSearchChips(
          storageKey: key,
          maxRecents: 2,
          defaultOpen: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(recent('third'), findsOneWidget);
    expect(recent('first'), findsNothing);
    expect(recent('second'), findsOneWidget);
  });

  testWidgets(
    'adding a chip updates recents and removing it preserves the recent',
    (tester) async {
      final changes = <List<String>>[];
      await tester.pumpWidget(
        beuiTestApp(BeuiMorphingSearchChips(onRecentsChange: changes.add)),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'remove me');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(changes, [
        ['remove me'],
      ]);
      expect(find.byType(Chip), findsOneWidget);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      expect(changes, [
        ['remove me'],
      ]);
      expect(find.byType(Chip), findsNothing);
      expect(find.text('remove me'), findsOneWidget);
    },
  );
}
