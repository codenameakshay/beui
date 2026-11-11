import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:beui/src/charts/_xy.dart';
import 'package:beui/src/tokens/motion.dart' show beuiSpringLayout;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fixture() =>
    jsonDecode(
          File(
            'test/fixtures/charts_xy/source-contract.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

void main() {
  final fixture = _fixture();

  group('pinned source fixture', () {
    test('normalization preserves source-index behavior and frozen gaps', () {
      final input = fixture['normalizationInput'] as Map<String, dynamic>;
      final series = (input['series'] as List).map((raw) {
        final row = raw as Map<String, dynamic>;
        return BeuiXYSeries(
          id: row['id'] as String,
          name: row['name'] as String,
          color: row['color'] as String,
          values: (row['values'] as List).map<num?>((value) {
            if (value == 'NaN' || value == 'Infinity') return double.nan;
            return value as num?;
          }).toList(),
        );
      }).toList();
      final categories = (input['categories'] as List).cast<String>();
      for (final raw in fixture['normalizeCases'] as List) {
        final testCase = raw as Map<String, dynamic>;
        final actual = normalizeBeuiXY(
          series,
          categories,
          nonnegative: testCase['nonnegative'] as bool,
        );
        expect({
          'rows': [
            for (final row in actual.rows)
              {
                'id': row.id,
                'name': row.name,
                'color': row.color,
                'values': row.values,
              },
          ],
          'categories': actual.categories,
        }, equals(testCase['expected']));
      }
    });

    test('nice domains equal all eight literal pinned outcomes', () {
      for (final raw in fixture['scaleCases'] as List) {
        final testCase = raw as Map<String, dynamic>;
        final options = testCase['options'] as Map<String, dynamic>;
        final fixed = options['fixed'] as List?;
        final actual = niceBeuiXYDomain(
          (testCase['values'] as List).cast<num>(),
          includeZero: options['includeZero'] as bool? ?? false,
          fixed: fixed == null ? null : (fixed[0] as num, fixed[1] as num),
        );
        final expected = testCase['expected'] as Map<String, dynamic>;
        expect(actual.min, expected['min']);
        expect(actual.max, expected['max']);
        expect(actual.ticks, expected['ticks']);
      }
    });

    test('line and area path data equal all three frozen path outcomes', () {
      for (final raw in fixture['pathCases'] as List) {
        final testCase = raw as Map<String, dynamic>;
        final points = (testCase['points'] as List).map<Offset?>((rawPoint) {
          if (rawPoint == null) return null;
          final point = rawPoint as Map<String, dynamic>;
          return Offset(
            (point['x'] as num).toDouble(),
            (point['y'] as num).toDouble(),
          );
        }).toList();
        final curve = BeuiXYCurve.values.byName(testCase['curve'] as String);
        expect(beuiXYLinePathData(points, curve: curve), testCase['line']);
        expect(
          beuiXYAreaPathData(
            points,
            (testCase['baseline'] as num).toDouble(),
            curve: curve,
          ),
          testCase['area'],
        );
      }
    });

    test('label stride equals all four literal source outcomes', () {
      for (final raw in fixture['strideCases'] as List) {
        final testCase = raw as Map<String, dynamic>;
        expect(
          beuiXYLabelStride(
            testCase['count'] as int,
            (testCase['length'] as num).toDouble(),
          ),
          testCase['expected'],
        );
      }
    });
  });

  test('extreme finite domains stay finite and ordered', () {
    for (final values in <List<num>>[
      [-1e308, 1e308],
      [5e-324],
      [0, 2e-323],
      [double.maxFinite],
      [-double.maxFinite],
      [1e308],
      [1e308, 1e308 + 1e293],
      [1e20, 2e20],
    ]) {
      final domain = niceBeuiXYDomain(values);
      expect(domain.min.isFinite, isTrue);
      expect(domain.max.isFinite, isTrue);
      expect(domain.min, lessThan(domain.max));
      expect(domain.ticks.every((tick) => tick.isFinite), isTrue);
      expect(domain.fraction(domain.min), 0);
      expect(domain.fraction(domain.max), 1);
    }
  });

  test('large finite domains retain data and scale through zero', () {
    final domain = niceBeuiXYDomain([-1e308, 1e308]);
    expect(domain.min, -1e308);
    expect(domain.max, 1e308);
    expect(domain.fraction(0), .5);
    expect(domain.fraction(-1e308), 0);
    expect(domain.fraction(1e308), 1);
    final large = niceBeuiXYDomain([1e20, 2e20]);
    expect(large.min, 1e20);
    expect(large.max, 2e20);
    final fixed = niceBeuiXYDomain([], fixed: (0, double.maxFinite));
    expect(fixed.max, double.maxFinite);
    expect(fixed.ticks.every((tick) => tick.isFinite), isTrue);
  });

  test('malformed fixed bounds fail at the domain boundary', () {
    expect(() => niceBeuiXYDomain([1], fixed: (2, 1)), throwsArgumentError);
    expect(() => niceBeuiXYDomain([1], fixed: (2, 2)), throwsArgumentError);
    expect(
      () => niceBeuiXYDomain([1], fixed: (double.nan, 1)),
      throwsArgumentError,
    );
    expect(() => niceBeuiXYDomain([1], count: 0), throwsArgumentError);
  });

  testWidgets(
    'inspector has one slider, tracks point positions and closes on Escape',
    (tester) async {
      var active = 0;
      var open = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Center(
                child: SizedBox(
                  key: const ValueKey('plot'),
                  width: 300,
                  height: 120,
                  child: BeuiXYInspector(
                    count: 4,
                    activeIndex: active,
                    onActiveIndexChanged: (value) =>
                        setState(() => active = value),
                    label: 'Chart values',
                    valueText: (index) => 'Category $index',
                    open: open,
                    onOpenChange: (value) => setState(() => open = value),
                    child: const ColoredBox(color: Colors.transparent),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Chart values'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Chart values'))
            .getSemanticsData()
            .value,
        'Category 0',
      );
      final plot = tester.getRect(find.byKey(const ValueKey('plot')));
      await tester.tapAt(
        Offset(plot.left + 250, plot.center.dy),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(active, 3);
      expect(open, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(open, isFalse);
      expect(active, 3);
    },
  );

  testWidgets('touch up retains inspection and cancellation closes it', (
    tester,
  ) async {
    var active = -1;
    var open = false;
    var touching = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 200,
              height: 80,
              child: BeuiXYInspector(
                count: 3,
                activeIndex: active,
                onActiveIndexChanged: (value) => setState(() => active = value),
                label: 'Samples',
                valueText: (index) => 'Sample $index',
                open: open,
                onOpenChange: (value) => setState(() => open = value),
                onTouchChange: (value) => setState(() => touching = value),
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
          ),
        ),
      ),
    );
    final center = tester.getCenter(find.byType(BeuiXYInspector));
    final gesture = await tester.startGesture(
      center,
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    expect(touching, isTrue);
    expect(open, isTrue);
    await gesture.up();
    await tester.pump();
    expect(touching, isFalse);
    expect(
      open,
      isTrue,
      reason: 'tap inspection remains open after pointer-up',
    );
    final canceled = await tester.startGesture(
      center + const Offset(4, 0),
      kind: PointerDeviceKind.touch,
    );
    await canceled.cancel();
    await tester.pump();
    expect(open, isFalse);
  });

  for (final scrollParent in [false, true]) {
    testWidgets(
      'canceling the first touch closes with scroll parent $scrollParent',
      (tester) async {
        var active = -1;
        var open = false;
        var touching = false;
        final openEvents = <bool>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  final inspector = SizedBox(
                    width: 200,
                    height: 80,
                    child: BeuiXYInspector(
                      count: 3,
                      activeIndex: active,
                      onActiveIndexChanged: (value) =>
                          setState(() => active = value),
                      label: 'Samples',
                      canHover: false,
                      valueText: (index) => 'Sample $index',
                      open: open,
                      onOpenChange: (value) {
                        openEvents.add(value);
                        setState(() => open = value);
                      },
                      onTouchChange: (value) =>
                          setState(() => touching = value),
                      child: const ColoredBox(color: Colors.transparent),
                    ),
                  );
                  return scrollParent
                      ? SingleChildScrollView(child: inspector)
                      : inspector;
                },
              ),
            ),
          ),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(BeuiXYInspector)),
          kind: PointerDeviceKind.touch,
        );
        await tester.pump();
        expect(open, isTrue);
        expect(touching, isTrue);
        await gesture.cancel();
        await tester.pump();
        expect(openEvents, [true, false]);
        expect(open, isFalse);
        expect(touching, isFalse);
      },
    );
  }

  test('source negative half rounds to the literal source path command', () {
    expect(beuiXYLinePathData(const [Offset(-.005, -.005)]), 'M0,0h0');
  });

  test('rendered monotone Path follows literal source cubic commands', () {
    const points = <Offset?>[
      Offset(.13, 2.17),
      Offset(3.71, 8.33),
      Offset(9.26, 4.19),
    ];
    // Derived from the pinned source tangents and rounded SVG commands. The
    // non-two-decimal input values make rounding order observable.
    expect(
      beuiXYLinePathData(points),
      'M0.13,2.17C1.32,5.25,2.52,8.33,3.71,8.33'
      'C5.56,8.33,7.41,6.26,9.26,4.19',
    );

    final actual = beuiXYLinePath(points).computeMetrics().single;
    final sourceCommands = Path()
      ..moveTo(.13, 2.17)
      ..cubicTo(1.32, 5.25, 2.52, 8.33, 3.71, 8.33)
      ..cubicTo(5.56, 8.33, 7.41, 6.26, 9.26, 4.19);
    final expected = sourceCommands.computeMetrics().single;
    expect(actual.length, closeTo(expected.length, .0001));
    for (final fraction in [.17, .43, .78]) {
      final actualPosition = actual
          .getTangentForOffset(actual.length * fraction)!
          .position;
      final sourcePosition = expected
          .getTangentForOffset(expected.length * fraction)!
          .position;
      expect(actualPosition.dx, closeTo(sourcePosition.dx, .0001));
      expect(actualPosition.dy, closeTo(sourcePosition.dy, .0001));
    }
  });

  testWidgets('point tracker springs keyed coordinates independently', (
    tester,
  ) async {
    expect(beuiSpringLayout.description.mass, .6);
    expect(beuiSpringLayout.description.stiffness, 360);
    expect(beuiSpringLayout.description.damping, 32);
    await tester.pumpWidget(const MaterialApp(home: _TrackerHarness()));
    final state = tester.state<_TrackerHarnessState>(
      find.byType(_TrackerHarness),
    );
    expect(state.positions['p'], const Offset(10, 20));

    state.update(target: const Offset(10, 100));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final first = state.positions['p']!;
    expect(first.dy, greaterThan(20));
    expect(first.dy, lessThan(100));
    expect(first.dx, 10, reason: 'an unchanged x coordinate must not move');

    // A parent-only rebuild retains the running spring instead of restarting it.
    state.rebuildUnchanged();
    await tester.pump(const Duration(milliseconds: 32));
    final progressed = state.positions['p']!;
    expect(progressed.dy, greaterThan(first.dy));
    expect(progressed.dx, 10);
    await tester.pumpAndSettle();
    expect(state.positions['p']!.dx, 10);
    expect(state.positions['p']!.dy, closeTo(100, .0001));
  });

  testWidgets('point tracker snaps resize and reduced-motion updates', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _TrackerHarness()));
    final state = tester.state<_TrackerHarnessState>(
      find.byType(_TrackerHarness),
    );
    state.update(target: const Offset(80, 90));
    await tester.pump(const Duration(milliseconds: 16));
    expect(state.positions['p']!.dx, lessThan(80));

    state.resize(width: 240);
    await tester.pump();
    expect(state.positions['p'], const Offset(80, 90));

    state.update(target: const Offset(130, 160));
    await tester.pump(const Duration(milliseconds: 16));
    expect(state.positions['p']!.dy, lessThan(160));
    state.setReducedMotion(true, target: const Offset(150, 170));
    await tester.pump();
    expect(state.positions['p'], const Offset(150, 170));

    state.update(target: const Offset(200, 210));
    await tester.pump();
    expect(state.positions['p'], const Offset(200, 210));
  });

  testWidgets('removed point controllers dispose without a ticker leak', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _TrackerHarness()));
    final state = tester.state<_TrackerHarnessState>(
      find.byType(_TrackerHarness),
    );
    state.update(target: const Offset(100, 120));
    await tester.pump(const Duration(milliseconds: 16));
    state.removePoint();
    await tester.pump();
    expect(state.positions, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('inspector horizontal and vertical arrows match range behavior', (
    tester,
  ) async {
    for (final orientation in Axis.values) {
      var active = 2;
      var open = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                height: 120,
                child: StatefulBuilder(
                  builder: (context, setState) => BeuiXYInspector(
                    count: 5,
                    activeIndex: active,
                    onActiveIndexChanged: (value) =>
                        setState(() => active = value),
                    label: 'Values',
                    valueText: (index) => 'Value $index',
                    orientation: orientation,
                    open: open,
                    onOpenChange: (value) => setState(() => open = value),
                    child: const ColoredBox(color: Colors.transparent),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Values'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(active, orientation == Axis.horizontal ? 3 : 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(active, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(active, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(active, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(active, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(active, 4);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      expect(active, 3);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      expect(active, 4);
      expect(open, isTrue);
    }
  });

  testWidgets(
    'band pointer mapping selects category slots, not nearest points',
    (tester) async {
      var active = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                key: const ValueKey('band-plot'),
                width: 200,
                height: 80,
                child: BeuiXYInspector(
                  count: 4,
                  activeIndex: active,
                  onActiveIndexChanged: (value) => active = value,
                  label: 'Bands',
                  valueText: (index) => 'Band $index',
                  mode: BeuiXYInspectionMode.band,
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byKey(const ValueKey('band-plot')));
      for (final sample in [(20.0, 0), (60.0, 1), (110.0, 2), (170.0, 3)]) {
        await tester.tapAt(Offset(rect.left + sample.$1, rect.center.dy));
        await tester.pump();
        expect(active, sample.$2);
      }
    },
  );

  testWidgets('pointer focus leaves readout; keyboard focus retains it', (
    tester,
  ) async {
    var active = 1;
    var open = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Center(
              child: SizedBox(
                key: const ValueKey('focus-plot'),
                width: 200,
                height: 80,
                child: BeuiXYInspector(
                  count: 4,
                  activeIndex: active,
                  onActiveIndexChanged: (value) =>
                      setState(() => active = value),
                  label: 'Focus values',
                  valueText: (index) => 'Value $index',
                  open: open,
                  onOpenChange: (value) => setState(() => open = value),
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final plot = tester.getRect(find.byKey(const ValueKey('focus-plot')));
    final mouse = await tester.createGesture(
      pointer: 42,
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: plot.center);
    await mouse.down(plot.center);
    await mouse.up();
    await tester.pump();
    expect(open, isTrue);
    await mouse.moveTo(plot.bottomRight + const Offset(20, 20));
    await tester.pump();
    expect(
      open,
      isFalse,
      reason: 'incidental mouse focus closes on pointer leave',
    );

    await mouse.moveTo(plot.center);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(active, 3);
    expect(
      open,
      isTrue,
      reason: 'keyboard interaction intentionally opens inspection',
    );
    await mouse.moveTo(plot.bottomRight + const Offset(40, 40));
    await tester.pump();
    expect(
      open,
      isTrue,
      reason: 'keyboard focus keeps inspection open on pointer leave',
    );
  });

  testWidgets('semantic increase and decrease update the slider value', (
    tester,
  ) async {
    var active = 1;
    var open = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => BeuiXYInspector(
              count: 4,
              activeIndex: active,
              onActiveIndexChanged: (value) => setState(() => active = value),
              label: 'Semantic values',
              valueText: (index) => 'Sample $index',
              open: open,
              onOpenChange: (value) => setState(() => open = value),
              child: const SizedBox(width: 240, height: 80),
            ),
          ),
        ),
      ),
    );
    final semanticFinder = find.semantics.byLabel('Semantic values');
    tester.semantics.performAction(semanticFinder, ui.SemanticsAction.increase);
    await tester.pump();
    expect(active, 2);
    expect(open, isTrue);
    tester.semantics.performAction(semanticFinder, ui.SemanticsAction.decrease);
    await tester.pump();
    expect(active, 1);
  });

  test('gapped line and area paths have the literal source geometry', () {
    final points = <Offset?>[
      const Offset(0, 2),
      const Offset(4, 8),
      null,
      const Offset(9, 3),
    ];
    expect(beuiXYLinePathData(points), 'M0,2L4,8M9,3h0');
    expect(beuiXYAreaPathData(points, 10), 'M0,2L4,8L4,10L0,10Z');
    final lineMetrics = beuiXYLinePath(points).computeMetrics().toList();
    expect(lineMetrics, hasLength(1));
    expect(lineMetrics[0].length, closeTo(7.2111, .0001));
    final areaMetrics = beuiXYAreaPath(points, 10).computeMetrics().toList();
    expect(areaMetrics, hasLength(1));
    expect(areaMetrics.single.length, closeTo(21.2111, .0001));
  });
}

class _TrackerHarness extends StatefulWidget {
  const _TrackerHarness();

  @override
  State<_TrackerHarness> createState() => _TrackerHarnessState();
}

class _TrackerHarnessState extends State<_TrackerHarness> {
  Offset target = const Offset(10, 20);
  double width = 120;
  bool reduceMotion = false;
  Map<String, Offset> positions = const {};
  bool includePoint = true;

  void update({required Offset target}) => setState(() => this.target = target);
  void resize({required double width}) => setState(() => this.width = width);
  void setReducedMotion(bool value, {required Offset target}) => setState(() {
    reduceMotion = value;
    this.target = target;
  });
  void removePoint() => setState(() => includePoint = false);
  void rebuildUnchanged() => setState(() {});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: BeuiXYPointTracker(
        targets: [
          if (includePoint) BeuiXYPointTarget(key: 'p', position: target),
        ],
        width: width,
        reduceMotion: reduceMotion,
        builder: (next) {
          positions = next;
          return const SizedBox(width: 200, height: 100);
        },
      ),
    ),
  );
}
