import 'package:beui/src/motion/tooltip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  testWidgets(
    'cursor-following surface does not intercept underlying pointer input',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        beuiTestApp(
          Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox.expand(),
              ),
              const Center(
                child: BeuiTooltip(
                  open: true,
                  followCursor: true,
                  content: SizedBox(
                    width: 100,
                    height: 30,
                    child: Text('Passive readout'),
                  ),
                  child: SizedBox(width: 20, height: 20),
                ),
              ),
            ],
          ),
          reduce: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.text('Passive readout')));
      await tester.pump();
      expect(taps, 1);
    },
  );

  testWidgets('external anchor positions and flips at the actual target', (
    tester,
  ) async {
    final anchor = GlobalKey();
    final link = LayerLink();
    var top = 100.0;
    var left = 200.0;
    late StateSetter update;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Stack(
              children: [
                Positioned(
                  top: top,
                  left: left,
                  child: CompositedTransformTarget(
                    key: anchor,
                    link: link,
                    child: const SizedBox(width: 80, height: 40),
                  ),
                ),
                Positioned(
                  top: 400,
                  left: 400,
                  child: BeuiTooltip(
                    open: true,
                    externalAnchor: anchor,
                    anchorLink: link,
                    content: const Text('External label'),
                    child: const SizedBox(width: 10, height: 10),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bubble = find
        .ancestor(
          of: find.text('External label'),
          matching: find.byType(DecoratedBox),
        )
        .first;
    expect(tester.getRect(bubble).bottom, closeTo(92, .01));
    expect(tester.getRect(bubble).center.dx, closeTo(240, .01));
    update(() {
      top = 1;
      left = 750;
    });
    await tester.pumpAndSettle();
    expect(tester.getRect(bubble).top, closeTo(49, .01));
    expect(tester.getRect(bubble).right, closeTo(792, .01));
  });

  testWidgets('transformed anchor keeps the tooltip surface and gap unscaled', (
    tester,
  ) async {
    final anchor = GlobalKey();
    final link = LayerLink();
    await tester.pumpWidget(
      beuiTestApp(
        Stack(
          children: [
            Positioned(
              top: 100,
              left: 180,
              child: Transform.rotate(
                angle: .2,
                child: Transform.scale(
                  scale: 1.8,
                  alignment: Alignment.topLeft,
                  child: CompositedTransformTarget(
                    key: anchor,
                    link: link,
                    child: const SizedBox(width: 80, height: 40),
                  ),
                ),
              ),
            ),
            BeuiTooltip(
              open: true,
              externalAnchor: anchor,
              anchorLink: link,
              side: BeuiTooltipSide.bottom,
              content: const SizedBox(
                width: 148,
                height: 24,
                child: Text('External label'),
              ),
              child: const SizedBox(width: 10, height: 10),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final surface = find
        .ancestor(
          of: find.text('External label'),
          matching: find.byType(DecoratedBox),
        )
        .first;
    final surfaceRect = tester.getRect(surface);
    final anchorBox = anchor.currentContext!.findRenderObject()! as RenderBox;
    final anchorRect = MatrixUtils.transformRect(
      anchorBox.getTransformTo(null),
      Offset.zero & anchorBox.size,
    );
    expect(surfaceRect.width, closeTo(170, .01));
    expect(surfaceRect.top - anchorRect.bottom, closeTo(8, .01));
  });

  testWidgets('external target resize updates the fixed surface position', (
    tester,
  ) async {
    final anchor = GlobalKey();
    final link = LayerLink();
    var height = 40.0;
    late StateSetter update;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Stack(
              children: [
                Positioned(
                  top: 100,
                  left: 120,
                  child: CompositedTransformTarget(
                    key: anchor,
                    link: link,
                    child: SizedBox(width: 80, height: height),
                  ),
                ),
                BeuiTooltip(
                  open: true,
                  externalAnchor: anchor,
                  anchorLink: link,
                  side: BeuiTooltipSide.bottom,
                  content: const Text('External label'),
                  child: const SizedBox(width: 10, height: 10),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final surface = find
        .ancestor(
          of: find.text('External label'),
          matching: find.byType(DecoratedBox),
        )
        .first;
    final before = tester.getRect(surface);
    update(() => height = 76);
    await tester.pumpAndSettle();
    expect(tester.getRect(surface).top, closeTo(before.top + 36, .01));
  });

  testWidgets('independent anchor transform updates a retained tooltip', (
    tester,
  ) async {
    final anchor = GlobalKey();
    final link = LayerLink();
    final translation = ValueNotifier(Offset.zero);
    addTearDown(translation.dispose);
    await tester.pumpWidget(
      beuiTestApp(
        Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 200,
              left: 200,
              child: ValueListenableBuilder<Offset>(
                valueListenable: translation,
                builder: (context, offset, child) =>
                    Transform.translate(offset: offset, child: child),
                child: CompositedTransformTarget(
                  key: anchor,
                  link: link,
                  child: const SizedBox(width: 80, height: 40),
                ),
              ),
            ),
            BeuiTooltip(
              open: true,
              externalAnchor: anchor,
              anchorLink: link,
              side: BeuiTooltipSide.bottom,
              content: const SizedBox(
                width: 148,
                height: 24,
                child: Text('Retained tooltip'),
              ),
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final surface = find
        .ancestor(
          of: find.text('Retained tooltip'),
          matching: find.byType(DecoratedBox),
        )
        .first;
    final before = tester.getRect(surface);
    translation.value = const Offset(50, 30);
    await tester.pumpAndSettle();
    final after = tester.getRect(surface);
    expect(after.left - before.left, closeTo(50, .01));
    expect(after.top - before.top, closeTo(30, .01));
    expect(after.width, closeTo(170, .01));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('tall collision-shifted surface retains the viewport margin', (
    tester,
  ) async {
    final anchor = GlobalKey();
    final link = LayerLink();
    await tester.pumpWidget(
      beuiTestApp(
        Stack(
          children: [
            Positioned(
              top: 300,
              left: 1,
              child: CompositedTransformTarget(
                key: anchor,
                link: link,
                child: const SizedBox(width: 30, height: 40),
              ),
            ),
            BeuiTooltip(
              open: true,
              externalAnchor: anchor,
              anchorLink: link,
              side: BeuiTooltipSide.bottom,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List<Widget>.generate(
                  20,
                  (index) => Text('Tall label line $index'),
                ),
              ),
              child: const SizedBox(width: 10, height: 10),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final surface = find
        .ancestor(
          of: find.text('Tall label line 0'),
          matching: find.byType(DecoratedBox),
        )
        .first;
    final rect = tester.getRect(surface);
    expect(rect.left, greaterThanOrEqualTo(8));
    expect(rect.bottom, lessThanOrEqualTo(592));
  });

  testWidgets('external target follows scrolling without a frame loop', (
    tester,
  ) async {
    final anchor = GlobalKey();
    final link = LayerLink();
    final controller = ScrollController();
    await tester.pumpWidget(
      beuiTestApp(
        SizedBox(
          height: 240,
          child: SingleChildScrollView(
            controller: controller,
            child: SizedBox(
              height: 900,
              child: Stack(
                children: [
                  Positioned(
                    top: 300,
                    left: 120,
                    child: CompositedTransformTarget(
                      key: anchor,
                      link: link,
                      child: const SizedBox(width: 80, height: 40),
                    ),
                  ),
                  BeuiTooltip(
                    open: true,
                    externalAnchor: anchor,
                    anchorLink: link,
                    side: BeuiTooltipSide.bottom,
                    content: const Text('External label'),
                    child: const SizedBox(width: 10, height: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final surface = find
        .ancestor(
          of: find.text('External label'),
          matching: find.byType(DecoratedBox),
        )
        .first;
    final before = tester.getRect(surface);
    controller.jumpTo(120);
    await tester.pump();
    await tester.pump();
    final after = tester.getRect(surface);
    expect(after.top, closeTo(before.top - 120, .01));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    controller.dispose();
  });

  testWidgets(
    'external target can be absent, unmounted and replaced while controlled',
    (tester) async {
      var anchor = GlobalKey();
      var link = LayerLink();
      var mounted = false;
      var open = true;
      var x = 100.0;
      final requests = <bool>[];
      late StateSetter update;
      await tester.pumpWidget(
        beuiTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Stack(
                children: [
                  if (mounted)
                    Positioned(
                      top: 200,
                      left: x,
                      child: CompositedTransformTarget(
                        key: anchor,
                        link: link,
                        child: const SizedBox(width: 80, height: 40),
                      ),
                    ),
                  Positioned(
                    top: 400,
                    left: 400,
                    child: BeuiTooltip(
                      open: open,
                      externalAnchor: anchor,
                      anchorLink: link,
                      onOpenChange: requests.add,
                      content: const Text('External label'),
                      child: const SizedBox(width: 10, height: 10),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('External label'), findsNothing);
      update(() => mounted = true);
      await tester.pumpAndSettle();
      expect(find.text('External label'), findsOneWidget);
      expect(
        tester.getCenter(find.text('External label')).dx,
        closeTo(140, .01),
      );
      update(() => mounted = false);
      await tester.pumpAndSettle();
      expect(find.text('External label'), findsNothing);
      update(() {
        mounted = true;
        anchor = GlobalKey();
        link = LayerLink();
        x = 300;
      });
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('External label')).dx,
        closeTo(340, .01),
      );
      for (var i = 0; i < 3; i++) {
        update(() => open = false);
        await tester.pumpAndSettle();
        expect(find.text('External label'), findsNothing);
        update(() => open = true);
        await tester.pumpAndSettle();
        expect(find.text('External label'), findsOneWidget);
      }
      await tester.tapAt(const Offset(790, 590));
      await tester.pumpAndSettle();
      expect(requests, [false]);
      expect(find.text('External label'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
