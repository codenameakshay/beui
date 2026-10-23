import 'dart:ui' as ui;

import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

const _segments = [
  BeuiDonutSegment(id: 'team', label: 'Team', value: 42, color: '#2563eb'),
  BeuiDonutSegment(
    id: 'business',
    label: 'Business',
    value: 31,
    color: '#38bdf8',
  ),
  BeuiDonutSegment(
    id: 'enterprise',
    label: 'Enterprise',
    value: 23,
    color: '#0d9488',
  ),
];

void main() {
  testWidgets(
    'center keeps full-size intrinsic digits outside its caption cap',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          BeuiDonutChart(
            segments: const [
              BeuiDonutSegment(id: 'team', label: 'Team', value: 42900),
              BeuiDonutSegment(id: 'business', label: 'Business', value: 31250),
              BeuiDonutSegment(
                id: 'enterprise',
                label: 'Enterprise',
                value: 22600,
              ),
              BeuiDonutSegment(id: 'starter', label: 'Starter', value: 18400),
            ],
            formatValue: (value) => '\$${beuiChartFormatNumber(value)}',
            child: const SizedBox(
              width: 240,
              height: 240,
              child: BeuiDonutPlot(child: BeuiDonutCenter()),
            ),
          ),
          fontFamily: 'Ahem',
          reduce: true,
        ),
      );
      await tester.pumpAndSettle();
      final center = tester.getRect(find.byType(BeuiDonutCenter));
      final digits = tester.getRect(find.byType(BeuiDigitSwap));
      final plot = tester.getRect(find.byType(BeuiDonutPlot));
      expect(center.width, closeTo(134.4, .001));
      expect(digits.width, greaterThan(center.width));
      expect(digits.center.dx, closeTo(plot.center.dx, .001));
      expect(digits.left, greaterThan(plot.left));
      expect(digits.right, lessThan(plot.right));
      final swap = tester.widget<BeuiDigitSwap>(find.byType(BeuiDigitSwap));
      expect(swap.value, '\$115,150');
      expect(swap.style!.fontSize, 24);
      expect(find.byType(FittedBox), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'source legend rows are 48px with inset four-pixel share tracks',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(const BeuiDonutChart(segments: _segments), reduce: true),
      );
      await tester.pumpAndSettle();
      final team = find.byKey(const ValueKey('donut-legend-team'));
      final business = find.byKey(const ValueKey('donut-legend-business'));
      final row = tester.getRect(team);
      expect(row.height, 48);
      expect(tester.getRect(business).top - row.bottom, 4);
      expect(tester.widget<Text>(find.text('Team')).style!.fontSize, 14);
      final swatch = find.descendant(
        of: team,
        matching: find.byType(BeuiChartSwatch),
      );
      expect(tester.getSize(swatch), const Size(10, 10));
      final track = find
          .descendant(
            of: team,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Container && widget.constraints?.maxHeight == 4,
            ),
          )
          .first;
      expect(tester.getRect(track).left - row.left, 34);
      expect(tester.getSize(track).height, 4);
      expect(
        tester.getSize(find.byType(BeuiDonutCenter)).width,
        closeTo(143.36, .001),
      );
    },
  );

  testWidgets('round caps leave the source gap open at twelve oclock', (
    tester,
  ) async {
    const key = ValueKey('ring-caps');
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiDonutChart(
          segments: _segments,
          child: RepaintBoundary(
            key: key,
            child: SizedBox(width: 200, height: 200, child: BeuiDonutPlot()),
          ),
        ),
        reduce: true,
      ),
    );
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      expect(
        bytes.getUint8((19 * image.width + 100) * 4 + 3),
        inInclusiveRange(152, 154),
      );
      image.dispose();
    });
  });
  testWidgets('renders ring, center total and legend', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiDonutChart(segments: _segments, label: 'Revenue by plan'),
      ),
    );
    await tester.pump();
    expect(find.byType(BeuiDonutPlot), findsOneWidget);
    expect(find.byType(BeuiDonutLegend), findsOneWidget);
    expect(
      tester.widget<BeuiDigitSwap>(find.byType(BeuiDigitSwap)).value,
      '96',
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Revenue by plan',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('supports controlled and uncontrolled active ids and selection', (
    tester,
  ) async {
    String? changed;
    String? selected;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiDonutChart(
          segments: _segments,
          defaultActiveId: 'team',
          onActiveChange: (id) => changed = id,
          onSelect: (id) => selected = id,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    final centerTicker = find.descendant(
      of: find.byType(BeuiDonutCenter),
      matching: find.byType(BeuiDigitSwap),
    );
    expect(tester.widget<BeuiDigitSwap>(centerTicker).value, '42');
    expect(
      find.descendant(
        of: find.byType(BeuiDonutCenter),
        matching: find.text('Team · 43.8%'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Business'));
    await tester.pump();
    expect(tester.widget<BeuiDigitSwap>(centerTicker).value, '31');
    expect(changed, 'business');
    expect(selected, 'business');
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiDonutChart(segments: _segments, activeId: 'enterprise'),
      ),
    );
    await tester.pump();
    expect(tester.widget<BeuiDigitSwap>(centerTicker).value, '23');
    expect(
      find.descendant(
        of: find.byType(BeuiDonutCenter),
        matching: find.text('Enterprise · 24.0%'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'native legend Up and Down wrap actual focus and Tab visits each row once',
    (tester) async {
      String? changed;
      await tester.pumpWidget(
        beuiTestApp(
          BeuiDonutChart(
            segments: _segments,
            onActiveChange: (id) => changed = id,
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(changed, 'team');
      FocusNode focus(String id) => tester
          .widget<TextButton>(find.byKey(ValueKey('donut-legend-$id')))
          .focusNode!;
      expect(focus('team').hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(focus('team').hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(changed, 'enterprise');
      expect(focus('enterprise').hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(changed, 'team');
      expect(focus('team').hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(changed, 'business');
      expect(focus('business').hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(changed, 'business');
    },
  );

  testWidgets('hovering legend rows updates the center ticker and caption', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beuiTestApp(const BeuiDonutChart(segments: _segments)),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final team = tester.getCenter(find.text('Team'));
    await mouse.addPointer(location: team);
    await mouse.moveTo(team);
    await tester.pump();
    expect(find.byType(BeuiDigitSwap), findsOneWidget);
    final centerTicker = find.descendant(
      of: find.byType(BeuiDonutCenter),
      matching: find.byType(BeuiDigitSwap),
    );
    expect(tester.widget<BeuiDigitSwap>(centerTicker).value, '42');
    expect(
      tester.widget<BeuiDigitSwap>(centerTicker).direction,
      BeuiDigitSwapDirection.down,
    );
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('Team · 43.8%'), findsOneWidget);

    final business = tester.getCenter(find.text('Business'));
    await mouse.moveTo(business);
    await tester.pump();
    expect(tester.widget<BeuiDigitSwap>(centerTicker).value, '31');
    expect(
      tester.widget<BeuiDigitSwap>(centerTicker).direction,
      BeuiDigitSwapDirection.down,
    );
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('Business · 32.3%'), findsOneWidget);
    await mouse.moveTo(team);
    await tester.pump();
    expect(tester.widget<BeuiDigitSwap>(centerTicker).value, '42');
    expect(
      tester.widget<BeuiDigitSwap>(centerTicker).direction,
      BeuiDigitSwapDirection.up,
    );
    await mouse.removePointer();
    semantics.dispose();
  });

  testWidgets('outgoing center caption exits upward without jumping', (
    tester,
  ) async {
    const chartKey = ValueKey('donut');
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiDonutChart(
          key: chartKey,
          segments: _segments,
          activeId: 'team',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 220));
    final outgoingCaption = find.text('Team · 43.8%');
    final originalPosition = tester.getTopLeft(outgoingCaption);

    await tester.pumpWidget(
      beuiTestApp(
        const BeuiDonutChart(
          key: chartKey,
          segments: _segments,
          activeId: 'business',
        ),
      ),
    );
    final startPosition = tester.getTopLeft(outgoingCaption);
    expect(startPosition.dy, closeTo(originalPosition.dy, 1));

    await tester.pump(const Duration(milliseconds: 110));
    final middlePosition = tester.getTopLeft(outgoingCaption);
    expect(middlePosition.dy, lessThan(startPosition.dy));
    final fading = find
        .ancestor(of: outgoingCaption, matching: find.byType(FadeTransition))
        .first;
    expect(
      tester.widget<FadeTransition>(fading).opacity.value,
      inExclusiveRange(0, 1),
    );

    await tester.pump(const Duration(milliseconds: 111));
    expect(outgoingCaption, findsNothing);
  });

  testWidgets('reduced motion snaps center ticker to active value', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiDonutChart(segments: _segments, activeId: 'team'),
        reduce: true,
      ),
    );
    await tester.pump();
    final centerTicker = find.descendant(
      of: find.byType(BeuiDonutCenter),
      matching: find.byType(BeuiDigitSwap),
    );
    expect(tester.widget<BeuiDigitSwap>(centerTicker).value, '42');
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('Team · 43.8%'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('reduced motion keeps the ring in its final state', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiDonutChart(segments: _segments), reduce: true),
    );
    await tester.pump();
    expect(
      tester.widget<BeuiDigitSwap>(find.byType(BeuiDigitSwap)).value,
      '96',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(640, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      beuiTestApp(
        const RepaintBoundary(
          child: BeuiDonutChart(segments: _segments, label: 'Donut chart'),
        ),
        width: 640,
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(BeuiDonutChart),
      matchesGoldenFile('goldens/beui_donut-chart.png'),
    );
  });
}
