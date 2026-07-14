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
}) {
  Widget child = Center(
    child: BeuiWheelPicker(
      key: const ValueKey('wp'),
      options: _opts(),
      value: value,
      defaultValue: defaultValue,
      enabled: enabled,
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
      await tester.drag(find.byType(ListWheelScrollView), const Offset(0, -120));
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
