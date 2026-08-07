import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps a [BeuiLoader] in a themed app. [reduce] forces reduced motion.
Widget _app(BeuiLoaderVariant variant, {bool reduce = false}) {
  Widget child = Center(child: BeuiLoader(variant: variant, size: 40));
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

void main() {
  // Loaders loop forever — never pumpAndSettle (it would time out); pump a
  // fixed number of frames instead.
  group('BeuiLoader renders every variant', () {
    for (final variant in BeuiLoaderVariant.values) {
      testWidgets('$variant builds and animates without error', (tester) async {
        await tester.pumpWidget(_app(variant));
        await tester.pump(); // first animated frame
        await tester.pump(const Duration(milliseconds: 120));
        expect(find.byType(BeuiLoader), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('BeuiLoader reduced motion', () {
    for (final variant in BeuiLoaderVariant.values) {
      testWidgets('$variant renders under reduced motion', (tester) async {
        await tester.pumpWidget(_app(variant, reduce: true));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        expect(find.byType(BeuiLoader), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('spinner drops rotation, keeps an opacity pulse', (
      tester,
    ) async {
      await tester.pumpWidget(_app(BeuiLoaderVariant.spinner, reduce: true));
      await tester.pump();
      // The reduced-motion pulse wraps the static frame in an Opacity.
      expect(
        find.descendant(
          of: find.byType(BeuiLoader),
          matching: find.byType(Opacity),
        ),
        findsWidgets,
      );
    });

    testWidgets('scramble settles to LOADING under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(_app(BeuiLoaderVariant.scramble, reduce: true));
      await tester.pump();
      expect(find.text('LOADING'), findsOneWidget);
    });
  });

  group('BeuiLoader API', () {
    testWidgets('applies the given color to a drawn variant', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          home: const Scaffold(
            body: Center(
              child: BeuiLoader(
                variant: BeuiLoaderVariant.spinner,
                color: Color(0xFF00FF00),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('exposes an accessible label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(BeuiLoaderVariant.dots));
      await tester.pump();
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      handle.dispose();
    });
  });

  testWidgets('grid golden (all variants at first frame)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(520, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        home: const Scaffold(
          body: Center(child: RepaintBoundary(child: _Grid())),
        ),
      ),
    );
    await tester.pump(); // deterministic first frame (controller value 0)
    await expectLater(
      find.byType(_Grid),
      matchesGoldenFile('goldens/beui_loader.png'),
    );
  });
}

/// A compact grid of every variant at rest, for the golden.
class _Grid extends StatelessWidget {
  const _Grid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final v in BeuiLoaderVariant.values)
          Padding(
            padding: const EdgeInsets.all(4),
            child: BeuiLoader(variant: v, size: 30),
          ),
      ],
    );
  }
}
