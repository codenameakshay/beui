import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  testWidgets('settles within its duration from the update, not a later tick', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiTextScramble(
          'Old',
          duration: Duration(milliseconds: 80),
          glyphs: '#',
        ),
      ),
    );
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiTextScramble(
          'New',
          duration: Duration(milliseconds: 80),
          glyphs: '#',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('N##'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('New'), findsOneWidget);
  });

  testWidgets('first mount shows the final text without scrambling', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiTextScramble('Inspecting the repository')),
    );
    await tester.pump();
    expect(find.text('Inspecting the repository'), findsOneWidget);
  });

  testWidgets('changing text scrambles then settles', (tester) async {
    var text = 'Alpha';
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiTextScramble(text),
              TextButton(
                onPressed: () => setState(() => text = 'Bravo'),
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    // Mid-scramble the display is not yet the final string.
    expect(find.text('Bravo'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Bravo'), findsOneWidget);
  });

  testWidgets('reduced motion shows the final text immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiTextScramble('Ready'), reduce: true),
    );
    await tester.pump();
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('semantics expose the final text', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(beuiTestApp(const BeuiTextScramble('Secret')));
    expect(find.bySemanticsLabel('Secret'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BeuiTextTheme.trackingNormal(
          ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        ),
        home: const Scaffold(
          body: Center(child: BeuiTextScramble('Inspecting the repository')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiTextScramble),
      matchesGoldenFile('goldens/beui_text_scramble.png'),
    );
  });
}
