import 'package:beui/src/motion/color_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beui/src/theme/beui_colors.dart';

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData(extensions: [BeuiColors.light()]),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('default trigger preserves the source lowercase hex text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const BeuiColorPicker(
          trigger: BeuiColorPickerTrigger(),
          child: BeuiColorPickerContent(child: BeuiColorPickerArea()),
        ),
      ),
    );
    expect(find.text('#3478f6'), findsOneWidget);
  });
  testWidgets(
    'hex previews full entries and restores rejected drafts on blur',
    (tester) async {
      final changes = <String>[];
      final commits = <String>[];
      await tester.pumpWidget(
        _app(
          BeuiColorPicker(
            onChanged: changes.add,
            onCommit: commits.add,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BeuiColorPickerHex(),
                TextButton(onPressed: null, child: Text('Other')),
              ],
            ),
          ),
        ),
      );
      final field = find.byType(TextField);
      await tester.enterText(field, 'abc');
      expect(changes, isEmpty);
      await tester.enterText(field, '123456');
      expect(changes, ['#123456']);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(commits, ['#123456']);
      await tester.enterText(field, 'notvalid');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '123456',
      );
      expect(commits, ['#123456']);
    },
  );

  testWidgets(
    'numeric channels edit live and accept shifted arrow increments',
    (tester) async {
      String color = '#3478f6';
      final commits = <String>[];
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, update) => SizedBox(
              width: 240,
              child: BeuiColorPicker(
                value: color,
                onChanged: (value) => update(() => color = value),
                onCommit: commits.add,
                child: const BeuiColorPickerChannels(),
              ),
            ),
          ),
        ),
      );
      final red = find.byType(TextField).first;
      await tester.enterText(red, '100');
      await tester.pump();
      expect(color, '#6478f6');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(color, '#6e78f6');
      expect(commits, ['#6e78f6']);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .controller
            .text,
        '110',
      );
    },
  );

  testWidgets('popover clamps horizontally and transfers focus in and back', (
    tester,
  ) async {
    final edits = <String>[];
    await tester.pumpWidget(
      _app(
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: BeuiColorPicker(
              onChanged: edits.add,
              trigger: const BeuiColorPickerTrigger(),
              child: const BeuiColorPickerContent(child: BeuiColorPickerArea()),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(BeuiColorPickerTrigger));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(BeuiColorPickerContent)).right,
      lessThanOrEqualTo(792),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(edits.single, '#367af6');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(BeuiColorPickerContent), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(BeuiColorPickerContent), findsOneWidget);
  });
  testWidgets('trigger chip grows into area and returns on controlled close', (
    tester,
  ) async {
    final open = ValueNotifier(false);
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder(
          valueListenable: open,
          builder: (context, value, _) => BeuiColorPicker(
            open: value,
            onOpenChanged: (value) => open.value = value,
            trigger: const BeuiColorPickerTrigger(),
            child: const BeuiColorPickerContent(child: BeuiColorPickerArea()),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(BeuiColorPickerTrigger));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    final spectrum = find.byKey(const ValueKey('color-picker-spectrum'));
    expect(tester.getRect(spectrum).width, closeTo(24, 1));
    await tester.pump(const Duration(milliseconds: 160));
    final growing = tester.getRect(spectrum).width;
    expect(growing, inExclusiveRange(24, 264));
    await tester.pumpAndSettle();
    expect(tester.getRect(spectrum).width, closeTo(264, .1));
    expect(tester.getRect(spectrum).height, closeTo(160, .1));
    open.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    expect(tester.getRect(spectrum).width, inExclusiveRange(24, 264));
    await tester.pumpAndSettle();
    expect(spectrum, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    open.dispose();
  });
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

  testWidgets('area loupe appears on pointer down and hides on pointer up', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const BeuiColorPicker(child: BeuiColorPickerArea())),
    );
    final center = tester.getCenter(find.byType(BeuiColorPickerArea));
    final pointer = await tester.startGesture(center);
    await tester.pump();
    expect(find.byKey(const ValueKey('color-picker-loupe')), findsOneWidget);

    await pointer.up();
    await tester.pump();
    expect(find.byKey(const ValueKey('color-picker-loupe')), findsNothing);
  });

  testWidgets('area hover is idle and a held pointer lifts the loupe', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const BeuiColorPicker(child: BeuiColorPickerArea())),
    );
    final center = tester.getCenter(find.byType(BeuiColorPickerArea));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: center);
    await mouse.moveTo(center);
    await tester.pump();
    expect(find.byKey(const ValueKey('color-picker-loupe')), findsNothing);
    await mouse.down(center);
    await tester.pump();
    expect(find.byKey(const ValueKey('color-picker-loupe')), findsOneWidget);
    await mouse.up();
    await tester.pump();
    expect(find.byKey(const ValueKey('color-picker-loupe')), findsNothing);
    await mouse.removePointer();
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

  testWidgets('reduced motion snaps the controlled area thumb to its color', (
    tester,
  ) async {
    var color = '#ffffff';
    late StateSetter updateColor;
    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SizedBox(
            width: 200,
            child: StatefulBuilder(
              builder: (context, setState) {
                updateColor = setState;
                return BeuiColorPicker(
                  value: color,
                  child: const BeuiColorPickerArea(),
                );
              },
            ),
          ),
        ),
      ),
    );
    final area = find.byType(BeuiColorPickerArea);
    final thumb = find.descendant(
      of: area,
      matching: find.byWidgetPredicate(
        (widget) => widget is Positioned && widget.child is Container,
      ),
    );
    Offset thumbOffset() => tester.getTopLeft(thumb) - tester.getTopLeft(area);
    expect(tester.getSize(thumb), const Size(16, 16));
    expect(thumbOffset(), const Offset(-8, -8));

    updateColor(() => color = '#ff0000');
    await tester.pump();
    expect(thumbOffset(), const Offset(192, -8));

    updateColor(() => color = '#000000');
    await tester.pump();
    expect(thumbOffset(), const Offset(-8, 152));
  });

  testWidgets('uncontrolled area tap retains and commits the requested color', (
    tester,
  ) async {
    final changes = <String>[];
    final commits = <String>[];
    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SizedBox(
            width: 200,
            child: BeuiColorPicker(
              defaultValue: '#ff0000',
              onChanged: changes.add,
              onCommit: commits.add,
              child: const BeuiColorPickerArea(),
            ),
          ),
        ),
      ),
    );
    final area = find.byType(BeuiColorPickerArea);
    final thumb = find.descendant(
      of: area,
      matching: find.byWidgetPredicate(
        (widget) => widget is Positioned && widget.child is Container,
      ),
    );
    await tester.tapAt(tester.getTopLeft(area) + const Offset(100, 80));
    await tester.pump();

    expect(changes, ['#804040', '#804040']);
    expect(commits, ['#804040']);
    expect(tester.getSize(area), const Size(200, 160));
    final offset = tester.getTopLeft(thumb) - tester.getTopLeft(area);
    expect(offset.dx, 92);
    expect(offset.dy, closeTo(71.686275, 0.001));
    final container = tester.widget<Positioned>(thumb).child as Container;
    final decoration = container.decoration! as BoxDecoration;
    expect(beuiColorToHex(decoration.color!), '#804040');
  });

  testWidgets('stale controlled area commits requested color on retry', (
    tester,
  ) async {
    final changes = <String>[];
    final commits = <String>[];
    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SizedBox(
            width: 200,
            child: BeuiColorPicker(
              value: '#ff0000',
              onChanged: changes.add,
              onCommit: commits.add,
              child: const BeuiColorPickerArea(),
            ),
          ),
        ),
      ),
    );
    final area = find.byType(BeuiColorPickerArea);
    final thumb = find.descendant(
      of: area,
      matching: find.byWidgetPredicate(
        (widget) => widget is Positioned && widget.child is Container,
      ),
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      final position = tester.getTopLeft(area) + const Offset(100, 80);
      if (attempt == 0) {
        await tester.tapAt(position);
      } else {
        final pointer = await tester.startGesture(position);
        await tester.pump();
        await pointer.up();
      }
      await tester.pump();
      expect(tester.getSize(area), const Size(200, 160));
      expect(tester.getSize(thumb), const Size(16, 16));
      expect(
        tester.getTopLeft(thumb) - tester.getTopLeft(area),
        const Offset(192, -8),
      );
    }
    expect(changes, ['#804040', '#804040', '#804040', '#804040']);
    expect(commits, ['#804040', '#804040']);
  });

  for (final alpha in [false, true]) {
    final sliderName = alpha ? 'alpha' : 'hue';
    final requestedColor = alpha ? '#ff000080' : '#00ffff';

    testWidgets('uncontrolled $sliderName release retains requested color', (
      tester,
    ) async {
      final changes = <String>[];
      final commits = <String>[];
      await tester.pumpWidget(
        _app(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: SizedBox(
              width: 200,
              child: BeuiColorPicker(
                defaultValue: '#ff0000',
                onChanged: changes.add,
                onCommit: commits.add,
                child: alpha
                    ? const BeuiColorPickerAlpha()
                    : const BeuiColorPickerHue(),
              ),
            ),
          ),
        ),
      );
      final slider = find.byType(
        alpha ? BeuiColorPickerAlpha : BeuiColorPickerHue,
      );
      final thumb = find.descendant(
        of: slider,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints ==
                  const BoxConstraints.tightFor(width: 18, height: 18),
        ),
      );
      expect(tester.getSize(slider), const Size(200, 14));
      expect(tester.getSize(thumb), const Size(18, 18));
      expect(
        tester.getTopLeft(thumb) - tester.getTopLeft(slider),
        alpha ? const Offset(182, -2) : const Offset(0, -2),
      );
      for (var attempt = 0; attempt < 2; attempt++) {
        final origin = tester.getTopLeft(slider);
        final pointer = await tester.startGesture(
          origin + const Offset(50, 12),
        );
        await pointer.moveTo(origin + const Offset(75, 12));
        await pointer.moveTo(origin + const Offset(100, 12));
        expect(changes.last, requestedColor);
        if (attempt == 1) await tester.pump();
        await pointer.up();
        await tester.pump();
        expect(changes.last, requestedColor);
        expect(
          tester.getTopLeft(thumb) - tester.getTopLeft(slider),
          const Offset(91, -2),
        );
      }
      expect(commits, [requestedColor, requestedColor]);
    });

    testWidgets(
      'stale controlled $sliderName commits requested color on retry',
      (tester) async {
        final changes = <String>[];
        final commits = <String>[];
        late StateSetter rebuild;
        await tester.pumpWidget(
          _app(
            MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: SizedBox(
                width: 200,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    rebuild = setState;
                    return BeuiColorPicker(
                      value: '#ff0000',
                      onChanged: changes.add,
                      onCommit: commits.add,
                      child: alpha
                          ? BeuiColorPickerAlpha(label: sliderName)
                          : BeuiColorPickerHue(label: sliderName),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        final slider = find.byType(
          alpha ? BeuiColorPickerAlpha : BeuiColorPickerHue,
        );
        final thumb = find.descendant(
          of: slider,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.constraints ==
                    const BoxConstraints.tightFor(width: 18, height: 18),
          ),
        );
        for (var attempt = 0; attempt < 2; attempt++) {
          final origin = tester.getTopLeft(slider);
          final pointer = await tester.startGesture(
            origin + const Offset(50, 12),
          );
          await pointer.moveTo(origin + const Offset(75, 12));
          await pointer.moveTo(origin + const Offset(100, 12));
          expect(changes.last, requestedColor);
          rebuild(() {});
          await tester.pump();
          await pointer.up();
          await tester.pump();
          expect(changes.last, requestedColor);
          expect(tester.getSize(slider), const Size(200, 14));
          expect(tester.getSize(thumb), const Size(18, 18));
          expect(
            tester.getTopLeft(thumb) - tester.getTopLeft(slider),
            alpha ? const Offset(182, -2) : const Offset(0, -2),
          );
        }
        expect(commits, [requestedColor, requestedColor]);
      },
    );
  }

  testWidgets('floating Material fits the picker body and dismisses outside', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const BeuiColorPicker(
          trigger: SizedBox(width: 40, height: 32, child: Text('Open')),
          child: BeuiColorPickerContent(child: BeuiColorPickerArea()),
        ),
      ),
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final material = find.byKey(const ValueKey('color-picker-panel-surface'));
      expect(tester.getSize(material), const Size(288, 184));
      expect(
        (tester.getTopLeft(material) -
                (tester.getBottomLeft(find.text('Open')) + const Offset(0, 8)))
            .distance,
        lessThan(0.01),
      );
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.byType(BeuiColorPickerContent), findsNothing);
    }
  });

  testWidgets('empty floating content still shrinkwraps its Material', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const BeuiColorPicker(
          trigger: Text('Open'),
          child: BeuiColorPickerContent(child: SizedBox.shrink()),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final material = find.byKey(const ValueKey('color-picker-panel-surface'));
    expect(tester.getSize(material), const Size(288, 24));
  });

  testWidgets('reduced motion panel keeps final geometry while fading', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const BeuiColorPicker(
            trigger: SizedBox(width: 40, height: 32, child: Text('Open')),
            child: BeuiColorPickerContent(child: BeuiColorPickerArea()),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    await tester.pump(const Duration(milliseconds: 50));
    final material = find.byKey(const ValueKey('color-picker-panel-surface'));
    final fade = find
        .ancestor(of: material, matching: find.byType(Opacity))
        .first;
    final expectedTopLeft =
        tester.getBottomLeft(find.text('Open')) + const Offset(0, 8);
    expect(tester.widget<Opacity>(fade).opacity, inExclusiveRange(0, 1));
    expect(tester.getTopLeft(material), expectedTopLeft);
    expect(
      tester.getBottomRight(material),
      expectedTopLeft + const Offset(288, 184),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(fade).opacity, 1);
    expect(tester.getTopLeft(material), expectedTopLeft);
    expect(
      tester.getBottomRight(material),
      expectedTopLeft + const Offset(288, 184),
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
