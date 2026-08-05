import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduce = false}) {
  Widget body = child;
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
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: body),
  );
}

double _maxBlurSigma(WidgetTester tester) => tester
    .widgetList<ImageFiltered>(find.byType(ImageFiltered))
    .map((f) {
      final m = RegExp(r'blur\(([\d.]+)').firstMatch(f.imageFilter.toString());
      return m == null ? 0.0 : double.parse(m.group(1)!);
    })
    .fold<double>(0, math.max);

/// A tall scrollable page with [child] embedded far below the fold.
Widget _page({
  required ScrollController controller,
  Widget? child,
  Widget? overlay,
  double lead = 2000,
}) {
  final list = SingleChildScrollView(
    controller: controller,
    child: Column(
      children: [
        SizedBox(height: lead),
        ?child,
        const SizedBox(height: 2000),
      ],
    ),
  );
  if (overlay == null) return list;
  return Stack(children: [list, overlay]);
}

/// A tall scroller whose rows are hit-testable, so pointer input (wheel, drag,
/// fling) actually lands on it — unlike [_page], which is built from empty
/// boxes that no hit test can find.
Widget _rows({required ScrollController controller}) => ListView.builder(
  controller: controller,
  itemCount: 40,
  itemBuilder: (context, i) => SizedBox(height: 100, child: Text('row $i')),
);

/// A wide horizontal scroller.
Widget _strip({required ScrollController controller}) => SizedBox(
  height: 120,
  child: ListView.builder(
    controller: controller,
    scrollDirection: Axis.horizontal,
    itemCount: 20,
    itemBuilder: (context, i) => SizedBox(width: 200, child: Text('$i')),
  ),
);

/// Sends one wheel notch over [target].
Future<void> _wheel(WidgetTester tester, Finder target, Offset delta) async {
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  final centre = tester.getCenter(target);
  await tester.sendEventToBinding(pointer.hover(centre));
  await tester.sendEventToBinding(pointer.scroll(delta));
  await tester.pump();
}

void main() {
  group('BeuiSmoothScroll', () {
    testWidgets('exposes scrollY and progress that track the scrollable', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      late BeuiSmoothScrollApi api;
      await tester.pumpWidget(
        _wrap(
          BeuiSmoothScroll(
            child: Builder(
              builder: (context) {
                api = BeuiSmoothScroll.of(context);
                return _page(controller: controller);
              },
            ),
          ),
        ),
      );
      expect(api.scrollY.value, 0);
      controller.jumpTo(1000);
      await tester.pump();
      expect(api.scrollY.value, 1000);
      expect(api.progress.value, greaterThan(0));
      expect(api.progress.value, lessThan(1));
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(api.progress.value, moreOrLessEquals(1, epsilon: 0.001));
    });

    testWidgets('scrollTo eases to the offset over time', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      late BeuiSmoothScrollApi api;
      await tester.pumpWidget(
        _wrap(
          BeuiSmoothScroll(
            child: Builder(
              builder: (context) {
                api = BeuiSmoothScroll.of(context);
                return _page(controller: controller);
              },
            ),
          ),
        ),
      );
      api.scrollTo(1500);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = controller.offset;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1500), reason: 'still gliding');
      await tester.pumpAndSettle();
      expect(controller.offset, moreOrLessEquals(1500, epsilon: 1));
    });

    testWidgets('scrollTo jumps instantly under reduced motion', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      late BeuiSmoothScrollApi api;
      await tester.pumpWidget(
        _wrap(
          BeuiSmoothScroll(
            child: Builder(
              builder: (context) {
                api = BeuiSmoothScroll.of(context);
                return _page(controller: controller);
              },
            ),
          ),
          reduce: true,
        ),
      );
      api.scrollTo(1500);
      await tester.pump();
      expect(controller.offset, 1500);
    });
  });

  group('BeuiSmoothScroll orientation', () {
    testWidgets('a vertical provider ignores a horizontal scrollable', (
      tester,
    ) async {
      final horizontal = ScrollController();
      addTearDown(horizontal.dispose);
      late BeuiSmoothScrollApi api;
      await tester.pumpWidget(
        _wrap(
          BeuiSmoothScroll(
            child: Builder(
              builder: (context) {
                api = BeuiSmoothScroll.of(context);
                return _strip(controller: horizontal);
              },
            ),
          ),
        ),
      );
      horizontal.jumpTo(400);
      await tester.pump();
      expect(
        api.scrollY.value,
        0,
        reason: 'the wrong axis must not feed the shared state',
      );
      expect(api.progress.value, 0);
    });

    testWidgets('a horizontal provider tracks the horizontal scrollable', (
      tester,
    ) async {
      final horizontal = ScrollController();
      addTearDown(horizontal.dispose);
      late BeuiSmoothScrollApi api;
      await tester.pumpWidget(
        _wrap(
          BeuiSmoothScroll(
            orientation: BeuiSmoothScrollOrientation.horizontal,
            child: Builder(
              builder: (context) {
                api = BeuiSmoothScroll.of(context);
                return _strip(controller: horizontal);
              },
            ),
          ),
        ),
      );
      horizontal.jumpTo(400);
      await tester.pump();
      expect(api.scrollY.value, 400);
      expect(api.progress.value, greaterThan(0));
      expect(api.progress.value, lessThan(1));
    });

    testWidgets('scrollTo glides the horizontal scrollable', (tester) async {
      final horizontal = ScrollController();
      addTearDown(horizontal.dispose);
      late BeuiSmoothScrollApi api;
      await tester.pumpWidget(
        _wrap(
          BeuiSmoothScroll(
            orientation: BeuiSmoothScrollOrientation.horizontal,
            child: Builder(
              builder: (context) {
                api = BeuiSmoothScroll.of(context);
                return _strip(controller: horizontal);
              },
            ),
          ),
        ),
      );
      api.scrollTo(600);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(horizontal.offset, greaterThan(0));
      expect(horizontal.offset, lessThan(600));
      await tester.pumpAndSettle();
      expect(horizontal.offset, moreOrLessEquals(600, epsilon: 1));
    });

    testWidgets('maps the vertical wheel onto the horizontal offset', (
      tester,
    ) async {
      final horizontal = ScrollController();
      addTearDown(horizontal.dispose);
      await tester.pumpWidget(
        _wrap(
          BeuiSmoothScroll(
            orientation: BeuiSmoothScrollOrientation.horizontal,
            child: _strip(controller: horizontal),
          ),
        ),
      );
      horizontal.jumpTo(100);
      await tester.pump();
      await _wheel(tester, find.byType(ListView), const Offset(0, 120));
      // Flutter alone would ignore dy here; the provider forwards it.
      expect(horizontal.offset, moreOrLessEquals(220, epsilon: 0.5));
    });
  });

  group('BeuiSmoothScroll wheelMultiplier', () {
    Future<double> wheeled(
      WidgetTester tester, {
      required double multiplier,
      bool reduce = false,
    }) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          BeuiSmoothScroll(
            wheelMultiplier: multiplier,
            child: _rows(controller: controller),
          ),
          reduce: reduce,
        ),
      );
      controller.jumpTo(500);
      await tester.pump();
      await _wheel(tester, find.byType(ListView), const Offset(0, 100));
      return controller.offset - 500;
    }

    testWidgets('1 (default) leaves the platform step untouched', (
      tester,
    ) async {
      expect(
        await wheeled(tester, multiplier: 1),
        moreOrLessEquals(100, epsilon: 0.5),
      );
    });

    testWidgets('scales the step up and down', (tester) async {
      expect(
        await wheeled(tester, multiplier: 2),
        moreOrLessEquals(200, epsilon: 0.5),
      );
      expect(
        await wheeled(tester, multiplier: 0.5),
        moreOrLessEquals(50, epsilon: 0.5),
      );
    });

    testWidgets('is bypassed under reduced motion', (tester) async {
      expect(
        await wheeled(tester, multiplier: 2, reduce: true),
        moreOrLessEquals(100, epsilon: 0.5),
        reason: 'reduced motion hands the wheel back to the platform',
      );
    });
  });

  group('BeuiSmoothScroll touch + lerp', () {
    Future<double> flung(
      WidgetTester tester, {
      required bool touch,
      required double lerp,
      bool reduce = false,
    }) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      // Drop any previous tree: a same-shaped rebuild would hand the old
      // ScrollPosition (and its offset) to the new controller.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _wrap(
          BeuiSmoothScroll(
            touch: touch,
            lerp: lerp,
            child: _rows(controller: controller),
          ),
          reduce: reduce,
        ),
      );
      await tester.fling(find.byType(ListView), const Offset(0, -200), 1200);
      await tester.pumpAndSettle();
      return controller.offset;
    }

    testWidgets('a lower lerp is heavier: the fling carries further', (
      tester,
    ) async {
      final light = await flung(tester, touch: true, lerp: 0.2);
      final heavy = await flung(tester, touch: true, lerp: 0.04);
      expect(heavy, greaterThan(light));
    });

    testWidgets('lerp is inert while touch is false', (tester) async {
      final a = await flung(tester, touch: false, lerp: 0.2);
      final b = await flung(tester, touch: false, lerp: 0.04);
      expect(b, moreOrLessEquals(a, epsilon: 0.5));
    });

    testWidgets('touch smoothing replaces the platform settle', (tester) async {
      final native = await flung(tester, touch: false, lerp: 0.1);
      final smoothed = await flung(tester, touch: true, lerp: 0.02);
      expect(smoothed, isNot(moreOrLessEquals(native, epsilon: 1)));
    });

    testWidgets('reduced motion hands the fling back to the platform', (
      tester,
    ) async {
      final native = await flung(tester, touch: false, lerp: 0.1);
      final reduced = await flung(
        tester,
        touch: true,
        lerp: 0.02,
        reduce: true,
      );
      expect(reduced, moreOrLessEquals(native, epsilon: 0.5));
    });
  });

  group('BeuiScrollProgress', () {
    testWidgets('bar scales with the provided progress (no spring)', (
      tester,
    ) async {
      final progress = ValueNotifier<double>(0);
      addTearDown(progress.dispose);
      await tester.pumpWidget(
        _wrap(
          Align(
            alignment: Alignment.topCenter,
            child: BeuiScrollProgress.bar(progress: progress, spring: false),
          ),
        ),
      );
      double scaleX() {
        final transform = tester.widget<Transform>(
          find.descendant(
            of: find.byType(BeuiScrollProgress),
            matching: find.byType(Transform),
          ),
        );
        return transform.transform.storage[0];
      }

      expect(scaleX(), moreOrLessEquals(0, epsilon: 0.001));
      progress.value = 0.5;
      await tester.pump();
      expect(scaleX(), moreOrLessEquals(0.5, epsilon: 0.001));
    });

    testWidgets('spring smoothing trails the raw value then settles', (
      tester,
    ) async {
      final progress = ValueNotifier<double>(0);
      addTearDown(progress.dispose);
      await tester.pumpWidget(
        _wrap(
          Align(
            alignment: Alignment.topCenter,
            child: BeuiScrollProgress.bar(progress: progress),
          ),
        ),
      );
      await tester.pump();
      progress.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final transform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(BeuiScrollProgress),
          matching: find.byType(Transform),
        ),
      );
      final mid = transform.transform.storage[0];
      expect(mid, greaterThan(0));
      expect(mid, lessThan(0.99), reason: 'spring still catching up');
      await tester.pumpAndSettle();
    });

    testWidgets('circle variant paints a ring', (tester) async {
      final progress = ValueNotifier<double>(0.4);
      addTearDown(progress.dispose);
      await tester.pumpWidget(
        _wrap(
          Center(
            child: BeuiScrollProgress.circle(progress: progress, size: 48),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final paint = find.descendant(
        of: find.byType(BeuiScrollProgress),
        matching: find.byType(CustomPaint),
      );
      expect(paint, findsAtLeastNWidgets(1));
      final box = tester.getSize(find.byType(BeuiScrollProgress));
      expect(box.width, 48);
      expect(box.height, 48);
    });

    testWidgets('bar tracks the enclosing BeuiSmoothScroll by default', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          BeuiSmoothScroll(
            child: _page(
              controller: controller,
              overlay: const Align(
                alignment: Alignment.topCenter,
                child: BeuiScrollProgress.bar(spring: false),
              ),
            ),
          ),
        ),
      );
      double scaleX() {
        final transform = tester.widget<Transform>(
          find.descendant(
            of: find.byType(BeuiScrollProgress),
            matching: find.byType(Transform),
          ),
        );
        return transform.transform.storage[0];
      }

      expect(scaleX(), moreOrLessEquals(0, epsilon: 0.001));
      controller.jumpTo(controller.position.maxScrollExtent / 2);
      await tester.pump();
      expect(scaleX(), moreOrLessEquals(0.5, epsilon: 0.01));
    });
  });

  group('BeuiParallax', () {
    testWidgets('drifts against the scroll as it crosses the viewport', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          _page(
            controller: controller,
            child: const BeuiParallax(
              speed: 0.3,
              spring: false,
              child: SizedBox(height: 100, width: 100),
            ),
          ),
        ),
      );

      double dy() {
        final transforms = tester.widgetList<Transform>(
          find.descendant(
            of: find.byType(BeuiParallax),
            matching: find.byType(Transform),
          ),
        );
        return transforms
            .map((t) => t.transform.getTranslation().y)
            .fold(0, (a, b) => a.abs() > b.abs() ? a : b);
      }

      // Element sits at y=2000 in a 600px viewport: off-screen, no progress.
      // Scroll so the element is entering from the bottom → positive drift
      // (moves with the scroll); past the middle → negative.
      controller.jumpTo(1500); // element near the bottom edge
      await tester.pump();
      final entering = dy();
      controller.jumpTo(2050); // element well past centre, exiting the top
      await tester.pump();
      final exiting = dy();
      expect(entering, greaterThan(0));
      expect(exiting, lessThan(0));
    });

    testWidgets('reduced motion renders static (no transform drift)', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          _page(
            controller: controller,
            child: const BeuiParallax(
              speed: 0.3,
              child: SizedBox(height: 100, width: 100),
            ),
          ),
          reduce: true,
        ),
      );
      controller.jumpTo(1800);
      await tester.pump();
      final transforms = tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(BeuiParallax),
          matching: find.byType(Transform),
        ),
      );
      final drift = transforms
          .map((t) => t.transform.getTranslation().y.abs())
          .fold<double>(0, math.max);
      expect(drift, lessThan(0.5));
    });
  });

  group('BeuiScrollReveal', () {
    testWidgets('hidden below the fold, reveals when scrolled into view', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          _page(
            controller: controller,
            child: const BeuiScrollReveal(
              child: SizedBox(height: 100, child: Text('Reveal me')),
            ),
          ),
        ),
      );
      double opacityOf() => tester
          .widgetList<Opacity>(
            find.ancestor(
              of: find.text('Reveal me'),
              matching: find.byType(Opacity),
            ),
          )
          .map((o) => o.opacity)
          .fold(1, math.min);

      await tester.pump();
      expect(opacityOf(), lessThan(0.01), reason: 'hidden before in-view');

      controller.jumpTo(1700); // brings the element well into view
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = opacityOf();
      expect(mid, greaterThan(0));
      await tester.pumpAndSettle();
      expect(opacityOf(), moreOrLessEquals(1, epsilon: 0.001));
    });

    testWidgets('once=true stays revealed after leaving view', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          _page(
            controller: controller,
            child: const BeuiScrollReveal(
              child: SizedBox(height: 100, child: Text('Reveal me')),
            ),
          ),
        ),
      );
      controller.jumpTo(1700);
      await tester.pump();
      await tester.pumpAndSettle();
      controller.jumpTo(0);
      await tester.pump();
      await tester.pumpAndSettle();
      final opacity = tester
          .widgetList<Opacity>(
            find.ancestor(
              of: find.text('Reveal me'),
              matching: find.byType(Opacity),
            ),
          )
          .map((o) => o.opacity)
          .fold<double>(1, math.min);
      expect(opacity, moreOrLessEquals(1, epsilon: 0.001));
    });

    testWidgets('once=false hides again after leaving view', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          _page(
            controller: controller,
            child: const BeuiScrollReveal(
              once: false,
              child: SizedBox(height: 100, child: Text('Reveal me')),
            ),
          ),
        ),
      );
      controller.jumpTo(1700);
      await tester.pump();
      await tester.pumpAndSettle();
      controller.jumpTo(0);
      await tester.pump();
      await tester.pumpAndSettle();
      final opacity = tester
          .widgetList<Opacity>(
            find.ancestor(
              of: find.text('Reveal me'),
              matching: find.byType(Opacity),
            ),
          )
          .map((o) => o.opacity)
          .fold<double>(1, math.min);
      expect(opacity, lessThan(0.01));
    });

    testWidgets('reduced motion reveals with a fade only (no blur)', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          _page(
            controller: controller,
            child: const BeuiScrollReveal(
              child: SizedBox(height: 100, child: Text('Reveal me')),
            ),
          ),
          reduce: true,
        ),
      );
      controller.jumpTo(1700);
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(_maxBlurSigma(tester), lessThan(0.5));
      }
      await tester.pumpAndSettle();
      expect(find.text('Reveal me'), findsOneWidget);
    });
  });

  group('BeuiScrollTo', () {
    testWidgets('tapping glides the scrollable to the pixel offset', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          BeuiSmoothScroll(
            child: _page(
              controller: controller,
              overlay: Align(
                alignment: Alignment.topLeft,
                child: BeuiScrollTo(to: 1200, child: const Text('Jump')),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Jump'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(controller.offset, greaterThan(0));
      await tester.pumpAndSettle();
      expect(controller.offset, moreOrLessEquals(1200, epsilon: 1));
    });

    testWidgets('extra offset clears a sticky header', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          BeuiSmoothScroll(
            child: _page(
              controller: controller,
              overlay: Align(
                alignment: Alignment.topLeft,
                child: BeuiScrollTo(
                  to: 1200,
                  offset: -80,
                  child: const Text('Jump'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Jump'));
      await tester.pumpAndSettle();
      expect(controller.offset, moreOrLessEquals(1120, epsilon: 1));
    });

    testWidgets('reduced motion jumps instantly', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          BeuiSmoothScroll(
            child: _page(
              controller: controller,
              overlay: Align(
                alignment: Alignment.topLeft,
                child: BeuiScrollTo(to: 1200, child: const Text('Jump')),
              ),
            ),
          ),
          reduce: true,
        ),
      );
      await tester.tap(find.text('Jump'));
      await tester.pump();
      expect(controller.offset, 1200);
    });
  });
}
