import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  testWidgets('slots use the active font zero advance and scale with text', (
    tester,
  ) async {
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        beuiTestApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: const BeuiDigitSwap(
                value: '0 1',
                style: TextStyle(fontFamily: 'Ahem', fontSize: 20),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(BeuiDigitSwap)).width,
        closeTo(54 * scale, 0.001),
      );
      expect(
        tester.getSize(find.byType(BeuiDigitSwap)).height,
        closeTo(22 * scale, 0.001),
      );
    }
  });

  testWidgets('non-BMP glyphs are not split into invalid surrogate slots', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(const BeuiDigitSwap(value: '🚀 1')));
    expect(find.text('🚀'), findsOneWidget);
    expect(find.bySemanticsLabel('🚀 1'), findsOneWidget);
    await tester.pumpWidget(beuiTestApp(const BeuiDigitSwap(value: '🌙 2')));
    await tester.pumpAndSettle();
    expect(find.text('🌙'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('outgoing glyph rolls away opposite the incoming glyph', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(const BeuiDigitSwap(value: '1')));
    await tester.pumpWidget(beuiTestApp(const BeuiDigitSwap(value: '2')));
    await tester.pump(const Duration(milliseconds: 60));
    double offset(String glyph) => tester
        .widget<SlideTransition>(
          find
              .ancestor(
                of: find.text(glyph),
                matching: find.byType(SlideTransition),
              )
              .first,
        )
        .position
        .value
        .dy;
    expect(offset('1'), lessThan(0));
    expect(offset('2'), greaterThan(0));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('unchanged staggered glyph receives new styling', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiDigitSwap(
          value: '12',
          glyphStyle: TextStyle(color: Colors.red),
        ),
      ),
    );
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiDigitSwap(
          value: '12',
          glyphStyle: TextStyle(color: Colors.blue),
        ),
      ),
    );
    expect(tester.widget<Text>(find.text('2')).style?.color, Colors.blue);
  });

  testWidgets('renders the value in semantics', (tester) async {
    await tester.pumpWidget(beuiTestApp(const BeuiDigitSwap(value: '4242')));
    expect(find.bySemanticsLabel('4242'), findsOneWidget);
  });

  testWidgets('changing value updates the announced string', (tester) async {
    var value = '•••• 0806';
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiDigitSwap(
                value: value,
                animationKey: value,
                direction: BeuiDigitSwapDirection.up,
                suffixLength: 4,
              ),
              TextButton(
                onPressed: () => setState(() => value = '4242 0806'),
                child: const Text('Reveal'),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('•••• 0806'), findsOneWidget);
    await tester.tap(find.text('Reveal'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('4242 0806'), findsOneWidget);
  });

  testWidgets('staggered slots paint the new glyph after settle', (
    tester,
  ) async {
    var value = '1111';
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiDigitSwap(value: value, animationKey: value),
              TextButton(
                onPressed: () => setState(() => value = '1414'),
                child: const Text('Swap'),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('4'), findsNothing);
    await tester.tap(find.text('Swap'));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsWidgets);
  });

  testWidgets('reduced motion still shows the value', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiDigitSwap(value: 42), reduce: true),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('42'), findsOneWidget);
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BeuiTextTheme.trackingNormal(
          ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        ),
        home: const Scaffold(
          body: Center(
            child: BeuiDigitSwap(value: '4242 4242 4242 0806', suffixLength: 4),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiDigitSwap),
      matchesGoldenFile('goldens/beui_digit_swap.png'),
    );
  });
}
