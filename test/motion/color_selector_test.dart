import 'dart:ui' show Tristate;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _colors = [
  BeuiColorSelectorItem(value: 'blue', color: Color(0xff3478f6), label: 'Blue'),
  BeuiColorSelectorItem(value: 'red', color: Color(0xffe55656), label: 'Red'),
];

const _keyedColors = [
  BeuiColorSelectorItem(
    key: ValueKey('blue'),
    value: 'blue',
    color: Color(0xff3478f6),
    label: 'Blue',
  ),
  BeuiColorSelectorItem(
    key: ValueKey('red'),
    value: 'red',
    color: Color(0xffe55656),
    label: 'Red',
  ),
  BeuiColorSelectorItem(
    key: ValueKey('green'),
    value: 'green',
    color: Color(0xff36a269),
    label: 'Green',
  ),
];

Widget _selector({
  String? value,
  String? defaultValue = 'blue',
  ValueChanged<String>? onChanged,
  bool reduce = false,
}) => beuiTestApp(
  BeuiColorSelector(
    value: value,
    defaultValue: defaultValue,
    onChanged: onChanged,
    children: const [
      BeuiColorSelectorLabel(child: Text('Accent')),
      BeuiColorSelectorList(children: _colors),
    ],
  ),
  reduce: reduce,
);

void main() {
  testWidgets('disabled choices reject taps and arrows skip them', (
    tester,
  ) async {
    final changes = <String>[];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiColorSelector(
          defaultValue: 'blue',
          onChanged: changes.add,
          children: const [
            BeuiColorSelectorItem(
              value: 'blue',
              color: Colors.blue,
              label: 'Blue',
            ),
            BeuiColorSelectorItem(
              value: 'red',
              color: Colors.red,
              label: 'Red',
              disabled: true,
            ),
            BeuiColorSelectorItem(
              value: 'green',
              color: Colors.green,
              label: 'Green',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Red'));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    await tester.tap(find.bySemanticsLabel('Blue'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(changes, ['green']);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Red'))
          .flagsCollection
          .isEnabled,
      Tristate.isFalse,
    );
  });

  testWidgets('Tab enters the checked choice and then leaves the group', (
    tester,
  ) async {
    final after = FocusNode();
    addTearDown(after.dispose);
    final changes = <String>[];
    await tester.pumpWidget(
      beuiTestApp(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BeuiColorSelector(
              defaultValue: 'red',
              onChanged: changes.add,
              children: _colors,
            ),
            TextButton(
              focusNode: after,
              onPressed: () {},
              child: const Text('After'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(changes, ['blue']);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(after.hasPrimaryFocus, isTrue);
  });

  testWidgets('label sits above its swatch list', (tester) async {
    await tester.pumpWidget(_selector());
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(find.text('Accent')).dy + 12,
      lessThanOrEqualTo(tester.getTopLeft(find.bySemanticsLabel('Blue')).dy),
    );
  });

  testWidgets('selection ring hops above the row and settles on its swatch', (
    tester,
  ) async {
    await tester.pumpWidget(_selector());
    await tester.pumpAndSettle();
    final ring = find.byKey(const ValueKey('beui_color_selector_ring'));
    final start = tester.getCenter(ring);
    await tester.tap(find.bySemanticsLabel('Red'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final middle = tester.getCenter(ring);
    expect(middle.dy, lessThan(start.dy - 1));
    expect(middle.dx, greaterThan(start.dx));
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(ring),
      tester.getCenter(find.bySemanticsLabel('Red')),
    );
  });

  testWidgets('space activates a focused unselected swatch', (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(
      _selector(defaultValue: null, onChanged: changes.add),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(changes, ['blue']);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Blue')),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
  });

  testWidgets('tap selects an option', (tester) async {
    String? selected;
    await tester.pumpWidget(_selector(onChanged: (value) => selected = value));
    await tester.tap(find.bySemanticsLabel('Red'));
    await tester.pumpAndSettle();
    expect(selected, 'red');
    expect(
      tester.getSemantics(find.bySemanticsLabel('Red')),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
  });

  testWidgets('arrow keys move selection and focus', (tester) async {
    String? selected;
    await tester.pumpWidget(_selector(onChanged: (value) => selected = value));
    await tester.tap(find.bySemanticsLabel('Blue'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(selected, 'red');
  });

  testWidgets('keyboard navigation uses only live children in child order', (
    tester,
  ) async {
    final changes = <String>[];
    final choices = ValueNotifier<List<Widget>>([_colors[0], _keyedColors[1]]);
    addTearDown(choices.dispose);

    await tester.pumpWidget(
      beuiTestApp(
        ValueListenableBuilder<List<Widget>>(
          valueListenable: choices,
          builder: (context, children, _) => BeuiColorSelector(
            defaultValue: 'red',
            onChanged: changes.add,
            children: children,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Red'));
    await tester.pumpAndSettle();
    final retainedFocus = FocusManager.instance.primaryFocus!;
    choices.value = [
      const BeuiColorSelectorItem(
        value: 'green',
        color: Color(0xff36a269),
        label: 'Green',
      ),
      _keyedColors[1],
    ];
    await tester.pumpAndSettle();
    expect(retainedFocus.context?.mounted, isTrue);
    expect(FocusManager.instance.primaryFocus, same(retainedFocus));
    expect(find.bySemanticsLabel('Blue'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(changes, ['green']);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Green')),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Red')),
      isSemantics(hasCheckedState: true, isChecked: false),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(changes, ['green', 'red']);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Red')),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('controlled selection can transition to null', (tester) async {
    final changes = <String>[];
    Widget buildSelector(String? value) => beuiTestApp(
      BeuiColorSelector(
        value: value,
        onChanged: changes.add,
        children: _colors,
      ),
    );

    await tester.pumpWidget(buildSelector('red'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.bySemanticsLabel('Red')),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
    await tester.pumpWidget(buildSelector(null));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('beui_color_selector_ring')),
      findsNothing,
    );
    for (final label in ['Blue', 'Red']) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(hasCheckedState: true, isChecked: false),
      );
    }
    await tester.tap(find.bySemanticsLabel('Blue'));
    await tester.pumpAndSettle();
    expect(changes, ['blue']);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Blue')),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
  });

  testWidgets('controlled selection can clear while children become empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiColorSelector(value: 'red', children: _colors)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('beui_color_selector_ring')),
      findsOneWidget,
    );
    await tester.pumpWidget(beuiTestApp(const BeuiColorSelector(children: [])));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('beui_color_selector_ring')),
      findsNothing,
    );
  });

  testWidgets('empty choices can repopulate and select again', (tester) async {
    final changes = <String>[];
    final choices = ValueNotifier<List<Widget>>(_keyedColors);
    addTearDown(choices.dispose);
    await tester.pumpWidget(
      beuiTestApp(
        ValueListenableBuilder<List<Widget>>(
          valueListenable: choices,
          builder: (context, children, _) => BeuiColorSelector(
            defaultValue: 'blue',
            onChanged: changes.add,
            children: children,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final ring = find.byKey(const ValueKey('beui_color_selector_ring'));
    expect(ring, findsOneWidget);
    choices.value = const [];
    await tester.pumpAndSettle();
    expect(ring, findsNothing);
    choices.value = _keyedColors;
    await tester.pumpAndSettle();
    expect(tester.getSize(ring), const Size(52, 52));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Blue')),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
    await tester.tap(find.bySemanticsLabel('Red'));
    await tester.pumpAndSettle();
    expect(changes, ['red']);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Red')),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
  });

  testWidgets('controlled rejection keeps checked state and permits retry', (
    tester,
  ) async {
    final changes = <String>[];
    final selected = ValueNotifier('blue');
    addTearDown(selected.dispose);
    await tester.pumpWidget(
      beuiTestApp(
        ValueListenableBuilder<String>(
          valueListenable: selected,
          builder: (context, value, _) => BeuiColorSelector(
            value: value,
            onChanged: changes.add,
            children: _keyedColors,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final ring = find.byKey(const ValueKey('beui_color_selector_ring'));
    final originalRect = tester.getRect(ring);
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.bySemanticsLabel('Red'));
      await tester.pumpAndSettle();
      expect(tester.getRect(ring), originalRect);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Blue')),
        isSemantics(hasCheckedState: true, isChecked: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Red')),
        isSemantics(hasCheckedState: true, isChecked: false),
      );
    }
    expect(changes, ['red', 'red']);
    selected.value = 'red';
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.bySemanticsLabel('Red')),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
    expect(
      (tester.getRect(ring).center -
              tester.getRect(find.bySemanticsLabel('Red')).center)
          .distance,
      lessThan(0.001),
    );
    expect(tester.getSize(ring), const Size(52, 52));
    final border =
        (tester.widget<DecoratedBox>(ring).decoration as BoxDecoration).border!
            as Border;
    expect(border.top.color, const Color(0xffe55656).withValues(alpha: 0.65));
  });

  testWidgets('removing the selected child removes its ring', (tester) async {
    final changes = <String>[];
    final choices = ValueNotifier<List<Widget>>(_keyedColors);
    addTearDown(choices.dispose);
    await tester.pumpWidget(
      beuiTestApp(
        ValueListenableBuilder<List<Widget>>(
          valueListenable: choices,
          builder: (context, children, _) => BeuiColorSelector(
            value: 'red',
            onChanged: changes.add,
            children: children,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('beui_color_selector_ring')),
      findsOneWidget,
    );

    choices.value = [_keyedColors[0], _keyedColors[2]];
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('beui_color_selector_ring')),
      findsNothing,
    );
    for (final label in ['Blue', 'Green']) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(hasCheckedState: true, isChecked: false),
      );
    }
    expect(changes, isEmpty);
    choices.value = _keyedColors;
    await tester.pumpAndSettle();
    expect(
      tester
          .getRect(find.byKey(const ValueKey('beui_color_selector_ring')))
          .center,
      tester.getRect(find.bySemanticsLabel('Red')).center,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Red')),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
  });

  testWidgets('reordering retained const children updates keyboard order', (
    tester,
  ) async {
    final changes = <String>[];
    final choices = ValueNotifier<List<Widget>>(_keyedColors);
    addTearDown(choices.dispose);
    await tester.pumpWidget(
      beuiTestApp(
        ValueListenableBuilder<List<Widget>>(
          valueListenable: choices,
          builder: (context, children, _) => BeuiColorSelector(
            defaultValue: 'red',
            onChanged: changes.add,
            children: children,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Red'));
    await tester.pumpAndSettle();
    final retainedFocus = FocusManager.instance.primaryFocus;
    choices.value = [_keyedColors[0], _keyedColors[2], _keyedColors[1]];
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(retainedFocus));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(changes, ['blue']);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Blue')),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
  });

  testWidgets('changing a selected item value drops its stale ring', (
    tester,
  ) async {
    final choices = ValueNotifier<List<Widget>>(_colors);
    addTearDown(choices.dispose);
    await tester.pumpWidget(
      beuiTestApp(
        ValueListenableBuilder<List<Widget>>(
          valueListenable: choices,
          builder: (context, children, _) =>
              BeuiColorSelector(value: 'blue', children: children),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final ring = find.byKey(const ValueKey('beui_color_selector_ring'));
    expect(ring, findsOneWidget);
    choices.value = [
      const BeuiColorSelectorItem(
        value: 'green',
        color: Color(0xff36a269),
        label: 'Green',
      ),
      _colors[1],
    ];
    await tester.pumpAndSettle();
    expect(ring, findsNothing);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Green')),
      isSemantics(hasCheckedState: true, isChecked: false),
    );
    choices.value = _colors;
    await tester.pumpAndSettle();
    expect(ring, findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Blue')),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
  });

  testWidgets('changing selected swatch color updates ring without moving it', (
    tester,
  ) async {
    final choices = ValueNotifier<List<Widget>>([
      const BeuiColorSelectorItem(
        value: 'blue',
        color: Color(0xff3478f6),
        label: 'Blue',
      ),
      _colors[1],
    ]);
    addTearDown(choices.dispose);
    await tester.pumpWidget(
      beuiTestApp(
        ValueListenableBuilder<List<Widget>>(
          valueListenable: choices,
          builder: (context, children, _) =>
              BeuiColorSelector(value: 'blue', children: children),
        ),
        reduce: true,
      ),
    );
    await tester.pumpAndSettle();
    final ring = find.byKey(const ValueKey('beui_color_selector_ring'));
    final originalRect = tester.getRect(ring);
    final originalBorder =
        (tester.widget<DecoratedBox>(ring).decoration as BoxDecoration).border!
            as Border;
    expect(
      originalBorder.top.color,
      const Color(0xff3478f6).withValues(alpha: 0.65),
    );
    choices.value = [
      const BeuiColorSelectorItem(
        value: 'blue',
        color: Color(0xff36a269),
        label: 'Blue',
      ),
      _colors[1],
    ];
    await tester.pumpAndSettle();
    expect(tester.getRect(ring), originalRect);
    final box = tester.widget<DecoratedBox>(ring);
    final border = (box.decoration as BoxDecoration).border! as Border;
    expect(border.top.color, const Color(0xff36a269).withValues(alpha: 0.65));
  });

  testWidgets(
    'reduced motion snaps the ring and never scales a pressed swatch',
    (tester) async {
      await tester.pumpWidget(_selector(value: 'red', reduce: true));
      await tester.pumpAndSettle();
      final ring = find.byKey(const ValueKey('beui_color_selector_ring'));
      final red = find.bySemanticsLabel('Red');
      expect(tester.getRect(ring), tester.getRect(red).inflate(4));
      final before = tester.getRect(red);
      final press = await tester.startGesture(tester.getCenter(red));
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getRect(red), before);
        for (final transform in tester.widgetList<Transform>(
          find.descendant(of: red, matching: find.byType(Transform)),
        )) {
          expect(transform.transform, Matrix4.identity());
        }
      }
      await press.up();
    },
  );

  for (final reduce in [false, true]) {
    testWidgets('selection ring is 52px in swatch color, reduced: $reduce', (
      tester,
    ) async {
      await tester.pumpWidget(_selector(value: 'blue', reduce: reduce));
      await tester.pumpAndSettle();
      final ring = find.byKey(const ValueKey('beui_color_selector_ring'));
      expect(ring, findsOneWidget);
      final size = tester.getSize(ring);
      expect(size, const Size(52, 52));
      final selector = tester.getSize(find.byType(BeuiColorSelector));
      expect(size.width, lessThan(selector.width / 2));
      final blue = tester.getRect(find.bySemanticsLabel('Blue'));
      final ringRect = tester.getRect(ring);
      expect(blue.size, const Size(44, 44));
      expect(ringRect, blue.inflate(4));
      final positioned = tester.widget<Positioned>(
        find.ancestor(of: ring, matching: find.byType(Positioned)).first,
      );
      expect(positioned.width, 52);
      expect(positioned.height, 52);
      expect(positioned.right, isNull);
      expect(positioned.bottom, isNull);
      final box = tester.widget<DecoratedBox>(ring);
      final border = (box.decoration as BoxDecoration).border! as Border;
      expect(border.top.color, const Color(0xff3478f6).withValues(alpha: 0.65));
      expect(border.top.width, 2);
    });
  }

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(_selector());
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiColorSelector),
      matchesGoldenFile('goldens/beui_color_selector.png'),
    );
  });
}
