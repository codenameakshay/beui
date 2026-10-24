import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beui/beui.dart';
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
  testWidgets(
    'liquid separation overshoots then settles at 600ms and retargets',
    (tester) async {
      await tester.pumpWidget(_stepper(defaultValue: 0));
      final value = find.byType(BeuiAdaptiveStepperValue);
      expect(tester.getSize(value).width, 152);
      await tester.tap(find.bySemanticsLabel('Increase value'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getSize(value).width, lessThan(88));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getSize(value).width, closeTo(88, .01));
      await tester.tap(find.bySemanticsLabel('Decrease value'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final interrupted = tester.getSize(value).width;
      await tester.tap(find.bySemanticsLabel('Increase value'));
      await tester.pump();
      expect(tester.getSize(value).width, closeTo(interrupted, .01));
      await tester.pumpAndSettle();
      expect(tester.getSize(value).width, closeTo(88, .01));
    },
  );
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

  testWidgets('actions leave their surface to the shared liquid layer', (
    tester,
  ) async {
    await tester.pumpWidget(_stepper(defaultValue: 2, min: 0, max: 3));
    await tester.pumpAndSettle();
    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.bySemanticsLabel('Increase value'),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final box = container.decoration! as BoxDecoration;
    expect(box.color, Colors.transparent);
    expect(box.borderRadius, BorderRadius.circular(24));
    expect(box.border, Border.all(color: Colors.transparent));
  });

  for (final increase in [false, true]) {
    testWidgets('hovered action clears its fill at ${increase ? 'max' : 'min'}', (
      tester,
    ) async {
      await tester.pumpWidget(
        _stepper(defaultValue: increase ? 2 : 1, min: 0, max: 3),
      );
      await tester.pumpAndSettle();
      final label = increase ? 'Increase value' : 'Decrease value';
      final part = find.byType(
        increase ? BeuiAdaptiveStepperIncrement : BeuiAdaptiveStepperDecrement,
      );
      final container = find.descendant(
        of: part,
        matching: find.byType(AnimatedContainer),
      );
      BoxDecoration decoration() =>
          tester.widget<AnimatedContainer>(container).decoration!
              as BoxDecoration;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await tester.pump();
      final hoverPoint =
          tester.getTopLeft(find.bySemanticsLabel(label)) +
          Offset(increase ? 8 : 40, 24);
      await mouse.moveTo(hoverPoint);
      await tester.pumpAndSettle();
      expect(decoration().color, BeuiColors.light().muted);

      await tester.tapAt(hoverPoint);
      await tester.pump();
      expect(find.text(increase ? '3' : '0'), findsOneWidget);
      expect(find.bySemanticsLabel(label), findsNothing);
      expect(decoration().color, Colors.transparent);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.descendant(of: part, matching: find.byType(AnimatedOpacity)),
            )
            .opacity,
        0,
      );
      // Hidden actions stay mounted; entering their bounds must not refill them.
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      await mouse.moveTo(tester.getCenter(container));
      await tester.pumpAndSettle();
      expect(decoration().color, Colors.transparent);
      expect(
        find.bySemanticsLabel(increase ? 'Decrease value' : 'Increase value'),
        findsOneWidget,
      );
    });
  }

  testWidgets('hover fills the action with muted', (tester) async {
    await tester.pumpWidget(_stepper(defaultValue: 2, min: 0, max: 3));
    await tester.pumpAndSettle();
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byIcon(LucideIcons.plus)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.bySemanticsLabel('Increase value'),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(
      (container.decoration! as BoxDecoration).color,
      BeuiColors.light().muted,
    );
  });
}
