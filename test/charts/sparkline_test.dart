import 'package:beui/src/charts/_xy_parts.dart' show BeuiXYFocusOutline;
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FontFeature, PointerDeviceKind;

import 'package:beui/src/charts/sparkline.dart';
import 'package:beui/src/charts/_xy.dart'
    show BeuiXYInspector, BeuiXYPointTracker;
import 'package:beui/src/charts/_shared.dart' show BeuiChartTicker;
import 'package:beui/src/motion/button/base.dart' show BeuiButton;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/sparkline_demo.dart' show sparklineDemo;
import '../support.dart';

Map<String, dynamic> get _preview =>
    jsonDecode(
          File(
            'test/fixtures/charts_xy/preview-contract.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

List<num?> _window(int offset, String id) {
  final offsets = (_preview['sparkline']['offsets'] as List).cast<Map>();
  final window = offsets.singleWhere((item) => item['offset'] == offset);
  final series = (window['series'] as List).cast<Map>();
  return (series.singleWhere((item) => item['id'] == id)['values'] as List)
      .cast<num?>();
}

Widget _sparkline(
  List<num?> values, {
  bool showDelta = false,
  bool invertDelta = false,
  bool interactive = false,
  List<String>? labels,
  bool reduce = false,
  double width = 360,
  String label = 'Metric, last 30 days',
  String Function(num value)? formatValue,
}) => beuiTestApp(
  SizedBox(
    width: width,
    child: BeuiSparkline(
      data: values,
      labels: labels,
      label: label,
      formatValue: formatValue,
      showDelta: showDelta,
      invertDelta: invertDelta,
      interactive: interactive,
      variant: BeuiSparklineVariant.area,
    ),
  ),
  reduce: reduce,
);

Finder _dotFinder() => find.byWidgetPredicate((widget) {
  if (widget is! DecoratedBox) return false;
  final decoration = widget.decoration;
  return decoration is BoxDecoration &&
      decoration.shape == BoxShape.circle &&
      decoration.color != null;
});

Offset _dotCenter(WidgetTester tester) => tester.getCenter(_dotFinder());

Finder _tickerDisplay(String value) => find.descendant(
  of: find.byType(BeuiChartTicker),
  matching: find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == value,
  ),
);

void main() {
  testWidgets('interactive extreme values stay inside a finite width', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sparkline([1e308, -1e308], interactive: true, reduce: true),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(BeuiXYInspector)).width, greaterThan(0));
  });

  testWidgets(
    'changing data length during animation tolerates empty and dense samples',
    (tester) async {
      Widget chart(List<num?> values) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: BeuiSparkline(
              data: values,
              label: 'Live trend',
              interactive: true,
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
            child: BeuiSparkline(
              data: const [1, 2],
              label: 'Trend',
              interactive: true,
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

  test(
    'frozen source preview windows have exact sample and endpoint outcomes',
    () {
      expect(_window(0, 'revenue').take(3), [39.1, 42.09, 43.24]);
      expect(_window(0, 'users')[29], 1939.45);
      expect(_window(0, 'errors')[29], 1.56);
      expect(_window(1, 'revenue').first, 42.09);
      expect(_window(1, 'users').last, 1960.36);
      expect(_window(30, 'revenue').first, 54.55);
      expect(_window(30, 'users').last, 2238.61);
      expect(_window(30, 'errors').last, 1.22);
      final terminal = (_preview['sparkline']['offsets'] as List)
          .cast<Map>()
          .singleWhere((item) => item['offset'] == 30);
      expect((terminal['labels'] as List).first, 'Oct 1');
      expect(
        (terminal['series'] as List).every(
          (item) => (item['values'] as List).length == 30,
        ),
        isTrue,
      );
      expect((_preview['sparkline']['interactive']['height'] as num), 48);
      expect((_preview['sparkline']['interactive']['strokeWidth'] as num), 2);
    },
  );

  testWidgets('finite extreme delta avoids intermediate subtraction overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sparkline([1e308, -1e308], showDelta: true, reduce: true),
    );
    expect(find.text('−200.0%'), findsOneWidget);
  });

  testWidgets('opposite finite extremes keep finite endpoint geometry', (
    tester,
  ) async {
    await tester.pumpWidget(_sparkline([1e308, -1e308], reduce: true));
    expect(tester.takeException(), isNull);
    expect(_dotCenter(tester).dy.isFinite, isTrue);
  });

  testWidgets('summary uses first and last finite samples and preserves gaps', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sparkline([null, 100, double.nan, 125, double.infinity]),
    );
    expect(
      find.bySemanticsLabel('Metric, last 30 days, from 100 to 125, up 25.0%'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'delta uses absolute negative first value and source flat threshold',
    (tester) async {
      await tester.pumpWidget(_sparkline([-10, -8], showDelta: true));
      expect(find.text('+20.0%'), findsOneWidget);
      await tester.pumpWidget(_sparkline([-10, -10.004], showDelta: true));
      expect(find.text('0.0%'), findsOneWidget);
      await tester.pumpWidget(_sparkline([0, 8], showDelta: true));
      expect(find.textContaining('%'), findsNothing);
    },
  );

  testWidgets('invertDelta colors a falling value as good; rise is bad', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sparkline([10, 8], showDelta: true, invertDelta: true),
    );
    final falling = tester.widget<Text>(find.text('−20.0%'));
    expect(falling.style!.color, const Color(0xFF009966));
    final fallingBadge = tester.widget<Container>(
      find
          .ancestor(of: find.text('−20.0%'), matching: find.byType(Container))
          .first,
    );
    expect(
      (fallingBadge.decoration! as BoxDecoration).color!.toARGB32(),
      0x1A00BC7D,
    );
    await tester.pumpWidget(
      _sparkline([8, 10], showDelta: true, invertDelta: true),
    );
    final rising = tester.widget<Text>(find.text('+25.0%'));
    expect(rising.style!.color, const Color(0xFFEC003F));
    final risingBadge = tester.widget<Container>(
      find
          .ancestor(of: find.text('+25.0%'), matching: find.byType(Container))
          .first,
    );
    expect(
      (risingBadge.decoration! as BoxDecoration).color!.toARGB32(),
      0x1AFF2056,
    );
  });

  testWidgets('delta palette follows Tailwind 4 tokens in both themes', (
    tester,
  ) async {
    await tester.pumpWidget(_sparkline([10, 8], showDelta: true));
    expect(
      tester.widget<Text>(find.text('−20.0%')).style!.color,
      const Color(0xFFEC003F),
    );
    await tester.pumpWidget(
      beuiTestApp(
        SizedBox(
          width: 360,
          child: const BeuiSparkline(
            data: [10, 8],
            label: 'Metric, last 30 days',
            showDelta: true,
          ),
        ),
        dark: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.widget<Text>(find.text('−20.0%')).style!.color,
      const Color(0xFFFF637E),
    );
    await tester.pumpWidget(
      beuiTestApp(
        SizedBox(
          width: 360,
          child: const BeuiSparkline(
            data: [8, 10],
            label: 'Metric, last 30 days',
            showDelta: true,
          ),
        ),
        dark: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.widget<Text>(find.text('+25.0%')).style!.color,
      const Color(0xFF00D492),
    );
    final darkEmeraldBadge = tester.widget<Container>(
      find
          .ancestor(of: find.text('+25.0%'), matching: find.byType(Container))
          .first,
    );
    expect(
      (darkEmeraldBadge.decoration! as BoxDecoration).color!.toARGB32(),
      0x1A00BC7D,
    );
  });

  testWidgets('empty input exposes no percent and a concise no-data summary', (
    tester,
  ) async {
    await tester.pumpWidget(_sparkline([null, double.nan], showDelta: true));
    expect(
      find.bySemanticsLabel('Metric, last 30 days, no data'),
      findsOneWidget,
    );
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('default labels use Sample N and a selected gap says no data', (
    tester,
  ) async {
    await tester.pumpWidget(_sparkline([10, 20, null], interactive: true));
    final slider = tester.getSemantics(
      find.bySemanticsLabel('Metric, last 30 days: inspect samples'),
    );
    expect(slider.getSemanticsData().value, 'Sample 3: no data');
  });

  testWidgets('one sample is centered and its area has no filled run', (
    tester,
  ) async {
    await tester.pumpWidget(_sparkline([7]));
    final plot = tester.getRect(
      find.bySemanticsLabel('Metric, last 30 days, from 7 to 7'),
    );
    final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
    expect(plot.width, 360);
    expect(paints, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('interactive inspector exposes one named sample slider', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sparkline(
        [10, 20, null, 40],
        interactive: true,
        labels: const ['Sep 1', 'Sep 2', 'Sep 3', 'Sep 4'],
      ),
    );
    expect(
      find.bySemanticsLabel('Metric, last 30 days: inspect samples'),
      findsOneWidget,
    );
    expect(find.byType(BeuiXYPointTracker), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(
      tester
          .getSemantics(
            find.bySemanticsLabel('Metric, last 30 days: inspect samples'),
          )
          .getSemanticsData()
          .hasAction(SemanticsAction.decrease),
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('End inspects the last present value and Escape closes readout', (
    tester,
  ) async {
    await tester.pumpWidget(_sparkline([10, 20, null, 40], interactive: true));
    final slider = find.bySemanticsLabel(
      'Metric, last 30 days: inspect samples',
    );
    await tester.tap(slider);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(_tickerDisplay('40'), findsOneWidget);
    expect(find.text('Sample 4'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Sample 4'), findsNothing);
    // Escape closes the inline label but leaves the final sample selected.
    expect(_tickerDisplay('40'), findsOneWidget);
  });

  testWidgets('interactive readout keeps max-content value and date width', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sparkline(
        [10, 20],
        interactive: true,
        labels: const ['Start', 'November 05, fiscal close'],
        formatValue: (_) => 'USD 123456789.00',
      ),
    );
    final plot = tester.getRect(find.byType(BeuiXYInspector));
    await tester.tapAt(Offset(plot.right - 1, plot.center.dy));
    await tester.pump();

    final semantics = tester.ensureSemantics();
    expect(find.text('November 05, fiscal close'), findsOneWidget);
    expect(tester.getSize(find.byType(BeuiChartTicker)).width, greaterThan(64));
    expect(tester.getSize(find.byType(BeuiXYInspector)).width, lessThan(288));
    expect(
      tester
          .getSemantics(
            find.bySemanticsLabel('Metric, last 30 days: inspect samples'),
          )
          .getSemanticsData()
          .value,
      'November 05, fiscal close: USD 123456789.00',
    );
    expect(find.bySemanticsLabel('November 05, fiscal close'), findsNothing);
    final ticker = tester.widget<BeuiChartTicker>(find.byType(BeuiChartTicker));
    expect(ticker.format(ticker.value), 'USD 123456789.00');
    expect(
      ticker.style,
      const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        height: 1.25,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
    semantics.dispose();
  });

  testWidgets(
    'source preview users select Sep 17, Home, End, and Escape values',
    (tester) async {
      final labels = (_preview['sparkline']['offsets'] as List)
          .cast<Map>()
          .firstWhere((item) => item['offset'] == 1)['labels']
          .cast<String>();
      String format(num value) => value.round().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );
      await tester.pumpWidget(
        _sparkline(
          _window(1, 'users'),
          interactive: true,
          labels: labels,
          formatValue: format,
        ),
      );
      final plot = tester.getRect(find.byType(BeuiXYInspector));
      await tester.tapAt(
        Offset(plot.left + plot.width * (15 / 29), plot.center.dy),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      expect(_tickerDisplay('1,876'), findsOneWidget);
      expect(find.text('Sep 17'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump(const Duration(milliseconds: 220));
      expect(_tickerDisplay('1,719'), findsOneWidget);
      expect(find.text('Sep 2'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump(const Duration(milliseconds: 220));
      expect(_tickerDisplay('1,960'), findsOneWidget);
      expect(find.text('Oct 1'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_tickerDisplay('1,960'), findsOneWidget);
      expect(find.text('Oct 1'), findsNothing);
    },
  );

  testWidgets('reduced motion snaps the rendered dot to the new endpoint', (
    tester,
  ) async {
    await tester.pumpWidget(_sparkline([10, 20, 30], reduce: true));
    await tester.pumpWidget(_sparkline([30, 20, 10], reduce: true));
    await tester.pump();
    final plot = tester.getRect(
      find.bySemanticsLabel('Metric, last 30 days, from 30 to 10, down 66.7%'),
    );
    expect(_dotCenter(tester), Offset(plot.left + 357, plot.top + 29));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard selection springs the rendered dot and settles', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sparkline([0, 10, 20], interactive: true, width: 360),
    );
    final plot = tester.getRect(find.byType(BeuiXYInspector));
    final initial = _dotCenter(tester);
    await tester.tapAt(Offset(plot.left + plot.width * .98, plot.center.dy));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final middle = _dotCenter(tester);
    expect(middle.dx, greaterThan(plot.left + 3));
    expect(middle.dx, lessThan(initial.dx));
    expect(middle.dy, greaterThan(plot.top + 3));
    expect(middle.dy, lessThan(plot.top + 29));
    await tester.pump(const Duration(milliseconds: 900));
    expect(_dotCenter(tester).dx, closeTo(plot.left + 3, .001));
    expect(_dotCenter(tester).dy, closeTo(plot.top + 29, .001));
  });

  testWidgets(
    'touch inspection selects gaps and keeps the latest visual value',
    (tester) async {
      await tester.pumpWidget(
        _sparkline([10, 20, null, 40], interactive: true),
      );
      final plot = tester.getRect(find.byType(BeuiXYInspector));
      final gesture = await tester.startGesture(
        Offset(plot.left + plot.width / 2, plot.center.dy),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();
      final semantics = tester.getSemantics(
        find.bySemanticsLabel('Metric, last 30 days: inspect samples'),
      );
      expect(semantics.getSemanticsData().value, 'Sample 3: no data');
      expect(_tickerDisplay('40'), findsOneWidget);
      await gesture.up();
      await tester.pump();
      expect(semantics.getSemanticsData().value, 'Sample 3: no data');
      expect(_tickerDisplay('40'), findsOneWidget);
    },
  );

  testWidgets('touch selection snaps the rendered dot to the finger sample', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sparkline([0, 10, 20, 30], interactive: true, width: 360),
    );
    final plot = tester.getRect(find.byType(BeuiXYInspector));
    final gesture = await tester.startGesture(
      Offset(plot.left + plot.width / 3, plot.center.dy),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    final settledPlot = tester.getRect(find.byType(BeuiXYInspector));
    expect(
      _dotCenter(tester).dx,
      closeTo(settledPlot.left + 3 + (settledPlot.width - 6) / 3, .001),
    );
    expect(
      _dotCenter(tester).dy,
      closeTo(settledPlot.top + 20.333333333333332, .001),
    );
    await gesture.up();
    await tester.pump();
    expect(
      _dotCenter(tester).dx,
      closeTo(settledPlot.left + 3 + (settledPlot.width - 6) / 3, .001),
    );
    expect(
      _dotCenter(tester).dy,
      closeTo(settledPlot.top + 20.333333333333332, .001),
    );
  });

  testWidgets('data morph and resize move the rendered dot, then dispose', (
    tester,
  ) async {
    await tester.pumpWidget(_sparkline([0, 10, 5, 4]));
    final tracker = tester.state(find.byType(BeuiXYPointTracker));
    final beforeDataChange = _dotCenter(tester);
    await tester.pumpWidget(_sparkline([0, 20, 5, 4]));
    expect(tester.state(find.byType(BeuiXYPointTracker)), same(tracker));
    await tester.pump(const Duration(milliseconds: 80));
    final dataMiddle = _dotCenter(tester);
    expect(dataMiddle.dy, greaterThan(beforeDataChange.dy));
    final dataPlot = tester.getRect(
      find.bySemanticsLabel('Metric, last 30 days, from 0 to 4'),
    );
    await tester.pump(const Duration(milliseconds: 900));
    final dataEnd = _dotCenter(tester);
    expect(dataEnd.dx, dataPlot.left + 357);
    expect(dataEnd.dy, closeTo(dataPlot.top + 23.8, .001));
    await tester.pumpWidget(_sparkline([0, 20, 5, 4], width: 220));
    expect(tester.state(find.byType(BeuiXYPointTracker)), same(tracker));
    await tester.pump(const Duration(milliseconds: 80));
    expect(_dotCenter(tester).dx, greaterThan(dataEnd.dx - 140));
    expect(_dotCenter(tester).dx, lessThan(dataEnd.dx));
    await tester.pump(const Duration(milliseconds: 900));
    final resizedPlot = tester.getRect(
      find.bySemanticsLabel('Metric, last 30 days, from 0 to 4'),
    );
    expect(_dotCenter(tester).dx, closeTo(resizedPlot.left + 217, .001));
    expect(_dotCenter(tester).dy, closeTo(resizedPlot.top + 23.8, .001));
    await tester.pumpWidget(_sparkline([null, null, null]));
    expect(_dotFinder(), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(beuiTestApp(const SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(BeuiXYPointTracker), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview Add sample disables at terminal offset 30', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(Builder(builder: sparklineDemo), width: 800),
    );
    final add = find.text('Add sample');
    for (var offset = 0; offset < 30; offset++) {
      await tester.tap(add);
      await tester.pump();
    }
    final button = tester.widget<BeuiButton>(
      find.ancestor(of: add, matching: find.byType(BeuiButton)),
    );
    expect(button.onPressed, isNull);
  });
}
