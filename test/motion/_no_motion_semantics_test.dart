// Pins the `motor` semantics that an entire class of beUI reduced-motion bugs
// depends on.
//
// `NoMotion` does NOT mean "jump to the target instantly". Its own doc reads
// "holds at the current value for [duration] and never reaches its target",
// and `NoMotionSimulation.x(time)` returns the *seeded start* value forever.
// Because every `animateTo` re-seeds `fromValue` from the controller's current
// value, a builder written as
//
//     SingleMotionBuilder(value: target, motion: reduce ? NoMotion() : spring)
//
// freezes at whatever it was mounted with and never arrives at `target` — an
// "arrival freeze". Any channel that is the *only* reveal mechanism (a height
// factor, a translate, a rotation, a highlight rect) therefore disappears
// entirely under reduced motion.
//
// The house fix is to bypass the frozen channel in the builder rather than the
// motion:
//
//     builder: (context, t, child) {
//       final v = reduce ? target : t;   // <- reduce?target idiom
//       ...
//     }
//
// or, when a short opacity transition should survive, to route a real motion
// through `motionFor(..., isMovement: false)` (see `_disclosure.dart`).
//
// If this test ever starts failing because `NoMotion` learned to snap to its
// target, that is a *good* upstream change — but it also means the
// compensations scattered across the library are now redundant and should be
// revisited deliberately, not left to rot.
import 'package:beui/src/motion/_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('motor NoMotion semantics (regression pin)', () {
    testWidgets('holds the seeded value and never arrives at the target', (
      tester,
    ) async {
      final seen = <double>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SingleMotionBuilder(
            value: 1,
            from: 0,
            motion: const NoMotion(),
            builder: (context, t, child) {
              seen.add(t);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // Give it every chance to arrive: a settle plus explicit frames well
      // past any plausible animation duration.
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(
        seen,
        isNotEmpty,
        reason: 'the builder must have run at least once',
      );
      expect(
        seen.last,
        0,
        reason:
            'NoMotion holds the seeded `from` value forever; it never reaches '
            'the `value` target. Components must compensate in the builder.',
      );
      expect(
        seen.every((t) => t == 0),
        isTrue,
        reason: 'NoMotion never moves at all, not even partway',
      );

      // A non-zero duration only extends the hold — it does not snap to the
      // target once the hold ends. Fully unmount the previous tree first so
      // its ticker is disposed before the next controller starts timing its
      // own hold.
      await tester.pumpWidget(const SizedBox());
      double durationLatest = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: SingleMotionBuilder(
            value: 1,
            from: 0.25,
            motion: const NoMotion(Duration(milliseconds: 200)),
            builder: (context, t, child) {
              durationLatest = t;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(durationLatest, 0.25);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(
        durationLatest,
        0.25,
        reason:
            'the hold ends but the value stays put; it does not settle to '
            'the target',
      );

      // animateTo under NoMotion re-seeds fromValue = current value, so a
      // mid-life target change is also ignored. Unmount first — otherwise
      // the still-live controller from the previous case carries its
      // current value (0.25) into this one instead of starting fresh.
      await tester.pumpWidget(const SizedBox());
      double retargetLatest = -1;
      Widget build(double value) => MaterialApp(
        home: SingleMotionBuilder(
          value: value,
          from: 0,
          motion: const NoMotion(),
          builder: (context, t, child) {
            retargetLatest = t;
            return const SizedBox.shrink();
          },
        ),
      );
      await tester.pumpWidget(build(0));
      await tester.pumpAndSettle();
      expect(retargetLatest, 0);
      // The exact shape of the bug: the widget's state changes (a row is
      // appended, a panel opens, the selection moves) and the driving value
      // updates — but the rendered channel does not follow.
      await tester.pumpWidget(build(1));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(
        retargetLatest,
        0,
        reason:
            'animateTo under NoMotion re-seeds fromValue = current (0) and '
            'holds there — the target is never observed',
      );
    });
  });
}
