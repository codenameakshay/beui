import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

Future<TestGesture> _hover(WidgetTester tester, Finder finder) async {
  // FocusableActionDetector only reports a hover highlight (which drives the
  // base button's 1.02 lift) when the focus highlight mode is `traditional` —
  // i.e. a real pointer host. The widget-test binding defaults to a touch-first
  // platform, so its highlight mode is `touch` and the callback never fires.
  // Force `alwaysTraditional` to faithfully simulate the mouse/desktop host the
  // hover lift targets, then restore the previous strategy.
  final previousStrategy = FocusManager.instance.highlightStrategy;
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => FocusManager.instance.highlightStrategy = previousStrategy);
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(finder));
  await tester.pumpAndSettle();
  return gesture;
}

double _buttonScale(WidgetTester tester) {
  // storage[0] is the x-scale. (getMaxScaleOnAxis is unusable here: a 2D
  // scale-down leaves the z axis at 1.0, so it would always report 1.0.)
  final transforms = tester.widgetList<Transform>(
    find.descendant(
      of: find.byType(BeuiButton),
      matching: find.byType(Transform),
    ),
  );
  return transforms.map((t) => t.transform.storage[0]).reduce(math.min);
}

void main() {
  group('BeuiButton', () {
    testWidgets('tap fires onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(BeuiButton(onPressed: () => taps++, child: const Text('Go'))),
      );
      await tester.tap(find.byType(BeuiButton));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('disabled (null onPressed) does not fire and is dimmed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const BeuiButton(onPressed: null, child: Text('Go'))),
      );
      await tester.tap(find.byType(BeuiButton), warnIfMissed: false);
      await tester.pump();
      final dim = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(BeuiButton),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(dim.opacity, 0.5);
    });

    testWidgets('Enter activates when focused', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(BeuiButton(onPressed: () => taps++, child: const Text('Go'))),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('exposes button + enabled semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(BeuiButton(onPressed: () {}, child: const Text('Go'))),
      );
      expect(
        tester.getSemantics(find.text('Go')),
        isSemantics(isButton: true, isEnabled: true),
      );
      handle.dispose();
    });

    testWidgets('icon size is square 32x32', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiButton(
            onPressed: () {},
            size: BeuiButtonSize.icon,
            child: const Icon(Icons.star),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(BeuiButton)), const Size(32, 32));
    });

    testWidgets('press scales down then settles back under normal motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(BeuiButton(onPressed: () {}, child: const Text('Go'))),
      );
      await tester.pumpAndSettle();
      expect(_buttonScale(tester), closeTo(1.0, 0.001));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(BeuiButton)),
      );
      var minScale = 1.0;
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        minScale = math.min(minScale, _buttonScale(tester));
      }
      expect(minScale, lessThan(1.0)); // pressed in at some point

      await gesture.up();
      await tester.pumpAndSettle();
      expect(_buttonScale(tester), closeTo(1.0, 0.001)); // settled back
    });

    testWidgets('no press scale under reduced motion', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiButton(onPressed: () {}, child: const Text('Go')),
          reduce: true,
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(BeuiButton)),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_buttonScale(tester), closeTo(1.0, 0.001));
      await gesture.up();
    });

    testWidgets('hover lifts to 1.02 by default', (tester) async {
      await tester.pumpWidget(
        _wrap(BeuiButton(onPressed: () {}, child: const Text('Go'))),
      );
      await tester.pumpAndSettle();
      await _hover(tester, find.byType(BeuiButton));
      expect(_buttonScale(tester), closeTo(1.02, 0.01));
    });

    testWidgets('enableHoverScale: false suppresses the hover lift', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BeuiButton(
            onPressed: () {},
            enableHoverScale: false,
            child: const Text('Go'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _hover(tester, find.byType(BeuiButton));
      expect(_buttonScale(tester), closeTo(1.0, 0.001));
    });
  });

  group('BeuiStatefulButton', () {
    testWidgets('idle shows label and fires onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(BeuiStatefulButton(label: 'Save', onPressed: () => taps++)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsOneWidget);
      await tester.tap(find.byType(BeuiStatefulButton));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('loading shows a spinner, busy lockout blocks taps', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiStatefulButton(
            label: 'Save',
            state: BeuiButtonState.loading,
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RotationTransition), findsAtLeastNWidgets(1));
      expect(find.text('Loading'), findsOneWidget);
      await tester.tap(find.byType(BeuiStatefulButton), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('text transition applies a visible blur', (tester) async {
      Widget app(BeuiButtonState s) => _wrap(
        BeuiStatefulButton(label: 'Save changes', state: s, onPressed: () {}),
      );
      await tester.pumpWidget(app(BeuiButtonState.idle));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(BeuiButtonState.success));
      await tester.pump(const Duration(milliseconds: 60)); // mid roll
      final sigmas = tester
          .widgetList<ImageFiltered>(find.byType(ImageFiltered))
          .map((f) {
            final m = RegExp(
              r'blur\(([\d.]+)',
            ).firstMatch(f.imageFilter.toString());
            return m == null ? 0.0 : double.parse(m.group(1)!);
          });
      expect(sigmas.fold<double>(0, math.max), greaterThan(2.0));
    });

    testWidgets('width morphs (does not snap) when toggling busy', (
      tester,
    ) async {
      Widget app(BeuiButtonState s) => _wrap(
        BeuiStatefulButton(
          label: 'Save changes',
          icon: LucideIcons.arrow_right,
          state: s,
          onPressed: () {},
        ),
      );
      await tester.pumpWidget(app(BeuiButtonState.idle));
      await tester.pumpAndSettle();

      // idle -> loading flips the base button to disabled. The width must
      // animate across frames, not snap (regression: a conditional Opacity
      // wrapper used to reset the AnimatedSize's State, jumping the width).
      await tester.pumpWidget(app(BeuiButtonState.loading));
      final widths = <double>[];
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        widths.add(tester.getSize(find.byType(BeuiStatefulButton)).width);
      }
      expect(widths.toSet().length, greaterThan(1)); // distinct => animating
    });

    testWidgets('success and error show their text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiStatefulButton(
            label: 'Save',
            state: BeuiButtonState.success,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          const BeuiStatefulButton(label: 'Save', state: BeuiButtonState.error),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('does not lift on hover (source whileHover={undefined})', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(BeuiStatefulButton(label: 'Save', onPressed: () {})),
      );
      await tester.pumpAndSettle();
      await _hover(tester, find.byType(BeuiButton));
      expect(_buttonScale(tester), closeTo(1.0, 0.001));
    });
  });

  group('BeuiMagnetic', () {
    testWidgets('applies a follow-spring on hover-capable; off under reduce', (
      tester,
    ) async {
      const child = SizedBox(
        key: ValueKey('magnetic-child'),
        width: 40,
        height: 40,
      );
      final box = find.byKey(const ValueKey('magnetic-child'));

      await tester.pumpWidget(_wrap(const BeuiMagnetic(child: child)));
      final rest = tester.getCenter(box);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      // A corner point, well off-center but still inside the 40x40 box, so
      // the pull is unambiguous.
      await gesture.moveTo(rest + const Offset(15, -15));
      // The ticker's first tick (this frame) fires at elapsed ~0, so sample a
      // few frames in to catch it mid-flight rather than already arrived.
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final midFrame = tester.getCenter(box);
      final target = const Offset(15, -15) * 0.35;
      // Already moving toward the cursor, not still at rest nor snapped there.
      expect(midFrame, isNot(rest));
      expect((midFrame - rest).distance, lessThan(target.distance));

      await tester.pumpAndSettle();
      final settled = tester.getCenter(box);
      // Settles near (cursor - center) * strength (default strength 0.35).
      expect(settled.dx - rest.dx, closeTo(15 * 0.35, 1));
      expect(settled.dy - rest.dy, closeTo(-15 * 0.35, 1));

      // Exit springs back to rest.
      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(box),
        offsetMoreOrLessEquals(rest, epsilon: 0.05),
      );

      // Reduced motion: hovering the same spot never moves it at all.
      await tester.pumpWidget(
        _wrap(const BeuiMagnetic(child: child), reduce: true),
      );
      final reducedRest = tester.getCenter(box);
      await gesture.moveTo(reducedRest + const Offset(15, -15));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.getCenter(box),
        offsetMoreOrLessEquals(reducedRest, epsilon: 0.05),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(box),
        offsetMoreOrLessEquals(reducedRest, epsilon: 0.05),
      );
    });

    testWidgets('BeuiMagneticButton taps through', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiMagneticButton(onPressed: () => taps++, child: const Text('Go')),
        ),
      );
      await tester.tap(find.byType(BeuiButton));
      await tester.pump();
      expect(taps, 1);
    });
  });

  testWidgets('rest-state golden (variants, sizes, stateful)', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final v in BeuiButtonVariant.values)
                  BeuiButton(
                    onPressed: () {},
                    variant: v,
                    child: const Text('Button'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final s in [
                  BeuiButtonSize.sm,
                  BeuiButtonSize.md,
                  BeuiButtonSize.lg,
                ])
                  BeuiButton(
                    onPressed: () {},
                    size: s,
                    child: const Text('Size'),
                  ),
                BeuiButton(
                  onPressed: () {},
                  size: BeuiButtonSize.icon,
                  child: const Icon(Icons.star),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                BeuiStatefulButton(label: 'Idle', onPressed: () {}),
                BeuiStatefulButton(
                  label: 'Save',
                  state: BeuiButtonState.success,
                  onPressed: () {},
                ),
                BeuiStatefulButton(
                  label: 'Save',
                  state: BeuiButtonState.error,
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Column).first,
      matchesGoldenFile('goldens/beui_button.png'),
    );
  });

  testWidgets(
    'label inherits the ambient font family and honours borderRadius',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily: 'HostFace',
          ).copyWith(extensions: [BeuiColors.light()]),
          home: const Scaffold(
            body: Center(
              child: BeuiButton(
                size: BeuiButtonSize.icon,
                borderRadius: BorderRadius.all(Radius.circular(999)),
                child: Text('Go'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // AnimatedDefaultTextStyle *replaces* the ambient style, so a bare
      // TextStyle would silently reset the label to the platform default face.
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('Go'))
            .text
            .style
            ?.fontFamily,
        'HostFace',
      );

      final box = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byType(BeuiButton),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(
        (box.decoration! as BoxDecoration).borderRadius,
        BorderRadius.circular(999),
      );
    },
  );
}
