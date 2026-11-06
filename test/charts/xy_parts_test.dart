import 'dart:io';
import 'dart:ui' show PointerDeviceKind, SemanticsRole, Tristate;

import 'package:beui/src/charts/_shared.dart'
    show BeuiChartTicker, beuiChartFormatNumber;
import 'package:beui/src/charts/_xy.dart';
import 'package:beui/src/charts/_xy_parts.dart';
import 'package:beui/src/theme/beui_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('XY axis controllers use the motion-engine facade', () {
    final source = File('lib/src/charts/_xy_parts.dart').readAsStringSync();
    expect(source, isNot(contains('AnimationController(')));
    expect(source, contains('SingleMotionController('));
  });

  group('BeuiXYAxisLayer', () {
    Widget axis({
      required List<double> ticks,
      required double Function(double) position,
      bool reduceMotion = false,
    }) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 100,
          child: BeuiXYAxisLayer(
            ticks: ticks,
            position: position,
            axis: Axis.vertical,
            from: 24,
            to: 192,
            labelOffset: 32,
            format: (value) => value.toStringAsFixed(0),
            reduceMotion: reduceMotion,
          ),
        ),
      ),
    );

    double labelOpacity(WidgetTester tester, String label) {
      final opacity = tester.widget<Opacity>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Opacity))
            .first,
      );
      return opacity.opacity;
    }

    testWidgets('initial ticks are visible and replacements fade in and out', (
      tester,
    ) async {
      await tester.pumpWidget(
        axis(ticks: [1, 2], position: (tick) => tick * 10),
      );
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(labelOpacity(tester, '1'), 1);

      await tester.pumpWidget(
        axis(ticks: [1, 3], position: (tick) => tick * 10),
      );
      expect(find.text('2'), findsOneWidget);
      expect(labelOpacity(tester, '3'), 0);
      await tester.pump(const Duration(milliseconds: 80));
      expect(labelOpacity(tester, '3'), greaterThan(0));
      expect(labelOpacity(tester, '3'), lessThan(1));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('2'), findsNothing);
      expect(labelOpacity(tester, '3'), 1);
    });

    testWidgets('reduced motion snaps a retained tick to its new position', (
      tester,
    ) async {
      await tester.pumpWidget(axis(ticks: [1], position: (_) => 10));
      await tester.pumpWidget(
        axis(ticks: [1], position: (_) => 40, reduceMotion: true),
      );
      final label = tester.widget<Positioned>(
        find
            .ancestor(of: find.text('1'), matching: find.byType(Positioned))
            .first,
      );
      expect(label.top, 40);
    });

    testWidgets('retained ticks spring toward rescaled positions', (
      tester,
    ) async {
      await tester.pumpWidget(axis(ticks: [1], position: (_) => 10));
      await tester.pumpWidget(axis(ticks: [1], position: (_) => 50));
      expect(_axisLabelTop(tester), 10);
      await tester.pump(const Duration(milliseconds: 60));
      expect(_axisLabelTop(tester), greaterThan(10));
      expect(_axisLabelTop(tester), lessThan(50));
      await tester.pumpAndSettle();
      expect(_axisLabelTop(tester), closeTo(50, .001));
    });

    testWidgets('a tick restored during its exit keeps its keyed state', (
      tester,
    ) async {
      await tester.pumpWidget(axis(ticks: [1], position: (_) => 10));
      await tester.pumpWidget(axis(ticks: [], position: (_) => 10));
      await tester.pump(const Duration(milliseconds: 40));
      final exitingOpacity = labelOpacity(tester, '1');
      expect(exitingOpacity, greaterThan(0));
      expect(exitingOpacity, lessThan(1));

      await tester.pumpWidget(axis(ticks: [1], position: (_) => 60));
      expect(find.text('1'), findsOneWidget);
      expect(labelOpacity(tester, '1'), lessThan(1));
      await tester.pumpAndSettle();
      expect(labelOpacity(tester, '1'), 1);
      expect(_axisLabelTop(tester), closeTo(60, .001));
    });

    testWidgets(
      'horizontal axis positions labels by x and draws vertical grid',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 100,
                child: BeuiXYAxisLayer(
                  ticks: const [0, 2],
                  position: (tick) => tick * 40 + 20,
                  axis: Axis.horizontal,
                  from: 12,
                  to: 90,
                  labelOffset: 72,
                  format: (value) => 'x${value.toStringAsFixed(0)}',
                ),
              ),
            ),
          ),
        );
        final xLabel = tester.widget<Positioned>(
          find
              .ancestor(of: find.text('x2'), matching: find.byType(Positioned))
              .first,
        );
        expect(xLabel.left, 100);
        expect(xLabel.top, 72);
        final grid = tester.widget<Positioned>(
          find
              .descendant(
                of: find.byType(BeuiXYAxisLayer),
                matching: find.byType(Positioned),
              )
              .first,
        );
        expect(grid.left, 19.5);
        final gridBox = find.descendant(
          of: find.byType(BeuiXYAxisLayer),
          matching: find.byType(ColoredBox),
        );
        expect(tester.getRect(gridBox.first).center.dx, 20);
        expect(tester.getRect(gridBox.last).center.dx, 100);
        expect(grid.width, 1);
        expect(grid.top, 12);
        expect(grid.bottom, 10);
        final lineAlphas = tester
            .widgetList<ColoredBox>(
              find.descendant(
                of: find.byType(BeuiXYAxisLayer),
                matching: find.byType(ColoredBox),
              ),
            )
            .map((line) => line.color.a)
            .toSet();
        expect(lineAlphas, {0.3, 0.12});
      },
    );
  });

  testWidgets('legend toggles by keyboard and reports focus hover', (
    tester,
  ) async {
    final rows = [
      BeuiXYRow(id: 'alpha', name: 'Alpha', color: '#336699', values: [1]),
      BeuiXYRow(id: 'beta', name: 'Beta', color: '#663399', values: [2]),
    ];
    final hidden = <String>[];
    final hoverEvents = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => BeuiXYLegend(
              rows: rows,
              hidden: hidden,
              onToggle: (id) => setState(() {
                if (hidden.contains(id)) {
                  hidden.remove(id);
                } else {
                  hidden.add(id);
                }
              }),
              onHover: hoverEvents.add,
              canHover: true,
              label: 'Series',
            ),
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Alpha')));
    await tester.pump();
    expect(hoverEvents.last, 'alpha');
    await mouse.removePointer();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(hoverEvents, contains('alpha'));
    final semantics = tester.ensureSemantics();
    final legendSemantics = tester.getSemantics(
      find.ancestor(
        of: find.text('Alpha'),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == 'Alpha',
        ),
      ),
    );
    expect(legendSemantics.label, 'Alpha');
    expect(legendSemantics.flagsCollection.isButton, isTrue);
    expect(legendSemantics.flagsCollection.isToggled, Tristate.isTrue);
    final outline = find
        .ancestor(
          of: find.text('Alpha'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint && widget.foregroundPainter != null,
          ),
        )
        .first;
    final outlineSize = tester.getSize(outline);
    expect(
      outline,
      paints..rrect(
        rrect: RRect.fromRectAndRadius(
          Rect.fromLTWH(-3, -3, outlineSize.width + 6, outlineSize.height + 6),
          const Radius.circular(9),
        ),
        style: PaintingStyle.stroke,
        strokeWidth: 2,
      ),
    );
    semantics.dispose();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 150));
    expect(hidden, ['alpha']);
    expect(hoverEvents.last, 'alpha');
    expect(
      tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .first
          .opacity,
      .5,
    );
    final swatch = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer).first,
    );
    expect(swatch.constraints, BoxConstraints.tightFor(width: 10, height: 10));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(hoverEvents, containsAllInOrder([null, 'beta']));
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('touch toggles a legend item without hover activation', (
    tester,
  ) async {
    final hidden = <String>[];
    final hoverEvents = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => BeuiXYLegend(
              rows: [
                BeuiXYRow(
                  id: 'touch',
                  name: 'Touch',
                  color: 'red',
                  values: [1],
                ),
              ],
              hidden: hidden,
              onToggle: (id) => setState(() => hidden.add(id)),
              onHover: hoverEvents.add,
              canHover: true,
              label: 'Series',
            ),
          ),
        ),
      ),
    );

    final touch = await tester.createGesture(kind: PointerDeviceKind.touch);
    await touch.down(tester.getCenter(find.text('Touch')));
    await touch.up();
    await tester.pump(const Duration(milliseconds: 150));
    expect(hidden, ['touch']);
    expect(hoverEvents.whereType<String>(), isEmpty);
  });

  testWidgets('hidden legend rows never become hover targets and blur clears', (
    tester,
  ) async {
    final hoverEvents = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BeuiXYLegend(
            rows: [
              BeuiXYRow(
                id: 'hidden',
                name: 'Hidden',
                color: 'red',
                values: [1],
              ),
            ],
            hidden: const ['hidden'],
            onToggle: (_) {},
            onHover: hoverEvents.add,
            canHover: true,
            label: 'Series',
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Hidden')));
    await tester.pump();
    expect(hoverEvents, isNot(contains('hidden')));
    await mouse.removePointer();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(hoverEvents, isNot(contains('hidden')));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(hoverEvents.last, isNull);
  });

  testWidgets('legend spacing defaults to four and accepts line spacing', (
    tester,
  ) async {
    Widget legend({double? spacing}) {
      final rows = [
        BeuiXYRow(id: 'a', name: 'A', color: 'red', values: [1]),
        BeuiXYRow(id: 'b', name: 'B', color: 'blue', values: [2]),
      ];
      final child = spacing == null
          ? BeuiXYLegend(
              rows: rows,
              hidden: const [],
              onToggle: (_) {},
              onHover: (_) {},
              canHover: false,
              label: 'Series',
            )
          : BeuiXYLegend(
              rows: rows,
              hidden: const [],
              onToggle: (_) {},
              onHover: (_) {},
              canHover: false,
              label: 'Series',
              spacing: spacing,
            );
      return MaterialApp(home: Scaffold(body: child));
    }

    await tester.pumpWidget(legend());
    expect(tester.widget<Wrap>(find.byType(Wrap)).spacing, 4);
    expect(tester.widget<Wrap>(find.byType(Wrap)).runSpacing, 4);
    Rect itemRect(String label) => tester.getRect(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(GestureDetector),
      ),
    );
    expect(itemRect('B').left - itemRect('A').right, 4);

    await tester.pumpWidget(legend(spacing: 16));
    expect(tester.widget<Wrap>(find.byType(Wrap)).spacing, 16);
    expect(tester.widget<Wrap>(find.byType(Wrap)).runSpacing, 4);
    expect(itemRect('B').left - itemRect('A').right, 16);
  });

  testWidgets('data table exposes every category, row, value, and data gap', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BeuiXYDataTable(
            label: 'Quarterly sales',
            categories: const ['Q1', 'Q2', 'Q3'],
            rows: [
              BeuiXYRow(
                id: 'a',
                name: 'North',
                color: 'red',
                values: [1.25, null, 3],
              ),
              BeuiXYRow(id: 'b', name: 'South', color: 'blue', values: [4, 5]),
            ],
            formatValue: (value) => '\$${value.toStringAsFixed(2)}',
          ),
        ),
      ),
    );

    final table = tester.getSemantics(
      find.bySemanticsLabel('Quarterly sales data'),
    );
    expect(table.role, SemanticsRole.table);
    expect(find.bySemanticsLabel('North'), findsOneWidget);
    expect(find.bySemanticsLabel('South'), findsOneWidget);
    expect(find.bySemanticsLabel('Q1'), findsOneWidget);
    expect(find.bySemanticsLabel('Q2'), findsOneWidget);
    expect(find.bySemanticsLabel('Q3'), findsOneWidget);
    expect(find.bySemanticsLabel('\$1.25'), findsOneWidget);
    expect(find.bySemanticsLabel('No data'), findsNWidgets(2));
    expect(find.bySemanticsLabel('\$5.00'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Q1')).role,
      SemanticsRole.columnHeader,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('\$1.25')).role,
      SemanticsRole.cell,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('\$1.25'))
          .flagsCollection
          .isFocused,
      Tristate.none,
    );
    semantics.dispose();
  });

  testWidgets(
    'tooltip preserves fractional formatting, compact width, and total',
    (tester) async {
      Widget tooltip({required bool compact}) => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: BeuiXYTooltipContent(
              title: 'May',
              compact: compact,
              rows: const [
                BeuiXYTooltipRow(
                  id: 'revenue',
                  name: 'Revenue',
                  color: '#369',
                  value: 1.25,
                ),
                BeuiXYTooltipRow(
                  id: 'cost',
                  name: 'Cost',
                  color: '#936',
                  value: null,
                ),
              ],
              total: 2.5,
              formatValue: (value) => '${value.toStringAsFixed(2)} USD',
            ),
          ),
        ),
      );

      await tester.pumpWidget(tooltip(compact: false));
      expect(tester.getSize(find.byType(BeuiXYTooltipContent)).width, 224);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('No data'), findsOneWidget);
      expect(find.byType(BeuiChartTicker), findsNWidgets(2));
      final ticker = tester.widget<BeuiChartTicker>(
        find.byType(BeuiChartTicker).first,
      );
      expect(ticker.format(1.25), '1.25 USD');
      final totalTicker = tester.widget<BeuiChartTicker>(
        find.byType(BeuiChartTicker).last,
      );
      expect(totalTicker.format(2.5), '2.50 USD');
      await tester.pump(const Duration(milliseconds: 220));
      expect(_tickerDisplay('1.25 USD'), findsOneWidget);
      expect(_tickerDisplay('2.50 USD'), findsOneWidget);

      await tester.pumpWidget(tooltip(compact: true));
      final compactWidth = tester
          .getSize(find.byType(BeuiXYTooltipContent))
          .width;
      expect(compactWidth, greaterThanOrEqualTo(144));
      expect(compactWidth, lessThan(224));
    },
  );

  testWidgets('tooltip contains extreme finite values and totals', (
    tester,
  ) async {
    for (final compact in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              child: Align(
                alignment: Alignment.topLeft,
                child: BeuiXYTooltipContent(
                  title: 'Extreme',
                  compact: compact,
                  rows: const [
                    BeuiXYTooltipRow(
                      id: 'x',
                      name: 'Value',
                      color: '#369',
                      value: 1e308,
                    ),
                  ],
                  total: 1e308,
                  formatValue: (value) =>
                      beuiChartFormatNumber(value, maximumFractionDigits: 2),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        _tickerDisplay(beuiChartFormatNumber(1e308, maximumFractionDigits: 2)),
        findsNWidgets(2),
      );
    }
  });

  testWidgets('compact tooltip fits long content at source minimum width', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final entry in {
        'XY Test Geist': 'Geist-Regular.ttf',
        'monospace': 'GeistMono-Regular.ttf',
      }.entries) {
        await (FontLoader(entry.key)..addFont(
              File(
                'example/assets/fonts/${entry.value}',
              ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            ))
            .load();
      }
    });
    Widget compact(double width) => MaterialApp(
      theme: ThemeData(fontFamily: 'XY Test Geist'),
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: Align(
            alignment: Alignment.topLeft,
            child: BeuiXYTooltipContent(
              title: 'A very long category heading that must wrap naturally',
              compact: true,
              rows: const [
                BeuiXYTooltipRow(
                  id: 'long',
                  name:
                      'A very long series label that should ellipsize cleanly',
                  color: '#336699',
                  value: 123456789.25,
                ),
              ],
              formatValue: (value) => '${value.toStringAsFixed(2)} USD',
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(compact(180));
    expect(tester.getSize(find.byType(BeuiXYTooltipContent)).width, 180);
    await tester.pumpWidget(compact(144));
    expect(tester.getSize(find.byType(BeuiXYTooltipContent)).width, 144);
    expect(tester.takeException(), isNull);
  });

  group('BeuiXYFocusOutline', () {
    Finder outlinePainter() => find.descendant(
      of: find.byType(BeuiXYFocusOutline),
      matching: find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.foregroundPainter != null,
      ),
    );

    testWidgets('adds no focus stop and preserves size and activation', (
      tester,
    ) async {
      Future<(Size, List<bool>, int)> traverse({required bool wrapped}) async {
        var activations = 0;
        Widget buttons = SizedBox(
          key: const ValueKey('group'),
          width: 240,
          height: 40,
          child: Row(
            children: [
              TextButton(
                key: const ValueKey('first'),
                onPressed: () => activations++,
                child: const Text('First'),
              ),
              TextButton(
                key: const ValueKey('second'),
                onPressed: () => activations++,
                child: const Text('Second'),
              ),
            ],
          ),
        );
        if (wrapped) buttons = BeuiXYFocusOutline(child: buttons);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buttons,
                  TextButton(
                    key: const ValueKey('outside'),
                    onPressed: () {},
                    child: const Text('Outside'),
                  ),
                ],
              ),
            ),
          ),
        );

        final size = tester.getSize(find.byKey(const ValueKey('group')));
        final stops = <bool>[];
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        stops.add(Focus.of(tester.element(find.text('First'))).hasPrimaryFocus);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        stops.add(
          Focus.of(tester.element(find.text('Second'))).hasPrimaryFocus,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        stops.add(
          Focus.of(tester.element(find.text('Outside'))).hasPrimaryFocus,
        );
        return (size, stops, activations);
      }

      final plain = await traverse(wrapped: false);
      final wrapped = await traverse(wrapped: true);
      expect(wrapped.$1, plain.$1);
      expect(wrapped.$2, plain.$2);
      expect(wrapped.$3, plain.$3);
      expect(plain.$2, [true, true, true]);
      expect(plain.$3, 2);
    });

    testWidgets('paints the themed ring at offsets four and two', (
      tester,
    ) async {
      final focusStrategy = FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      const ring = Color(0xFF12AB34);
      final colors = BeuiColors.light().copyWith(ring: ring);
      try {
        for (final offset in [4.0, 2.0]) {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(extensions: [colors]),
              home: Scaffold(
                body: BeuiXYFocusOutline(
                  offset: offset,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Focus me'),
                  ),
                ),
              ),
            ),
          );
          expect(outlinePainter(), findsNothing);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();

          final childSize = tester.getSize(
            find.descendant(
              of: find.byType(BeuiXYFocusOutline),
              matching: find.byType(TextButton),
            ),
          );
          final expansion = offset + 1;
          expect(
            outlinePainter(),
            paints..rrect(
              rrect: RRect.fromRectAndRadius(
                (Offset.zero & childSize).inflate(expansion),
                Radius.circular(4 + expansion),
              ),
              color: ring,
              style: PaintingStyle.stroke,
              strokeWidth: 2,
            ),
          );
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        FocusManager.instance.highlightStrategy = focusStrategy;
      }
    });

    testWidgets('touch and highlight-mode changes suppress a focused ring', (
      tester,
    ) async {
      final focusStrategy = FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BeuiXYFocusOutline(
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Focus me'),
                ),
              ),
            ),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(outlinePainter(), findsOneWidget);

        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTouch;
        await tester.pump();
        expect(outlinePainter(), findsNothing);
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        await tester.pump();
        expect(outlinePainter(), findsOneWidget);

        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic;
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(outlinePainter(), findsOneWidget);
        final touch = await tester.createGesture(kind: PointerDeviceKind.touch);
        await touch.down(tester.getCenter(find.text('Focus me')));
        await touch.up();
        await tester.pump();
        expect(outlinePainter(), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        FocusManager.instance.highlightStrategy = focusStrategy;
      }
    });

    testWidgets('keyboard then mouse then Tab follows focus-visible modality', (
      tester,
    ) async {
      final strategy = FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  BeuiXYFocusOutline(
                    child: Row(
                      children: [
                        for (final label in ['First', 'Second'])
                          SizedBox(
                            width: 120,
                            height: 40,
                            child: BeuiXYInspector(
                              count: 2,
                              activeIndex: 0,
                              onActiveIndexChanged: (_) {},
                              label: label,
                              valueText: (index) => '$index',
                              child: Text(label),
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton(onPressed: () {}, child: const Text('Outside')),
                ],
              ),
            ),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          Focus.of(tester.element(find.text('First'))).hasPrimaryFocus,
          isTrue,
        );
        expect(outlinePainter(), findsOneWidget);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: tester.getCenter(find.text('Second')));
        await mouse.down(tester.getCenter(find.text('Second')));
        await mouse.up();
        await tester.pump();
        expect(
          Focus.of(tester.element(find.text('Second'))).hasPrimaryFocus,
          isTrue,
        );
        expect(outlinePainter(), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          Focus.of(tester.element(find.text('Outside'))).hasPrimaryFocus,
          isTrue,
        );
        expect(outlinePainter(), findsNothing);
        await tester.sendKeyEvent(
          LogicalKeyboardKey.tab,
          physicalKey: PhysicalKeyboardKey.tab,
        );
        await tester.pump();
        expect(
          Focus.of(tester.element(find.text('First'))).hasPrimaryFocus,
          isTrue,
        );
        expect(outlinePainter(), findsOneWidget);
        await mouse.removePointer();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        FocusManager.instance.highlightStrategy = strategy;
      }
    });

    testWidgets(
      'mouse focus from unfocused stays hidden until a handled keyboard key',
      (tester) async {
        final strategy = FocusManager.instance.highlightStrategy;
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic;
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: BeuiXYFocusOutline(
                  child: SizedBox(
                    width: 120,
                    height: 40,
                    child: BeuiXYInspector(
                      count: 2,
                      activeIndex: 0,
                      onActiveIndexChanged: (_) {},
                      label: 'Mouse target',
                      valueText: (index) => '$index',
                      child: const Text('Mouse target'),
                    ),
                  ),
                ),
              ),
            ),
          );

          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          final target = tester.getCenter(find.text('Mouse target'));
          await mouse.addPointer(location: target);
          await mouse.down(target);
          await mouse.up();
          await tester.pump();
          expect(
            Focus.of(tester.element(find.text('Mouse target'))).hasPrimaryFocus,
            isTrue,
          );
          expect(outlinePainter(), findsNothing);

          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pump();
          expect(outlinePainter(), findsOneWidget);
          await mouse.removePointer();
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          FocusManager.instance.highlightStrategy = strategy;
        }
      },
    );

    testWidgets(
      'clears on focus exit, disabled descendants, replacement, and disposal',
      (tester) async {
        final focusStrategy = FocusManager.instance.highlightStrategy;
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        try {
          Widget host({required Widget child}) => MaterialApp(
            home: Scaffold(
              body: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BeuiXYFocusOutline(child: child),
                  TextButton(
                    key: const ValueKey('outside'),
                    onPressed: () {},
                    child: const Text('Outside'),
                  ),
                ],
              ),
            ),
          );

          await tester.pumpWidget(
            host(
              child: TextButton(
                key: const ValueKey('inside'),
                onPressed: () {},
                child: const Text('Inside'),
              ),
            ),
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(outlinePainter(), findsOneWidget);

          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(outlinePainter(), findsNothing);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            host(
              child: Focus(
                canRequestFocus: false,
                descendantsAreFocusable: false,
                child: TextButton(
                  key: const ValueKey('disabled'),
                  onPressed: () {},
                  child: const Text('Disabled'),
                ),
              ),
            ),
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(
            Focus.of(tester.element(find.text('Outside'))).hasPrimaryFocus,
            isTrue,
          );
          expect(outlinePainter(), findsNothing);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            host(
              child: TextButton(
                key: const ValueKey('replace-me'),
                onPressed: () {},
                child: const Text('Replace me'),
              ),
            ),
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(outlinePainter(), findsOneWidget);
          await tester.pumpWidget(
            host(child: const SizedBox(key: ValueKey('replacement'))),
          );
          await tester.pump();
          expect(outlinePainter(), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
          FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.alwaysTouch;
          await tester.pump();
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          FocusManager.instance.highlightStrategy = focusStrategy;
        }
      },
    );
  });
}

double _axisLabelTop(WidgetTester tester) => tester
    .widget<Positioned>(
      find
          .ancestor(of: find.text('1'), matching: find.byType(Positioned))
          .first,
    )
    .top!;

Finder _tickerDisplay(String value) => find.descendant(
  of: find.byType(BeuiChartTicker),
  matching: find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == value,
  ),
);
