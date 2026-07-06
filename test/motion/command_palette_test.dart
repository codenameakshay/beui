import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduce = false}) {
  Widget body = Center(child: child);
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

List<BeuiCommandItem> _items(List<String> selected) => [
  BeuiCommandItem(
    id: 'new',
    label: 'New file',
    group: 'Actions',
    hint: '⌘N',
    onSelect: () => selected.add('new'),
  ),
  BeuiCommandItem(
    id: 'github',
    label: 'GitHub',
    group: 'Links',
    keywords: const ['repo'],
    onSelect: () => selected.add('github'),
  ),
  BeuiCommandItem(
    id: 'settings',
    label: 'Open settings',
    group: 'Actions',
    onSelect: () => selected.add('settings'),
  ),
];

Future<void> _openWithShortcut(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16)); // first ticker tick
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('BeuiCommandPalette', () {
    testWidgets('closed by default; ⌘K opens with input focused', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(BeuiCommandPalette(items: _items([]))));
      await tester.pump();
      expect(find.text('New file'), findsNothing);

      await _openWithShortcut(tester);
      expect(find.text('New file'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.byType(EditableText), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
    });

    testWidgets('renders group headers', (tester) async {
      await tester.pumpWidget(_wrap(BeuiCommandPalette(items: _items([]))));
      await _openWithShortcut(tester);
      expect(find.text('ACTIONS'), findsOneWidget);
      expect(find.text('LINKS'), findsOneWidget);
    });

    testWidgets('Esc closes the palette', (tester) async {
      await tester.pumpWidget(_wrap(BeuiCommandPalette(items: _items([]))));
      await _openWithShortcut(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('New file'), findsNothing);
    });

    testWidgets('fuzzy filter matches subsequences and keywords', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(BeuiCommandPalette(items: _items([]))));
      await _openWithShortcut(tester);
      await tester.enterText(find.byType(EditableText), 'gh');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('GitHub'), findsOneWidget); // g…h subsequence
      expect(find.text('New file'), findsNothing);

      await tester.enterText(find.byType(EditableText), 'repo');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('GitHub'), findsOneWidget); // keyword match
    });

    testWidgets('shows the empty message when nothing matches', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiCommandPalette(items: _items([]), emptyMessage: 'Nothing here'),
        ),
      );
      await _openWithShortcut(tester);
      await tester.enterText(find.byType(EditableText), 'zzzz');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Nothing here'), findsOneWidget);
    });

    testWidgets('arrow keys + Enter select the active item and close', (
      tester,
    ) async {
      final selected = <String>[];
      await tester.pumpWidget(
        _wrap(BeuiCommandPalette(items: _items(selected))),
      );
      await _openWithShortcut(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(selected, ['settings']); // Actions group: new(0) → settings(1)
      expect(find.text('New file'), findsNothing, reason: 'closed on select');
    });

    testWidgets('tapping a row selects it', (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(
        _wrap(BeuiCommandPalette(items: _items(selected))),
      );
      await _openWithShortcut(tester);
      await tester.tap(find.text('GitHub'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(selected, ['github']);
    });

    testWidgets('controlled open works without the shortcut', (tester) async {
      final opens = <bool>[];
      await tester.pumpWidget(
        _wrap(
          BeuiCommandPalette(
            items: _items([]),
            open: true,
            onOpenChange: opens.add,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('New file'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(opens.last, isFalse);
    });

    testWidgets('reduced motion opens with fade only', (tester) async {
      await tester.pumpWidget(
        _wrap(BeuiCommandPalette(items: _items([])), reduce: true),
      );
      await _openWithShortcut(tester);
      expect(find.text('New file'), findsOneWidget);
    });
  });
}
