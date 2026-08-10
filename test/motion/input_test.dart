import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool reduce = false}) {
  Widget body = Center(child: SizedBox(width: 320, child: child));
  if (reduce) {
    final inner = body;
    body = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(body: body),
  );
}

void main() {
  group('BeuiInput text', () {
    testWidgets('uncontrolled seeds defaultValue and reports edits', (
      tester,
    ) async {
      String? last;
      await tester.pumpWidget(
        _app(BeuiInput(defaultValue: 'hi', onChanged: (v) => last = v)),
      );
      expect(find.text('hi'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'hello');
      expect(last, 'hello');
    });

    testWidgets('controlled reflects external value', (tester) async {
      await tester.pumpWidget(_app(const BeuiInput(value: 'abc')));
      expect(find.text('abc'), findsOneWidget);
      await tester.pumpWidget(_app(const BeuiInput(value: 'xyz')));
      await tester.pump();
      expect(find.text('xyz'), findsOneWidget);
    });
  });

  group('BeuiInput states', () {
    // Regression: `ring-2` is an *outset* ring. Expressing it as a BoxShadow on
    // a fill-less BoxDecoration floods the field's interior with the ring
    // colour, because there is no fill to occlude the shadow's rounded rect.
    testWidgets('focus ring is an outset stroke, never a fill', (tester) async {
      await tester.pumpWidget(_app(const BeuiInput(error: 'Bad value')));
      await tester.pumpAndSettle();

      final decorated = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>();
      expect(decorated, isNotEmpty);
      for (final d in decorated) {
        // No filled shadow, and no background fill: the field is transparent.
        expect(d.boxShadow, anyOf(isNull, isEmpty));
        expect(d.color, anyOf(isNull, const Color(0x00000000)));
      }
      // The ring itself is a 2px border laid out-of-flow, so it costs no space.
      final ring = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.border?.top.width == 2);
      expect(ring, hasLength(1));
    });

    testWidgets('string error renders an alert message', (tester) async {
      await tester.pumpWidget(_app(const BeuiInput(error: 'Bad value')));
      await tester.pumpAndSettle();
      expect(find.text('Bad value'), findsOneWidget);
    });

    testWidgets('success shows the check CustomPaint', (tester) async {
      await tester.pumpWidget(_app(const BeuiInput(success: true)));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BeuiInput),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );
    });
  });

  group('BeuiInput motion fidelity', () {
    testWidgets('error appearance drives the shake transform', (tester) async {
      await tester.pumpWidget(_app(const BeuiInput()));
      await tester.pumpWidget(_app(const BeuiInput(error: true)));
      await tester.pump(const Duration(milliseconds: 100));
      final t = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(BeuiInput),
              matching: find.byType(Transform),
            )
            .first,
      );
      // Mid-shake the field is translated off-centre.
      expect(t.transform.getTranslation().x.abs(), greaterThan(0));
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion drops the shake transform', (tester) async {
      await tester.pumpWidget(_app(const BeuiInput(), reduce: true));
      await tester.pumpWidget(_app(const BeuiInput(error: true), reduce: true));
      await tester.pump(const Duration(milliseconds: 100));
      // No AnimatedBuilder-driven shake wrapper under reduced motion.
      expect(
        find.descendant(
          of: find.byType(BeuiInput),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    });
  });

  testWidgets('rest-state golden (idle / success / error / disabled)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BeuiTextTheme.trackingNormal(
          ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        ),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              key: ValueKey('golden'),
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BeuiInput(label: 'Idle', defaultValue: 'Hello'),
                  SizedBox(height: 12),
                  BeuiInput(
                    label: 'Success',
                    defaultValue: 'Taken',
                    success: true,
                  ),
                  SizedBox(height: 12),
                  BeuiInput(
                    label: 'Error',
                    defaultValue: 'x',
                    error: 'Invalid',
                  ),
                  SizedBox(height: 12),
                  BeuiInput(
                    label: 'Disabled',
                    defaultValue: 'Off',
                    enabled: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('golden')),
      matchesGoldenFile('goldens/beui_input.png'),
    );
  });
}
