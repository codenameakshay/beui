import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _history = [
  BeuiPriceHistoryPoint(date: '2025-09-14', price: 158.4),
  BeuiPriceHistoryPoint(date: '2025-10-14', price: 164.2),
  BeuiPriceHistoryPoint(date: '2025-11-14', price: 160.8),
];
const _targets = [
  BeuiPriceTarget(key: 'High', price: 232, analysts: 9),
  BeuiPriceTarget(key: 'Mean', price: 205, analysts: 34),
  BeuiPriceTarget(key: 'Low', price: 168, analysts: 6),
];

Future<void> _pumpChart(
  WidgetTester tester,
  BeuiPriceTargetFan chart, {
  bool reduce = false,
}) async {
  tester.view.physicalSize = const Size(800, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(beuiTestApp(chart, reduce: reduce, width: 640));
  await tester.pumpAndSettle();
}

BeuiPriceTargetFan _chart({
  BeuiPriceTargetFanActive? active,
  BeuiPriceTargetFanActive? defaultActive,
  ValueChanged<BeuiPriceTargetFanActive?>? onActiveChange,
}) => BeuiPriceTargetFan(
  current: 178.52,
  targets: _targets,
  history: _history,
  dates: const BeuiPriceTargetDates(horizon: 'Sep 2027'),
  active: active,
  defaultActive: defaultActive,
  onActiveChange: onActiveChange,
);

void main() {
  testWidgets('renders accessible plot, history, and target buttons', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpChart(tester, _chart());
    expect(find.bySemanticsLabel(RegExp('Price target fan')), findsWidgets);
    expect(find.text('232'), findsOneWidget);
    expect(find.text('205'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('High target 232')), findsWidgets);
    semantics.dispose();
  });

  testWidgets('header prices and percentage use animated tickers', (
    tester,
  ) async {
    await _pumpChart(tester, _chart());
    expect(find.byType(BeuiNumberTicker), findsNWidgets(2));
    final tickers = tester.widgetList<BeuiNumberTicker>(
      find.byType(BeuiNumberTicker),
    );
    expect(
      tickers.map((ticker) => ticker.duration),
      everyElement(const Duration(milliseconds: 500)),
    );
    expect(tickers.map((ticker) => ticker.prefix), contains(r'$'));
    expect(tickers.map((ticker) => ticker.suffix), contains('%'));
    expect(tickers.first.value, 20500);
    expect(find.text('Mean target'), findsOneWidget);
  });

  testWidgets('history points sit left of the plot midpoint', (tester) async {
    await _pumpChart(tester, _chart());
    final plot = tester.getRect(find.byType(BeuiPriceTargetPlot));
    final last = tester.getCenter(
      find.byKey(const ValueKey('price-target-history-2025-11-14')),
    );
    expect(last.dx, lessThan(plot.left + plot.width * 0.62));
  });

  testWidgets('plot width cap remains inside Center', (tester) async {
    await _pumpChart(tester, _chart());
    final cappedPlot = find.descendant(
      of: find.byType(BeuiPriceTargetPlot),
      matching: find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 520,
      ),
    );
    expect(cappedPlot, findsOneWidget);
    expect(
      find.ancestor(of: cappedPlot, matching: find.byType(Center)),
      findsOneWidget,
    );
  });

  testWidgets('current guide repaints when current changes in a boundary', (
    tester,
  ) async {
    var current = 178.52;
    var paints = 0;
    late StateSetter update;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeuiPriceTargetFan(
              current: current,
              targets: _targets,
              history: _history,
              child: _PaintObserver(
                onPaint: () => paints++,
                child: const BeuiPriceTargetNow(),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = paints;
    update(() => current = 188);
    await tester.pump();
    expect(paints, greaterThan(before));
  });

  testWidgets('axes repaint when current changes the price domain', (
    tester,
  ) async {
    var current = 178.52;
    var paints = 0;
    late StateSetter update;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeuiPriceTargetFan(
              current: current,
              targets: _targets,
              history: _history,
              child: _PaintObserver(
                onPaint: () => paints++,
                child: const BeuiPriceTargetAxes(),
              ),
            );
          },
        ),
      ),
    );
    final before = paints;
    update(() => current = 250);
    await tester.pump();
    expect(paints, greaterThan(before));
  });

  testWidgets('history path repaints when history changes in a boundary', (
    tester,
  ) async {
    var history = _history;
    var paints = 0;
    late StateSetter update;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeuiPriceTargetFan(
              current: 178.52,
              targets: _targets,
              history: history,
              child: _PaintObserver(
                onPaint: () => paints++,
                child: const BeuiPriceTargetHistory(),
              ),
            );
          },
        ),
      ),
    );
    final before = paints;
    update(
      () => history = [
        ..._history.take(2),
        const BeuiPriceHistoryPoint(date: '2025-11-14', price: 185),
      ],
    );
    await tester.pump();
    expect(paints, greaterThan(before));
  });

  testWidgets('target paths repaint their origin when current changes', (
    tester,
  ) async {
    var current = 178.52;
    var paints = 0;
    late StateSetter update;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeuiPriceTargetFan(
              current: current,
              targets: _targets,
              history: _history,
              child: _PaintObserver(
                onPaint: () => paints++,
                child: const BeuiPriceTargetTargets(),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    double originY() {
      final canvas = TestRecordingCanvas();
      final paint = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(BeuiPriceTargetTargets),
              matching: find.byType(CustomPaint),
            ),
          )
          .first;
      paint.painter!.paint(canvas, const Size(520, 236));
      final path =
          canvas.invocations
                  .firstWhere((call) => call.invocation.memberName == #drawPath)
                  .invocation
                  .positionalArguments
                  .first
              as Path;
      return path.computeMetrics().first.getTangentForOffset(0)!.position.dy;
    }

    expect(originY(), closeTo(150.85093, .001));
    update(() => current = 188);
    await tester.pump();
    expect(originY(), closeTo(128.77019, .001));
  });

  testWidgets('history points can be inspected by hover and keyboard', (
    tester,
  ) async {
    await _pumpChart(tester, _chart());
    final point = find.byKey(const ValueKey('price-target-history-2025-10-14'));
    await tester.ensureVisible(point);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(point));
    await tester.tap(point);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('Tue, Oct 14'), findsWidgets);
    expect(find.text('Price'), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(find.text('Sun, Sep 14'), findsWidgets);
  });

  testWidgets('dragging from a history point selects the last history date', (
    tester,
  ) async {
    BeuiPriceTargetFanActive? changed;
    await _pumpChart(
      tester,
      _chart(onActiveChange: (value) => changed = value),
    );
    final first = tester.getCenter(
      find.byKey(const ValueKey('price-target-history-2025-09-14')),
    );
    final last = tester.getCenter(
      find.byKey(const ValueKey('price-target-history-2025-11-14')),
    );
    await tester.dragFrom(first, last - first);
    await tester.pump();

    expect(changed, const BeuiPriceTargetFanActive.history('2025-11-14'));
  });

  testWidgets('target hover exit restores the mean header', (tester) async {
    await _pumpChart(tester, _chart());
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    final high = find.byKey(const ValueKey('price-target-target-High'));
    await mouse.moveTo(tester.getCenter(high));
    await tester.pump();
    expect(find.text('High target'), findsWidgets);

    await mouse.moveTo(const Offset(790, 630));
    await tester.pump();
    expect(find.text('Mean target'), findsOneWidget);
  });

  testWidgets('history hover exit clears active history', (tester) async {
    BeuiPriceTargetFanActive? changed;
    await _pumpChart(
      tester,
      _chart(onActiveChange: (value) => changed = value),
    );
    final point = find.byKey(const ValueKey('price-target-history-2025-11-14'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(point));
    await tester.pump();
    expect(changed, const BeuiPriceTargetFanActive.history('2025-11-14'));

    await mouse.moveTo(const Offset(790, 630));
    await tester.pump();
    expect(changed, isNull);
  });

  testWidgets('history focus blur clears active history', (tester) async {
    BeuiPriceTargetFanActive? changed;
    await _pumpChart(
      tester,
      _chart(onActiveChange: (value) => changed = value),
    );
    final focus =
        tester.state(find.byKey(const ValueKey('price-target-history-slider')))
            as dynamic;
    focus.focusNode.requestFocus();
    await tester.pump();
    expect(changed, const BeuiPriceTargetFanActive.history('2025-11-14'));

    focus.focusNode.unfocus();
    await tester.pump();
    expect(changed, isNull);
  });

  testWidgets('axis painter repaints when theme changes on the same chart', (
    tester,
  ) async {
    var dark = false;
    var paints = 0;
    late StateSetter update;
    final chart = BeuiPriceTargetFan(
      current: 178.52,
      targets: _targets,
      history: _history,
      child: _PaintObserver(
        onPaint: () => paints++,
        child: const BeuiPriceTargetAxes(),
      ),
    );
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          final brightness = dark ? Brightness.dark : Brightness.light;
          return MaterialApp(
            theme: ThemeData(
              brightness: brightness,
              extensions: [
                BeuiColors.of(BeuiColorTheme.defaultMono, brightness),
              ],
            ),
            home: Scaffold(body: chart),
          );
        },
      ),
    );
    final before = paints;
    update(() => dark = true);
    await tester.pumpAndSettle();
    expect(paints, greaterThan(before));
  });

  testWidgets('target buttons report the selected projection', (tester) async {
    BeuiPriceTargetFanActive? changed;
    await _pumpChart(
      tester,
      _chart(onActiveChange: (value) => changed = value),
    );
    await tester.tap(find.byKey(const ValueKey('price-target-target-High')));
    await tester.pump();
    expect(changed, const BeuiPriceTargetFanActive.target('High'));
  });

  testWidgets('arrow keys step the uncontrolled active date', (tester) async {
    BeuiPriceTargetFanActive? changed;
    await _pumpChart(
      tester,
      _chart(
        defaultActive: const BeuiPriceTargetFanActive.history('2025-09-14'),
        onActiveChange: (value) => changed = value,
      ),
    );
    expect(find.text('Sun, Sep 14'), findsWidgets);
    await tester.tap(
      find.byKey(const ValueKey('price-target-history-2025-09-14')),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changed, const BeuiPriceTargetFanActive.history('2025-10-14'));
    expect(find.text('Tue, Oct 14'), findsWidgets);
  });

  testWidgets('keyboard inspector selects an endpoint and Escape clears', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpChart(tester, _chart());
    await tester.tap(find.byKey(const ValueKey('price-target-target-Mean')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(
      tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.selected == true),
      isEmpty,
    );
    semantics.dispose();
  });

  testWidgets(
    'rejects repeated or nonpositive targets and unsorted ISO history',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          BeuiPriceTargetFan(
            current: 10,
            targets: const [
              BeuiPriceTarget(key: 'H', price: 20),
              BeuiPriceTarget(key: 'M', price: 20),
              BeuiPriceTarget(key: 'L', price: -2),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isArgumentError);
      await tester.pumpWidget(
        beuiTestApp(
          BeuiPriceTargetFan(
            current: 10,
            targets: const [
              BeuiPriceTarget(key: 'H', price: 20),
              BeuiPriceTarget(key: 'M', price: 15),
              BeuiPriceTarget(key: 'L', price: 5),
            ],
            history: const [
              BeuiPriceHistoryPoint(date: '2025-02-01', price: 8),
              BeuiPriceHistoryPoint(date: '2025-01-01', price: 9),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isArgumentError);
    },
  );

  testWidgets('rejects a nonpositive or non-finite current price', (
    tester,
  ) async {
    for (final current in [0.0, -1.0, double.nan, double.infinity]) {
      await tester.pumpWidget(
        beuiTestApp(
          BeuiPriceTargetFan(
            current: current,
            targets: _targets,
            history: _history,
          ),
        ),
      );
      expect(tester.takeException(), isArgumentError);
    }
  });

  testWidgets('reduced-motion rest state matches golden', (tester) async {
    await _pumpChart(tester, _chart(), reduce: true);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(BeuiPriceTargetFan),
      matchesGoldenFile('goldens/beui_price_target_fan.png'),
    );
  });
}

class _PaintObserver extends SingleChildRenderObjectWidget {
  const _PaintObserver({required this.onPaint, required super.child});

  final VoidCallback onPaint;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _ObservedRepaintBoundary(onPaint);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _ObservedRepaintBoundary renderObject,
  ) {
    renderObject.onPaint = onPaint;
  }
}

class _ObservedRepaintBoundary extends RenderProxyBox {
  _ObservedRepaintBoundary(this.onPaint);

  VoidCallback onPaint;

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    onPaint();
    super.paint(context, offset);
  }
}
