import 'package:beui/src/motion/plinko_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default payouts follow the symmetric geometric source curve', () {
    expect(generatePlinkoSlots(12), <num>[
      100,
      50,
      20,
      10,
      5,
      2,
      1,
      2,
      5,
      10,
      20,
      50,
      100,
    ]);
  });

  test('fractional custom payouts round to one significant digit', () {
    expect(generatePlinkoSlots(8, center: 0.5, edge: 10), <num>[
      10,
      5,
      2,
      1,
      0.5,
      1,
      2,
      5,
      10,
    ]);
    expect(generatePlinkoSlots(0), <num>[100, 100]);
  });

  test('peg hits follow rendered turns and do not backfill skipped rows', () {
    final trajectory = PlinkoTrajectory(
      rows: 2,
      width: 128,
      nextRight: () => false,
    );
    final consecutive = PlinkoRenderedHitTracker(trajectory);
    expect(consecutive.observe(37.5), isNull);
    expect(consecutive.observe(30.5), 0);
    expect(consecutive.observe(67.5), isNull);
    expect(consecutive.observe(60.5), 1);

    final skipped = PlinkoRenderedHitTracker(trajectory);
    expect(skipped.observe(70), isNull);
    expect(skipped.observe(60.5), 1);

    final toggled = PlinkoRenderedHitTracker(trajectory);
    expect(toggled.observe(37.5), isNull);
    expect(toggled.observe(30.5), 0);
    expect(toggled.observe(30.5), isNull);
  });

  test('trajectory consumes each direction once and ends in that slot', () {
    final choices = <bool>[true, false];
    var calls = 0;
    final trajectory = PlinkoTrajectory(
      rows: 2,
      width: 128,
      nextRight: () => choices[calls++],
    );

    expect(calls, 2);
    expect(trajectory.slot, 1);
    expect(trajectory.pegIds, <String>['0-0', '1-1']);
    expect(trajectory.points, <Offset>[
      const Offset(64, 7),
      const Offset(64, 37.5),
      const Offset(72, 30.5),
      const Offset(80, 67.5),
      const Offset(72, 60.5),
      const Offset(64, 104),
    ]);
    expect(trajectory.positionAt(0), const Offset(64, 7));
    expect(trajectory.positionAt(1), const Offset(64, 104));
    final hopMidpoint = trajectory.positionAt(
      (trajectory.times[1] + trajectory.times[2]) / 2,
    );
    expect(hopMidpoint.dx, 68);
    expect(hopMidpoint.dy, closeTo(31.44, 0.03));
    expect(trajectory.hitProgress(0), closeTo(0.22 / 0.72, 1e-12));
    expect(trajectory.durationSeconds, closeTo(0.72, 1e-12));
  });
}
