import 'dart:ui'
    show PointerDeviceKind, SemanticsRole, Tristate, SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import 'package:beui/src/motion/file_tree.dart';
import 'package:beui/src/motion/_engine.dart'
    show SingleMotionBuilder, SpringMotion;
import 'package:beui/src/theme/beui_colors.dart';

void main() {
  group('BeuiFileTree interaction', () {
    testWidgets('expands nested items and selects a file', (tester) async {
      String? selected;
      await tester.pumpWidget(
        _app(
          BeuiFileTree(
            defaultExpandedIds: const ['src'],
            onChanged: (value) => selected = value,
            children: const [
              BeuiFileTreeFolder(
                value: 'src',
                name: 'src',
                children: [BeuiFileTreeFile(value: 'main', name: 'main.dart')],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('main.dart'), findsOneWidget);
      await tester.tap(find.text('main.dart'));
      await tester.pumpAndSettle();
      expect(selected, 'main');
    });

    testWidgets('controlled selection and expansion report changes only', (
      tester,
    ) async {
      String? selected;
      List<String>? expanded;
      await tester.pumpWidget(
        _app(
          BeuiFileTree(
            value: 'one',
            expandedIds: const [],
            onChanged: (value) => selected = value,
            onExpandedChanged: (value) => expanded = value,
            children: const [
              BeuiFileTreeFolder(
                value: 'folder',
                name: 'folder',
                children: [BeuiFileTreeFile(value: 'one', name: 'one.dart')],
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('folder'));
      await tester.pumpAndSettle();
      expect(expanded, ['folder']);
      expect(find.text('one.dart'), findsNothing);

      await tester.tap(find.text('folder'));
      await tester.pumpAndSettle();
      expect(selected, 'folder');
    });

    testWidgets('disabled items do not select or expand', (tester) async {
      var changed = false;
      await tester.pumpWidget(
        _app(
          BeuiFileTree(
            onChanged: (_) => changed = true,
            children: const [
              BeuiFileTreeFolder(
                value: 'locked',
                name: 'locked',
                disabled: true,
                children: [BeuiFileTreeFile(value: 'secret', name: 'secret')],
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('locked'));
      await tester.pumpAndSettle();
      expect(changed, isFalse);
      expect(find.text('secret'), findsNothing);
    });

    testWidgets('hovering a row uses foreground text color', (tester) async {
      await tester.pumpWidget(
        _app(
          const BeuiFileTree(
            children: [BeuiFileTreeFile(value: 'file', name: 'file.txt')],
          ),
        ),
      );
      final label = find.text('file.txt');
      expect(
        tester.widget<Text>(label).style!.color,
        BeuiColors.light().mutedForeground,
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(tester.getCenter(label));
      await tester.pump();

      expect(
        tester.widget<Text>(label).style!.color,
        BeuiColors.light().foreground,
      );
    });

    testWidgets('folder chevron uses the spring motion builder', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const BeuiFileTree(
            children: [
              BeuiFileTreeFolder(
                value: 'folder',
                name: 'folder',
                children: [BeuiFileTreeFile(value: 'child', name: 'child.txt')],
              ),
            ],
          ),
        ),
      );
      expect(find.byType(SingleMotionBuilder), findsOneWidget);
      expect(
        tester
            .widget<SingleMotionBuilder>(find.byType(SingleMotionBuilder))
            .motion,
        isA<SpringMotion>(),
      );

      await tester.tap(find.text('folder'));
      await tester.pump();

      expect(find.text('child.txt'), findsOneWidget);
      expect(find.byType(SingleMotionBuilder), findsOneWidget);
    });

    testWidgets('reduced motion snaps the folder chevron to expanded', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(
              body: BeuiFileTree(
                children: [
                  BeuiFileTreeFolder(
                    value: 'folder',
                    name: 'folder',
                    children: [
                      BeuiFileTreeFile(value: 'child', name: 'child.txt'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SingleMotionBuilder), findsNothing);
      await tester.tap(find.text('folder'));
      await tester.pump();

      final rotation = tester.widget<Transform>(
        find
            .ancestor(
              of: find.byIcon(LucideIcons.chevron_right),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(rotation.transform.storage[0], closeTo(0, 0.001));
      expect(rotation.transform.storage[1], closeTo(1, 0.001));
      expect(find.text('child.txt'), findsOneWidget);
    });

    testWidgets('keyboard navigation follows visible tree rows', (
      tester,
    ) async {
      String? selected;
      await tester.pumpWidget(
        _app(
          BeuiFileTree(
            defaultExpandedIds: const ['folder'],
            onChanged: (value) => selected = value,
            children: const [
              BeuiFileTreeFolder(
                value: 'folder',
                name: 'folder',
                children: [BeuiFileTreeFile(value: 'child', name: 'child.txt')],
              ),
              BeuiFileTreeFile(value: 'last', name: 'last.txt'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(selected, 'child');
    });
  });

  testWidgets('exposes supported list and listitem semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const BeuiFileTree(
          ariaLabel: 'Project files',
          defaultExpandedIds: ['src'],
          children: [
            BeuiFileTreeFolder(
              value: 'src',
              name: 'src',
              children: [BeuiFileTreeFile(value: 'main', name: 'main.dart')],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Project files'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Project files'))
          .getSemanticsData()
          .role,
      SemanticsRole.list,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('main.dart').first)
          .getSemanticsData()
          .role,
      SemanticsRole.listItem,
    );
    semantics.dispose();
  });

  testWidgets(
    'row actions expose selection and disabled state without losing focus',
    (tester) async {
      final handle = tester.ensureSemantics();

      final selections = <String>[];
      final expansions = <List<String>>[];
      await tester.pumpWidget(
        _app(
          BeuiFileTree(
            defaultValue: 'selected',
            onChanged: selections.add,
            onExpandedChanged: expansions.add,
            children: const [
              BeuiFileTreeFile(value: 'selected', name: 'Selected'),
              BeuiFileTreeFolder(
                value: 'disabled',
                name: 'Disabled',
                disabled: true,
                children: [BeuiFileTreeFile(value: 'hidden', name: 'Hidden')],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final nodes = <SemanticsData>[];
      void collect(SemanticsNode node) {
        nodes.add(node.getSemanticsData());
        node.visitChildren((SemanticsNode child) {
          collect(child);
          return true;
        });
      }

      collect(tester.getSemantics(find.byType(BeuiFileTree)));
      final selected = nodes.singleWhere(
        (SemanticsData d) =>
            d.label == 'Selected' && d.flagsCollection.isButton,
      );
      expect(selected.flagsCollection.isSelected, Tristate.isTrue);
      final disabled = nodes.singleWhere(
        (SemanticsData d) =>
            d.label == 'Disabled' && d.flagsCollection.isButton,
      );
      expect(disabled.flagsCollection.isEnabled, Tristate.isFalse);
      expect(disabled.hasAction(SemanticsAction.tap), isFalse);
      final row = nodes.singleWhere(
        (d) => d.label == 'Disabled' && d.role == SemanticsRole.listItem,
      );
      expect(row.flagsCollection.isEnabled, Tristate.none);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'file tree Disabled',
      );
      for (final key in [
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.arrowRight,
      ]) {
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
      }
      expect(selections, isEmpty);
      expect(expansions, isEmpty);
      expect(find.text('Hidden'), findsNothing);
      handle.dispose();
    },
  );

  testWidgets('row icon keeps independent content actions', (tester) async {
    final handle = tester.ensureSemantics();
    final calls = <String>[];
    await tester.pumpWidget(
      _app(
        BeuiFileTree(
          children: [
            BeuiFileTreeFile(
              value: 'file',
              name: 'File',
              icon: Row(
                children: [
                  for (final label in ['Inspect', 'Pin'])
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: label,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => calls.add(label),
                          child: const SizedBox(height: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final label in ['Inspect', 'Pin']) {
      final node = tester.getSemantics(find.bySemanticsLabel(label));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pump();
    }
    expect(calls, ['Inspect', 'Pin']);
    handle.dispose();
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(
      _app(
        const BeuiFileTree(
          value: 'file-tree',
          defaultExpandedIds: ['app', 'components'],
          children: [
            BeuiFileTreeFolder(
              value: 'app',
              name: 'app',
              children: [
                BeuiFileTreeFolder(
                  value: 'components',
                  name: 'components',
                  children: [
                    BeuiFileTreeFile(
                      value: 'file-tree',
                      name: 'file_tree.dart',
                    ),
                    BeuiFileTreeFile(value: 'button', name: 'button.dart'),
                  ],
                ),
                BeuiFileTreeFile(value: 'page', name: 'page.dart'),
              ],
            ),
            BeuiFileTreeFolder(
              value: 'public',
              name: 'public',
              children: [BeuiFileTreeFile(value: 'logo', name: 'logo.svg')],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiFileTree),
      matchesGoldenFile('goldens/beui_file_tree.png'),
    );
  });
}

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
  home: Scaffold(body: Center(child: child)),
);
