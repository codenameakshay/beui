import 'dart:math' as math;
import 'dart:ui' show SemanticsRole, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beui/src/motion/bloom_menu.dart';
import 'package:beui/src/theme/beui_colors.dart';
import 'package:beui/src/theme/beui_text_theme.dart';
import 'package:beui/src/tokens/icons.dart';

Widget _testApp(Widget child, {bool reduce = false}) => MaterialApp(
  theme: BeuiTextTheme.trackingNormal(
    ThemeData(extensions: [BeuiColors.light()]),
  ),
  home: Scaffold(
    body: reduce
        ? Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child,
            ),
          )
        : child,
  ),
);

double _maxBlurSigma(WidgetTester tester) => tester
    .widgetList<ImageFiltered>(find.byType(ImageFiltered))
    .map((filter) {
      final match = RegExp(
        r'blur\(([\d.]+)',
      ).firstMatch(filter.imageFilter.toString());
      return match == null ? 0.0 : double.parse(match.group(1)!);
    })
    .fold<double>(0, math.max);

Finder _labelSemantics(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

Finder _itemSemantics(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.label == label &&
      widget.properties.role == SemanticsRole.menuItem,
);

const _items = [
  BeuiBloomMenuItem(label: 'Doc', icon: LucideIcons.file_text),
  BeuiBloomMenuItem(label: 'Board', icon: LucideIcons.layout_grid),
  BeuiBloomMenuItem(label: 'Table', icon: LucideIcons.table),
  BeuiBloomMenuItem(label: 'Folder', icon: LucideIcons.folder_closed),
  BeuiBloomMenuItem(label: 'Reminder', icon: LucideIcons.bell),
  BeuiBloomMenuItem(label: 'Link', icon: LucideIcons.link),
];

Widget _app({
  required FocusNode beforeMenu,
  FocusNode? afterMenu,
  ValueChanged<String>? onSelect,
  bool reduce = false,
}) => _testApp(
  FocusTraversalGroup(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          focusNode: beforeMenu,
          onPressed: () {},
          child: const Text('Before menu'),
        ),
        BeuiBloomMenu(items: _items, onSelect: onSelect),
        TextButton(
          focusNode: afterMenu,
          onPressed: () {},
          child: const Text('After menu'),
        ),
      ],
    ),
  ),
  reduce: reduce,
);

Future<void> _focusTrigger(WidgetTester tester, FocusNode beforeMenu) async {
  beforeMenu.requestFocus();
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
  expect(
    tester.getSemantics(_labelSemantics('Create')).flagsCollection.isFocused,
    Tristate.isTrue,
    reason:
        'Tab from the preceding control should focus the native-button trigger.',
  );
}

Future<void> _openByKey(
  WidgetTester tester,
  FocusNode beforeMenu,
  LogicalKeyboardKey key,
) async {
  await _focusTrigger(tester, beforeMenu);
  await tester.sendKeyEvent(key);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pump();
}

Future<void> _sendKey(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
  await tester.pump();
}

void _expectItemFocused(WidgetTester tester, String label) {
  expect(
    find.text(label),
    findsOneWidget,
    reason: 'The open menu should be visible.',
  );
  expect(
    tester.getSemantics(_itemSemantics(label)).flagsCollection.isFocused,
    Tristate.isTrue,
    reason: '$label should be the current roving menu-item focus target.',
  );
}

void main() {
  group('BeuiBloomMenu source keyboard contract', () {
    testWidgets('keyboard focus keeps grid dividers at their resting width', (
      tester,
    ) async {
      final beforeMenu = FocusNode(debugLabel: 'before bloom menu');
      addTearDown(beforeMenu.dispose);
      await tester.pumpWidget(_app(beforeMenu: beforeMenu));
      await _openByKey(tester, beforeMenu, LogicalKeyboardKey.arrowDown);
      _expectItemFocused(tester, 'Doc');
      Border borderFor(String label) {
        final cell = tester.widget<Container>(
          find
              .descendant(
                of: _itemSemantics(label),
                matching: find.byType(Container),
              )
              .first,
        );
        return (cell.decoration! as BoxDecoration).border! as Border;
      }

      expect(borderFor('Doc').right.width, 1);
      expect(borderFor('Doc').bottom.width, 1);
      final docSize = tester.getSize(_itemSemantics('Doc'));
      await _sendKey(tester, LogicalKeyboardKey.arrowRight);
      _expectItemFocused(tester, 'Board');
      expect(borderFor('Board').right.width, 1);
      expect(borderFor('Board').bottom.width, 1);
      expect(tester.getSize(_itemSemantics('Doc')), docSize);
    });

    testWidgets('keyboard focus does not widen a content-sized trigger', (
      tester,
    ) async {
      final beforeMenu = FocusNode(debugLabel: 'before bloom menu');
      addTearDown(beforeMenu.dispose);
      await tester.pumpWidget(
        _testApp(
          FocusTraversalGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  focusNode: beforeMenu,
                  onPressed: () {},
                  child: const Text('Before menu'),
                ),
                const BeuiBloomMenu(triggerLabel: 'Create another workspace'),
              ],
            ),
          ),
        ),
      );
      final unfocused = tester.getSize(find.byType(BeuiBloomMenu));
      beforeMenu.requestFocus();
      await tester.pump();
      await _sendKey(tester, LogicalKeyboardKey.tab);
      expect(tester.getSize(find.byType(BeuiBloomMenu)), unfocused);
    });

    for (final (key, keyName) in [
      (LogicalKeyboardKey.arrowDown, 'ArrowDown'),
      (LogicalKeyboardKey.arrowUp, 'ArrowUp'),
    ]) {
      testWidgets(
        '$keyName opens from the trigger and focuses the first item',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final beforeMenu = FocusNode(debugLabel: 'before bloom menu');
          addTearDown(beforeMenu.dispose);
          await tester.pumpWidget(_app(beforeMenu: beforeMenu));

          await _openByKey(tester, beforeMenu, key);

          _expectItemFocused(tester, 'Doc');
          expect(find.text('Create'), findsWidgets);
          semantics.dispose();
        },
      );
    }

    testWidgets(
      'three-column arrows follow source steps and clamp at grid edges',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final beforeMenu = FocusNode(debugLabel: 'before bloom menu');
        addTearDown(beforeMenu.dispose);
        await tester.pumpWidget(_app(beforeMenu: beforeMenu));
        await _openByKey(tester, beforeMenu, LogicalKeyboardKey.arrowDown);
        _expectItemFocused(tester, 'Doc');

        // Source maps Left/Right to -1/+1, including crossing a row boundary.
        await _sendKey(tester, LogicalKeyboardKey.arrowRight);
        _expectItemFocused(tester, 'Board');
        await _sendKey(tester, LogicalKeyboardKey.arrowRight);
        _expectItemFocused(tester, 'Table');
        await _sendKey(tester, LogicalKeyboardKey.arrowRight);
        _expectItemFocused(tester, 'Folder');
        await _sendKey(tester, LogicalKeyboardKey.arrowLeft);
        _expectItemFocused(tester, 'Table');

        // Three columns means vertical steps are +/-3, not +/-1.
        await _sendKey(tester, LogicalKeyboardKey.arrowDown);
        _expectItemFocused(tester, 'Link');
        await _sendKey(tester, LogicalKeyboardKey.arrowDown);
        _expectItemFocused(tester, 'Link');
        await _sendKey(tester, LogicalKeyboardKey.arrowUp);
        _expectItemFocused(tester, 'Table');
        await _sendKey(tester, LogicalKeyboardKey.arrowLeft);
        _expectItemFocused(tester, 'Board');
        await _sendKey(tester, LogicalKeyboardKey.arrowUp);
        _expectItemFocused(tester, 'Board');
        await _sendKey(tester, LogicalKeyboardKey.arrowLeft);
        _expectItemFocused(tester, 'Doc');
        await _sendKey(tester, LogicalKeyboardKey.arrowLeft);
        _expectItemFocused(tester, 'Doc');
        semantics.dispose();
      },
    );

    testWidgets(
      'Home and End move the roving focus to literal grid endpoints',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final beforeMenu = FocusNode(debugLabel: 'before bloom menu');
        addTearDown(beforeMenu.dispose);
        await tester.pumpWidget(_app(beforeMenu: beforeMenu));
        await _openByKey(tester, beforeMenu, LogicalKeyboardKey.arrowUp);

        await _sendKey(tester, LogicalKeyboardKey.end);
        _expectItemFocused(tester, 'Link');
        await _sendKey(tester, LogicalKeyboardKey.home);
        _expectItemFocused(tester, 'Doc');
        semantics.dispose();
      },
    );

    for (final (key, keyName, selectedLabel) in [
      (LogicalKeyboardKey.enter, 'Enter', 'Board'),
      (LogicalKeyboardKey.space, 'Space', 'Link'),
    ]) {
      testWidgets(
        '$keyName activates the focused menu item, reports its exact label, and closes',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final beforeMenu = FocusNode(debugLabel: 'before bloom menu');
          addTearDown(beforeMenu.dispose);
          final selected = <String>[];
          await tester.pumpWidget(
            _app(beforeMenu: beforeMenu, onSelect: selected.add),
          );
          await _openByKey(tester, beforeMenu, LogicalKeyboardKey.arrowDown);
          if (selectedLabel == 'Board') {
            await _sendKey(tester, LogicalKeyboardKey.arrowRight);
          } else {
            await _sendKey(tester, LogicalKeyboardKey.end);
          }
          _expectItemFocused(tester, selectedLabel);

          await tester.sendKeyEvent(key);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 800));

          expect(selected, <String>[selectedLabel]);
          expect(
            find.text('Doc'),
            findsNothing,
            reason: 'Selection should close the menu.',
          );
          semantics.dispose();
        },
      );
    }

    testWidgets('closing menu ignores repeated keyboard selection', (
      tester,
    ) async {
      final beforeMenu = FocusNode(debugLabel: 'before bloom menu');
      addTearDown(beforeMenu.dispose);
      final selected = <String>[];
      await tester.pumpWidget(
        _app(beforeMenu: beforeMenu, onSelect: selected.add),
      );
      await _openByKey(tester, beforeMenu, LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await _sendKey(tester, LogicalKeyboardKey.enter);
      await _sendKey(tester, LogicalKeyboardKey.enter);
      expect(selected, ['Doc']);
      await tester.pump(const Duration(milliseconds: 800));
    });

    testWidgets('closing menu ignores pointer selection during exit', (
      tester,
    ) async {
      final beforeMenu = FocusNode(debugLabel: 'before bloom menu');
      addTearDown(beforeMenu.dispose);
      final selected = <String>[];
      await tester.pumpWidget(
        _app(beforeMenu: beforeMenu, onSelect: selected.add),
      );
      await _openByKey(tester, beforeMenu, LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await _sendKey(tester, LogicalKeyboardKey.enter);
      await tester.tap(find.text('Table'));
      expect(selected, ['Doc']);
      await tester.pump(const Duration(milliseconds: 800));
    });

    testWidgets('Escape closes and returns focus to the trigger', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final beforeMenu = FocusNode(debugLabel: 'before bloom menu');
      addTearDown(beforeMenu.dispose);
      await tester.pumpWidget(_app(beforeMenu: beforeMenu));
      await _openByKey(tester, beforeMenu, LogicalKeyboardKey.arrowDown);
      _expectItemFocused(tester, 'Doc');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      expect(find.text('Doc'), findsNothing);
      expect(
        tester
            .getSemantics(_labelSemantics('Create'))
            .flagsCollection
            .isFocused,
        Tristate.isTrue,
        reason:
            'Closing while a menu item owns focus restores focus to the trigger.',
      );
      semantics.dispose();
    });

    testWidgets('a new focus target during close is not overridden later', (
      tester,
    ) async {
      final beforeMenu = FocusNode(debugLabel: 'before bloom menu');
      final afterMenu = FocusNode(debugLabel: 'after bloom menu');
      addTearDown(beforeMenu.dispose);
      addTearDown(afterMenu.dispose);
      await tester.pumpWidget(
        _app(beforeMenu: beforeMenu, afterMenu: afterMenu),
      );
      await _openByKey(tester, beforeMenu, LogicalKeyboardKey.arrowDown);
      _expectItemFocused(tester, 'Doc');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      afterMenu.requestFocus();
      await tester.pump();
      expect(afterMenu.hasFocus, isTrue);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      expect(find.text('Doc'), findsNothing);
      expect(afterMenu.hasFocus, isTrue);
    });

    testWidgets(
      'reduced motion preserves keyboard opening, focus, and selection',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final beforeMenu = FocusNode(debugLabel: 'before bloom menu');
        addTearDown(beforeMenu.dispose);
        final selected = <String>[];
        await tester.pumpWidget(
          _app(beforeMenu: beforeMenu, onSelect: selected.add, reduce: true),
        );
        await _openByKey(tester, beforeMenu, LogicalKeyboardKey.arrowDown);
        _expectItemFocused(tester, 'Doc');

        await _sendKey(tester, LogicalKeyboardKey.arrowRight);
        _expectItemFocused(tester, 'Board');
        await _sendKey(tester, LogicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 800));

        expect(selected, <String>['Board']);
        expect(find.text('Doc'), findsNothing);
        semantics.dispose();
      },
    );

    for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
      testWidgets('trigger activates with ${key.keyLabel}', (tester) async {
        final beforeMenu = FocusNode(debugLabel: 'before bloom menu');
        addTearDown(beforeMenu.dispose);
        await tester.pumpWidget(_app(beforeMenu: beforeMenu));
        await _focusTrigger(tester, beforeMenu);

        await tester.sendKeyEvent(key);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump();

        _expectItemFocused(tester, 'Doc');
      });
    }

    testWidgets('leaving the menu closes without stealing the next focus', (
      tester,
    ) async {
      final beforeMenu = FocusNode(debugLabel: 'before bloom menu');
      final afterMenu = FocusNode(debugLabel: 'after bloom menu');
      addTearDown(beforeMenu.dispose);
      addTearDown(afterMenu.dispose);
      await tester.pumpWidget(
        _app(beforeMenu: beforeMenu, afterMenu: afterMenu),
      );
      await _openByKey(tester, beforeMenu, LogicalKeyboardKey.arrowDown);
      _expectItemFocused(tester, 'Doc');

      await _sendKey(tester, LogicalKeyboardKey.tab);
      await _sendKey(tester, LogicalKeyboardKey.tab);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Doc'), findsNothing);
      expect(afterMenu.hasFocus, isTrue);
    });

    testWidgets('a surviving active label retains focus across item updates', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final beforeMenu = FocusNode(debugLabel: 'before bloom menu');
      addTearDown(beforeMenu.dispose);
      var items = _items;
      late StateSetter update;
      await tester.pumpWidget(
        _testApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    focusNode: beforeMenu,
                    onPressed: () {},
                    child: const Text('Before menu'),
                  ),
                  BeuiBloomMenu(items: items),
                ],
              );
            },
          ),
        ),
      );
      await _openByKey(tester, beforeMenu, LogicalKeyboardKey.arrowDown);
      await _sendKey(tester, LogicalKeyboardKey.arrowRight);
      _expectItemFocused(tester, 'Board');

      update(
        () => items = [
          ..._items,
          const BeuiBloomMenuItem(label: 'Archive', icon: LucideIcons.archive),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump();
      _expectItemFocused(tester, 'Board');

      update(
        () => items = [
          const BeuiBloomMenuItem(label: 'Board', icon: LucideIcons.archive),
          ..._items.where((item) => item.label != 'Board'),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump();
      _expectItemFocused(tester, 'Board');

      update(
        () => items = items.where((item) => item.label != 'Board').toList(),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump();
      _expectItemFocused(tester, 'Doc');
      semantics.dispose();
    });

    testWidgets('removing the active label resets focus and remains usable', (
      tester,
    ) async {
      final beforeMenu = FocusNode(debugLabel: 'before bloom menu');
      addTearDown(beforeMenu.dispose);
      var items = _items;
      late StateSetter update;
      await tester.pumpWidget(
        _testApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    focusNode: beforeMenu,
                    onPressed: () {},
                    child: const Text('Before menu'),
                  ),
                  BeuiBloomMenu(items: items),
                  TextButton(onPressed: () {}, child: const Text('After menu')),
                ],
              );
            },
          ),
        ),
      );
      await _openByKey(tester, beforeMenu, LogicalKeyboardKey.arrowDown);
      update(() {
        items = const [
          BeuiBloomMenuItem(label: 'Archive', icon: LucideIcons.archive),
          BeuiBloomMenuItem(label: 'Move', icon: LucideIcons.folder_closed),
        ];
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump();

      _expectItemFocused(tester, 'Archive');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump();
      _expectItemFocused(tester, 'Move');
    });

    testWidgets('disposing during an open transition is safe', (tester) async {
      var showMenu = true;
      late StateSetter update;
      await tester.pumpWidget(
        _testApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return showMenu ? const BeuiBloomMenu() : const Text('Removed');
            },
          ),
        ),
      );
      await tester.tap(find.text('Create'));
      await tester.pump(const Duration(milliseconds: 32));
      update(() => showMenu = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Removed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty item list opens without invalid menu semantics', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(const BeuiBloomMenu(items: <BeuiBloomMenuItem>[])),
      );
      await tester.tap(find.text('Create'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Doc'), findsNothing);
      expect(find.byIcon(LucideIcons.x), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('narrow viewport lays out and reduced motion skips movement', (
      tester,
    ) async {
      final media = MediaQueryData(size: const Size(240, 640));
      await tester.pumpWidget(
        _testApp(
          MediaQuery(
            data: media.copyWith(disableAnimations: true),
            child: const SizedBox(
              width: 240,
              child: Align(
                alignment: Alignment.topCenter,
                child: BeuiBloomMenu(),
              ),
            ),
          ),
          reduce: true,
        ),
      );
      await tester.tap(find.text('Create'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));

      expect(find.text('Link'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(_maxBlurSigma(tester), lessThan(0.5));
      final scales = tester.widgetList<Transform>(find.byType(Transform));
      expect(
        scales.where(
          (transform) => transform.transform.getMaxScaleOnAxis() != 1,
        ),
        isEmpty,
      );
    });

    testWidgets(
      'radial item reveal begins at the source blur before its stagger releases',
      (tester) async {
        final beforeMenu = FocusNode(debugLabel: 'before bloom menu');
        addTearDown(beforeMenu.dispose);
        await tester.pumpWidget(_app(beforeMenu: beforeMenu));
        await tester.tap(find.text('Create'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 160));

        expect(_maxBlurSigma(tester), 3.0);
      },
    );
  });
}
