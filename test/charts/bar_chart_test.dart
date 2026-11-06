import 'package:beui/src/charts/_xy_parts.dart' show BeuiXYFocusOutline;
import 'package:beui/src/charts/bar_chart.dart';
import 'package:beui/src/charts/_xy.dart' show BeuiXYInspector;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _categories = ['A', 'B', 'C'];
const _series = [
  BeuiBarChartSeries(id: 'x', name: 'X', color: '#2563eb', values: [3, 1, 2]),
  BeuiBarChartSeries(id: 'y', name: 'Y', color: '#0d9488', values: [2, 4, 1]),
];

Finder get _inspector => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.label == 'Bar chart: inspect categories',
);

Widget _app(
  Widget child, {
  Size size = const Size(640, 800),
  bool disableAnimations = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: size, disableAnimations: disableAnimations),
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets(
    'changing data length during animation tolerates empty and dense samples',
    (tester) async {
      Widget chart(List<num?> values) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: BeuiBarChart(
              series: [
                BeuiBarChartSeries(
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
            child: BeuiBarChart(series: _series, categories: _categories),
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

  testWidgets('keyboard inspection clears a previous touch tooltip anchor', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const SizedBox(
          width: 600,
          child: BeuiBarChart(series: _series, categories: _categories),
        ),
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();
    final inspection = find.byKey(const ValueKey('bar-inspection'));
    final gesture = await tester.startGesture(
      tester.getTopLeft(inspection) + const Offset(10, 30),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(BeuiBarChartPlot));
    expect(BeuiBarChart.of(context).pointerPosition, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(BeuiBarChart.of(context).activeId, 'C');
    expect(BeuiBarChart.of(context).pointerPosition, isNull);
  });

  testWidgets(
    'normalizes non-finite and negative values as gaps and stable sorts visible totals',
    (tester) async {
      late BeuiBarChartModel model;
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 600,
            child: BeuiBarChart(
              series: [
                const BeuiBarChartSeries(
                  id: 'x',
                  name: 'X',
                  color: 'red',
                  values: [3, -1, double.nan],
                ),
                const BeuiBarChartSeries(
                  id: 'y',
                  name: 'Y',
                  color: 'blue',
                  values: [2, 4, double.infinity],
                ),
              ],
              categories: _categories,
              sort: BeuiBarChartSort.descending,
              max: 10,
              child: Builder(
                builder: (context) {
                  model = BeuiBarChart.of(context);
                  return const SizedBox(height: 10);
                },
              ),
            ),
          ),
        ),
      );
      expect(model.categories, _categories);
      expect(model.rows.first.values, [3, null, null]);
      expect(model.rows.last.values, [2, 4, null]);
      expect(model.totals, [5, 4, 0]);
      expect(model.order, [0, 1, 2]);
      expect((model.domain.min, model.domain.max), (0, 10));
    },
  );

  testWidgets(
    'stacked domain and sort use only visible rows, ties retain input order',
    (tester) async {
      late BeuiBarChartModel model;
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 600,
            child: BeuiBarChart(
              series: _series,
              categories: _categories,
              layout: BeuiBarChartLayout.stacked,
              sort: BeuiBarChartSort.ascending,
              defaultHiddenSeries: const ['y'],
              child: Builder(
                builder: (context) {
                  model = BeuiBarChart.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      expect(model.order, [1, 2, 0]);
      expect(model.visibleRows.map((row) => row.id), ['x']);
      expect(model.totals, [3, 1, 2]);
      expect(model.domain.min, 0);
      expect(model.domain.max, greaterThanOrEqualTo(3));
    },
  );

  testWidgets(
    'controlled null selection stays inactive and reports changed requests only',
    (tester) async {
      final changes = <String?>[];
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 600,
            child: BeuiBarChart(
              series: _series,
              categories: _categories,
              activeId: null,
              controlledActive: true,
              onActiveChange: changes.add,
              child: const BeuiBarChartPlot(),
            ),
          ),
        ),
      );
      expect(_inspector, findsOneWidget);
      final inspector = _inspector;
      final focus = Focus.of(tester.element(inspector));
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      expect(changes, ['C']);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(changes, ['C', 'C']);
      // The controlled null does not become a locally-selected category.
      final scope = tester.element(find.byType(BeuiBarChartPlot).first);
      expect(BeuiBarChart.of(scope).activeIndex, -1);
    },
  );

  testWidgets('hidden series state is controlled until the parent updates it', (
    tester,
  ) async {
    final changes = <List<String>>[];
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 600,
          child: BeuiBarChart(
            series: _series,
            categories: _categories,
            hiddenSeries: const [],
            controlledHiddenSeries: true,
            onHiddenSeriesChange: changes.add,
          ),
        ),
      ),
    );
    final row = find.text('X');
    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pump(const Duration(milliseconds: 200));
    expect(changes, [
      const ['x'],
    ]);
    expect(
      BeuiBarChart.of(
        tester.element(find.byType(BeuiBarChartLegend)),
      ).hiddenSeries,
      isEmpty,
    );
  });

  testWidgets(
    'horizontal stacked bar keeps its end cap on the value endpoint',
    (tester) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 400,
            child: BeuiBarChart(
              series: const [
                BeuiBarChartSeries(
                  id: 'x',
                  name: 'X',
                  color: '#2563eb',
                  values: [4],
                ),
              ],
              categories: const ['A'],
              layout: BeuiBarChartLayout.stacked,
              orientation: BeuiBarChartOrientation.horizontal,
              max: 10,
              child: const BeuiBarChartPlot(height: 36),
            ),
          ),
          disableAnimations: true,
        ),
      );

      final plot = find.byType(BeuiBarChartPlot);
      final plotRect = tester.getRect(plot);
      final mark = find.byKey(const ValueKey('bar-mark-x'));
      final body = find.descendant(of: mark, matching: find.byType(ColoredBox));
      final cap = find.descendant(
        of: mark,
        matching: find.byType(DecoratedBox),
      );
      final bodyRect = tester.getRect(body.first);
      final capRect = tester.getRect(cap.first);

      expect(bodyRect.left - plotRect.left, closeTo(96, .01));
      expect(bodyRect.width, closeTo(108, .01));
      expect(capRect.left - plotRect.left, closeTo(200, .01));
      expect(capRect.width, closeTo(8, .01));
    },
  );

  testWidgets('bar value changes spring the rendered body to its new length', (
    tester,
  ) async {
    Widget chart(num value) => _app(
      SizedBox(
        width: 640,
        child: BeuiBarChart(
          series: [
            BeuiBarChartSeries(
              id: 'x',
              name: 'X',
              color: '#2563eb',
              values: [value],
            ),
          ],
          categories: const ['A'],
          layout: BeuiBarChartLayout.stacked,
          max: 10,
          child: const BeuiBarChartPlot(),
        ),
      ),
    );

    await tester.pumpWidget(chart(2));
    await tester.pumpAndSettle();
    final body = find.descendant(
      of: find.byKey(const ValueKey('bar-mark-x')),
      matching: find.byType(ColoredBox),
    );
    final start = tester.getRect(body.first).height;
    expect(start, closeTo(51.2, .1));

    await tester.pumpWidget(chart(8));
    await tester.pump(const Duration(milliseconds: 100));
    final middle = tester.getRect(body.first).height;
    expect(middle, greaterThan(start));
    expect(middle, lessThan(216.8));

    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getRect(body.first).height, closeTo(216.8, .1));
  });

  testWidgets('touch inspection opens the readout and cancellation closes it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 600,
          child: BeuiBarChart(
            series: _series,
            categories: _categories,
            child: const BeuiBarChartPlot(),
          ),
        ),
      ),
    );
    final inspector = _inspector;
    final originalInspectorState = tester.state(find.byType(BeuiXYInspector));
    final point = tester.getRect(inspector).center;
    final gesture = await tester.startGesture(
      point,
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    expect(
      tester.state(find.byType(BeuiXYInspector)),
      same(originalInspectorState),
      reason: 'Mounting the tooltip anchor must retain the input gesture state',
    );
    var model = BeuiBarChart.of(tester.element(find.byType(BeuiBarChartPlot)));
    expect(model.open, isTrue);
    expect(model.activeId, isNotNull);
    expect(model.touching, isTrue);
    await gesture.cancel();
    await tester.pump();
    model = BeuiBarChart.of(tester.element(find.byType(BeuiBarChartPlot)));
    expect(model.open, isFalse);
    expect(model.touching, isFalse);
  });

  testWidgets('category labels begin eight pixels below the plot', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 400,
          child: BeuiBarChart(
            series: _series,
            categories: _categories,
            child: const BeuiBarChartPlot(),
          ),
        ),
        disableAnimations: true,
      ),
    );
    final plot = find.byType(BeuiBarChartPlot);
    final label = find.descendant(of: plot, matching: find.text('A'));
    expect(tester.getTopLeft(label).dy - tester.getTopLeft(plot).dy, 296);
    expect(tester.getSize(plot).height, 312);
  });

  testWidgets('touch snaps inspection but category ranks retain their spring', (
    tester,
  ) async {
    late StateSetter update;
    var sort = BeuiBarChartSort.none;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return SizedBox(
              width: 400,
              child: BeuiBarChart(
                series: _series,
                categories: _categories,
                orientation: BeuiBarChartOrientation.horizontal,
                sort: sort,
                child: const BeuiBarChartPlot(height: 108),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final plot = find.byType(BeuiBarChartPlot);
    final label = find.descendant(of: plot, matching: find.text('A'));
    final start = tester.getCenter(label).dy;
    final categoryMark = find.descendant(
      of: find.byKey(const ValueKey('A')),
      matching: find.byKey(const ValueKey('bar-mark-x')),
    );
    final body = find.descendant(
      of: categoryMark,
      matching: find.byType(ColoredBox),
    );
    final bodyStart = tester.getCenter(body).dy;
    final gesture = await tester.startGesture(tester.getCenter(_inspector));
    await tester.pump();
    expect(BeuiBarChart.of(tester.element(plot)).touching, isTrue);
    update(() => sort = BeuiBarChartSort.ascending);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final mid = tester.getCenter(label).dy;
    expect(mid, greaterThan(start));
    expect(mid, lessThan(start + 36));
    expect(tester.getCenter(body).dy, greaterThan(bodyStart));
    expect(tester.getCenter(body).dy, lessThan(bodyStart + 36));
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.getCenter(label).dy, closeTo(start + 36, .01));
    expect(tester.getCenter(body).dy, closeTo(bodyStart + 36, .01));
    await gesture.cancel();
    await tester.pump();
    expect(BeuiBarChart.of(tester.element(plot)).open, isFalse);
  });

  testWidgets('tooltip content wraps and stays inside narrow viewport bounds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 160,
          child: BeuiBarChart(
            series: _series,
            categories: _categories,
            child: Column(
              children: [
                const BeuiBarChartPlot(),
                BeuiBarChartTooltip(
                  child: Text(List.filled(20, 'long').join(' ')),
                ),
              ],
            ),
          ),
        ),
        size: const Size(240, 600),
      ),
    );
    final inspector = _inspector;
    final focus = Focus.of(tester.element(inspector));
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    final panel = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          (widget.properties.identifier?.startsWith('beui-tooltip-') ?? false),
    );
    final panelRect = tester.getRect(panel);
    expect(panel, findsOneWidget);
    expect(panelRect.width, lessThanOrEqualTo(224.01));
    expect(panelRect.height, greaterThan(40));
    expect(panelRect.left, greaterThanOrEqualTo(8));
    expect(panelRect.right, lessThanOrEqualTo(232));
    expect(panelRect.top, greaterThanOrEqualTo(8));
    expect(panelRect.bottom, lessThanOrEqualTo(592));
  });

  testWidgets('disposing during the intro cancels its pending timers', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 600,
          child: BeuiBarChart(series: _series, categories: _categories),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(_app(const SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byType(BeuiBarChartPlot), findsNothing);
  });

  testWidgets(
    'actual shared panel follows scroll and transforms, clamps and disposes',
    (tester) async {
      tester.view.physicalSize = const Size(360, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      late StateSetter update;
      var offset = Offset.zero;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return SingleChildScrollView(
                  controller: scroll,
                  child: Column(
                    children: [
                      const SizedBox(height: 200),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Transform.translate(
                          offset: offset,
                          child: BeuiBarChart(
                            series: _series,
                            categories: _categories,
                            max: 10,
                            child: const Column(
                              children: [
                                BeuiBarChartPlot(height: 120),
                                BeuiBarChartTooltip(
                                  child: SizedBox(
                                    width: 120,
                                    height: 40,
                                    child: Text('Panel'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 600),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      final focus = Focus.of(tester.element(_inspector));
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      final panel = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.identifier?.startsWith('beui-tooltip-') ??
                false),
      );
      final first = tester.getRect(panel);
      expect(first.size, const Size(142, 50));
      expect(first.left, closeTo(45, .01));
      expect(first.top, closeTo(229.6, .01));

      scroll.jumpTo(80);
      await tester.pumpAndSettle();
      final scrolled = tester.getRect(panel);
      expect(scrolled.left, closeTo(45, .01));
      expect(scrolled.top, closeTo(149.6, .01));

      update(() => offset = const Offset(16, 10));
      await tester.pumpAndSettle();
      final transformed = tester.getRect(panel);
      expect(transformed.left, closeTo(61, .01));
      expect(transformed.top, closeTo(159.6, .01));

      tester.view.physicalSize = const Size(300, 500);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      final edge = tester.getRect(panel);
      expect(edge.size, const Size(142, 50));
      expect(edge.left, closeTo(150, .01));
      expect(edge.right, closeTo(292, .01));
      expect(edge.top, closeTo(170.4, .01));

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets(
    'custom parts replace defaults while table remains and horizontal plot gets 36px rows',
    (tester) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 420,
            child: BeuiBarChart(
              series: _series,
              categories: _categories,
              orientation: BeuiBarChartOrientation.horizontal,
              child: const Column(
                children: [
                  BeuiBarChartPlot(height: 130),
                  BeuiBarChartTooltip(),
                  BeuiBarChartLegend(),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(BeuiBarChartPlot)).height, 154);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.byType(BeuiBarChartTooltip), findsOneWidget);
      expect(find.text('No data'), findsNothing);
    },
  );

  testWidgets('stacked totals beyond double range clamp to the finite max', (
    tester,
  ) async {
    late BeuiBarChartModel model;
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 420,
          child: BeuiBarChart(
            layout: BeuiBarChartLayout.stacked,
            series: const [
              BeuiBarChartSeries(
                id: 'x',
                name: 'X',
                color: '#2563eb',
                values: [1e308, 1],
              ),
              BeuiBarChartSeries(
                id: 'y',
                name: 'Y',
                color: '#0d9488',
                values: [1e308, 1],
              ),
            ],
            categories: const ['A', 'B'],
            child: Builder(
              builder: (context) {
                model = BeuiBarChart.of(context);
                return const BeuiBarChartPlot();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(model.totals, [double.maxFinite, 2]);
  });

  testWidgets('empty categories keep a valid empty plot fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const SizedBox(
          width: 420,
          child: BeuiBarChart(
            series: _series,
            categories: [],
            child: BeuiBarChartPlot(),
          ),
        ),
      ),
    );
    expect(find.text('No data'), findsOneWidget);
  });
}
