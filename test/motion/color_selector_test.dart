import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _colors = [
  BeuiColorSelectorItem(value: 'blue', color: Color(0xff3478f6), label: 'Blue'),
  BeuiColorSelectorItem(value: 'red', color: Color(0xffe55656), label: 'Red'),
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

  testWidgets(
    'reduced motion positions ring directly and drops motion builder',
    (tester) async {
      await tester.pumpWidget(_selector(value: 'red', reduce: true));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('beui_color_selector_ring')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString().contains('MotionBuilder'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(_selector());
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiColorSelector),
      matchesGoldenFile('goldens/beui_color_selector.png'),
    );
  });
}
