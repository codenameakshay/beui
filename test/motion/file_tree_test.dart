import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beui/src/motion/file_tree.dart';
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

  testWidgets('exposes tree and treeitem semantics', (tester) async {
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
