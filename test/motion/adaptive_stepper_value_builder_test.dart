import 'dart:ui' as ui;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

Widget _stepper({
  double? value,
  double defaultValue = 2,
  double min = 0,
  double max = 10,
  double step = 1,
  bool disabled = false,
  bool reduce = false,
  ValueChanged<double>? onChanged,
  String Function(double)? formatValueText,
  Widget Function(BuildContext, double)? builder,
}) => beuiTestApp(
  BeuiAdaptiveStepper(
    value: value,
    defaultValue: defaultValue,
    min: min,
    max: max,
    step: step,
    disabled: disabled,
    onChanged: onChanged,
    formatValueText: formatValueText,
    semanticLabel: 'Guests',
    children: [
      const BeuiAdaptiveStepperDecrement(),
      BeuiAdaptiveStepperValue(builder: builder),
      const BeuiAdaptiveStepperIncrement(),
    ],
  ),
  reduce: reduce,
);

double _opacityOf(WidgetTester tester, String text) {
  final content = find.text(text).first;
  final opacity = find
      .ancestor(of: content, matching: find.byType(Opacity))
      .first;
  final renderOpacity = tester.renderObject<RenderOpacity>(opacity);
  return renderOpacity.opacity;
}

void _expectPaint(
  WidgetTester tester,
  String text, {
  required double opacity,
  required double sigma,
}) {
  final content = find.text(text).first;
  final opacityFinder = find
      .ancestor(of: content, matching: find.byType(Opacity))
      .first;
  final renderOpacity = tester.renderObject<RenderOpacity>(opacityFinder);
  expect(renderOpacity.opacity, closeTo(opacity, 1e-6));
  final opacityLayer = renderOpacity.debugLayer;
  expect(opacityLayer, isA<OpacityLayer>());
  expect((opacityLayer! as OpacityLayer).alpha, (opacity * 255).round());
  final filter = find
      .ancestor(of: content, matching: find.byType(ImageFiltered))
      .first;
  final layer = tester.renderObject(filter).debugLayer! as ImageFilterLayer;
  expect(layer.imageFilter, ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma));
}

void main() {
  testWidgets('const default value keeps its numeric renderer', (tester) async {
    const value = BeuiAdaptiveStepperValue();
    expect(value.builder, isNull);
    await tester.pumpWidget(_stepper());

    final switcher = tester.widget<AnimatedSwitcher>(
      find.descendant(
        of: find.byType(BeuiAdaptiveStepperValue),
        matching: find.byType(AnimatedSwitcher),
      ),
    );
    expect(switcher.duration, const Duration(milliseconds: 180));
    expect(switcher.reverseDuration, const Duration(milliseconds: 120));
    expect(switcher.switchOutCurve, const Cubic(0.16, 1, 0.3, 1));
    expect(find.text('2'), findsOneWidget);
    final renderedNumber = tester.widget<Text>(find.text('2'));
    expect(renderedNumber.key, const ValueKey<String>('2'));
    expect(renderedNumber.maxLines, 1);
    expect(renderedNumber.overflow, TextOverflow.fade);
    expect(renderedNumber.softWrap, isFalse);
    expect(
      find.descendant(
        of: find.byType(BeuiAdaptiveStepperValue),
        matching: find.byType(SlideTransition),
      ),
      findsOneWidget,
    );
    expect(find.byType(ImageFiltered), findsNothing);
    expect(
      tester.getSize(find.byType(BeuiAdaptiveStepper)),
      const Size(216, 48),
    );
  });

  testWidgets('builder receives the effective clamped numeric value once', (
    tester,
  ) async {
    final values = <double>[];
    await tester.pumpWidget(
      _stepper(
        value: 99,
        min: 1,
        max: 3,
        builder: (context, value) {
          values.add(value);
          return Text('value ${value.toInt()}');
        },
      ),
    );
    expect(values, [3]);
    expect(find.text('value 3'), findsOneWidget);
  });

  testWidgets('geometry frames reuse the ordinary build output', (
    tester,
  ) async {
    final values = <double>[];
    Widget at(double value) => _stepper(
      value: value,
      max: 3,
      builder: (context, effective) {
        values.add(effective);
        return Text('value ${effective.toInt()}');
      },
    );
    await tester.pumpWidget(at(2));
    await tester.pumpAndSettle();
    expect(values, [2]);
    await tester.pumpWidget(at(3));
    expect(values, [2, 3]);
    await tester.pump(const Duration(milliseconds: 90));
    expect(values, [2, 3]);
    expect(find.text('value 3'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(values, [2, 3]);
    expect(tester.getSize(find.byType(BeuiAdaptiveStepperValue)).width, 152);
  });

  testWidgets('non-finite inputs and empty bounds use effective values', (
    tester,
  ) async {
    double? built;
    await tester.pumpWidget(
      _stepper(
        value: double.nan,
        min: 2,
        max: 4,
        builder: (context, value) {
          built = value;
          return Text(value.toString());
        },
      ),
    );
    expect(built, 2);
    expect(find.text('2.0'), findsOneWidget);

    await tester.pumpWidget(
      _stepper(
        value: double.infinity,
        min: 4,
        max: 2,
        builder: (context, value) => Text(value.toString()),
      ),
    );
    expect(find.text('4.0'), findsOneWidget);

    await tester.pumpWidget(
      KeyedSubtree(
        key: const ValueKey('fresh uncontrolled non-finite default'),
        child: _stepper(
          defaultValue: double.nan,
          min: double.nan,
          max: 3,
          builder: (context, value) => Text(value.toString()),
        ),
      ),
    );
    expect(find.text('0.0'), findsOneWidget);
  });

  testWidgets('uncontrolled and controlled values retain owner behavior', (
    tester,
  ) async {
    final changes = <double>[];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiAdaptiveStepper(
          defaultValue: 2,
          min: 0,
          max: 3,
          onChanged: changes.add,
          children: [
            const BeuiAdaptiveStepperDecrement(),
            BeuiAdaptiveStepperValue(
              builder: (context, value) => Text('mine ${value.toInt()}'),
            ),
            const BeuiAdaptiveStepperIncrement(),
          ],
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Increase value'));
    await tester.pumpAndSettle();
    expect(changes, [3]);
    expect(find.text('mine 3'), findsOneWidget);

    final controlledValue = ValueNotifier<double>(2);
    addTearDown(controlledValue.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<double>(
        valueListenable: controlledValue,
        builder: (context, value, child) => beuiTestApp(
          BeuiAdaptiveStepper(
            value: value,
            min: 0,
            max: 3,
            onChanged: (next) {
              changes.add(next);
              controlledValue.value = next;
            },
            children: [
              const BeuiAdaptiveStepperDecrement(),
              BeuiAdaptiveStepperValue(
                builder: (context, effective) =>
                    Text('controlled ${effective.toInt()}'),
              ),
              const BeuiAdaptiveStepperIncrement(),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Increase value'));
    await tester.pumpAndSettle();
    expect(changes, [3, 3]);
    expect(find.text('controlled 3'), findsOneWidget);

    var refusedCalls = 0;
    await tester.pumpWidget(
      _stepper(
        value: 2,
        min: 0,
        max: 3,
        onChanged: (_) => refusedCalls++,
        builder: (context, value) => Text('refused ${value.toInt()}'),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Increase value'));
    await tester.pumpAndSettle();
    expect(refusedCalls, 1);
    expect(find.text('refused 2'), findsOneWidget);
  });

  testWidgets('disabled actions do not call the owner', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var calls = 0;
      await tester.pumpWidget(
        beuiTestApp(
          BeuiAdaptiveStepper(
            defaultValue: 2,
            min: 0,
            max: 3,
            disabled: true,
            onChanged: (_) => calls++,
            children: [
              const BeuiAdaptiveStepperDecrement(),
              BeuiAdaptiveStepperValue(
                builder: (context, value) => Text('value ${value.toInt()}'),
              ),
              const BeuiAdaptiveStepperIncrement(),
            ],
          ),
        ),
      );
      final action = tester.getSemantics(
        find.bySemanticsLabel('Increase value'),
      );
      expect(action.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      await tester.tap(find.bySemanticsLabel('Increase value'));
      await tester.pump();
      expect(calls, 0);
      expect(find.text('value 2'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('parent formatter owns speech and custom output is decorative', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _stepper(
          min: 1,
          formatValueText: (value) => '${value.toInt()} mines',
          builder: (context, value) => Semantics(
            button: true,
            label: 'Child action',
            onTap: () {},
            child: Text('${value.toInt()} mines'),
          ),
        ),
      );

      final parent = tester.getSemantics(find.bySemanticsLabel('Guests'));
      expect(parent.getSemanticsData().value, '2 mines');
      expect(find.bySemanticsLabel('2 mines'), findsOneWidget);
      final output = tester.getSemantics(find.bySemanticsLabel('2 mines'));
      expect(output.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      expect(find.bySemanticsLabel('Child action'), findsNothing);
      expect(find.byType(ExcludeSemantics), findsWidgets);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('semantic owner activation still invokes the parent action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final changes = <double>[];
      await tester.pumpWidget(
        beuiTestApp(
          BeuiAdaptiveStepper(
            defaultValue: 2,
            min: 0,
            max: 3,
            onChanged: changes.add,
            children: [
              const BeuiAdaptiveStepperDecrement(),
              BeuiAdaptiveStepperValue(
                builder: (context, value) => Text('value ${value.toInt()}'),
              ),
              const BeuiAdaptiveStepperIncrement(),
            ],
          ),
        ),
      );
      final action = tester.getSemantics(
        find.bySemanticsLabel('Increase value'),
      );
      expect(find.bySemanticsLabel('Increase value'), findsOneWidget);
      expect(action.getSemanticsData().label, 'Increase value');
      expect(action.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(
        action.getSemanticsData().flagsCollection.isEnabled,
        ui.Tristate.isTrue,
      );
      expect(action.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      action.owner!.performAction(action.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(changes, [3]);
      expect(find.text('value 3'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('custom descendants cannot receive pointer or focus input', (
    tester,
  ) async {
    final childFocus = FocusNode(debugLabel: 'decorative value');
    addTearDown(childFocus.dispose);
    var activations = 0;
    await tester.pumpWidget(
      _stepper(
        builder: (context, value) => Focus(
          focusNode: childFocus,
          child: GestureDetector(
            onTap: () => activations++,
            child: Text('custom ${value.toInt()}'),
          ),
        ),
      ),
    );
    childFocus.requestFocus();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNot(childFocus));

    await tester.tapAt(tester.getCenter(find.text('custom 2')));
    await tester.pump();
    expect(activations, 0);

    await tester.tap(find.bySemanticsLabel('Increase value'));
    await tester.pumpAndSettle();
    expect(find.text('custom 3'), findsOneWidget);
    expect(activations, 0);
  });

  testWidgets('Tab traversal and bound focus transfer stay parent-owned', (
    tester,
  ) async {
    await tester.pumpWidget(
      _stepper(
        defaultValue: 1,
        max: 2,
        builder: (context, value) => Text('value ${value.toInt()}'),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Decrease value');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Increase value');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('value 2'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Decrease value');
  });

  testWidgets(
    'same-value builder replacement updates without a new transition',
    (tester) async {
      var changes = 0;
      await tester.pumpWidget(
        _stepper(
          value: 2,
          onChanged: (_) => changes++,
          builder: (context, value) => Text('first ${value.toInt()}'),
        ),
      );
      _expectPaint(tester, 'first 2', opacity: 1, sigma: 0);
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, 'first 2'), 1);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(
        _stepper(
          value: 2,
          onChanged: (_) => changes++,
          builder: (context, value) => Text('replacement ${value.toInt()}'),
        ),
      );
      expect(find.text('replacement 2'), findsOneWidget);
      expect(_opacityOf(tester, 'replacement 2'), 1);
      expect(tester.binding.transientCallbackCount, 0);
      expect(changes, 0);
    },
  );

  testWidgets('custom numeric changes use literal entry opacity and blur', (
    tester,
  ) async {
    await tester.pumpWidget(
      _stepper(
        value: 2,
        builder: (context, value) => Text('number ${value.toInt()}'),
      ),
    );
    await tester.pumpAndSettle();
    _expectPaint(tester, 'number 2', opacity: 1, sigma: 0);

    await tester.pumpWidget(
      _stepper(
        value: 3,
        builder: (context, value) => Text('number ${value.toInt()}'),
      ),
    );
    final entryOrigin = tester.getTopLeft(find.text('number 3'));
    _expectPaint(tester, 'number 3', opacity: 0.35, sigma: 2);
    await tester.pump(const Duration(milliseconds: 90));
    final easeHalf = const Cubic(0.16, 1, 0.3, 1).transform(0.5);
    _expectPaint(
      tester,
      'number 3',
      opacity: 0.35 + 0.65 * easeHalf,
      sigma: 2 * (1 - easeHalf),
    );
    expect(tester.getTopLeft(find.text('number 3')).dy, entryOrigin.dy);
    expect(
      find.ancestor(
        of: find.text('number 3'),
        matching: find.descendant(
          of: find.byType(BeuiAdaptiveStepperValue),
          matching: find.byType(SlideTransition),
        ),
      ),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 90));
    _expectPaint(tester, 'number 3', opacity: 1, sigma: 0);
  });

  testWidgets('custom outgoing render layers follow literal 120ms EASE_OUT', (
    tester,
  ) async {
    await tester.pumpWidget(
      _stepper(
        value: 2,
        builder: (context, value) => Text('number ${value.toInt()}'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _stepper(
        value: 3,
        builder: (context, value) => Text('number ${value.toInt()}'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 180));
    _expectPaint(tester, 'number 3', opacity: 1, sigma: 0);
    await tester.pumpWidget(
      _stepper(
        value: 4,
        builder: (context, value) => Text('number ${value.toInt()}'),
      ),
    );
    final exitOrigin = tester.getTopLeft(find.text('number 3'));
    await tester.pump(const Duration(milliseconds: 60));

    final easeHalf = const Cubic(0.16, 1, 0.3, 1).transform(0.5);
    _expectPaint(
      tester,
      'number 3',
      opacity: 1 - easeHalf,
      sigma: 2 * easeHalf,
    );
    expect(tester.getTopLeft(find.text('number 3')).dy, exitOrigin.dy);
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('number 3'), findsNothing);
  });

  testWidgets('an interrupted custom entry does not jump on reversal', (
    tester,
  ) async {
    Widget at(double value) => _stepper(
      value: value,
      builder: (context, effective) => Text('number ${effective.toInt()}'),
    );
    await tester.pumpWidget(at(1));
    await tester.pumpAndSettle();
    await tester.pumpWidget(at(2));
    await tester.pump(const Duration(milliseconds: 40));
    final beforeReversal = _opacityOf(tester, 'number 2');
    const easeOut = Cubic(0.16, 1, 0.3, 1);
    final entryProgress = 40 / 180;
    final entryEase = easeOut.transform(entryProgress);
    expect(beforeReversal, closeTo(0.35 + 0.65 * entryEase, 1e-6));
    _expectPaint(
      tester,
      'number 2',
      opacity: beforeReversal,
      sigma: 2 * (1 - entryEase),
    );
    await tester.pumpWidget(at(3));
    expect(_opacityOf(tester, 'number 2'), closeTo(beforeReversal, 1e-6));
    _expectPaint(
      tester,
      'number 2',
      opacity: beforeReversal,
      sigma: 2 * (1 - entryEase),
    );
    expect(find.text('number 3'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 60));
    final exitEase = easeOut.transform(0.5);
    _expectPaint(
      tester,
      'number 2',
      opacity: beforeReversal * (1 - exitEase),
      sigma: 2 * (1 - entryEase) + 2 * entryEase * exitEase,
    );
    await tester.pump(const Duration(milliseconds: 59));
    expect(find.text('number 2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('number 2'), findsNothing);
    await tester.pump(const Duration(milliseconds: 60));
    _expectPaint(tester, 'number 3', opacity: 1, sigma: 0);
  });

  testWidgets('a zero-elapsed custom entry retains the full source exit', (
    tester,
  ) async {
    Widget at(double value) => _stepper(
      value: value,
      builder: (context, effective) => Text('number ${effective.toInt()}'),
    );
    await tester.pumpWidget(at(1));
    await tester.pumpAndSettle();
    await tester.pumpWidget(at(2));
    _expectPaint(tester, 'number 2', opacity: 0.35, sigma: 2);
    await tester.pumpWidget(at(3));
    _expectPaint(tester, 'number 2', opacity: 0.35, sigma: 2);
    await tester.pump(const Duration(milliseconds: 60));
    final easeHalf = const Cubic(0.16, 1, 0.3, 1).transform(0.5);
    _expectPaint(tester, 'number 2', opacity: 0.35 * (1 - easeHalf), sigma: 2);
    await tester.pump(const Duration(milliseconds: 59));
    expect(find.text('number 2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('number 2'), findsNothing);
  });

  testWidgets('rapid replacement and removal dispose without extra callbacks', (
    tester,
  ) async {
    var changes = 0;
    await tester.pumpWidget(
      _stepper(
        value: 1,
        onChanged: (_) => changes++,
        builder: (context, value) => Text('value ${value.toInt()}'),
      ),
    );
    await tester.pumpWidget(
      _stepper(
        value: 2,
        onChanged: (_) => changes++,
        builder: (context, value) => Text('value ${value.toInt()}'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(
      _stepper(
        value: 3,
        onChanged: (_) => changes++,
        builder: (context, value) => Text('value ${value.toInt()}'),
      ),
    );
    expect(find.text('value 2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('value 3'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(find.byType(BeuiAdaptiveStepperValue), findsNothing);
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
    expect(changes, 0);
  });

  testWidgets('reduced motion is settled and removes custom filter layers', (
    tester,
  ) async {
    await tester.pumpWidget(
      _stepper(
        value: 2,
        reduce: true,
        builder: (context, value) => Text('number ${value.toInt()}'),
      ),
    );
    expect(find.byType(ImageFiltered), findsNothing);
    expect(
      find.ancestor(of: find.text('number 2'), matching: find.byType(Opacity)),
      findsNothing,
    );

    await tester.pumpWidget(
      _stepper(
        value: 3,
        reduce: true,
        builder: (context, value) => Text('number ${value.toInt()}'),
      ),
    );
    expect(find.text('number 2'), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(
      find.ancestor(of: find.text('number 3'), matching: find.byType(Opacity)),
      findsNothing,
    );
    await tester.pumpWidget(
      _stepper(
        value: 3,
        builder: (context, value) => Text('number ${value.toInt()}'),
      ),
    );
    _expectPaint(tester, 'number 3', opacity: 1, sigma: 0);
  });

  testWidgets('normal and reduced toggles keep the current value visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _stepper(
        value: 2,
        builder: (context, value) => Text('number ${value.toInt()}'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _stepper(
        value: 3,
        builder: (context, value) => Text('number ${value.toInt()}'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(
      _stepper(
        value: 3,
        reduce: true,
        builder: (context, value) => Text('number ${value.toInt()}'),
      ),
    );
    expect(find.text('number 3'), findsOneWidget);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(
      find.ancestor(of: find.text('number 3'), matching: find.byType(Opacity)),
      findsNothing,
    );
  });

  testWidgets('custom Text inherits literal value style and allows overrides', (
    tester,
  ) async {
    await tester.pumpWidget(
      _stepper(builder: (context, value) => Text('plain ${value.toInt()}')),
    );
    final plain = tester.widget<RichText>(
      find
          .descendant(
            of: find.byType(BeuiAdaptiveStepperValue),
            matching: find.byType(RichText),
          )
          .first,
    );
    expect(plain.text.style?.fontSize, 18);
    expect(plain.text.style?.fontWeight, FontWeight.w600);
    expect(plain.text.style?.color, BeuiColors.light().foreground);
    expect(
      plain.text.style?.fontFeatures,
      contains(const ui.FontFeature.tabularFigures()),
    );

    await tester.pumpWidget(
      _stepper(
        builder: (context, value) => Text(
          'styled ${value.toInt()}',
          style: const TextStyle(
            color: Colors.red,
            fontSize: 22,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
    final styled = tester.widget<RichText>(
      find
          .descendant(
            of: find.byType(BeuiAdaptiveStepperValue),
            matching: find.byType(RichText),
          )
          .first,
    );
    expect(styled.text.style?.fontSize, 22);
    expect(styled.text.style?.fontWeight, FontWeight.w400);
    expect(styled.text.style?.color, Colors.red);
    expect(
      styled.text.style?.fontFeatures,
      contains(const ui.FontFeature.tabularFigures()),
    );
  });

  testWidgets('custom value geometry remains fixed at all bound widths', (
    tester,
  ) async {
    for (final testCase in [
      (value: 1.0, min: 1.0, max: 4.0, width: 152.0),
      (value: 2.0, min: 1.0, max: 4.0, width: 88.0),
      (value: 4.0, min: 1.0, max: 4.0, width: 152.0),
      (value: 1.0, min: 1.0, max: 1.0, width: 216.0),
    ]) {
      await tester.pumpWidget(
        _stepper(
          value: testCase.value,
          min: testCase.min,
          max: testCase.max,
          builder: (context, value) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.circle, size: 16),
              Text(' ${value.toInt()}'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(BeuiAdaptiveStepperValue)).width,
        testCase.width,
      );
      expect(
        tester.getSize(find.byType(BeuiAdaptiveStepper)),
        const Size(216, 48),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
