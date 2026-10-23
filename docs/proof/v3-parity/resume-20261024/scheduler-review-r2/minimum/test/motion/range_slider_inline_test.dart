import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _track = ValueKey<String>('beui_inline_slider_track');

void main() {
  testWidgets('arrow keys move between stops', (tester) async {
    double? changed;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiInlineSlider(
          label: 'Icon size',
          defaultValue: 48,
          min: 8,
          max: 128,
          step: 8,
          onChanged: (v) => changed = v,
        ),
        width: 320,
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(changed, isNotNull);
    expect(changed! > 48, isTrue);
  });

  testWidgets('tap on track commits a stop', (tester) async {
    double? changed;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiInlineSlider(
          label: 'Icon size',
          defaultValue: 48,
          min: 8,
          max: 128,
          step: 8,
          onChanged: (v) => changed = v,
        ),
        width: 320,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_track));
    await tester.pumpAndSettle();
    expect(changed, isNotNull);
  });

  testWidgets('reduced motion still updates the value', (tester) async {
    double? changed;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiInlineSlider(
          label: 'Icon size',
          defaultValue: 8,
          min: 8,
          max: 128,
          step: 8,
          onChanged: (v) => changed = v,
        ),
        width: 320,
        reduce: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(changed, 128);
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BeuiTextTheme.trackingNormal(
          ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        ),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: BeuiInlineSlider(
                label: 'Icon size',
                defaultValue: 48,
                min: 8,
                max: 128,
                step: 8,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiInlineSlider),
      matchesGoldenFile('goldens/beui_inline_slider.png'),
    );
  });
}
