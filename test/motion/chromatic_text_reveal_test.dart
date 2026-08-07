import 'package:beui/beui.dart';
import 'package:beui/src/motion/chromatic_text_reveal.dart'
    show chromaticGradient;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _prefix = 'Build faster with';
const _fg = Color(0xFF00AA55);

Widget _app(Widget child, {bool reduce = false}) {
  Widget body = child;
  if (reduce) {
    body = MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: body,
    );
  }
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(body: Center(child: body)),
  );
}

Widget _reveal({
  List<String> words = const ['Flutter'],
  Duration duration = const Duration(milliseconds: 400),
  Duration pause = const Duration(milliseconds: 100),
  bool loop = true,
}) => BeuiChromaticTextReveal(
  prefix: _prefix,
  words: words,
  foregroundColor: _fg,
  duration: duration,
  pauseDuration: pause,
  loop: loop,
  style: const TextStyle(fontSize: 20),
);

/// The swept word's own [Text] — the one recoloured to [_fg]; the invisible
/// sizing copies keep the ambient style.
Finder _sweptText(String word) => find.byWidgetPredicate(
  (w) => w is Text && w.data == word && w.style?.color == _fg,
);

Finder _inReveal(Finder matching) => find.descendant(
  of: find.byType(BeuiChromaticTextReveal),
  matching: matching,
);

void main() {
  group('chromatic gradient (source composeChromaticGradient)', () {
    const palette = BeuiChromaticTextReveal.defaultColors;

    void expectStops(List<double> actual, List<double> expected) {
      expect(actual.length, expected.length);
      for (var i = 0; i < expected.length; i++) {
        expect(actual[i], closeTo(expected[i], 1e-9), reason: 'stop $i');
      }
    }

    test('mid-sweep stop layout matches the CSS formula', () {
      final g = chromaticGradient(
        sweep: 0.5,
        palette: palette,
        foreground: _fg,
      );

      expect(g.colors.length, g.stops.length);
      // fg 0% · fg (s-14%) · the five palette stops spread over s±14% ·
      // transparent (s+14%) · transparent 100%.
      expectStops(g.stops, [
        0.0,
        0.36,
        0.36,
        0.43,
        0.50,
        0.57,
        0.64,
        0.64,
        1.0,
      ]);
      expect(g.colors[0], _fg);
      expect(g.colors[1], _fg);
      expect(g.colors.sublist(2, 7), palette);
      // The terminator is the last palette hue at alpha 0 — CSS `transparent`
      // without the black fringe Flutter's unpremultiplied lerp would add.
      expect(g.colors[7], palette.last.withValues(alpha: 0));
      expect(g.colors[8], palette.last.withValues(alpha: 0));
    });

    test(
      'stops stay inside 0..1 and never regress, across the whole travel',
      () {
        for (final sweep in <double>[-0.14, 0, 0.25, 0.5, 0.75, 1, 1.14]) {
          final g = chromaticGradient(
            sweep: sweep,
            palette: palette,
            foreground: _fg,
          );
          expect(g.stops.first, 0.0);
          expect(g.stops.last, 1.0);
          for (var i = 1; i < g.stops.length; i++) {
            expect(
              g.stops[i],
              inInclusiveRange(0.0, 1.0),
              reason: 'sweep $sweep',
            );
            expect(
              g.stops[i],
              greaterThanOrEqualTo(g.stops[i - 1]),
              reason: 'sweep $sweep, stop $i',
            );
          }
        }
      },
    );

    test('travel start paints nothing; travel end paints solid foreground', () {
      final start = chromaticGradient(
        sweep: -0.14,
        palette: palette,
        foreground: _fg,
      );
      // Every stop but the trailing one has collapsed to 0, so the painted
      // 0..1 range reads the transparent terminator: the word is unrevealed.
      expect(start.stops.sublist(0, start.stops.length - 1), everyElement(0.0));
      expect(start.colors.last.a, 0);

      final end = chromaticGradient(
        sweep: 1.14,
        palette: palette,
        foreground: _fg,
      );
      // Foreground spans the full width: the trail has left the far edge.
      expect(end.stops[1], closeTo(1, 1e-9));
      expect(end.colors[0], _fg);
      expect(end.colors[1], _fg);
    });

    test('a single-colour palette collapses the trail to one hue', () {
      const red = Color(0xFFFF0000);
      final g = chromaticGradient(
        sweep: 0.5,
        palette: const [red],
        foreground: _fg,
      );
      expectStops(g.stops, [0.0, 0.36, 0.50, 0.64, 1.0]);
      expect(g.colors, [
        _fg,
        _fg,
        red,
        red.withValues(alpha: 0),
        red.withValues(alpha: 0),
      ]);
    });

    test('an empty palette falls back to the source default', () {
      final g = chromaticGradient(
        sweep: 0.5,
        palette: const [],
        foreground: _fg,
      );
      expect(g.colors.sublist(2, 7), BeuiChromaticTextReveal.defaultColors);
    });
  });

  group('reveal', () {
    testWidgets('renders the prefix and announces the whole sentence', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_reveal()));
      await tester.pump();

      expect(find.textContaining(_prefix), findsOneWidget);
      // The animated glyphs are decorative; the resolved sentence is what a
      // screen reader gets.
      expect(find.bySemanticsLabel('$_prefix Flutter'), findsOneWidget);

      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets(
      'sweeps the word through a ShaderMask, then settles to plain foreground text',
      (tester) async {
        await tester.pumpWidget(_app(_reveal()));
        await tester.pump();
        // No enclosing scrollable → counts as in view and starts on first
        // layout (startOnView defaults to true).
        await tester.pump(const Duration(milliseconds: 200));

        // Mid-sweep: the chromatic edge is painted as a mask over the glyphs,
        // riding the enter fade and rise.
        expect(_inReveal(find.byType(ShaderMask)), findsOneWidget);
        expect(_inReveal(find.byType(Transform)), findsOneWidget);
        final opacity = tester.widget<Opacity>(
          find
              .ancestor(
                of: find.byType(ShaderMask),
                matching: find.byType(Opacity),
              )
              .first,
        );
        expect(opacity.opacity, greaterThanOrEqualTo(0.56));
        expect(opacity.opacity, lessThanOrEqualTo(1.0));

        // Settled: the mask, the blur and the transform are all gone — a
        // revealed word costs nothing per frame.
        await tester.pump(const Duration(milliseconds: 500));
        expect(_inReveal(find.byType(ShaderMask)), findsNothing);
        expect(_inReveal(find.byType(ImageFiltered)), findsNothing);
        expect(_inReveal(find.byType(Transform)), findsNothing);
        expect(_sweptText('Flutter'), findsOneWidget);
      },
    );

    testWidgets('cycles to the next word after the sweep plus the pause', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          _reveal(
            words: const ['Flutter', 'Dart'],
            duration: const Duration(milliseconds: 200),
            pause: const Duration(milliseconds: 100),
          ),
        ),
      );
      await tester.pump();

      // Sweep done — the word is revealed but the pause has not elapsed.
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.bySemanticsLabel('$_prefix Flutter'), findsOneWidget);

      // Pause elapsed — hand over to the next word.
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.bySemanticsLabel('$_prefix Dart'), findsOneWidget);
      expect(find.bySemanticsLabel('$_prefix Flutter'), findsNothing);

      await tester.pumpWidget(const SizedBox()); // cancel the pending cycle
      handle.dispose();
    });

    testWidgets('loop: false holds on the last word', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          _reveal(
            words: const ['One', 'Two'],
            duration: const Duration(milliseconds: 100),
            pause: const Duration(milliseconds: 50),
            loop: false,
          ),
        ),
      );
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 200)); // sweep 1
      await tester.pump(const Duration(milliseconds: 100)); // pause → word 2
      expect(find.bySemanticsLabel('$_prefix Two'), findsOneWidget);

      // Well past sweep 2 + pause: it must not wrap back to the first word,
      // and no cycle timer may be left pending.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('$_prefix Two'), findsOneWidget);

      handle.dispose();
    });

    testWidgets(
      'reduced motion settles on the foreground colour: no sweep, no movement, no cycling',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _app(
            _reveal(
              words: const ['Flutter', 'Dart'],
              duration: const Duration(milliseconds: 200),
              pause: const Duration(milliseconds: 100),
            ),
            reduce: true,
          ),
        );
        await tester.pump();

        // The word is already in its final colour...
        expect(_sweptText('Flutter'), findsOneWidget);
        // ...painted directly, with no mask, no blur and no transform delta.
        expect(_inReveal(find.byType(ShaderMask)), findsNothing);
        expect(_inReveal(find.byType(ImageFiltered)), findsNothing);
        expect(_inReveal(find.byType(Transform)), findsNothing);

        // The cycle exists only to show the sweep, so it never starts.
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.bySemanticsLabel('$_prefix Flutter'), findsOneWidget);
        expect(find.bySemanticsLabel('$_prefix Dart'), findsNothing);

        handle.dispose();
      },
    );

    testWidgets('an empty word list renders the prefix alone', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_reveal(words: const [])));
      await tester.pumpAndSettle();

      expect(find.text(_prefix), findsOneWidget);
      expect(find.bySemanticsLabel(_prefix), findsOneWidget);
      expect(_inReveal(find.byType(ShaderMask)), findsNothing);

      handle.dispose();
    });
  });
}
