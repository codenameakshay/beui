import 'package:flutter/gestures.dart';
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
  Key? listKey,
  bool reparent = false,
  Widget? after,
  bool handlesEnabled = true,
}) {
  final child = BeuiSortableList<({String id, String label})>(
    key: listKey,
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
                    BeuiSortableListHandle(enabled: handlesEnabled),
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
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (reparent)
                  Padding(padding: const EdgeInsets.all(1), child: child)
                else
                  child,
                ?after,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  _ownershipMain();
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

  testWidgets('hovering the handle paints the muted background', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final handle = find.byTooltip('Reorder Collect references');
    final handleRect = tester.getRect(handle);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(handleRect.center);
    await tester.pump(const Duration(milliseconds: 300));

    final button = tester.widget<IconButton>(find.byType(IconButton).first);
    expect(
      button.style!.backgroundColor!.resolve({WidgetState.hovered}),
      BeuiColors.light().muted,
    );
    await mouse.removePointer();
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

  for (final reduce in [false, true]) {
    testWidgets('rejected controlled move keeps Undo disabled ($reduce)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final calls = <List<String>>[];
      await tester.pumpWidget(
        _app(
          items: _items,
          reduce: reduce,
          onItemsChange: (v) => calls.add(v.map((e) => e.id).toList()),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(calls, [
        ['beta', 'alpha', 'gamma'],
      ]);
      expect(_visibleOrder(tester), ['alpha', 'beta', 'gamma']);
      expect(_undoButton(tester).onPressed, isNull);
      await tester.tap(find.text('Undo reorder'));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(find.bySemanticsLabel('Previous order restored.'), findsNothing);
      semantics.dispose();
    });

    testWidgets('accepted controlled move and Undo restore once ($reduce)', (
      tester,
    ) async {
      var items = _items.toList();
      final calls = <List<String>>[];
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, update) => _app(
            items: items,
            reduce: reduce,
            onItemsChange: (v) {
              calls.add(v.map((e) => e.id).toList());
              update(() => items = v);
            },
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(_visibleOrder(tester), ['beta', 'alpha', 'gamma']);
      expect(_undoButton(tester).onPressed, isNotNull);
      await tester.tap(find.text('Undo reorder'));
      await tester.pumpAndSettle();
      expect(_visibleOrder(tester), ['alpha', 'beta', 'gamma']);
      expect(calls, [
        ['beta', 'alpha', 'gamma'],
        ['alpha', 'beta', 'gamma'],
      ]);
      expect(_undoButton(tester).onPressed, isNull);
    });
  }

  testWidgets(
    'external saved-order reset disables Undo and guards a retained action',
    (tester) async {
      var items = _items.toList();
      late StateSetter update;
      var count = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return _app(
              items: items,
              onItemsChange: (v) {
                count++;
                set(() => items = v);
              },
            );
          },
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      final retainedUndo = _undoButton(tester).onPressed!;
      update(() => items = _items.toList());
      await tester.pumpAndSettle();
      retainedUndo();
      await tester.pumpAndSettle();
      expect(count, 1);
      expect(_undoButton(tester).onPressed, isNull);
      expect(_visibleOrder(tester), ['alpha', 'beta', 'gamma']);
    },
  );

  testWidgets('membership replacement permanently invalidates saved order', (
    tester,
  ) async {
    var items = _items.toList();
    late StateSetter update;
    var count = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, set) {
          update = set;
          return _app(
            items: items,
            onItemsChange: (v) {
              count++;
              set(() => items = v);
            },
          );
        },
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    update(
      () => items = [_items[1], _items[0], (id: 'delta', label: 'Replacement')],
    );
    await tester.pumpAndSettle();
    expect(_undoButton(tester).onPressed, isNull);
    update(() => items = [_items[1], _items[0], _items[2]]);
    await tester.pumpAndSettle();
    expect(_undoButton(tester).onPressed, isNull);
    expect(count, 1);
  });

  testWidgets('Home End and boundaries preserve uncontrolled Undo', (
    tester,
  ) async {
    final calls = <List<String>>[];
    await tester.pumpWidget(
      _app(onItemsChange: (v) => calls.add(v.map((e) => e.id).toList())),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    for (final key in [LogicalKeyboardKey.home, LogicalKeyboardKey.arrowUp]) {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }
    expect(calls, isEmpty);
    expect(_undoButton(tester).onPressed, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(_visibleOrder(tester), ['beta', 'gamma', 'alpha']);
    for (final key in [LogicalKeyboardKey.end, LogicalKeyboardKey.arrowDown]) {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }
    expect(calls, hasLength(1));
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(_visibleOrder(tester), ['alpha', 'beta', 'gamma']);
    await tester.tap(find.text('Undo reorder'));
    await tester.pumpAndSettle();
    expect(_visibleOrder(tester), ['beta', 'gamma', 'alpha']);
    expect(calls, hasLength(3));
    expect(_undoButton(tester).onPressed, isNull);
  });

  testWidgets('disabling root guards a previously enabled Undo action', (
    tester,
  ) async {
    var disabled = false;
    late StateSetter update;
    var count = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, set) {
          update = set;
          return _app(disabled: disabled, onItemsChange: (_) => count++);
        },
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final retainedUndo = _undoButton(tester).onPressed!;
    update(() => disabled = true);
    await tester.pumpAndSettle();
    retainedUndo();
    await tester.pumpAndSettle();
    expect(count, 1);
    expect(_undoButton(tester).onPressed, isNull);
    expect(_visibleOrder(tester), ['beta', 'alpha', 'gamma']);
  });

  for (final reduce in [false, true]) {
    testWidgets(
      'Undo transfers keyboard ownership to first restored item ($reduce)',
      (tester) async {
        await tester.pumpWidget(_app(reduce: reduce));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final movedNode = FocusManager.instance.primaryFocus;
        for (final key in [LogicalKeyboardKey.end, LogicalKeyboardKey.home]) {
          await tester.sendKeyEvent(key);
          await tester.pumpAndSettle();
          expect(FocusManager.instance.primaryFocus, same(movedNode));
        }
        await tester.tap(find.text('Undo reorder'));
        await tester.pumpAndSettle();
        expect(_visibleOrder(tester), ['beta', 'gamma', 'alpha']);
        expect(_focusedHandle(), 'Reorder Explore the visual system');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(_visibleOrder(tester), ['gamma', 'beta', 'alpha']);
      },
    );
  }

  testWidgets('Undo respects focus chosen by the controlled owner', (
    tester,
  ) async {
    final external = FocusNode();
    addTearDown(external.dispose);
    var items = _items.toList();
    var calls = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, update) => _app(
          items: items,
          after: ElevatedButton(
            focusNode: external,
            onPressed: () {},
            child: const Text('Outside'),
          ),
          onItemsChange: (next) {
            update(() => items = next);
            if (++calls == 3) external.requestFocus();
          },
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    for (final key in [LogicalKeyboardKey.end, LogicalKeyboardKey.home]) {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Undo reorder'));
    await tester.pumpAndSettle();
    expect(external.hasPrimaryFocus, isTrue);
    expect(_visibleOrder(tester), ['beta', 'gamma', 'alpha']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(calls, 3);
    expect(external.hasPrimaryFocus, isTrue);
  });

  testWidgets(
    'reparent retains handle ownership and never replays stale focus',
    (tester) async {
      final listKey = GlobalKey();
      final external = FocusNode();
      addTearDown(external.dispose);
      Widget app(bool reparent) => _app(
        listKey: listKey,
        reparent: reparent,
        after: ElevatedButton(
          focusNode: external,
          onPressed: () {},
          child: const Text('Outside'),
        ),
      );
      await tester.pumpWidget(app(false));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      final node = FocusManager.instance.primaryFocus;
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, same(node));
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(_visibleOrder(tester), ['alpha', 'beta', 'gamma']);
      external.requestFocus();
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(false));
      await tester.pumpAndSettle();
      expect(external.hasPrimaryFocus, isTrue);
    },
  );

  testWidgets(
    'removed and reintroduced handle does not reclaim external focus',
    (tester) async {
      final external = FocusNode();
      addTearDown(external.dispose);
      var items = _items.toList();
      late StateSetter update;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return _app(
              items: items,
              after: ElevatedButton(
                focusNode: external,
                onPressed: () {},
                child: const Text('Outside'),
              ),
              onItemsChange: (next) => set(() => items = next),
            );
          },
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      external.requestFocus();
      await tester.pump();
      update(() => items = [_items[1], _items[2]]);
      await tester.pumpAndSettle();
      update(() => items = _items.toList());
      await tester.pumpAndSettle();
      expect(external.hasPrimaryFocus, isTrue);
      expect(_undoButton(tester).onPressed, isNull);
    },
  );

  testWidgets('disposal during Undo does not leave a deferred focus request', (
    tester,
  ) async {
    final external = FocusNode();
    addTearDown(external.dispose);
    var visible = true;
    var calls = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, update) => visible
            ? _app(
                onItemsChange: (_) {
                  if (++calls == 2) update(() => visible = false);
                },
              )
            : MaterialApp(
                home: Scaffold(
                  body: ElevatedButton(
                    focusNode: external,
                    onPressed: () {},
                    child: const Text('Replacement'),
                  ),
                ),
              ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo reorder'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(external.hasPrimaryFocus, isTrue);
    expect(calls, 2);
    expect(find.byType(BeuiSortableListHandle), findsNothing);
  });

  testWidgets('Undo never focuses a disabled handle', (tester) async {
    var handlesEnabled = true;
    late StateSetter update;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, set) {
          update = set;
          return _app(handlesEnabled: handlesEnabled);
        },
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    update(() => handlesEnabled = false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo reorder'));
    await tester.pumpAndSettle();
    expect(_visibleOrder(tester), ['alpha', 'beta', 'gamma']);
    expect(_focusedHandle(), isNull);
    expect(_undoButton(tester).onPressed, isNull);
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

TextButton _undoButton(WidgetTester tester) =>
    tester.widget<TextButton>(find.byType(TextButton));

List<String> _visibleOrder(WidgetTester tester) {
  final items = _items.toList()
    ..sort(
      (a, b) => tester
          .getTopLeft(find.text(a.label))
          .dy
          .compareTo(tester.getTopLeft(find.text(b.label)).dy),
    );
  return items.map((item) => item.id).toList();
}

String? _focusedHandle() {
  String? label;
  FocusManager.instance.primaryFocus?.context?.visitAncestorElements((element) {
    if (element.widget case IconButton(:final tooltip)) {
      label = tooltip;
      return false;
    }
    return true;
  });
  return label;
}

Widget _ownershipApp({
  List<String>? items,
  ValueChanged<List<String>>? change,
  bool second = false,
  bool firstEnabled = true,
  bool secondEnabled = true,
  bool showFirst = true,
  int generation = 0,
  FocusNode? outside,
  VoidCallback? firstPress,
  VoidCallback? secondPress,
  Key? rootKey,
  bool reparent = false,
  bool visible = true,
}) {
  final list = BeuiSortableList<String>(
    key: rootKey,
    defaultItems: const ['A', 'B', 'C'],
    items: items,
    getItemId: (s) => s,
    getItemLabel: (s) => s,
    onItemsChange: change,
    children: (values) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BeuiSortableListGroup(
          children: [
            for (final id in values)
              BeuiSortableListItem(
                id: id,
                child: Row(
                  children: [
                    if (showFirst)
                      BeuiSortableListHandle(
                        key: ValueKey('$id-first-$generation'),
                        enabled: firstEnabled,
                        onPressed: firstPress,
                        child: Text('$id-first'),
                      ),
                    if (second)
                      BeuiSortableListHandle(
                        key: ValueKey('$id-second'),
                        enabled: secondEnabled,
                        onPressed: secondPress,
                        child: Text('$id-second'),
                      ),
                    Text(id),
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
    theme: ThemeData(extensions: [BeuiColors.light()]),
    home: Scaffold(
      body: Column(
        children: [
          if (visible)
            SizedBox(
              width: 400,
              child: reparent
                  ? Padding(padding: const EdgeInsets.all(1), child: list)
                  : list,
            ),
          TextButton(
            focusNode: outside,
            onPressed: () {},
            child: const Text('Outside'),
          ),
        ],
      ),
    ),
  );
}

FocusNode _ownershipNode(WidgetTester t, String label) =>
    Focus.of(t.element(find.text(label)));
Future<void> _ownershipFocus(WidgetTester t, String label) async {
  _ownershipNode(t, label).requestFocus();
  await t.pump();
}

VoidCallback _ownershipUndo(WidgetTester t) => t
    .widget<TextButton>(
      find.ancestor(
        of: find.text('Undo reorder'),
        matching: find.byType(TextButton),
      ),
    )
    .onPressed!;
Future<void> _ownershipKey(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await t.pumpAndSettle();
}

void _ownershipMain() {
  for (final transferRoot in [false, true]) {
    testWidgets(
      'handle transfers item owner and root=$transferRoot without stale Undo target',
      (t) async {
        final handleKey = GlobalKey();
        final external = FocusNode();
        addTearDown(external.dispose);
        var transferred = false;
        late StateSetter update;
        final changes = <String>[];
        Widget list(String root) => BeuiSortableList<String>(
          key: ValueKey(root),
          defaultItems: const ['A', 'B'],
          getItemId: (id) => id,
          getItemLabel: (id) => id,
          onItemsChange: (ids) => changes.add('$root:${ids.join()}'),
          children: (ids) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiSortableListGroup(
                children: [
                  for (final id in ids)
                    BeuiSortableListItem(
                      id: id,
                      child: Row(
                        children: [
                          Text('$root-$id'),
                          if (root ==
                                  (transferred && transferRoot
                                      ? 'right'
                                      : 'left') &&
                              id == (transferred && !transferRoot ? 'B' : 'A'))
                            BeuiSortableListHandle(
                              key: handleKey,
                              child: const Text('Transferred'),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              BeuiSortableListUndo(child: Text('Undo $root')),
            ],
          ),
        );
        await t.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: [BeuiColors.light()]),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, set) {
                  update = set;
                  return Column(
                    children: [
                      list('left'),
                      list('right'),
                      TextButton(
                        focusNode: external,
                        onPressed: () {},
                        child: const Text('Outside'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await _ownershipFocus(t, 'Transferred');
        final original = _ownershipNode(t, 'Transferred');
        await _ownershipKey(t, LogicalKeyboardKey.end);
        expect(changes, ['left:BA']);
        update(() => transferred = true);
        await t.pumpAndSettle();
        expect(_ownershipNode(t, 'Transferred'), same(original));
        external.requestFocus();
        await t.pump();
        t
            .widget<TextButton>(
              find.ancestor(
                of: find.text('Undo left'),
                matching: find.byType(TextButton),
              ),
            )
            .onPressed!();
        await t.pumpAndSettle();
        expect(external.hasPrimaryFocus, isTrue);
        expect(changes, ['left:BA', 'left:AB']);
        await _ownershipFocus(t, 'Transferred');
        await _ownershipKey(
          t,
          transferRoot ? LogicalKeyboardKey.end : LogicalKeyboardKey.home,
        );
        expect(changes.last, transferRoot ? 'right:BA' : 'left:BA');
        if (transferRoot) {
          external.requestFocus();
          await t.pump();
          t
              .widget<TextButton>(
                find.ancestor(
                  of: find.text('Undo right'),
                  matching: find.byType(TextButton),
                ),
              )
              .onPressed!();
          await t.pumpAndSettle();
          expect(original.hasPrimaryFocus, isTrue);
          expect(changes.last, 'right:AB');
        }
        await t.pumpWidget(const SizedBox());
        expect(original.parent, isNull);
        expect(original.hasFocus, isFalse);
      },
    );
  }
  for (final removeFirst in [false, true]) {
    testWidgets(
      'Undo selects eligible second handle after first removed=$removeFirst',
      (t) async {
        var changed = false;
        late StateSetter update;
        await t.pumpWidget(
          StatefulBuilder(
            builder: (context, set) {
              update = set;
              return _ownershipApp(
                second: true,
                showFirst: !changed || !removeFirst,
                firstEnabled: !changed,
              );
            },
          ),
        );
        await _ownershipFocus(t, 'A-second');
        final second = _ownershipNode(t, 'A-second');
        await _ownershipKey(t, LogicalKeyboardKey.end);
        update(() => changed = true);
        await t.pumpAndSettle();
        await t.tap(find.text('Undo reorder'));
        await t.pumpAndSettle();
        expect(_ownershipNode(t, 'A-second'), same(second));
        expect(second.hasPrimaryFocus, isTrue);
        await _ownershipKey(t, LogicalKeyboardKey.arrowDown);
        expect(
          t.getTopLeft(find.text('B-second')).dy,
          lessThan(t.getTopLeft(find.text('A-second')).dy),
        );
      },
    );
  }

  testWidgets('Enter activates the requested first handle callback', (t) async {
    final calls = <String>[];
    await t.pumpWidget(
      _ownershipApp(
        second: true,
        firstPress: () => calls.add('first'),
        secondPress: () => calls.add('second'),
      ),
    );
    await _ownershipFocus(t, 'A-first');
    await _ownershipKey(t, LogicalKeyboardKey.enter);
    expect(calls, ['first']);
  });

  testWidgets('two enabled handles preserve independent focus ownership', (
    t,
  ) async {
    await t.pumpWidget(_ownershipApp(second: true));
    expect(
      _ownershipNode(t, 'A-first'),
      isNot(same(_ownershipNode(t, 'A-second'))),
    );
    await _ownershipFocus(t, 'A-first');
    expect(_ownershipNode(t, 'A-first').context, isNotNull);
    final primary = FocusManager.instance.primaryFocus;
    expect(
      primary?.context?.findAncestorWidgetOfExactType<IconButton>()?.icon,
      isA<Text>().having((w) => w.data, 'focused handle', 'A-first'),
    );
  });
  testWidgets('disabled second handle does not disable first handle', (
    t,
  ) async {
    var calls = 0;
    await t.pumpWidget(
      _ownershipApp(second: true, secondEnabled: false, change: (_) => calls++),
    );
    await _ownershipFocus(t, 'A-first');
    await _ownershipKey(t, LogicalKeyboardKey.arrowDown);
    expect(calls, 1);
  });
  testWidgets('removing second handle leaves first usable', (t) async {
    var calls = 0;
    await t.pumpWidget(_ownershipApp(second: true, change: (_) => calls++));
    await _ownershipFocus(t, 'A-second');
    await t.pumpWidget(_ownershipApp(second: false, change: (_) => calls++));
    await t.pumpAndSettle();
    await _ownershipFocus(t, 'A-first');
    await _ownershipKey(t, LogicalKeyboardKey.arrowDown);
    expect(calls, 1);
  });
  testWidgets('key remount keeps replacement handle usable', (t) async {
    var calls = 0;
    await t.pumpWidget(_ownershipApp(change: (_) => calls++));
    await _ownershipFocus(t, 'A-first');
    await t.pumpWidget(_ownershipApp(generation: 1, change: (_) => calls++));
    await t.pumpAndSettle();
    await _ownershipFocus(t, 'A-first');
    await _ownershipKey(t, LogicalKeyboardKey.arrowDown);
    expect(calls, 1);
  });
  for (final accept in [true, false]) {
    testWidgets(
      'controlled Undo accept=$accept respects already focused external owner',
      (t) async {
        final external = FocusNode();
        addTearDown(external.dispose);
        var values = ['A', 'B', 'C'];
        var calls = 0;
        await t.pumpWidget(
          StatefulBuilder(
            builder: (context, set) => _ownershipApp(
              items: values,
              outside: external,
              change: (next) {
                calls++;
                if (calls == 1 || accept) set(() => values = next);
                if (calls == 2) external.requestFocus();
              },
            ),
          ),
        );
        await _ownershipFocus(t, 'A-first');
        await _ownershipKey(t, LogicalKeyboardKey.end);
        external.requestFocus();
        await t.pump();
        expect(external.hasPrimaryFocus, isTrue);
        _ownershipUndo(t)();
        await t.pumpAndSettle();
        expect(external.hasPrimaryFocus, isTrue);
        expect(values, accept ? ['A', 'B', 'C'] : ['B', 'C', 'A']);
        expect(calls, 2);
      },
    );
  }
  testWidgets(
    'membership removes focused handle and reintroduces fresh usable handle',
    (t) async {
      var values = ['A', 'B', 'C'];
      late StateSetter set;
      var calls = 0;
      await t.pumpWidget(
        StatefulBuilder(
          builder: (c, s) {
            set = s;
            return _ownershipApp(items: values, change: (_) => calls++);
          },
        ),
      );
      await _ownershipFocus(t, 'A-first');
      set(() => values = ['B', 'C']);
      await t.pumpAndSettle();
      set(() => values = ['A', 'B', 'C']);
      await t.pumpAndSettle();
      await _ownershipFocus(t, 'A-first');
      await _ownershipKey(t, LogicalKeyboardKey.arrowDown);
      expect(calls, 1);
    },
  );
  testWidgets('focused root reparent and disposal preserve external focus', (
    t,
  ) async {
    final root = GlobalKey();
    final external = FocusNode();
    addTearDown(external.dispose);
    await t.pumpWidget(_ownershipApp(rootKey: root, outside: external));
    await _ownershipFocus(t, 'A-first');
    final original = FocusManager.instance.primaryFocus;
    await t.pumpWidget(
      _ownershipApp(rootKey: root, reparent: true, outside: external),
    );
    await t.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(original));
    external.requestFocus();
    await t.pump();
    await t.pumpWidget(
      _ownershipApp(rootKey: root, visible: false, outside: external),
    );
    await t.pumpAndSettle();
    expect(external.hasPrimaryFocus, isTrue);
  });
  testWidgets('disabled sole handle is not chosen by Undo', (t) async {
    var enabled = true;
    late StateSetter set;
    await t.pumpWidget(
      StatefulBuilder(
        builder: (c, s) {
          set = s;
          return _ownershipApp(firstEnabled: enabled);
        },
      ),
    );
    await _ownershipFocus(t, 'A-first');
    await _ownershipKey(t, LogicalKeyboardKey.end);
    set(() => enabled = false);
    await t.pumpAndSettle();
    _ownershipUndo(t)();
    await t.pumpAndSettle();
    expect(_ownershipNode(t, 'A-first').hasFocus, isFalse);
  });
}
