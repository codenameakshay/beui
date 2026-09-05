import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduce = false}) {
  Widget body = child;
  if (reduce) {
    body = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child,
      ),
    );
  }
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(
      body: Center(child: SizedBox(width: 320, height: 400, child: body)),
    ),
  );
}

void main() {
  group('BeuiPullToRefresh', () {
    testWidgets('calls onRefresh when released past threshold', (tester) async {
      var calls = 0;
      final done = Completer<void>();

      await tester.pumpWidget(
        _wrap(
          BeuiPullToRefresh(
            threshold: 76,
            onRefresh: () async {
              calls++;
              await done.future;
            },
            child: const SizedBox(height: 600, child: Text('Pull me')),
          ),
        ),
      );
      await tester.pump();

      final center = tester.getCenter(find.byType(BeuiPullToRefresh));
      // Drag well past threshold (raw distance is resisted; need ~200+ raw).
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(0, 220));
      await tester.pump();
      expect(find.text('Release to refresh'), findsOneWidget);

      await gesture.up();
      await tester.pump(); // start refresh
      expect(calls, 1);
      expect(find.text('Refreshing'), findsOneWidget);

      // The test controls completion directly rather than waiting on a real
      // delay, so the assertion below can't be timing-flaky.
      done.complete();
      await tester.pump(); // let the completed future resolve
      await tester.pump(const Duration(milliseconds: 400));
      // Back to idle — refresh finished exactly once.
      expect(calls, 1);
      expect(find.text('Refreshing'), findsNothing);
    });

    testWidgets('disabled does not pull', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiPullToRefresh(
            disabled: true,
            onRefresh: () => calls++,
            child: const SizedBox(height: 600, child: Text('Locked')),
          ),
        ),
      );
      await tester.pump();

      final center = tester.getCenter(find.byType(BeuiPullToRefresh));
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(0, 220));
      await tester.pump();
      expect(find.text('Release to refresh'), findsNothing);
      await gesture.up();
      await tester.pump();
      expect(calls, 0);
    });

    // The indicator's entire visual state — opacity, buddy scale, content
    // translate — is derived from the `y` that `SingleMotionBuilder` hands the
    // builder. That builder used to be given `const NoMotion()` for the whole
    // duration of a drag, and `NoMotion` holds its seeded value forever rather
    // than snapping to the target (see `_no_motion_semantics_test.dart`), so
    // `y` sat pinned at 0 for every frame of the pull: measured
    // [0, 0, 0, 0, 0, 0, 0, 0] across an 8-step 200px drag, opacity 0.
    //
    // Note this was NOT a reduced-motion-only bug — `_dragging` is true for
    // every pull — and it survived the tests above because they assert on the
    // status *label*, which reads plain state rather than the animated value.
    //
    // The fix is motor's `active: false`, which stops the controller and
    // assigns the target outright, so the value tracks the finger AND stays
    // seeded for the release spring.
    testWidgets('indicator tracks the finger during a drag', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiPullToRefresh(
            threshold: 76,
            onRefresh: () {},
            child: const SizedBox(height: 600, child: Text('Track me')),
          ),
        ),
      );
      await tester.pump();

      // The content translate is a direct read-out of the animated `y`.
      double contentY() {
        final t = tester.widget<Transform>(
          find
              .ancestor(
                of: find.byType(SingleChildScrollView),
                matching: find.byType(Transform),
              )
              .first,
        );
        return t.transform.getTranslation().y;
      }

      // The indicator opacity is derived from the same `y`.
      double indicatorOpacity() {
        final o = tester.widget<Opacity>(
          find
              .descendant(
                of: find.byType(IgnorePointer),
                matching: find.byType(Opacity),
              )
              .first,
        );
        return o.opacity;
      }

      expect(contentY(), 0);
      expect(indicatorOpacity(), 0);

      final center = tester.getCenter(find.byType(BeuiPullToRefresh));
      final gesture = await tester.startGesture(center);

      // Drag down in steps and sample every frame. The value must be
      // monotonically increasing, not pinned at the mount value.
      final samples = <double>[];
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 25));
        await tester.pump();
        samples.add(contentY());
      }

      expect(
        samples.first,
        greaterThan(0),
        reason:
            'the indicator must move on the very first drag frame, not stay '
            'seeded at 0',
      );
      for (var i = 1; i < samples.length; i++) {
        expect(
          samples[i],
          greaterThan(samples[i - 1]),
          reason:
              'frame $i did not follow the finger: ${samples[i - 1]} -> '
              '${samples[i]} (an arrival freeze would repeat the same value)',
        );
      }
      expect(
        indicatorOpacity(),
        greaterThan(0),
        reason: 'the indicator must be visible once pulled',
      );

      // Release continuity: the spring has to start from where the finger let
      // go, not from a stale 0. A builder-side bypass (`_dragging ? _y : y`)
      // would have rendered the drag correctly but left the controller seeded
      // at 0, so the release would visibly jump to the top before springing
      // back. Assert the first post-release frame is still near the release
      // position, then that it actually retracts.
      final released = samples.last;
      await gesture.up();
      await tester.pump();
      expect(
        contentY(),
        closeTo(released, 12),
        reason: 'release must continue from the drag position, not jump',
      );

      await tester.pump(const Duration(milliseconds: 500));
      expect(
        contentY(),
        lessThan(released),
        reason: 'the panel spring must retract after release',
      );
      await tester.pumpAndSettle();
    });

    testWidgets('external refreshing holds indicator', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiPullToRefresh(
            refreshing: true,
            onRefresh: () {},
            child: const SizedBox(height: 400, child: Text('Busy')),
          ),
        ),
      );
      // Let spring settle toward holdDistance so opacity > 0.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Refreshing'), findsOneWidget);
      expect(find.text('Busy'), findsOneWidget);
    });
  });
}
