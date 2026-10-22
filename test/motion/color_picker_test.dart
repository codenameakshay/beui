import 'package:beui/src/motion/color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beui/src/theme/beui_colors.dart';

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData(extensions: [BeuiColors.light()]),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  test('hex parsing accepts short, long, and alpha forms', () {
    expect(beuiColorFromHex('#abc'), const Color(0xffaabbcc));
    expect(beuiColorFromHex('#aabbcc'), const Color(0xffaabbcc));
    expect((beuiColorFromHex('#aabbcc80')!.a * 255.0).round(), 128);
    expect(beuiColorFromHex('not-a-color'), isNull);
  });

  testWidgets('area, sliders, hex and presets update color', (tester) async {
    String? changed;
    await tester.pumpWidget(
      _app(
        BeuiColorPicker(
          defaultValue: '#3478f6',
          onChanged: (value) => changed = value,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiColorPickerArea(),
              BeuiColorPickerHue(),
              BeuiColorPickerAlpha(),
              BeuiColorPickerHex(),
              BeuiColorPickerPresets(
                items: [BeuiColorPickerPresetItem('#e55656', label: 'Red')],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Red'));
    await tester.pump();
    expect(changed, '#e55656');
  });

  testWidgets('controlled color reports changes without changing its value', (
    tester,
  ) async {
    String? changed;
    await tester.pumpWidget(
      _app(
        BeuiColorPicker(
          value: '#3478f6',
          onChanged: (value) => changed = value,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiColorPickerHex(),
              BeuiColorPickerPresets(
                items: [BeuiColorPickerPresetItem('#e55656')],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('#e55656'));
    await tester.pump();
    expect(changed, '#e55656');
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '3478F6',
    );
  });

  testWidgets('trigger opens content as an accessible dialog', (tester) async {
    await tester.pumpWidget(
      _app(
        const BeuiColorPicker(
          trigger: BeuiColorPickerTrigger(),
          child: BeuiColorPickerContent(child: BeuiColorPickerArea()),
        ),
      ),
    );
    await tester.tap(find.byType(BeuiColorPickerTrigger));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Color picker'), findsOneWidget);
    expect(find.byType(BeuiColorPickerArea), findsOneWidget);
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(
      _app(
        const BeuiColorPicker(
          child: BeuiColorPickerContent(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BeuiColorPickerArea(),
                SizedBox(height: 10),
                BeuiColorPickerHue(),
                SizedBox(height: 8),
                BeuiColorPickerAlpha(),
                SizedBox(height: 10),
                BeuiColorPickerHex(),
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(BeuiColorPicker),
      matchesGoldenFile('goldens/beui_color_picker.png'),
    );
  });
}
