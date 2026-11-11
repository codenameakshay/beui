import 'package:beui/src/charts/_xy_parts.dart' show BeuiXYFocusOutline;
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show SemanticsRole;

import 'package:beui/src/charts/_xy.dart';
import 'package:beui/src/charts/_shared.dart' show BeuiChartTooltip;
import 'package:beui/src/charts/line_chart.dart';
import 'package:beui/src/motion/button/base.dart' show BeuiButton;
import 'package:beui/src/motion/tooltip.dart' show BeuiTooltip, BeuiTooltipSide;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderParagraph, RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/line_chart_demo.dart' show lineChartDemo;
import '../support.dart';

Finder get _inspectorSemantics => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.label == 'Illustrative monthly revenue: inspect values',
);

Future<void> _focusInspector(WidgetTester tester) async {
  final focus = Focus.of(tester.element(_inspectorSemantics));
  focus.requestFocus();
  await tester.pumpAndSettle();
  expect(focus.hasFocus, isTrue);
  expect(FocusManager.instance.primaryFocus, same(focus));
}

Map<String, dynamic> get _preview =>
    jsonDecode(
          File(
            'test/fixtures/charts_xy/preview-contract.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

List<BeuiLineChartSeries> _fixtureSeries(int seed) {
  final snapshots = (_preview['line']['snapshots'] as List).cast<Map>();
  final snapshot = snapshots.singleWhere((item) => item['seed'] == seed);
  return [
    for (final row in (snapshot['series'] as List).cast<Map<String, dynamic>>())
      BeuiLineChartSeries(
        id: row['id'] as String,
        name: row['name'] as String,
        color: row['color'] as String,
        values: (row['values'] as List).cast<num?>(),
      ),
  ];
}

Widget _chart({
  Widget? child,
  BeuiLineChartStatus status = BeuiLineChartStatus.ready,
  String? activeId,
  String? defaultActiveId,
  bool controlledActive = false,
  ValueChanged<String?>? onActiveChange,
  List<String>? hiddenSeries,
  bool controlledHiddenSeries = false,
  ValueChanged<List<String>>? onHiddenSeriesChange,
  bool reduce = false,
  List<BeuiLineChartSeries>? series,
  List<String>? categories,
  (num, num)? domain,
  double width = 520,
  String loadingLabel = 'Loading data',
}) => beuiTestApp(
  RepaintBoundary(
    key: const ValueKey('line-test-boundary'),
    child: SizedBox(
      width: width,
      child: ColoredBox(
        color: Colors.white,
        child: BeuiLineChart(
          series: series ?? _fixtureSeries(7),
          categories:
              categories ??
              (_preview['line']['categories'] as List).cast<String>(),
          variant: BeuiLineChartVariant.area,
          domain: domain,
          label: 'Illustrative monthly revenue',
          formatValue: (value) => '\$${value.toStringAsFixed(1)}K',
          formatTick: (value) =>
              value == 0 ? r'$0' : '\$${value.toStringAsFixed(0)}K',
          status: status,
          loadingLabel: loadingLabel,
          activeId: activeId,
          defaultActiveId: defaultActiveId,
          controlledActive: controlledActive,
          onActiveChange: onActiveChange,
          hiddenSeries: hiddenSeries,
          controlledHiddenSeries: controlledHiddenSeries,
          onHiddenSeriesChange: onHiddenSeriesChange,
          child: child,
        ),
      ),
    ),
  ),
  reduce: reduce,
);

Future<List<double>> _linePixelContrasts(
  WidgetTester tester,
  List<double> fractions, {
  double lineOffset = 0,
}) async {
  final boundary = tester.getRect(
    find.byKey(const ValueKey('line-test-boundary')),
  );
  final paint = find
      .descendant(
        of: find.byKey(const ValueKey('line-loading')),
        matching: find.byType(CustomPaint),
      )
      .first;
  final rect = tester.getRect(paint);
  final image = (await tester.runAsync(
    () => tester
        .renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('line-test-boundary')),
        )
        .toImage(pixelRatio: 1),
  ))!;
  final bytes = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  final width = image.width;
  image.dispose();

  double luminanceAt(double x, double y) {
    final px = (rect.left - boundary.left + x * rect.width).round();
    final py = (rect.top - boundary.top + y).round();
    final offset = (py * width + px) * 4;
    return .2126 * bytes.getUint8(offset) +
        .7152 * bytes.getUint8(offset + 1) +
        .0722 * bytes.getUint8(offset + 2);
  }

  return [
    for (final fraction in fractions)
      (luminanceAt(
                fraction,
                rect.height *
                        (.62 -
                            .18 * fraction +
                            .07 * math.sin(fraction * math.pi * 3)) +
                    lineOffset,
              ) -
              luminanceAt(
                fraction,
                rect.height *
                        (.62 -
                            .18 * fraction +
                            .07 * math.sin(fraction * math.pi * 3)) +
                    10,
              ))
          .abs(),
  ];
}

Future<Color> _renderedPixel(
  WidgetTester tester,
  Finder boundaryFinder,
  Offset boundaryPosition,
) async {
  final image = (await tester.runAsync(
    () => tester
        .renderObject<RenderRepaintBoundary>(boundaryFinder)
        .toImage(pixelRatio: 1),
  ))!;
  final bytes = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  final x = boundaryPosition.dx.round();
  final y = boundaryPosition.dy.round();
  final offset = (y * image.width + x) * 4;
  final color = Color.fromARGB(
    bytes.getUint8(offset + 3),
    bytes.getUint8(offset),
    bytes.getUint8(offset + 1),
    bytes.getUint8(offset + 2),
  );
  image.dispose();
  return color;
}

Rect _rectInBoundary(
  WidgetTester tester,
  Finder boundaryFinder,
  Finder childFinder,
) => tester.getRect(childFinder).shift(-tester.getRect(boundaryFinder).topLeft);

bool _matchesRgb(Color actual, Color expected, {int tolerance = 8}) =>
    ((actual.r * 255).round().clamp(0, 255) -
                (expected.r * 255).round().clamp(0, 255))
            .abs() <=
        tolerance &&
    ((actual.g * 255).round().clamp(0, 255) -
                (expected.g * 255).round().clamp(0, 255))
            .abs() <=
        tolerance &&
    ((actual.b * 255).round().clamp(0, 255) -
                (expected.b * 255).round().clamp(0, 255))
            .abs() <=
        tolerance;

void main() {
  testWidgets(
    'opposite finite extremes paint and inspect within fixed domain',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          SizedBox(
            width: 600,
            child: BeuiLineChart(
              series: [
                BeuiLineChartSeries(
                  id: 'x',
                  name: 'X',
                  color: '#2563eb',
                  values: [1e308, -1e308],
                ),
              ],
              categories: ['A', 'B'],
              domain: (-1e308, 1e308),
            ),
          ),
          reduce: true,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing data length during animation tolerates empty and dense samples',
    (tester) async {
      Widget chart(List<num?> values) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: BeuiLineChart(
              series: [
                BeuiLineChartSeries(
                  id: 'x',
                  name: 'X',
                  color: '#2563eb',
                  values: values,
                ),
              ],
              categories: List.generate(values.length, (i) => 'Category $i'),
            ),
          ),
        ),
      );
      await tester.pumpWidget(chart(const [1, 2, 3]));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpWidget(chart(const [9]));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpWidget(chart(const []));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpWidget(chart(List<num?>.filled(1000, 4)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keyboard inspection paints a visible focus outline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: BeuiLineChart(
              series: const [
                BeuiLineChartSeries(
                  id: 'x',
                  name: 'X',
                  color: '#2563eb',
                  values: [1, 2],
                ),
              ],
              categories: const ['A', 'B'],
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(BeuiXYFocusOutline),
        matching: find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.foregroundPainter != null,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('demo matches the source width, alignment and chart gap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(beuiTestApp(Builder(builder: lineChartDemo)));

    final header = tester.getRect(
      find.ancestor(
        of: find.text('Monthly revenue'),
        matching: find.byType(Wrap),
      ),
    );
    final plot = tester.getRect(find.byType(BeuiLineChartPlot));
    expect(plot.width, 768);
    expect(header.left, plot.left);
    expect(plot.top - header.bottom, 20);
  });

  testWidgets(
    'demo keeps tabs active while loading and disables both actions',
    (tester) async {
      await tester.pumpWidget(beuiTestApp(Builder(builder: lineChartDemo)));
      final plot = find.byType(BeuiLineChartPlot);

      await tester.tap(find.text('Reload'));
      await tester.pump();
      expect(BeuiLineChart.of(tester.element(plot)).loading, isTrue);

      for (final label in ['New data', 'Reload']) {
        final button = tester.widget<BeuiButton>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(BeuiButton),
          ),
        );
        expect(button.onPressed, isNull);
      }

      await tester.tap(find.text('Line'));
      await tester.pump();
      final model = BeuiLineChart.of(tester.element(plot));
      expect(model.loading, isTrue);
      expect(model.variant, BeuiLineChartVariant.line);

      await tester.pump(const Duration(milliseconds: 1800));
      expect(BeuiLineChart.of(tester.element(plot)).loading, isFalse);
    },
  );

  test('preview uses the source-frozen seeds and exact July readout', () {
    final series = _fixtureSeries(7);
    expect(series.map((row) => row.id), ['this-year', 'last-year', 'target']);
    expect(series[0].values[6], 53.6);
    expect(series[1].values[6], 44.2);
    expect(series[2].values[6], 51.0);
    expect(_fixtureSeries(337897)[0].values, [
      42.2,
      42.5,
      47.8,
      50.7,
      53.1,
      57.3,
      57.8,
      59.3,
      59.6,
      66.3,
      66.4,
      66.9,
    ]);
  });

  testWidgets('model exposes normalized immutable rows, gaps and domain', (
    tester,
  ) async {
    late BeuiLineChartModel model;
    await tester.pumpWidget(
      _chart(
        child: Builder(
          builder: (context) {
            model = BeuiLineChart.of(context);
            return const BeuiLineChartPlot(height: 190);
          },
        ),
      ),
    );
    expect(model.categories, _preview['line']['categories']);
    expect(model.rows[0].values[6], 53.6);
    expect(model.domain.min, 0);
    expect(model.domain.max, 80);
    expect(() => model.rows.add(model.rows.first), throwsUnsupportedError);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty plots return a centered 14px message without axis art', (
    tester,
  ) async {
    Future<void> expectEmpty({
      required List<BeuiLineChartSeries> series,
      required List<String> categories,
    }) async {
      await tester.pumpWidget(
        _chart(series: series, categories: categories, reduce: true),
      );

      final plot = tester.getRect(find.byType(BeuiLineChartPlot));
      final message = tester.widget<Text>(find.text('No data'));
      expect(plot.height, 288);
      expect(tester.getRect(find.text('No data')).center, plot.center);
      expect(message.style!.fontSize, 14);
      expect(find.byKey(const ValueKey('line-axis-grid')), findsNothing);
      expect(find.byKey(const ValueKey('line-axis-labels')), findsNothing);
      expect(
        find.byKey(const ValueKey('line-inspector-position')),
        findsNothing,
      );
    }

    await expectEmpty(
      series: const [],
      categories: (_preview['line']['categories'] as List).cast<String>(),
    );
    await expectEmpty(series: _fixtureSeries(7), categories: const []);
  });

  testWidgets('long category labels stay centered at their source sample', (
    tester,
  ) async {
    const categories = [
      'Start',
      'Middle',
      'Last category label beyond sixty px',
    ];
    final series = [
      const BeuiLineChartSeries(
        id: 'series',
        name: 'Series',
        color: '#2563eb',
        values: [1, 2, 3],
      ),
    ];
    await tester.pumpWidget(
      _chart(series: series, categories: categories, reduce: true),
    );

    final plot = tester.getRect(find.byType(BeuiLineChartPlot));
    final label = tester.getRect(
      find.byKey(const ValueKey('line-category-label-2')),
    );
    expect(label.width, greaterThan(60));
    expect(label.center.dx, closeTo(plot.right - 16, .01));
  });

  testWidgets('inspection markers are centered on the raw sample coordinates', (
    tester,
  ) async {
    await tester.pumpWidget(_chart(defaultActiveId: 'Jul'));
    await _focusInspector(tester);
    await tester.pumpAndSettle();
    final plot = tester.getRect(find.byType(BeuiLineChartPlot));
    final marker = find.byKey(const ValueKey('mark-this-year'));
    expect(marker, findsOneWidget);
    final bounds = tester.getRect(marker);
    final domain = BeuiLineChart.of(
      tester.element(find.byType(BeuiLineChartPlot)),
    ).domain;
    final expectedX = plot.left + 44 + 6 / 11 * (plot.width - 60);
    final expectedY =
        plot.top + 12 + (domain.max - 53.6) / domain.max * (288 - 20);
    expect(bounds.size, const Size(20, 20));
    expect(bounds.center.dx, closeTo(expectedX, 1));
    expect(bounds.center.dy, closeTo(expectedY, 1));
  });

  testWidgets(
    'controlled null remains selected as controlled; keyboard changes request values',
    (tester) async {
      final changes = <String?>[];
      await tester.pumpWidget(
        _chart(
          controlledActive: true,
          activeId: null,
          onActiveChange: changes.add,
        ),
      );
      final plot = tester.getRect(find.byType(BeuiLineChartPlot));
      await tester.tapAt(Offset(plot.left + 50, plot.center.dy));
      await tester.pump();
      expect(changes, isNotEmpty);
      expect(changes.last, 'Jan');
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(changes.last, 'Dec');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(BeuiChartTooltip), findsNothing);
    },
  );

  testWidgets('focused inspector supports Home, arrows, End and Escape', (
    tester,
  ) async {
    final requests = <String?>[];
    await tester.pumpWidget(
      _chart(defaultActiveId: 'Jun', onActiveChange: requests.add),
    );
    await _focusInspector(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(requests, isNotEmpty);
    expect(requests.last, 'Jan');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(requests.last, 'Feb');
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(requests.last, 'Dec');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(BeuiChartTooltip), findsNothing);
  });

  testWidgets('pointer inspection preserves the focused inspector state', (
    tester,
  ) async {
    await tester.pumpWidget(_chart());
    await _focusInspector(tester);
    final inspector = find.byType(BeuiXYInspector);
    final state = tester.state<State>(inspector);
    final plot = tester.getRect(find.byType(BeuiLineChartPlot));
    final sampleX = plot.left + 44 + (plot.width - 60) * 6 / 11;

    await tester.tapAt(Offset(sampleX, plot.top + 100));
    await tester.pump();

    expect(identical(tester.state<State>(inspector), state), isTrue);
    expect(
      BeuiLineChart.of(tester.element(find.byType(BeuiLineChartPlot))).activeId,
      'Jul',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('category pill exits over the source 100ms interval', (
    tester,
  ) async {
    await tester.pumpWidget(_chart(defaultActiveId: 'Jun'));
    await _focusInspector(tester);
    expect(find.byKey(const ValueKey('line-category-pill')), findsOneWidget);

    final plot = tester.getRect(find.byType(BeuiLineChartPlot));
    final pill = tester.getRect(
      find.byKey(const ValueKey('line-category-pill')),
    );
    expect(pill.top - plot.top, 296);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(Duration.zero);
    expect(find.byKey(const ValueKey('line-category-pill')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 99));
    expect(find.byKey(const ValueKey('line-category-pill')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    final exit = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('line-category-pill')),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(exit.opacity.value, 0);
    await tester.pump(const Duration(microseconds: 1));
    expect(find.byKey(const ValueKey('line-category-pill')), findsNothing);
  });

  testWidgets(
    'hidden series callbacks are immutable and hidden source rows stay in table',
    (tester) async {
      List<String>? requested;
      await tester.pumpWidget(
        _chart(onHiddenSeriesChange: (value) => requested = value),
      );
      await tester.tap(find.text('This year'));
      await tester.pump();
      expect(requested, ['this-year']);
      expect(() => requested!.add('mutate'), throwsUnsupportedError);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.role == SemanticsRole.columnHeader &&
              widget.properties.label == 'This year',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('series visibility eases its plot opacity over source duration', (
    tester,
  ) async {
    await tester.pumpWidget(_chart());
    await tester.pumpAndSettle();

    double opacityFor(Finder opacity) => tester
        .widgetList<FadeTransition>(
          find.descendant(of: opacity, matching: find.byType(FadeTransition)),
        )
        .singleWhere((transition) => transition.child is CustomPaint)
        .opacity
        .value;

    final seriesOpacity = find.byKey(
      const ValueKey('line-series-opacity-this-year'),
    );
    expect(opacityFor(seriesOpacity), 1);
    await tester.tap(find.text('This year'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(opacityFor(seriesOpacity), greaterThan(0));
    expect(opacityFor(seriesOpacity), lessThan(1));
    await tester.pump(const Duration(milliseconds: 150));
    expect(opacityFor(seriesOpacity), 0);
  });

  testWidgets('loading fade is 150ms and independent of 180ms row emphasis', (
    tester,
  ) async {
    await tester.pumpWidget(_chart());
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpWidget(_chart(status: BeuiLineChartStatus.loading));

    double renderedOpacity(Finder scope, {required Type childType}) => tester
        .widgetList<FadeTransition>(
          find.descendant(of: scope, matching: find.byType(FadeTransition)),
        )
        .singleWhere((transition) => transition.child.runtimeType == childType)
        .opacity
        .value;

    final loadingFade = find.byKey(const ValueKey('line-series-loading-fade'));
    final rowFade = find.byKey(const ValueKey('line-series-opacity-this-year'));
    final categoryFade = find.byKey(
      const ValueKey('line-category-loading-fade'),
    );
    final categoryRow = find.byKey(const ValueKey('line-category-label-11'));
    final categoryBounds = tester.getRect(categoryRow);
    final seriesPaints = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter.runtimeType.toString() == '_LineChartPainter',
    );
    expect(seriesPaints, findsNWidgets(3));
    await tester.pump(const Duration(milliseconds: 75));
    expect(renderedOpacity(loadingFade, childType: Stack), greaterThan(0));
    expect(renderedOpacity(loadingFade, childType: Stack), lessThan(1));
    expect(renderedOpacity(categoryFade, childType: Stack), greaterThan(0));
    expect(renderedOpacity(categoryFade, childType: Stack), lessThan(1));
    expect(renderedOpacity(rowFade, childType: CustomPaint), 1);
    await tester.pump(const Duration(milliseconds: 75));
    expect(renderedOpacity(loadingFade, childType: Stack), 0);
    expect(renderedOpacity(categoryFade, childType: Stack), 0);
    expect(tester.getRect(categoryRow), categoryBounds);
    expect(renderedOpacity(rowFade, childType: CustomPaint), 1);
    expect(seriesPaints, findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'loading removes the table and inspector while showing the placeholder',
    (tester) async {
      await tester.pumpWidget(_chart(status: BeuiLineChartStatus.loading));
      expect(find.text('Loading data'), findsOneWidget);
      expect(find.byType(BeuiXYInspector), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Jan.*This year')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced loading opacity pulses on an 1800ms cycle', (
    tester,
  ) async {
    await tester.pumpWidget(
      _chart(status: BeuiLineChartStatus.loading, reduce: true),
    );
    final boundaryFinder = find.byKey(const ValueKey('line-test-boundary'));
    final paintFinder = find.descendant(
      of: find.byKey(const ValueKey('line-loading')),
      matching: find.byType(CustomPaint),
    );
    expect(paintFinder, findsOneWidget);

    Future<double> strokeContrast() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        boundaryFinder,
      );
      final boundaryRect = tester.getRect(boundaryFinder);
      final lineRect = tester.getRect(paintFinder);
      final image = (await tester.runAsync(
        () => boundary.toImage(pixelRatio: 1),
      ))!;
      final bytes = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      image.dispose();
      final data = bytes!;
      final x = (lineRect.left - boundaryRect.left + lineRect.width * 2 / 15)
          .round();
      final lineY =
          lineRect.top -
          boundaryRect.top +
          lineRect.height *
              (.62 - .18 * 2 / 15 + .07 * math.sin(2 / 15 * math.pi * 3));

      double luminanceAt(double y) {
        final offset = (y.round() * image.width + x) * 4;
        return .2126 * data.getUint8(offset) +
            .7152 * data.getUint8(offset + 1) +
            .0722 * data.getUint8(offset + 2);
      }

      return (luminanceAt(lineY) - luminanceAt(lineY + 5)).abs();
    }

    final start = await strokeContrast();
    await tester.pump(const Duration(milliseconds: 900));
    final peak = await strokeContrast();
    expect(peak, greaterThan(start));
    await tester.pump(const Duration(microseconds: 1));
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(microseconds: 899999));
    final end = await strokeContrast();
    expect(end, closeTo(start, 2));
  });

  testWidgets('loading strokeWidth changes painted placeholder thickness', (
    tester,
  ) async {
    Future<double> contrastFor(double strokeWidth) async {
      await tester.pumpWidget(
        _chart(
          status: BeuiLineChartStatus.loading,
          reduce: true,
          child: BeuiLineChartPlot(strokeWidth: strokeWidth),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      return (await _linePixelContrasts(tester, const [
        2 / 15,
      ], lineOffset: 3)).single;
    }

    final sourceStroke = await contrastFor(8);
    final defaultStroke = await contrastFor(2);
    expect(sourceStroke, greaterThan(10));
    expect(defaultStroke, lessThan(5));
  });

  testWidgets(
    'area gradients use each series path bounds and literal rendered colors',
    (tester) async {
      const categories = ['Start', 'Middle', 'End'];
      final series = [
        BeuiLineChartSeries(
          id: 'upper',
          name: 'Upper',
          color: '#2563eb',
          values: const [80, 80, 80],
        ),
        BeuiLineChartSeries(
          id: 'lower',
          name: 'Lower',
          color: '#0d9488',
          values: const [20, 20, 20],
        ),
      ];
      await tester.pumpWidget(
        _chart(series: series, categories: categories, domain: (0, 100)),
      );
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      final boundary = find.byKey(const ValueKey('line-test-boundary'));
      final plot = _rectInBoundary(
        tester,
        boundary,
        find.byType(BeuiLineChartPlot),
      );
      const innerHeight = 268.0;
      const baseline = 280.0;
      double yFor(num value) => 12 + (100 - value) / 100 * innerHeight;
      final x = 44 + (plot.width - 60) / 2;
      final upperY = yFor(80);
      final lowerY = yFor(20);
      final upperSample = await _renderedPixel(
        tester,
        boundary,
        Offset(x, plot.top + upperY + (baseline - upperY) * .25),
      );
      final lowerSample = await _renderedPixel(
        tester,
        boundary,
        Offset(x, plot.top + lowerY + (baseline - lowerY) * .25),
      );

      expect(
        _matchesRgb(upperSample, const Color(0xffe8effd), tolerance: 3),
        isTrue,
      );
      expect(
        _matchesRgb(lowerSample, const Color(0xffe0f0f2), tolerance: 3),
        isTrue,
      );
    },
  );

  testWidgets(
    'plot reveal clips rendered strokes and preserves the loading handoff',
    (tester) async {
      const categories = ['Start', 'Middle', 'End'];
      final series = [
        BeuiLineChartSeries(
          id: 'stroke',
          name: 'Stroke',
          color: '#2563eb',
          values: const [20, 80, 20],
        ),
      ];
      await tester.pumpWidget(
        _chart(
          series: series,
          categories: categories,
          domain: (0, 100),
          child: const BeuiLineChartPlot(fadeEdges: false, strokeWidth: 8),
        ),
      );
      final boundary = find.byKey(const ValueKey('line-test-boundary'));
      final plot = _rectInBoundary(
        tester,
        boundary,
        find.byType(BeuiLineChartPlot),
      );
      final sample = Offset(
        44 + (plot.width - 60) / 2,
        plot.top + 12 + (100 - 80) / 100 * 268,
      );
      final trailingSample = Offset(
        plot.width - 17,
        plot.top + 12 + (100 - 20) / 100 * 268,
      );
      final background = await _renderedPixel(tester, boundary, sample);
      expect(background, const Color(0xffffffff));
      expect(
        await _renderedPixel(tester, boundary, trailingSample),
        const Color(0xffffffff),
      );

      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 100));
      final during = await _renderedPixel(tester, boundary, sample);
      expect(_matchesRgb(during, const Color(0xff2563eb)), isTrue);
      expect(
        await _renderedPixel(tester, boundary, trailingSample),
        const Color(0xffffffff),
      );
      await tester.pump(const Duration(milliseconds: 600));
      final after = await _renderedPixel(tester, boundary, sample);
      expect(_matchesRgb(after, const Color(0xff2563eb)), isTrue);
      expect(
        _matchesRgb(
          await _renderedPixel(tester, boundary, trailingSample),
          const Color(0xff2563eb),
        ),
        isTrue,
      );

      await tester.pumpWidget(
        _chart(
          series: series,
          categories: categories,
          domain: (0, 100),
          status: BeuiLineChartStatus.loading,
          child: const BeuiLineChartPlot(fadeEdges: false, strokeWidth: 8),
        ),
      );
      await tester.pump(const Duration(milliseconds: 75));
      final handoff = await _renderedPixel(tester, boundary, sample);
      expect(
        (handoff.b * 255).round().clamp(0, 255),
        greaterThan((after.b * 255).round().clamp(0, 255)),
      );
      expect(
        (handoff.b * 255).round().clamp(0, 255),
        lessThan((background.b * 255).round().clamp(0, 255)),
      );
      await tester.pump(const Duration(milliseconds: 75));
      final faded = await _renderedPixel(tester, boundary, sample);
      expect(faded, const Color(0xffffffff));
      await tester.pump(const Duration(milliseconds: 160));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long final category label uses loaded inherited font and scale',
    (tester) async {
      final fontData = ByteData.sublistView(
        File('example/assets/fonts/Geist-Regular.ttf').readAsBytesSync(),
      );
      final font = FontLoader('Geist')..addFont(Future.value(fontData));
      await font.load();

      const categories = ['A', 'B', 'A long final category label'];
      final chart = BeuiLineChart(
        series: const [
          BeuiLineChartSeries(
            id: 'values',
            name: 'Values',
            color: '#2563eb',
            values: [1, 2, 3],
          ),
        ],
        categories: categories,
        child: const BeuiLineChartPlot(),
      );
      await tester.pumpWidget(
        beuiTestApp(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: SizedBox(width: 520, child: chart),
          ),
          fontFamily: 'Geist',
        ),
      );

      final labelFinder = find.byKey(const ValueKey('line-category-label-2'));
      final label = tester.getRect(labelFinder);
      final plot = tester.getRect(find.byType(BeuiLineChartPlot));
      final paragraphFinder = find.descendant(
        of: labelFinder,
        matching: find.text(categories.last),
      );
      final paragraph = tester.renderObject<RenderParagraph>(paragraphFinder);
      final glyphs = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: categories.last.length),
      );
      expect(glyphs, hasLength(1));
      final glyph = glyphs.single;
      expect(glyph.right - glyph.left, greaterThan(120));
      expect(glyph.left, greaterThanOrEqualTo(0));
      expect(glyph.right, lessThanOrEqualTo(paragraph.size.width));
      expect(glyph.right - glyph.left, closeTo(label.width, .5));
      final glyphCenter =
          tester.getRect(paragraphFinder).left + (glyph.left + glyph.right) / 2;
      expect(glyphCenter, closeTo(plot.right - 16, .01));
    },
  );

  testWidgets(
    'travelling highlight follows the source band through its cycle',
    (tester) async {
      await tester.pumpWidget(
        _chart(
          status: BeuiLineChartStatus.loading,
          loadingLabel: '',
          child: const BeuiLineChartPlot(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      const width = 460.0;
      final progress = const Cubic(.77, 0, .175, 1).transform(.5);
      final band = math.max(80.0, width * .28);
      final left = -band + (width + band) * progress;
      final center = (left + band / 2) / width;
      final before = (left - band * .5) / width;
      final after = (left + band * 1.5) / width;
      final baseline = (await _linePixelContrasts(tester, [center])).single;

      await tester.pump(const Duration(milliseconds: 600));
      final middle = await _linePixelContrasts(tester, [center, before, after]);
      expect(middle[0], greaterThan(baseline + 12));
      expect(middle[0], greaterThan(middle[1] + 12));
      expect(middle[0], greaterThan(middle[2] + 12));

      await tester.pump(const Duration(milliseconds: 800));
      final end = (await _linePixelContrasts(tester, [center])).single;
      expect(end, closeTo(baseline, 2));
    },
  );

  testWidgets(
    'reduced motion reveals the complete plot without waiting for entrance timing',
    (tester) async {
      const categories = ['Start', 'Middle', 'End'];
      const series = [
        BeuiLineChartSeries(
          id: 'stroke',
          name: 'Stroke',
          color: '#2563eb',
          values: [20, 80, 20],
        ),
      ];
      await tester.pumpWidget(
        _chart(
          reduce: true,
          series: series,
          categories: categories,
          domain: (0, 100),
          child: const BeuiLineChartPlot(fadeEdges: false, strokeWidth: 8),
        ),
      );
      final boundary = find.byKey(const ValueKey('line-test-boundary'));
      final plotFinder = find.byType(BeuiLineChartPlot);
      final plotBounds = _rectInBoundary(tester, boundary, plotFinder);
      final sample = Offset(
        44 + (plotBounds.width - 60) / 2,
        plotBounds.top + 12 + (100 - 80) / 100 * 268,
      );
      expect(plotBounds.size, const Size(520, 316));
      expect(
        _matchesRgb(
          await _renderedPixel(tester, boundary, sample),
          const Color(0xff2563eb),
        ),
        isTrue,
      );
      await tester.pump();
      expect(_rectInBoundary(tester, boundary, plotFinder), plotBounds);
      expect(
        _matchesRgb(
          await _renderedPixel(tester, boundary, sample),
          const Color(0xff2563eb),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('first reveal is painted once after thirty percent enters view', (
    tester,
  ) async {
    final scroll = ScrollController();
    const categories = ['Start', 'Middle', 'End'];
    const series = [
      BeuiLineChartSeries(
        id: 'stroke',
        name: 'Stroke',
        color: '#2563eb',
        values: [20, 80, 20],
      ),
    ];
    await tester.pumpWidget(
      beuiTestApp(
        SizedBox(
          height: 320,
          child: SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                const SizedBox(height: 700),
                RepaintBoundary(
                  key: const ValueKey('line-in-view-boundary'),
                  child: SizedBox(
                    width: 520,
                    child: const ColoredBox(
                      color: Colors.white,
                      child: BeuiLineChart(
                        series: series,
                        categories: categories,
                        variant: BeuiLineChartVariant.area,
                        domain: (0, 100),
                        child: BeuiLineChartPlot(
                          fadeEdges: false,
                          strokeWidth: 8,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final boundary = find.byKey(const ValueKey('line-in-view-boundary'));
    final plotFinder = find.byType(BeuiLineChartPlot);
    final initialBounds = _rectInBoundary(tester, boundary, plotFinder);
    final middleSample = Offset(
      44 + (initialBounds.width - 60) / 2,
      initialBounds.top + 12 + (100 - 80) / 100 * 268,
    );
    final trailingSample = Offset(
      initialBounds.width - 17,
      initialBounds.top + 12 + (100 - 20) / 100 * 268,
    );
    scroll.jumpTo(466);
    await tester.pump();
    expect(_rectInBoundary(tester, boundary, plotFinder), initialBounds);
    expect(
      await _renderedPixel(tester, boundary, middleSample),
      const Color(0xffffffff),
    );
    scroll.jumpTo(467);
    await tester.pump();
    expect(_rectInBoundary(tester, boundary, plotFinder), initialBounds);
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 119));
    expect(
      await _renderedPixel(tester, boundary, middleSample),
      const Color(0xffffffff),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(Duration.zero);
    expect(
      await _renderedPixel(tester, boundary, middleSample),
      const Color(0xffffffff),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      _matchesRgb(
        await _renderedPixel(tester, boundary, middleSample),
        const Color(0xff2563eb),
      ),
      isTrue,
    );
    expect(
      await _renderedPixel(tester, boundary, trailingSample),
      const Color(0xffffffff),
    );
    expect(_rectInBoundary(tester, boundary, plotFinder), initialBounds);
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      _matchesRgb(
        await _renderedPixel(tester, boundary, middleSample),
        const Color(0xff2563eb),
      ),
      isTrue,
    );
    expect(
      _matchesRgb(
        await _renderedPixel(tester, boundary, trailingSample),
        const Color(0xff2563eb),
      ),
      isTrue,
    );
    scroll.jumpTo(466);
    await tester.pump();
    expect(
      _matchesRgb(
        await _renderedPixel(tester, boundary, middleSample),
        const Color(0xff2563eb),
      ),
      isTrue,
    );
    scroll.jumpTo(467);
    await tester.pump();
    expect(_rectInBoundary(tester, boundary, plotFinder), initialBounds);
    expect(
      _matchesRgb(
        await _renderedPixel(tester, boundary, trailingSample),
        const Color(0xff2563eb),
      ),
      isTrue,
    );
    scroll.dispose();
  });

  testWidgets(
    'custom composition exposes plot, tooltip data and legend parts',
    (tester) async {
      await tester.pumpWidget(
        _chart(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BeuiLineChartPlot(height: 280),
              BeuiLineChartTooltip(
                builder: (data) => Text('${data.category}:${data.rows.length}'),
              ),
              const BeuiLineChartLegend(),
            ],
          ),
        ),
      );
      final plot = tester.getRect(find.byType(BeuiLineChartPlot));
      expect(plot.height, 308);
      await tester.tapAt(Offset(plot.left + 295, plot.top + 100));
      await tester.pumpAndSettle();
      expect(find.byType(BeuiLineChartPlot), findsOneWidget);
      expect(find.byType(BeuiLineChartLegend), findsOneWidget);
      expect(find.text('Jul:3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tooltip accepts static child content alongside its builder API',
    (tester) async {
      await tester.pumpWidget(
        _chart(
          defaultActiveId: 'Jul',
          child: Column(
            children: const [
              BeuiLineChartPlot(height: 280),
              BeuiLineChartTooltip(child: Text('Static readout')),
            ],
          ),
        ),
      );
      await _focusInspector(tester);
      await tester.pumpAndSettle();
      expect(find.text('Static readout'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'narrow auto tooltip flips below using actual custom plot height',
    (tester) async {
      await tester.pumpWidget(
        _chart(
          width: 220,
          defaultActiveId: 'Jul',
          child: Column(
            children: [
              const BeuiLineChartPlot(height: 180),
              BeuiLineChartTooltip(
                builder: (data) => SizedBox(
                  width: 220,
                  height: 160,
                  child: Text('${data.category}:${data.rows.length}'),
                ),
              ),
            ],
          ),
        ),
      );
      await _focusInspector(tester);
      await tester.pumpAndSettle();
      final tooltip = tester.widget<BeuiTooltip>(find.byType(BeuiTooltip));
      expect(tooltip.side, BeuiTooltipSide.bottom);
      expect(tooltip.externalAnchor, isNotNull);
      final panel = find
          .ancestor(of: find.text('Jul:3'), matching: find.byType(DecoratedBox))
          .first;
      final panelRect = tester.getRect(panel);
      final overlayRect = tester.getRect(find.byType(Overlay).first);
      final model = BeuiLineChart.of(
        tester.element(find.byType(BeuiLineChartPlot)),
      );
      final anchorRect = tester.getRect(find.byKey(model.tooltipAnchor));
      expect(panelRect.size, const Size(242, 170));
      expect(panelRect.top - anchorRect.bottom, 16);
      expect(panelRect.center.dx, closeTo(anchorRect.center.dx, .01));
      expect(panelRect.left, greaterThanOrEqualTo(overlayRect.left));
      expect(panelRect.top, greaterThanOrEqualTo(overlayRect.top));
      expect(panelRect.right, lessThanOrEqualTo(overlayRect.right));
      expect(panelRect.bottom, lessThanOrEqualTo(overlayRect.bottom));
      expect(tester.takeException(), isNull);
    },
  );

  test('shared path contract keeps gaps and singleton areas empty', () {
    const points = <BeuiXYPathPoint>[
      Offset(0, 10),
      Offset(10, 20),
      null,
      Offset(30, 5),
    ];
    expect(
      beuiXYLinePathData(points, curve: BeuiXYCurve.linear),
      'M0,10L10,20M30,5h0',
    );
    expect(
      beuiXYAreaPathData(points, 30, curve: BeuiXYCurve.linear),
      'M0,10L10,20L10,30L0,30Z',
    );
  });
}
