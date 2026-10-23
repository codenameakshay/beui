import 'package:beui/src/motion/tooltip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
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
