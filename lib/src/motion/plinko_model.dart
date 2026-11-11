import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

const double _gap = 32;
const double _row = 30;
const double _peg = 3.5;
const double _ball = 7;
const double _top = 48;
const double _hopHeight = 7;
const double _hopSeconds = 0.09;
const double _dropSeconds = 0.16;
const Cubic _fall = Cubic(0.55, 0, 1, 0.45);
const Cubic _rise = Cubic(0, 0.55, 0.45, 1);

/// One precomputed, randomized path through a Plinko board.
@immutable
class PlinkoTrajectory {
  /// Creates a path using [nextRight] once for each peg row.
  factory PlinkoTrajectory({
    required int rows,
    required double width,
    required bool Function() nextRight,
  }) => PlinkoTrajectory._(
    rows,
    width,
    List.unmodifiable(List.generate(rows, (_) => nextRight())),
  );

  PlinkoTrajectory._(this.rows, this.width, List<bool> directions)
    : points = _buildPoints(rows, width, directions),
      times = _buildTimes(rows),
      pegIds = _buildPegIds(directions),
      slot = directions.where((right) => right).length;

  /// Number of peg rows in the board.
  final int rows;

  /// Width of the board in source SVG units.
  final double width;

  /// Ball-center keyframes from the chute to the slot.
  final List<Offset> points;

  /// Normalized elapsed times corresponding to [points].
  final List<double> times;

  /// Peg identifier hit by each right/left decision.
  final List<String> pegIds;

  /// The final slot index.
  final int slot;

  /// Total source duration in seconds.
  double get durationSeconds => 0.22 + rows * (_hopSeconds + _dropSeconds);

  /// Progress at which the ball begins rising from each peg.
  double hitProgress(int row) => times[1 + row * 2];

  /// Interpolates the source's horizontal linear and vertical eased keyframes.
  Offset positionAt(double progress) {
    final t = progress.clamp(0.0, 1.0).toDouble();
    var segment = 0;
    while (segment < times.length - 2 && t > times[segment + 1]) {
      segment++;
    }
    final start = times[segment];
    final end = times[segment + 1];
    final local = end == start ? 1.0 : ((t - start) / (end - start));
    final from = points[segment];
    final to = points[segment + 1];
    final vertical = (segment.isOdd ? _rise : _fall).transform(local);
    return Offset(
      from.dx + (to.dx - from.dx) * local,
      from.dy + (to.dy - from.dy) * vertical,
    );
  }

  static List<Offset> _buildPoints(
    int rows,
    double width,
    List<bool> directions,
  ) {
    final center = width / 2;
    final points = <Offset>[Offset(center, _ball)];
    var rightSteps = 0;
    for (var row = 0; row < rows; row++) {
      final x = center + (rightSteps - row / 2) * _gap;
      points.add(Offset(x, _contactY(row)));
      final right = directions[row];
      points.add(
        Offset(x + (right ? _gap / 4 : -_gap / 4), _contactY(row) - _hopHeight),
      );
      if (right) rightSteps++;
    }
    final slotY = _top + rows * _row - _ball + 3;
    points.add(Offset(center + (rightSteps - rows / 2) * _gap, slotY));
    return List.unmodifiable(points);
  }

  static List<double> _buildTimes(int rows) {
    final durations = <double>[0.22];
    for (var row = 0; row < rows; row++) {
      durations
        ..add(_hopSeconds)
        ..add(_dropSeconds);
    }
    final total = durations.fold<double>(0, (sum, step) => sum + step);
    final times = <double>[0];
    for (final duration in durations) {
      times.add(times.last + duration / total);
    }
    times[times.length - 1] = 1;
    return List.unmodifiable(times);
  }

  static List<String> _buildPegIds(List<bool> directions) {
    var rightSteps = 0;
    return List.unmodifiable(
      List.generate(directions.length, (row) {
        final id = '$row-$rightSteps';
        if (directions[row]) rightSteps++;
        return id;
      }),
    );
  }

  static double _contactY(int row) => _top + row * _row - _peg - _ball;
}

/// Tracks the source's hit event from consecutive rendered vertical positions.
class PlinkoRenderedHitTracker {
  PlinkoRenderedHitTracker(this.trajectory);

  final PlinkoTrajectory trajectory;
  double _previousY = 0;
  bool _wasRising = false;
  int _lastRow = -1;

  /// Returns only a newly observed rising-turn row; skipped turns are missed.
  int? observe(double y) {
    final rising = y < _previousY;
    final row = ((math.max(_previousY, y) - (_top - _peg - _ball)) / _row)
        .round();
    final hit = rising && !_wasRising && row > _lastRow && row < trajectory.rows
        ? row
        : null;
    if (hit != null) _lastRow = hit;
    _previousY = y;
    _wasRising = rising;
    return hit;
  }
}

/// Generates symmetric, geometrically spaced payouts for [rows].
///
/// Values between 1 (inclusive) and 10 (exclusive) round to whole numbers.
/// Other values round to one significant digit, matching the source game.
List<num> generatePlinkoSlots(int rows, {num center = 1, num edge = 100}) {
  final rowCount = math.max(1, rows).toInt();
  final centerValue = math.max(0.01, center.toDouble());
  final edgeValue = math.max(centerValue, edge.toDouble());
  final half = rowCount / 2;
  return List<num>.generate(rowCount + 1, (slot) {
    final value =
        centerValue *
        math.pow(edgeValue / centerValue, (slot - half).abs() / half);
    if (value >= 1 && value < 10) return value.round();
    final rounded = double.parse(value.toStringAsPrecision(1));
    return rounded == rounded.roundToDouble() ? rounded.toInt() : rounded;
  }, growable: false);
}
