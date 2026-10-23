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
