import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _sample = <BeuiSidebarResource>[
  const BeuiSidebarResource(
    id: 'platform',
    label: 'Platform',
    kind: BeuiSidebarResourceKind.project,
    children: [
      BeuiSidebarResource(
        id: 'api',
        label: 'API migration',
        kind: BeuiSidebarResourceKind.file,
      ),
      BeuiSidebarResource(
        id: 'docs',
        label: 'Read platform docs',
        kind: BeuiSidebarResourceKind.bookmark,
      ),
    ],
  ),
  const BeuiSidebarResource(
    id: 'notes',
    label: 'Release notes',
    kind: BeuiSidebarResourceKind.file,
  ),
  const BeuiSidebarResource(
    id: 'archive',
    label: 'Archive',
    kind: BeuiSidebarResourceKind.folder,
  ),
];

Widget _host({
  List<BeuiSidebarResource>? items,
  List<BeuiSidebarResource> defaultItems = const [],
  String? activeId,
  String? defaultActiveId,
  List<String> defaultExpandedIds = const [],
  ValueChanged<String>? onActiveChange,
  ValueChanged<List<BeuiSidebarResource>>? onItemsChange,
  Future<void> Function(BeuiSidebarResourceMove move)? onMove,
  Future<void> Function(BeuiSidebarResource item, String label)? onRename,
  bool reduce = false,
}) {
  Widget child = Center(
    child: SizedBox(
      width: 320,
      height: 480,
      child: Material(
        child: BeuiAiSidebar(
          items: items,
          defaultItems: defaultItems.isEmpty ? _sample : defaultItems,
          activeId: activeId,
          defaultActiveId: defaultActiveId,
          defaultExpandedIds: defaultExpandedIds,
          onActiveChange: onActiveChange,
          onItemsChange: onItemsChange,
          onMove: onMove,
          onRename: onRename,
        ),
      ),
    ),
  );
  if (reduce) {
    final inner = child;
    child = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  group('tree helpers', () {
    test('move before / after / inside', () {
      final after = beuiSidebarMove(
        _sample,
        const BeuiSidebarResourceMove(
          itemId: 'notes',
          targetId: 'platform',
          position: BeuiSidebarResourceDropPosition.before,
        ),
      )!;
      expect(after.map((r) => r.id).toList(), ['notes', 'platform', 'archive']);

      final inside = beuiSidebarMove(
        _sample,
        const BeuiSidebarResourceMove(
          itemId: 'notes',
          targetId: 'platform',
          position: BeuiSidebarResourceDropPosition.inside,
        ),
      )!;
      final platform = inside.firstWhere((r) => r.id == 'platform');
      expect(platform.children!.map((c) => c.id).toList(), [
        'api',
        'docs',
        'notes',
      ]);
    });

    test('move rejects nesting into self / non-container', () {
      expect(
        beuiSidebarMove(
          _sample,
          const BeuiSidebarResourceMove(
            itemId: 'platform',
            targetId: 'api',
            position: BeuiSidebarResourceDropPosition.inside,
          ),
        ),
        isNull,
      );
      expect(
        beuiSidebarMove(
          _sample,
          const BeuiSidebarResourceMove(
            itemId: 'docs',
            targetId: 'notes',
            position: BeuiSidebarResourceDropPosition.inside,
          ),
        ),
        isNull,
      );
    });

    test('rename updates label', () {
      final next = beuiSidebarRename(_sample, 'api', 'API v2');
      expect(beuiSidebarFind(next, 'api')!.label, 'API v2');
    });
  });

  group('BeuiAiSidebar', () {
    testWidgets('renders top-level resources', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      expect(find.byKey(beuiAiSidebarKey), findsOneWidget);
      expect(find.text('Platform'), findsOneWidget);
      expect(find.text('Release notes'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      // Children hidden until expanded.
      expect(find.text('API migration'), findsNothing);
    });

    testWidgets('expands folder and shows children', (tester) async {
      await tester.pumpWidget(_host(defaultExpandedIds: const ['platform']));
      await tester.pumpAndSettle();

      expect(find.text('API migration'), findsOneWidget);
      expect(find.text('Read platform docs'), findsOneWidget);
    });

    testWidgets('tap folder toggles expand', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Platform'));
      await tester.pumpAndSettle();
      expect(find.text('API migration'), findsOneWidget);

      await tester.tap(find.text('Platform'));
      await tester.pumpAndSettle();
      expect(find.text('API migration'), findsNothing);
    });

    testWidgets('selects leaf and reports onActiveChange', (tester) async {
      String? selected;
      await tester.pumpWidget(
        _host(
          defaultExpandedIds: const ['platform'],
          onActiveChange: (id) => selected = id,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(beuiAiSidebarRowKey('api')));
      // GestureDetector delays onTap when onDoubleTap is set.
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();
      expect(selected, 'api');
    });

    testWidgets('controlled activeId highlights leaf', (tester) async {
      await tester.pumpWidget(
        _host(defaultExpandedIds: const ['platform'], activeId: 'docs'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Read platform docs'), findsOneWidget);
    });

    testWidgets('inline rename via F2 commits on submit', (tester) async {
      List<BeuiSidebarResource>? items;
      String? renamedTo;

      await tester.pumpWidget(
        _host(
          defaultExpandedIds: const ['platform'],
          defaultActiveId: 'api',
          onItemsChange: (next) => items = next,
          onRename: (item, label) async {
            renamedTo = label;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Focus the row then press F2.
      await tester.tap(find.byKey(beuiAiSidebarRowKey('api')));
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pumpAndSettle();

      expect(find.byKey(beuiAiSidebarRenameKey('api')), findsOneWidget);

      await tester.enterText(
        find.byKey(beuiAiSidebarRenameKey('api')),
        'API v2',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(renamedTo, 'API v2');
      expect(beuiSidebarFind(items!, 'api')!.label, 'API v2');
      expect(find.text('API v2'), findsOneWidget);
    });

    testWidgets('double-tap leaf starts rename', (tester) async {
      await tester.pumpWidget(_host(defaultExpandedIds: const ['platform']));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(beuiAiSidebarRowKey('api')));
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(find.byKey(beuiAiSidebarRowKey('api')));
      await tester.pumpAndSettle();

      expect(find.byKey(beuiAiSidebarRenameKey('api')), findsOneWidget);
    });

    testWidgets('optimistic move rolls back on failure', (tester) async {
      final snapshots = <List<String>>[];

      await tester.pumpWidget(
        _host(
          onItemsChange: (next) =>
              snapshots.add(next.map((r) => r.id).toList()),
          onMove: (_) async {
            throw StateError('server rejected');
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(beuiAiSidebarRowKey('notes')));
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump(); // optimistic apply
      await tester.pumpAndSettle(); // rollback completes

      expect(snapshots, isNotEmpty);
      // Final tree after rollback matches original order.
      expect(snapshots.last, ['platform', 'notes', 'archive']);
      // At least one intermediate snapshot reordered optimistically.
      expect(snapshots.any((s) => s.join() != 'platformnotesarchive'), isTrue);
    });

    testWidgets('keyboard move reorders optimistically', (tester) async {
      List<BeuiSidebarResource>? latest;

      await tester.pumpWidget(
        _host(onItemsChange: (next) => latest = next, onMove: (_) async {}),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(beuiAiSidebarRowKey('notes')));
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();

      expect(latest, isNotNull);
      expect(latest!.map((r) => r.id).toList(), [
        'notes',
        'platform',
        'archive',
      ]);
    });

    testWidgets('reduced motion still renders', (tester) async {
      await tester.pumpWidget(
        _host(reduce: true, defaultExpandedIds: const ['platform']),
      );
      await tester.pumpAndSettle();
      expect(find.text('API migration'), findsOneWidget);
    });
  });
}
