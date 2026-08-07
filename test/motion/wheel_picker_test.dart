import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _options = <String>['Apple', 'Banana', 'Cherry', 'Date', 'Elderberry'];

List<BeuiWheelPickerOption> _opts() =>
    _options.map(BeuiWheelPickerOption.text).toList();

/// Wraps a [BeuiWheelPicker] in a themed app. [reduce] forces reduced motion.
Widget _app({
  String? value,
  String? defaultValue,
  ValueChanged<String>? onChanged,
  bool enabled = true,
  bool reduce = false,
  int visibleCount = 5,
  double itemHeight = 36,
}) {
  Widget child = Center(
    child: BeuiWheelPicker(
      key: const ValueKey('wp'),
      options: _opts(),
      value: value,
      defaultValue: defaultValue,
      enabled: enabled,
      visibleCount: visibleCount,
      itemHeight: itemHeight,
      semanticLabel: 'Fruit',
      onChanged: onChanged,
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
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: child),
  );
}

ListWheelScrollView _wheel(WidgetTester tester) =>
    tester.widget<ListWheelScrollView>(find.byType(ListWheelScrollView));

void main() {
  group('BeuiWheelPicker interaction', () {
    testWidgets('drag changes selection via onChanged', (tester) async {
      String? changed;
      await tester.pumpWidget(
        _app(defaultValue: 'Apple', onChanged: (v) => changed = v),
      );
      await tester.pumpAndSettle();
      // Drag the drum upward to advance toward later rows.
      await tester.drag(
        find.byType(ListWheelScrollView),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      expect(changed, isNotNull);
      expect(changed, isNot('Apple'));
    });

    testWidgets('ArrowDown moves selection down one row', (tester) async {
      String? changed;
      await tester.pumpWidget(
        _app(defaultValue: 'Apple', onChanged: (v) => changed = v),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(changed, 'Banana');
    });

    testWidgets('End jumps to the last row', (tester) async {
      String? changed;
      await tester.pumpWidget(
        _app(defaultValue: 'Apple', onChanged: (v) => changed = v),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(changed, 'Elderberry');
    });

    testWidgets('disabled is not scrollable', (tester) async {
      await tester.pumpWidget(_app(defaultValue: 'Apple', enabled: false));
      await tester.pumpAndSettle();
      expect(_wheel(tester).physics, isA<NeverScrollableScrollPhysics>());
    });

    testWidgets('controlled value change glides the drum', (tester) async {
      await tester.pumpWidget(_app(value: 'Apple'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(value: 'Cherry'));
      await tester.pumpAndSettle();
      final controller =
          _wheel(tester).controller! as FixedExtentScrollController;
      expect(controller.selectedItem, _options.indexOf('Cherry'));
    });
  });

  group('BeuiWheelPicker motion fidelity', () {
    testWidgets('drum is curved under normal motion', (tester) async {
      await tester.pumpWidget(_app(defaultValue: 'Apple'));
      await tester.pumpAndSettle();
      final ratio = _wheel(tester).diameterRatio;
      // Source geometry gives a tightly wrapped drum; the framework default is
      // 2.0 (much flatter). It must be curved but valid.
      expect(ratio, greaterThan(0));
      expect(ratio, lessThan(2.0));
    });

    // The drum's whole point is that it reproduces the source's cylinder, not
    // merely "some" curve. Both engines project a row seated on the drum to
    //   Y(i) = R·sin(i·θ) / (1 + p·R·(1 − cos(i·θ)))
    // — the source via CSS rotateX/translateZ under `perspective: 1000px`,
    // Flutter via MatrixUtils.createCylindricalProjectionTransform. So the
    // render matches exactly when the triple (R, θ, p) matches, and this pins
    // all three. It is a genuine three-knob solve: diameterRatio alone fixes θ
    // but forces R ≥ height/2, which is larger than the source's R and spreads
    // the rows apart — squeeze is what frees R, and perspective must be CSS's
    // 1/1000 rather than Flutter's 0.003 default.
    testWidgets('drum reproduces the source cylinder exactly', (tester) async {
      const itemHeight = 42.0;
      const visibleCount = 7;
      await tester.pumpWidget(
        _app(
          defaultValue: 'Apple',
          visibleCount: visibleCount,
          itemHeight: itemHeight,
        ),
      );
      await tester.pumpAndSettle();

      // Source geometry (components/motion/wheel-picker.tsx):
      //   rowsEachSide = floor(visibleCount/2); cutoff = rowsEachSide + 1;
      //   itemAngle = 90/cutoff; radius = itemHeight / tan(itemAngle);
      //   height = round(2·radius·sin(rowsEachSide·itemAngle) + itemHeight).
      const rowsEachSide = visibleCount ~/ 2;
      const cutoff = rowsEachSide + 1;
      const srcAngle = (math.pi / 2) / cutoff;
      final srcRadius = itemHeight / math.tan(srcAngle);
      final height =
          (2 * srcRadius * math.sin(rowsEachSide * srcAngle) + itemHeight)
              .roundToDouble();

      final wheel = _wheel(tester);
      // Flutter's own definitions (rendering/list_wheel_viewport.dart).
      final maxVisibleRadian = wheel.diameterRatio < 1.0
          ? math.pi / 2
          : math.asin(1.0 / wheel.diameterRatio);
      final radius = height * wheel.diameterRatio / 2;
      final angle =
          (itemHeight / height) * 2 * maxVisibleRadian / wheel.squeeze;

      expect(radius, closeTo(srcRadius, 0.01), reason: 'drum radius');
      expect(angle, closeTo(srcAngle, 1e-6), reason: 'per-row angle');
      expect(wheel.perspective, closeTo(0.001, 1e-9), reason: 'CSS 1000px');

      double project(double r, double t, double p, int i) =>
          r * math.sin(i * t) / (1 + p * r * (1 - math.cos(i * t)));

      // Every visible row lands within a tenth of a pixel of the source, and
      // the outermost pair still clears the box edge rather than being clipped.
      for (var i = 1; i <= rowsEachSide; i++) {
        expect(
          project(radius, angle, wheel.perspective, i),
          closeTo(project(srcRadius, srcAngle, 0.001, i), 0.1),
          reason: 'row +$i offset',
        );
      }
      expect(
        project(radius, angle, wheel.perspective, rowsEachSide) +
            itemHeight / 2,
        lessThan(height / 2),
        reason: 'outermost row must fit inside the box',
      );
    });

    testWidgets('off-centre rows are dimmed by colour only', (tester) async {
      await tester.pumpWidget(_app(defaultValue: 'Apple'));
      await tester.pumpAndSettle();
      // The source's drum rows are all `text-muted-foreground` at full opacity;
      // the only alpha falloff is the shared `maskFade` gradient. An opacity
      // ramp here would multiply with that mask and halve the rows' luminance.
      expect(_wheel(tester).overAndUnderCenterOpacity, 1.0);
    });

    testWidgets('reduced motion flattens the drum', (tester) async {
      await tester.pumpWidget(_app(defaultValue: 'Apple', reduce: true));
      await tester.pumpAndSettle();
      // Reduced motion drops the 3D rotation: a large diameter ratio makes each
      // row's angle ~0, so the drum reads as a flat scrolling list.
      expect(_wheel(tester).diameterRatio, greaterThanOrEqualTo(50));
    });

    testWidgets('still scrollable under reduced motion', (tester) async {
      await tester.pumpWidget(_app(defaultValue: 'Apple', reduce: true));
      await tester.pumpAndSettle();
      expect(_wheel(tester).physics, isA<FixedExtentScrollPhysics>());
    });
  });

  group('BeuiWheelPicker semantics', () {
    testWidgets('exposes the selected value', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(defaultValue: 'Cherry'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byType(BeuiWheelPicker)),
        isSemantics(label: 'Fruit', value: 'Cherry', isEnabled: true),
      );
      handle.dispose();
    });
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        home: Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BeuiWheelPicker(options: _opts(), defaultValue: 'Cherry'),
                const SizedBox(width: 16),
                BeuiWheelPicker(
                  options: _opts(),
                  defaultValue: 'Banana',
                  enabled: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Row),
      matchesGoldenFile('goldens/beui_wheel_picker.png'),
    );
  });
}
