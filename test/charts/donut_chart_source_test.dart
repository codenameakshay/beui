import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderDecoratedBox, RenderOpacity;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _segments = [
  BeuiDonutSegment(id: 'team', name: 'Team', value: 50, color: '#2563eb'),
  BeuiDonutSegment(
    id: 'business',
    name: 'Business',
    value: 30,
    color: '#38bdf8',
  ),
  BeuiDonutSegment(
    id: 'starter',
    label: 'Starter',
    value: 20,
    color: '#0d9488',
  ),
];

Widget _chart({
  String? activeId,
  bool controlActiveId = false,
  String? defaultActiveId,
  String? selectedId,
  ValueChanged<String?>? onActiveChange,
  ValueChanged<String>? onSelect,
  BeuiDonutCenterBuilder? centerBuilder,
  String totalLabel = 'Total',
  Widget? totalCaption,
  BeuiDonutLegendBuilder? renderDetail,
  BeuiDonutLegendBuilder? renderValue,
  List<BeuiDonutSegment> segments = _segments,
  String Function(double)? formatValue,
  bool reduce = true,
  Widget? afterLegend,
}) => beuiTestApp(
  SizedBox(
    width: 480,
    child: BeuiDonutChart(
      segments: segments,
      activeId: activeId,
      controlActiveId: controlActiveId,
      defaultActiveId: defaultActiveId,
      selectedId: selectedId,
      onActiveChange: onActiveChange,
      onSelect: onSelect,
      formatValue: formatValue,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 240,
            height: 240,
            child: BeuiDonutPlot(
              child: BeuiDonutCenter(
                totalLabel: totalLabel,
                builder: centerBuilder,
                totalCaption: totalCaption,
              ),
            ),
          ),
          BeuiDonutLegend(renderDetail: renderDetail, renderValue: renderValue),
          ?afterLegend,
        ],
      ),
    ),
  ),
  reduce: reduce,
  width: 520,
);

Offset _point(double degrees, double radius) {
  final radians = degrees * math.pi / 180;
  return Offset(
    100 + radius * math.sin(radians),
    100 - radius * math.cos(radians),
  );
}

void main() {
  group('BeuiDonutGeometry', () {
    test(
      'uses source cap inset and source paint order at overlapping caps',
      () {
        final geometry = BeuiDonutGeometry.build(const [
          BeuiDonutSegment(id: 'first', name: 'First', value: 1),
          BeuiDonutSegment(id: 'second', name: 'Second', value: 1),
        ]);

        expect(geometry.radius, 81);
        expect(geometry.placed.first.startDegrees, closeTo(9.2809, .001));
        expect(geometry.placed.first.endDegrees, closeTo(170.7191, .001));
        expect(geometry.hitTest(_point(90, 81)), 'first');
        expect(geometry.hitTest(_point(0, 81)), 'second');

        final defaultSegments = BeuiDonutGeometry.build(_segments);
        expect(defaultSegments.hitTest(_point(180, 81)), 'business');
      },
    );

    test(
      'uses the enlarged stroke at radial edges but leaves a wide gap open',
      () {
        final defaultGap = BeuiDonutGeometry.build(const [
          BeuiDonutSegment(id: 'first', label: 'First', value: 1),
          BeuiDonutSegment(id: 'second', label: 'Second', value: 1),
        ]);
        expect(defaultGap.hitTest(_point(90, 95.99)), 'first');
        expect(defaultGap.hitTest(_point(90, 96.01)), isNull);

        final wideGap = BeuiDonutGeometry.build(const [
          BeuiDonutSegment(id: 'first', label: 'First', value: 1),
          BeuiDonutSegment(id: 'second', label: 'Second', value: 1),
        ], gap: 40);
        expect(wideGap.hitTest(_point(0, 81)), isNull);
      },
    );

    test('keeps a single segment as a full ring and clamps tiny arcs', () {
      final single = BeuiDonutGeometry.build(const [
        BeuiDonutSegment(id: 'only', label: 'Only', value: 1),
      ]);
      expect(single.placed.single.single, isTrue);
      expect(single.hitTest(_point(180, 81)), 'only');

      final tiny = BeuiDonutGeometry.build(const [
        BeuiDonutSegment(id: 'tiny', label: 'Tiny', value: 1),
        BeuiDonutSegment(id: 'rest', label: 'Rest', value: 100000),
      ]);
      expect(
        tiny.placed.first.endDegrees - tiny.placed.first.startDegrees,
        closeTo(.01, .000001),
      );
    });

    test('placed centerline path is typed and defensive', () {
      final geometry = BeuiDonutGeometry.build(const [
        BeuiDonutSegment(id: 'first', name: 'First', value: 1),
        BeuiDonutSegment(id: 'second', name: 'Second', value: 1),
      ]);
      final placed = geometry.placed.first;
      final original = placed.path;
      expect(original.computeMetrics().single.length, greaterThan(0));
      original.reset();
      expect(placed.path.computeMetrics().single.length, greaterThan(0));
      expect(geometry.hitTest(_point(90, 81)), 'first');
    });

    test('drops invalid data and geometry without creating invalid arcs', () {
      final invalidData = BeuiDonutGeometry.build([
        const BeuiDonutSegment(id: 'zero', label: 'Zero', value: 0),
        const BeuiDonutSegment(id: 'negative', label: 'Negative', value: -2),
        BeuiDonutSegment(id: 'nan', label: 'NaN', value: double.nan),
        BeuiDonutSegment(
          id: 'infinity',
          label: 'Infinity',
          value: double.infinity,
        ),
      ]);
      expect(invalidData.total, 0);
      expect(invalidData.placed, isEmpty);

      final invalidRadius = BeuiDonutGeometry.build(const [
        BeuiDonutSegment(id: 'one', label: 'One', value: 1),
      ], thickness: 200);
      expect(invalidRadius.placed, isEmpty);
      expect(invalidRadius.hitTest(const Offset(181, 100)), isNull);
    });
  });

  group('BeuiDonutChart source behavior', () {
    testWidgets(
      'ring hover and touch never select while hover changes active',
      (tester) async {
        final selections = <String>[];
        final active = <String?>[];
        await tester.pumpWidget(
          _chart(
            selectedId: 'business',
            onSelect: selections.add,
            onActiveChange: active.add,
          ),
        );
        await tester.pump();

        final plot = tester.getRect(find.byType(BeuiDonutPlot));
        final ringPoint = Offset(plot.center.dx + 97.2, plot.center.dy);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(ringPoint);
        await tester.pump();
        expect(active.last, 'team');
        await tester.tapAt(ringPoint);
        await tester.pump();
        expect(selections, isEmpty);
        expect(active.last, 'team');
        final businessRow = tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.byKey(const ValueKey('donut-legend-business')),
            matching: find.byType(AnimatedContainer),
          ),
        );
        expect(
          (businessRow.decoration! as BoxDecoration).boxShadow,
          hasLength(1),
        );
        await mouse.removePointer();
      },
    );

    testWidgets('hover callbacks follow static hit ownership transitions', (
      tester,
    ) async {
      final active = <String?>[];
      await tester.pumpWidget(_chart(onActiveChange: active.add));
      await tester.pump();
      final plot = tester.getRect(find.byType(BeuiDonutPlot));
      Offset at(double degrees) =>
          Offset(plot.center.dx, plot.center.dy) +
          (_point(degrees, 97.2) - const Offset(100, 100));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(at(90));
      await tester.pump();
      expect(active, ['team']);
      await mouse.moveTo(at(100));
      await tester.pump();
      expect(active, ['team']);

      await mouse.moveTo(at(240));
      await tester.pump();
      expect(active, ['team', null, 'business']);
      await mouse.moveTo(at(180));
      await tester.pump();
      expect(active, ['team', null, 'business']);
      await mouse.moveTo(plot.center);
      await tester.pump();
      expect(active, ['team', null, 'business', null]);
      await mouse.moveTo(at(90));
      await tester.pump();
      expect(
        tester.getRect(find.byType(BeuiDonutChart)).contains(Offset.zero),
        isFalse,
      );
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(active, ['team', null, 'business', null, 'team', null]);
      await mouse.removePointer();
    });

    testWidgets('controlled null overrides the default active segment', (
      tester,
    ) async {
      await tester.pumpWidget(
        _chart(controlActiveId: true, activeId: null, defaultActiveId: 'team'),
      );
      await tester.pump();
      final readout = tester.widget<BeuiDigitSwap>(find.byType(BeuiDigitSwap));
      expect(readout.value, '100');
      expect(find.text('Team · 50.0%'), findsNothing);
    });

    testWidgets('focus-visible ring uses rendered paint and local input mode', (
      tester,
    ) async {
      final outside = FocusNode();
      addTearDown(outside.dispose);
      await tester.pumpWidget(
        _chart(
          afterLegend: TextButton(
            focusNode: outside,
            onPressed: () {},
            child: const Text('Outside legend'),
          ),
        ),
      );
      await tester.pump();
      RenderDecoratedBox rowPaint(String id) =>
          tester.renderObject<RenderDecoratedBox>(
            find
                .descendant(
                  of: find.byKey(ValueKey('donut-legend-$id')),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
      BoxShadow? focusShadow(String id) =>
          (rowPaint(id).decoration as BoxDecoration).boxShadow?.firstOrNull;

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 75));
      expect(focusShadow('team')!.spreadRadius, closeTo(1, .02));
      await tester.pump(const Duration(milliseconds: 75));
      final keyboardRing = focusShadow('team')!;
      expect(keyboardRing.spreadRadius, 2);
      expect(keyboardRing.blurRadius, 0);
      expect(keyboardRing.offset, Offset.zero);
      expect(keyboardRing.color, const Color(0x1F0B0B0B));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      final business = tester.getRect(
        find.byKey(const ValueKey('donut-legend-business')),
      );
      await mouse.moveTo(business.center);
      await mouse.down(business.center);
      await mouse.up();
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 150));
      expect(focusShadow('team'), isNull);
      expect(focusShadow('business'), isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 150));
      expect(focusShadow('business'), isNull);
      expect(focusShadow('starter')!.spreadRadius, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 150));
      expect(focusShadow('starter'), isNull);
      expect(focusShadow('business')!.spreadRadius, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump(Duration.zero);
      expect(FocusManager.instance.primaryFocus, same(outside));
      await tester.pump(const Duration(milliseconds: 150));
      expect(focusShadow('team'), isNull);
      expect(focusShadow('business'), isNull);
      expect(focusShadow('starter'), isNull);
      await mouse.removePointer();
    });

    testWidgets('uncontrolled default active resolves to the named segment', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(defaultActiveId: 'team'));
      await tester.pump();
      final readout = tester.widget<BeuiDigitSwap>(find.byType(BeuiDigitSwap));
      expect(readout.value, '50');
      expect(find.text('Team · 50.0%'), findsOneWidget);
    });

    testWidgets('removed and invalid segments do not stay active or render', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(defaultActiveId: 'team'));
      await tester.pump();
      await tester.pumpWidget(
        _chart(
          defaultActiveId: 'team',
          segments: const [
            BeuiDonutSegment(id: 'bad', label: 'Bad', value: -4),
            BeuiDonutSegment(id: 'business', label: 'Business', value: 30),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Team'), findsNothing);
      expect(find.text('Bad'), findsNothing);
      expect(
        tester.widget<BeuiDigitSwap>(find.byType(BeuiDigitSwap)).value,
        '30',
      );
    });

    testWidgets('replaces removed rows and disposes chart focus state', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(defaultActiveId: 'team'));
      await tester.pump();
      await tester.pumpWidget(
        _chart(
          segments: const [
            BeuiDonutSegment(id: 'replacement', name: 'Replacement', value: 7),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Replacement'), findsOneWidget);
      expect(find.byKey(const ValueKey('donut-legend-team')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    testWidgets('legend activation calls the latest callback once', (
      tester,
    ) async {
      final oldCalls = <String>[];
      final latestCalls = <String>[];
      await tester.pumpWidget(_chart(onSelect: oldCalls.add));
      await tester.pump();
      await tester.pumpWidget(_chart(onSelect: latestCalls.add));
      await tester.tap(find.byKey(const ValueKey('donut-legend-team')));
      await tester.pump();
      expect(oldCalls, isEmpty);
      expect(latestCalls, ['team']);
    });

    testWidgets('arrow navigation wraps and Space and Enter activate once', (
      tester,
    ) async {
      final selected = <String>[];
      await tester.pumpWidget(_chart(onSelect: selected.add));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final teamButton = tester.widget<FocusableActionDetector>(
        find.byKey(const ValueKey('donut-legend-team')),
      );
      expect(teamButton.focusNode!.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(
        tester
            .widget<FocusableActionDetector>(
              find.byKey(const ValueKey('donut-legend-starter')),
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        tester
            .widget<FocusableActionDetector>(
              find.byKey(const ValueKey('donut-legend-team')),
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      expect(selected, isEmpty);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      expect(selected, isEmpty);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(selected, ['starter']);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      expect(selected, ['starter', 'starter']);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      expect(selected, ['starter', 'starter']);
    });

    testWidgets('Space arm clears on focus loss and row replacement', (
      tester,
    ) async {
      final selected = <String>[];
      await tester.pumpWidget(_chart(onSelect: selected.add));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(selected, isEmpty);

      tester
          .widget<FocusableActionDetector>(
            find.byKey(const ValueKey('donut-legend-business')),
          )
          .focusNode!
          .requestFocus();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pumpWidget(
        _chart(
          onSelect: selected.add,
          segments: const [
            BeuiDonutSegment(id: 'replacement', name: 'Replacement', value: 1),
          ],
        ),
      );
      await tester.pumpWidget(
        _chart(
          onSelect: selected.add,
          segments: const [
            BeuiDonutSegment(id: 'business', name: 'Business', value: 1),
          ],
        ),
      );
      final replacement = tester.widget<FocusableActionDetector>(
        find.byKey(const ValueKey('donut-legend-business')),
      );
      replacement.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(selected, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantic button activation invokes selection', (tester) async {
      final selected = <String>[];
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_chart(onSelect: selected.add));
      await tester.pump();
      final node = tester.getSemantics(
        find.byKey(const ValueKey('donut-legend-team')),
      );
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pump();
      expect(selected, ['team']);
      semantics.dispose();
    });

    testWidgets(
      'pointer exit clears readout but retains legend keyboard focus',
      (tester) async {
        final active = <String?>[];
        await tester.pumpWidget(_chart(onActiveChange: active.add));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final team = tester.getRect(
          find.byKey(const ValueKey('donut-legend-team')),
        );
        final teamButton = tester.widget<FocusableActionDetector>(
          find.byKey(const ValueKey('donut-legend-team')),
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(team.center);
        await tester.pump();
        expect(active.last, 'team');
        await mouse.moveTo(Offset(team.right + 2, team.center.dy));
        await tester.pump();
        expect(active.last, isNull);
        expect(teamButton.focusNode!.hasFocus, isTrue);
        await mouse.removePointer();
      },
    );

    testWidgets('center and legend renderer callbacks receive segment data', (
      tester,
    ) async {
      await tester.pumpWidget(
        _chart(
          defaultActiveId: 'team',
          centerBuilder: (context, segment, total) =>
              Text('${segment?.name}:${segment?.share}:$total'),
          renderValue: (context, segment) => Text('value:${segment.name}'),
          renderDetail: (context, segment) => Text('detail:${segment.name}'),
        ),
      );
      await tester.pump();
      expect(find.text('Team:0.5:100.0'), findsOneWidget);
      expect(find.text('value:Team'), findsOneWidget);
      expect(find.text('detail:Team'), findsOneWidget);
    });

    testWidgets('default formatter keeps three fractional digits when needed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _chart(
          segments: const [
            BeuiDonutSegment(id: 'decimal', label: 'Decimal', value: 12.75),
            BeuiDonutSegment(id: 'other', label: 'Other', value: 1.5),
          ],
        ),
      );
      await tester.pump();
      expect(
        tester.widget<BeuiDigitSwap>(find.byType(BeuiDigitSwap)).value,
        '14.25',
      );
      expect(find.text('12.75'), findsOneWidget);
      expect(find.text('1.5'), findsOneWidget);
    });

    testWidgets('default formatter rounds and groups literal three decimals', (
      tester,
    ) async {
      await tester.pumpWidget(
        _chart(
          defaultActiveId: 'round',
          segments: const [
            BeuiDonutSegment(id: 'round', name: 'Round', value: 12.3456),
          ],
        ),
      );
      await tester.pump();
      expect(
        tester.widget<BeuiDigitSwap>(find.byType(BeuiDigitSwap)).value,
        '12.346',
      );

      await tester.pumpWidget(
        _chart(
          defaultActiveId: 'grouped',
          segments: const [
            BeuiDonutSegment(id: 'grouped', name: 'Grouped', value: 12345.6789),
          ],
        ),
      );
      await tester.pump();
      expect(
        tester.widget<BeuiDigitSwap>(find.byType(BeuiDigitSwap)).value,
        '12,345.679',
      );
    });

    testWidgets('custom total caption is composed and center width is a cap', (
      tester,
    ) async {
      await tester.pumpWidget(
        _chart(
          totalLabel: 'Legacy caption',
          totalCaption: const Text('Custom caption', key: ValueKey('caption')),
        ),
      );
      await tester.pump();
      expect(find.text('Custom caption'), findsOneWidget);
      expect(find.text('Legacy caption'), findsNothing);
      final caption = tester.getSize(find.byKey(const ValueKey('caption')));
      expect(caption.width, lessThanOrEqualTo(240 * .56 + .01));
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.byKey(const ValueKey('caption')),
                    matching: find.byType(ClipRect),
                  )
                  .first,
            )
            .height,
        16,
      );
      final richText = tester.widget<RichText>(
        find.descendant(
          of: find.byKey(const ValueKey('caption')),
          matching: find.byType(RichText),
        ),
      );
      expect(richText.textAlign, TextAlign.center);
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('caption')))
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
    });

    testWidgets(
      'center default keeps its caption and custom content has intrinsic bounds',
      (tester) async {
        await tester.pumpWidget(_chart(totalLabel: 'Monthly total'));
        await tester.pump();
        expect(find.text('Monthly total'), findsOneWidget);
        await tester.pumpWidget(
          _chart(
            centerBuilder: (context, segment, total) => const Text(
              'Short',
              key: ValueKey('short-center'),
              style: TextStyle(fontSize: 12, height: 16 / 12),
            ),
          ),
        );
        await tester.pump();
        final short = tester.getRect(
          find.byKey(const ValueKey('short-center')),
        );
        final plot = tester.getRect(find.byType(BeuiDonutPlot));
        expect(short.width, lessThan(240 * .56));
        expect(short.center.dx, closeTo(plot.center.dx, .01));
        expect(short.center.dy, closeTo(plot.center.dy, .01));
        await tester.pumpWidget(
          _chart(
            centerBuilder: (context, segment, total) => const Text(
              'A composed center that wraps across several words',
              key: ValueKey('wrapped-center'),
              style: TextStyle(fontSize: 12, height: 16 / 12),
            ),
          ),
        );
        await tester.pump();
        final wrapped = find.byKey(const ValueKey('wrapped-center'));
        final size = tester.getSize(wrapped);
        expect(
          tester
              .widget<RichText>(
                find.descendant(of: wrapped, matching: find.byType(RichText)),
              )
              .textAlign,
          TextAlign.center,
        );
        expect(size.width, lessThanOrEqualTo(240 * .56 + .01));
        expect(size.height, greaterThan(16));
        final wrappedRect = tester.getRect(wrapped);
        expect(wrappedRect.center.dx, closeTo(plot.center.dx, .01));
        expect(wrappedRect.center.dy, closeTo(plot.center.dy, .01));
      },
    );

    testWidgets('ring entrance and segment opacity follow source timing', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(reduce: false));
      await tester.pump(Duration.zero);
      final plotSpace = tester.renderObject(
        find.byKey(const ValueKey('donut-plot-coordinate-space')),
      );
      final teamPaint = find.descendant(
        of: find.byKey(const ValueKey('team')),
        matching: find.byType(CustomPaint),
      );
      final businessPaint = find.descendant(
        of: find.byKey(const ValueKey('business')),
        matching: find.byType(CustomPaint),
      );
      final starterPaint = find.descendant(
        of: find.byKey(const ValueKey('starter')),
        matching: find.byType(CustomPaint),
      );
      RenderOpacity segmentOpacity(Finder paint) =>
          tester.renderObject<RenderOpacity>(
            find.ancestor(of: paint, matching: find.byType(Opacity)).first,
          );
      final teamOpacity = segmentOpacity(teamPaint);
      final businessOpacity = segmentOpacity(businessPaint);
      final starterOpacity = segmentOpacity(starterPaint);
      final entranceOpacity = tester.renderObject<RenderOpacity>(
        find.ancestor(of: teamPaint, matching: find.byType(Opacity)).last,
      );
      final initial = tester.renderObject(teamPaint).getTransformTo(plotSpace);
      expect(
        math.atan2(initial.storage[1], initial.storage[0]),
        closeTo(-math.pi / 2, .01),
      );
      expect(
        math.sqrt(
          initial.storage[0] * initial.storage[0] +
              initial.storage[1] * initial.storage[1],
        ),
        closeTo(.88, .01),
      );
      expect(teamOpacity.opacity, 0);
      expect(businessOpacity.opacity, 0);
      expect(starterOpacity.opacity, 0);
      expect(entranceOpacity.opacity, 0);

      await tester.pump(const Duration(milliseconds: 149));
      expect(teamOpacity.opacity, 0);
      expect(businessOpacity.opacity, 0);
      expect(starterOpacity.opacity, 0);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(Duration.zero);
      expect(teamOpacity.opacity, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(teamOpacity.opacity, greaterThan(0));
      expect(businessOpacity.opacity, 0);
      expect(starterOpacity.opacity, 0);
      await tester.pump(const Duration(milliseconds: 59));
      await tester.pump(Duration.zero);
      expect(businessOpacity.opacity, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(businessOpacity.opacity, greaterThan(0));
      expect(starterOpacity.opacity, 0);
      await tester.pump(const Duration(milliseconds: 59));
      await tester.pump(Duration.zero);
      expect(starterOpacity.opacity, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(starterOpacity.opacity, greaterThan(0));

      await tester.pump(const Duration(milliseconds: 278));
      expect(teamOpacity.opacity, lessThan(1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(teamOpacity.opacity, closeTo(1, .01));
      expect(businessOpacity.opacity, lessThan(1));
      await tester.pump(const Duration(milliseconds: 59));
      expect(businessOpacity.opacity, lessThan(1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(businessOpacity.opacity, closeTo(1, .01));
      expect(starterOpacity.opacity, lessThan(1));
      await tester.pump(const Duration(milliseconds: 60));
      expect(starterOpacity.opacity, closeTo(1, .01));
      await tester.pump(const Duration(milliseconds: 230));
      final settled = tester.renderObject(teamPaint).getTransformTo(plotSpace);
      expect(
        math.atan2(settled.storage[1], settled.storage[0]),
        closeTo(0, .01),
      );
      expect(
        math.sqrt(
          settled.storage[0] * settled.storage[0] +
              settled.storage[1] * settled.storage[1],
        ),
        closeTo(1, .01),
      );
      expect(teamOpacity.opacity, closeTo(1, .01));
      expect(businessOpacity.opacity, closeTo(1, .01));
      expect(starterOpacity.opacity, closeTo(1, .01));
      expect(entranceOpacity.opacity, closeTo(1, .01));

      final plot = tester.getRect(find.byType(BeuiDonutPlot));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(Offset(plot.center.dx + 97.2, plot.center.dy));
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 450));
      final teamTransform = tester
          .renderObject(teamPaint)
          .getTransformTo(plotSpace);
      final teamScale = math.sqrt(
        teamTransform.storage[0] * teamTransform.storage[0] +
            teamTransform.storage[1] * teamTransform.storage[1],
      );
      expect(teamScale, greaterThan(1));
      await mouse.moveTo(plot.center);
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 10));
      expect(businessOpacity.opacity, greaterThan(.3));
      await tester.pump(const Duration(milliseconds: 440));
      expect(teamOpacity.opacity, closeTo(1, .01));
      expect(businessOpacity.opacity, closeTo(1, .01));
      expect(starterOpacity.opacity, closeTo(1, .01));
      await mouse.removePointer();
    });

    testWidgets('reduced motion snaps ring transform and active emphasis', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(defaultActiveId: 'team', reduce: true));
      await tester.pump();
      final plotSpace = tester.renderObject(
        find.byKey(const ValueKey('donut-plot-coordinate-space')),
      );
      final teamPaint = find.descendant(
        of: find.byKey(const ValueKey('team')),
        matching: find.byType(CustomPaint),
      );
      final businessPaint = find.descendant(
        of: find.byKey(const ValueKey('business')),
        matching: find.byType(CustomPaint),
      );
      final teamTransform = tester
          .renderObject(teamPaint)
          .getTransformTo(plotSpace);
      final businessTransform = tester
          .renderObject(businessPaint)
          .getTransformTo(plotSpace);
      expect(
        math.atan2(businessTransform.storage[1], businessTransform.storage[0]),
        closeTo(0, .01),
      );
      expect(
        math.sqrt(
          businessTransform.storage[0] * businessTransform.storage[0] +
              businessTransform.storage[1] * businessTransform.storage[1],
        ),
        closeTo(1, .01),
      );
      expect(
        math.sqrt(
          teamTransform.storage[0] * teamTransform.storage[0] +
              teamTransform.storage[1] * teamTransform.storage[1],
        ),
        closeTo(1.05, .01),
      );
      RenderOpacity opacityOf(Finder paint) =>
          tester.renderObject<RenderOpacity>(
            find.ancestor(of: paint, matching: find.byType(Opacity)).first,
          );
      expect(opacityOf(teamPaint).opacity, 1);
      expect(opacityOf(businessPaint).opacity, closeTo(.3, .01));
    });

    testWidgets(
      'forty-percent visibility starts entrance and disposal cancels it',
      (tester) async {
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          beuiTestApp(
            SizedBox(
              height: 180,
              child: SingleChildScrollView(
                controller: scroll,
                child: Column(
                  children: [
                    const SizedBox(height: 240),
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: BeuiDonutChart(
                        segments: _segments,
                        child: const BeuiDonutPlot(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            reduce: false,
            width: 520,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byKey(const ValueKey('donut-ring-entrance')), findsNothing);
        scroll.jumpTo(139);
        await tester.pump();
        final viewport = tester.getRect(find.byType(SingleChildScrollView));
        final plot = tester.getRect(find.byType(BeuiDonutPlot));
        final belowThreshold = plot.intersect(viewport).height / plot.height;
        expect(belowThreshold, closeTo(.395, .005));
        expect(find.byKey(const ValueKey('donut-ring-entrance')), findsNothing);
        scroll.jumpTo(141);
        await tester.pump();
        final abovePlot = tester.getRect(find.byType(BeuiDonutPlot));
        final aboveThreshold =
            abovePlot.intersect(viewport).height / abovePlot.height;
        expect(aboveThreshold, closeTo(.405, .005));
        expect(
          find.byKey(const ValueKey('donut-ring-entrance')),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('typed scope reads and requests through the root owner', (
      tester,
    ) async {
      final changes = <String?>[];
      await tester.pumpWidget(
        beuiTestApp(
          BeuiDonutChart(
            segments: _segments,
            onActiveChange: changes.add,
            child: Builder(
              builder: (context) {
                final model = BeuiDonutChartScope.of(context);
                return Column(
                  children: [
                    Text(
                      '${model.activeId}:${model.placed.length}:${model.total}',
                    ),
                    Text(model.formatValue(12345.6789)),
                    TextButton(
                      onPressed: () => model.setActive('business'),
                      child: const Text('Set active'),
                    ),
                  ],
                );
              },
            ),
          ),
          width: 520,
        ),
      );
      await tester.pump();
      expect(find.text('null:3:100.0'), findsOneWidget);
      expect(find.text('12,345.679'), findsOneWidget);
      await tester.tap(find.text('Set active'));
      await tester.pump();
      expect(find.text('business:3:100.0'), findsOneWidget);
      expect(changes, ['business']);
    });

    testWidgets('legacy label callers work and name takes precedence', (
      tester,
    ) async {
      await tester.pumpWidget(
        _chart(
          segments: const [
            BeuiDonutSegment(
              id: 'legacy',
              label: 'Legacy label',
              name: 'Source name',
              value: 1,
            ),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Source name'), findsOneWidget);
      expect(find.text('Legacy label'), findsNothing);
    });
  });
}
