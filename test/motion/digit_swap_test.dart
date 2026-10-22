import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
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
