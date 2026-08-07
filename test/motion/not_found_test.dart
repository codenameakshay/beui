import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduce = false}) {
  Widget body = SingleChildScrollView(child: Center(child: child));
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
  group('BeuiNotFound variants', () {
    testWidgets('each variant renders code, copy and both actions', (
      tester,
    ) async {
      final variants = <Widget>[
        const BeuiNotFoundGlitch(),
        const BeuiNotFoundMagnetic(),
        const BeuiNotFoundSpotlight(),
        const BeuiNotFoundStacked(),
      ];
      for (final variant in variants) {
        await tester.pumpWidget(_wrap(variant));
        await tester.pump(const Duration(milliseconds: 1000));
        expect(find.text('Page not found'), findsOneWidget);
        expect(
          find.text(
            'The page you are looking for moved, vanished, or never existed.',
          ),
          findsOneWidget,
        );
        expect(find.text('Back home'), findsOneWidget);
        expect(find.text('Browse components'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('actions fire onHome and onBrowse', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(
        _wrap(
          BeuiNotFoundStacked(
            onHome: () => log.add('home'),
            onBrowse: () => log.add('browse'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back home'));
      await tester.tap(find.text('Browse components'));
      await tester.pumpAndSettle();
      expect(log, ['home', 'browse']);
    });

    testWidgets('glitch scrambles on mount, then settles to the code', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const BeuiNotFoundGlitch(code: '404')));
      await tester.pump(const Duration(milliseconds: 100)); // mid-scramble
      // After the 700ms scramble the real code is shown.
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('404'), findsWidgets);
    });

    testWidgets('glitch under reduced motion shows the code immediately', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const BeuiNotFoundGlitch(code: '404'), reduce: true),
      );
      await tester.pump();
      expect(find.text('404'), findsWidgets);
    });

    testWidgets('magnetic renders one Magnetic wrapper per glyph', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const BeuiNotFoundMagnetic(code: '404')));
      await tester.pumpAndSettle();
      expect(find.byType(BeuiMagnetic), findsNWidgets(3));
    });

    testWidgets('stacked spreads the deck on hover', (tester) async {
      await tester.pumpWidget(_wrap(const BeuiNotFoundStacked()));
      await tester.pumpAndSettle();

      double maxRotation() => tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(BeuiNotFoundStacked),
              matching: find.byType(Transform),
            ),
          )
          .map((t) {
            final m = t.transform;
            // Rotation shows up in the off-diagonal terms.
            return m.storage[1].abs() + m.storage[4].abs();
          })
          .fold<double>(0, (a, b) => a > b ? a : b);

      expect(maxRotation(), lessThan(0.01));

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('404')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(maxRotation(), greaterThan(0.05), reason: 'cards fanned out');
    });

    testWidgets('terminal types its script', (tester) async {
      await tester.pumpWidget(_wrap(const BeuiNotFoundTerminal(code: '404')));
      // Reveals stagger over ~2s; the cursor pulses forever → bounded pumps.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.textContaining('~/beui'), findsOneWidget);
      expect(find.text('Back home'), findsOneWidget);
    });
  });
}
