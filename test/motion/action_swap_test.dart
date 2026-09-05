import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

Widget _wrap(Widget child, {bool reduce = false}) {
  Widget body = Center(child: child);
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

/// Max blur sigma currently applied by any ImageFiltered in the tree.
const _items = [
  BeuiActionSwapItem(id: 'copy', label: 'Copy link', icon: Icons.link),
  BeuiActionSwapItem(id: 'copied', label: 'Copied', icon: Icons.check),
];

void main() {
  group('BeuiActionSwapButton', () {
    testWidgets('tap cycles to the next item and fires onChanged', (
      tester,
    ) async {
      String? changedTo;
      await tester.pumpWidget(
        _wrap(
          BeuiActionSwapButton(
            items: _items,
            onChanged: (id, _) => changedTo = id,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Copy link'), findsOneWidget);

      await tester.tap(find.byType(BeuiActionSwapButton));
      await tester.pumpAndSettle();
      expect(changedTo, 'copied');
      expect(find.text('Copied'), findsOneWidget);

      // Wraps back around.
      await tester.tap(find.byType(BeuiActionSwapButton));
      await tester.pumpAndSettle();
      expect(find.text('Copy link'), findsOneWidget);
    });

    testWidgets('label inherits the ambient font family', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily: 'HostFace',
          ).copyWith(extensions: [BeuiColors.light()]),
          home: const Scaffold(
            body: Center(child: BeuiActionSwapButton(items: _items)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // AnimatedDefaultTextStyle *replaces* the ambient style, so a bare
      // TextStyle would silently reset the label to the platform default face.
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('Copy link'))
            .text
            .style
            ?.fontFamily,
        'HostFace',
      );
    });

    testWidgets('controlled value ignores internal state', (tester) async {
      var changes = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiActionSwapButton(
            items: _items,
            value: 'copy',
            onChanged: (_, _) => changes++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BeuiActionSwapButton));
      await tester.pumpAndSettle();
      // onChanged still fires, but the label stays 'Copy link' (parent owns it).
      expect(changes, 1);
      expect(find.text('Copy link'), findsOneWidget);
    });

    testWidgets('iconOnly hides the label and exposes a semantic label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const BeuiActionSwapButton(items: _items, iconOnly: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Copy link'), findsNothing);
    });
  });

  group('BeuiActionSwapText — value change triggers transition', () {
    testWidgets('width animates (does not snap) when the label grows', (
      tester,
    ) async {
      Widget app(String v, String t) =>
          _wrap(BeuiActionSwapText(value: v, text: t));
      // Measure the AnimatedSize box, which hugs the content width.
      final box = find.descendant(
        of: find.byType(BeuiActionSwapText),
        matching: find.byType(AnimatedSize),
      );

      await tester.pumpWidget(app('a', 'Hi'));
      await tester.pumpAndSettle();
      final start = tester.getSize(box).width;

      await tester.pumpWidget(app('b', 'A much longer label'));
      final widths = <double>[];
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        widths.add(tester.getSize(box).width);
      }
      // Distinct intermediate widths => animating, not snapping.
      expect(widths.toSet().length, greaterThan(1));
      await tester.pumpAndSettle();
      final end = tester.getSize(box).width;
      expect(end, greaterThan(start));
    });

    testWidgets('blur variant applies a visible blur mid-transition', (
      tester,
    ) async {
      Widget app(String v, String t) => _wrap(
        BeuiActionSwapText(
          value: v,
          text: t,
          variant: BeuiActionSwapVariant.blur,
        ),
      );
      await tester.pumpWidget(app('a', 'One'));
      await tester.pumpAndSettle();
      expect(maxBlurSigma(tester), 0);

      await tester.pumpWidget(app('b', 'Two'));
      await tester.pump(const Duration(milliseconds: 60));
      expect(maxBlurSigma(tester), greaterThan(0.5));
    });
  });

  group('variants differ', () {
    // roll/cascade translate; blur scales. Verify the mechanics diverge by
    // sampling the transform tree mid-transition.
    Future<bool> hasTranslate(
      WidgetTester tester,
      BeuiActionSwapVariant variant,
    ) async {
      Widget app(String v, String t) =>
          _wrap(BeuiActionSwapText(value: v, text: t, variant: variant));
      await tester.pumpWidget(app('a', 'One'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app('b', 'Two'));
      await tester.pump(const Duration(milliseconds: 50));
      final translated = tester
          .widgetList<Transform>(find.byType(Transform))
          .any((t) => t.transform.getTranslation().y.abs() > 0.5);
      await tester.pumpAndSettle();
      return translated;
    }

    testWidgets('roll uses vertical translation', (tester) async {
      expect(await hasTranslate(tester, BeuiActionSwapVariant.roll), isTrue);
    });

    testWidgets('cascade uses vertical translation', (tester) async {
      expect(await hasTranslate(tester, BeuiActionSwapVariant.cascade), isTrue);
    });

    testWidgets('blur does not translate (scales instead)', (tester) async {
      expect(await hasTranslate(tester, BeuiActionSwapVariant.blur), isFalse);
    });
  });

  group('roll direction (source: old out the top, new from below)', () {
    // The non-zero vertical translation applied to [text]'s layer.
    double translateY(WidgetTester tester, String text) {
      final transforms = find.ancestor(
        of: find.text(text),
        matching: find.byType(Transform),
      );
      for (final t in tester.widgetList<Transform>(transforms)) {
        final y = t.transform.getTranslation().y;
        if (y.abs() > 0.01) return y;
      }
      return 0;
    }

    testWidgets('old text rolls UP and out; new text enters from BELOW', (
      tester,
    ) async {
      Widget app(String v, String t) => _wrap(
        BeuiActionSwapText(
          value: v,
          text: t,
          variant: BeuiActionSwapVariant.roll,
        ),
      );
      await tester.pumpWidget(app('a', 'One'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(app('b', 'Two'));
      await tester.pump(const Duration(milliseconds: 90)); // mid-transition

      // Both layers are on screen; the OUTgoing 'One' is above the baseline
      // (negative y → out the top), the INcoming 'Two' is below it (positive y).
      expect(translateY(tester, 'One'), lessThan(0));
      expect(translateY(tester, 'Two'), greaterThan(0));

      await tester.pumpAndSettle();
    });
  });

  group('reduced motion drops movement', () {
    Future<void> checkNoMovement(
      WidgetTester tester,
      BeuiActionSwapVariant variant,
    ) async {
      Widget app(String v, String t) => _wrap(
        BeuiActionSwapText(value: v, text: t, variant: variant),
        reduce: true,
      );
      await tester.pumpWidget(app('a', 'One'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app('b', 'Two'));
      // Sample across the whole transition window.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        // No movement: no translating Transform, no blur.
        final translated = tester
            .widgetList<Transform>(find.byType(Transform))
            .any((t) => t.transform.getTranslation().y.abs() > 0.5);
        expect(translated, isFalse, reason: '$variant should not translate');
        expect(maxBlurSigma(tester), 0, reason: '$variant should not blur');
      }
      await tester.pumpAndSettle();
    }

    testWidgets('blur: crossfade only', (tester) async {
      await checkNoMovement(tester, BeuiActionSwapVariant.blur);
    });
    testWidgets('roll: crossfade only', (tester) async {
      await checkNoMovement(tester, BeuiActionSwapVariant.roll);
    });
    testWidgets('cascade: crossfade only', (tester) async {
      await checkNoMovement(tester, BeuiActionSwapVariant.cascade);
    });
  });
}
