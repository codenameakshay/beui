import 'package:beui/src/motion/_disclosure.dart'
    show BeuiAgentDisclosureInternal;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _body = SizedBox(
  height: 100,
  width: 200,
  child: Center(child: Text('body')),
);

Widget _app({
  required bool open,
  bool reduce = false,
  bool disclosureReduce = false,
  double? openHeight,
  Widget child = _body,
}) {
  Widget disclosure = Center(
    child: BeuiAgentDisclosureInternal(
      key: const ValueKey('disclosure'),
      open: open,
      reduce: disclosureReduce,
      openHeight: openHeight,
      child: child,
    ),
  );
  if (reduce) {
    // Bind the subtree to a fresh local first. Referencing `disclosure` from
    // inside the closure would capture the *variable*, which is reassigned on
    // the very next line — the builder would then return a MediaQuery wrapping
    // itself, and the tree recurses until the stack blows.
    final inner = disclosure;
    disclosure = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(home: Scaffold(body: disclosure));
}

// The reveal is `ClipRect(Align(heightFactor: v, child: content))` (or a
// `SizedBox` in the `openHeight` branch), all wrapped in `Offstage`. The
// child's own render box always reports its *intrinsic* height (measuring it
// directly would show a constant 100 throughout the animation, since
// `Align.heightFactor` scales the *container's* box, not the child's layout
// size). `Offstage.size` is a proxy for its child (the Align/SizedBox stack)
// when onstage, and collapses to `constraints.smallest` (zero, here) when
// offstage — so measuring the widget's own render box is what tracks the
// animated reveal end-to-end, including the closed/settled case.
double _outerHeight(WidgetTester tester) =>
    tester.getSize(find.byType(BeuiAgentDisclosureInternal)).height;

Finder _fadeOpacity() => find.descendant(
  of: find.byType(BeuiAgentDisclosureInternal),
  matching: find.byType(Opacity),
);

void main() {
  group('BeuiAgentDisclosureInternal reveal', () {
    testWidgets('opens from 0 to full height', (tester) async {
      await tester.pumpWidget(_app(open: false));
      await tester.pump();
      expect(_outerHeight(tester), closeTo(0, 0.5));

      await tester.pumpWidget(_app(open: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110)); // mid 220ms open
      final mid = _outerHeight(tester);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(100));

      await tester.pumpAndSettle();
      expect(_outerHeight(tester), closeTo(100, 0.5));
    });

    testWidgets('closes faster than it opens', (tester) async {
      await tester.pumpWidget(_app(open: true));
      await tester.pumpAndSettle();
      expect(_outerHeight(tester), closeTo(100, 0.5));

      await tester.pumpWidget(_app(open: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70)); // mid 140ms close
      final mid = _outerHeight(tester);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(100));

      // Rest of the 140ms close, plus one settle frame of slack.
      await tester.pump(const Duration(milliseconds: 71));
      expect(_outerHeight(tester), closeTo(0, 0.5));
    });

    testWidgets(
      'a close mid-open reverses from wherever the animation is, no jump to full',
      (tester) async {
        await tester.pumpWidget(_app(open: false));
        await tester.pump();

        await tester.pumpWidget(_app(open: true));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100)); // mid-open
        final atInterruption = _outerHeight(tester);
        expect(atInterruption, greaterThan(0));
        expect(atInterruption, lessThan(100));

        await tester.pumpWidget(_app(open: false));
        await tester.pump();
        final justAfterReverse = _outerHeight(tester);
        // The whole point: it reverses from the interruption point, not from
        // a full-height start.
        expect(justAfterReverse, lessThan(100));

        var previous = justAfterReverse;
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          final h = _outerHeight(tester);
          expect(h, lessThanOrEqualTo(previous + 0.5));
          previous = h;
        }
        // Past the 140ms close duration; should be settled at 0.
        await tester.pump(const Duration(milliseconds: 50));
        expect(_outerHeight(tester), closeTo(0, 0.5));
      },
    );
  });

  group('BeuiAgentDisclosureInternal hit testing and semantics', () {
    testWidgets('collapsed content is unreachable and unannounced', (
      tester,
    ) async {
      await tester.pumpWidget(_app(open: false));
      await tester.pumpAndSettle();
      // find.text defaults to skipOffstage: true, and the Offstage ancestor
      // (offstage: true) makes debugVisitOnstageChildren skip its subtree —
      // so the collapsed body is invisible to the default finder, which is
      // also what keeps it out of hit testing and the semantics tree.
      expect(find.text('body'), findsNothing);

      await tester.pumpWidget(_app(open: true));
      await tester.pumpAndSettle();
      expect(find.text('body'), findsOneWidget);
    });
  });

  group('BeuiAgentDisclosureInternal reduced motion', () {
    testWidgets(
      'height snaps within one frame; a fade still runs both directions',
      (tester) async {
        // Opening: closed -> open under reduced motion.
        await tester.pumpWidget(_app(open: false, reduce: true));
        await tester.pump();
        expect(_outerHeight(tester), closeTo(0, 0.5));

        await tester.pumpWidget(_app(open: true, reduce: true));
        await tester.pump(); // (a) one frame is enough for the height snap
        expect(_outerHeight(tester), closeTo(100, 0.5));

        await tester.pump(
          const Duration(milliseconds: 60),
        ); // partway through the ~120ms reduced fade
        expect(_fadeOpacity(), findsOneWidget);
        final midIn = tester.widget<Opacity>(_fadeOpacity()).opacity;
        expect(midIn, greaterThan(0));
        expect(midIn, lessThan(1));

        await tester.pump(const Duration(milliseconds: 80)); // settle
        expect(_outerHeight(tester), closeTo(100, 0.5));
        // NOTE: the Opacity widget is elided once fade == 1 (`if (fade < 1)`
        // in `_frame`), so "fully faded in" is asserted by its absence.
        expect(_fadeOpacity(), findsNothing);

        // Closing: open -> closed under reduced motion. The height is HELD
        // open for the duration of the fade-out, then dropped. Snapping it to
        // 0 on the first frame instead would make the fade invisible — a
        // zero-height box cannot be seen fading — which collapses straight
        // back into the hard cut this branch exists to fix. The height change
        // is still instantaneous; it just lands at the end, not the start.
        await tester.pumpWidget(_app(open: false, reduce: true));
        await tester.pump();
        expect(_outerHeight(tester), closeTo(100, 0.5));

        await tester.pump(const Duration(milliseconds: 60)); // partway out
        expect(_fadeOpacity(), findsOneWidget);
        final midOut = tester.widget<Opacity>(_fadeOpacity()).opacity;
        expect(midOut, greaterThan(0));
        expect(midOut, lessThan(1));
        // Still full height while it fades, so the fade is actually on screen.
        expect(_outerHeight(tester), closeTo(100, 0.5));

        await tester.pump(const Duration(milliseconds: 80)); // settle
        expect(_outerHeight(tester), closeTo(0, 0.5));
        expect(find.text('body'), findsNothing);
      },
    );

    testWidgets(
      "the widget's own reduce: true also takes the reduced path, with no "
      'MediaQuery override',
      (tester) async {
        await tester.pumpWidget(_app(open: false, disclosureReduce: true));
        await tester.pump();
        expect(_outerHeight(tester), closeTo(0, 0.5));

        await tester.pumpWidget(_app(open: true, disclosureReduce: true));
        await tester.pump(); // one frame is enough for the height snap
        expect(_outerHeight(tester), closeTo(100, 0.5));
      },
    );
  });

  group('BeuiAgentDisclosureInternal openHeight', () {
    testWidgets('child is pinned to openHeight for the whole reveal', (
      tester,
    ) async {
      // The contract: the child is laid out at exactly `openHeight` on every
      // frame (the OverflowBox pins min == max == openHeight) while the outer
      // box animates 0 -> openHeight and clips. That is the no-reflow
      // guarantee — the `Align.heightFactor` path would instead re-lay-out the
      // child at a fraction of its height each frame, reflowing its text.
      // A child taller than openHeight is clamped, not allowed to overflow.
      const tallKey = ValueKey('tall');
      const tallChild = SizedBox(
        key: tallKey,
        height: 260,
        width: 200,
        child: Text('tall body'),
      );

      await tester.pumpWidget(
        _app(open: false, openHeight: 100, child: tallChild),
      );
      await tester.pump();

      await tester.pumpWidget(
        _app(open: true, openHeight: 100, child: tallChild),
      );
      await tester.pump();

      // Sample the child across the whole 220ms reveal: it must never move.
      for (final elapsed in [40, 90, 150, 220]) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(
          tester.getSize(find.byKey(tallKey)).height,
          closeTo(100, 0.5),
          reason: 'child reflowed ${elapsed}ms into the reveal',
        );
      }

      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(tallKey)).height, closeTo(100, 0.5));
      expect(_outerHeight(tester), closeTo(100, 0.5));
    });

    testWidgets('the outer box animates while the child stays put', (
      tester,
    ) async {
      const innerKey = ValueKey('inner');
      const child = SizedBox(key: innerKey, height: 100, width: 200);

      await tester.pumpWidget(_app(open: false, openHeight: 100, child: child));
      await tester.pump();
      expect(_outerHeight(tester), closeTo(0, 0.5));

      await tester.pumpWidget(_app(open: true, openHeight: 100, child: child));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110)); // mid-reveal
      final mid = _outerHeight(tester);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(100));
      expect(tester.getSize(find.byKey(innerKey)).height, closeTo(100, 0.5));

      await tester.pumpAndSettle();
      expect(_outerHeight(tester), closeTo(100, 0.5));
    });
  });
}
