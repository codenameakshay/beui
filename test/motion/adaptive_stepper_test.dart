import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beui/src/motion/adaptive_stepper.dart';
import '../support.dart';

Widget _stepper({
  double defaultValue = 2,
  double min = 0,
  double max = 10,
  double step = 1,
  bool disabled = false,
  bool reduce = false,
  String Function(double)? formatValueText,
}) => beuiTestApp(
  BeuiAdaptiveStepper(
    defaultValue: defaultValue,
    min: min,
    max: max,
    step: step,
    disabled: disabled,
    formatValueText: formatValueText,
    semanticLabel: 'Guests',
    children: const [
      BeuiAdaptiveStepperDecrement(),
      BeuiAdaptiveStepperValue(),
      BeuiAdaptiveStepperIncrement(),
    ],
  ),
  reduce: reduce,
);

void main() {
  testWidgets('increment and decrement update the uncontrolled value', (
    tester,
  ) async {
    await tester.pumpWidget(_stepper());
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Increase value'));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Decrease value'));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('clamps initial and controlled values to the range', (
    tester,
  ) async {
    await tester.pumpWidget(_stepper(defaultValue: -4, max: 3));
    expect(find.text('0'), findsOneWidget);

    await tester.pumpWidget(
      beuiTestApp(
        const BeuiAdaptiveStepper(
          value: 99,
          min: 0,
          max: 3,
          children: [
            BeuiAdaptiveStepperDecrement(),
            BeuiAdaptiveStepperValue(),
            BeuiAdaptiveStepperIncrement(),
          ],
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.bySemanticsLabel('Increase value'), findsNothing);
  });

  testWidgets('formatValueText changes the announced text, not the number', (
    tester,
  ) async {
    await tester.pumpWidget(
      _stepper(formatValueText: (value) => '${value.toInt()} guests'),
    );
    expect(find.text('2'), findsOneWidget);
    expect(find.bySemanticsLabel('2 guests'), findsOneWidget);
  });

  testWidgets('hides decrement at minimum and keeps increment available', (
    tester,
  ) async {
    await tester.pumpWidget(_stepper(defaultValue: 0, max: 3));
    expect(find.bySemanticsLabel('Decrease value'), findsNothing);
    expect(find.bySemanticsLabel('Increase value'), findsOneWidget);
    expect(
      tester.getSize(find.byType(BeuiAdaptiveStepper)),
      const Size(216, 48),
    );
  });

  testWidgets('keyboard activation transfers focus off a disappearing action', (
    tester,
  ) async {
    await tester.pumpWidget(_stepper(defaultValue: 1, max: 2));
    final decrementNode = tester
        .widgetList<FocusableActionDetector>(
          find.byType(FocusableActionDetector),
        )
        .first
        .focusNode!;
    decrementNode.requestFocus();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Decrease value');

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Increase value');
  });

  testWidgets('reduced motion changes value without vertical rolling', (
    tester,
  ) async {
    await tester.pumpWidget(_stepper(reduce: true));
    await tester.tap(find.bySemanticsLabel('Increase value'));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('3'), findsOneWidget);
    for (final transition in tester.widgetList<SlideTransition>(
      find.byType(SlideTransition),
    )) {
      expect(transition.position.value, Offset.zero);
    }
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(_stepper(defaultValue: 2, min: 0, max: 3));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiAdaptiveStepper),
      matchesGoldenFile('goldens/beui_adaptive_stepper.png'),
    );
  });
}
