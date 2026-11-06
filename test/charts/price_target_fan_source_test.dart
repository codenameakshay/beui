import 'package:beui/beui.dart';
import 'package:beui/src/charts/_shared.dart' show BeuiChartTween;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart' show SpringMotion;

import '../support.dart';

const _history = [
  BeuiPriceHistoryPoint(date: '2025-09-14', price: 158.4),
  BeuiPriceHistoryPoint(date: '2025-10-14', price: 164.2),
  BeuiPriceHistoryPoint(date: '2025-11-14', price: 160.8),
  BeuiPriceHistoryPoint(date: '2025-12-14', price: 173.1),
  BeuiPriceHistoryPoint(date: '2026-01-14', price: 170.6),
  BeuiPriceHistoryPoint(date: '2026-02-14', price: 181.3),
  BeuiPriceHistoryPoint(date: '2026-03-14', price: 175.8),
  BeuiPriceHistoryPoint(date: '2026-04-14', price: 183.7),
  BeuiPriceHistoryPoint(date: '2026-05-14', price: 178.2),
  BeuiPriceHistoryPoint(date: '2026-06-14', price: 184.1),
  BeuiPriceHistoryPoint(date: '2026-07-14', price: 180.5),
  BeuiPriceHistoryPoint(date: '2026-08-14', price: 177.3),
  BeuiPriceHistoryPoint(date: '2026-09-14', price: 178.52),
];

const _targets = [
  BeuiPriceTarget(key: 'High', price: 232, analysts: 9),
  BeuiPriceTarget(key: 'Mean', price: 205, analysts: 34),
  BeuiPriceTarget(key: 'Low', price: 168, analysts: 6),
];

Widget _chart({
  List<BeuiPriceTarget> targets = _targets,
  List<BeuiPriceHistoryPoint> history = _history,
  BeuiPriceTargetFanActive? active,
  BeuiPriceTargetFanActive? defaultActive,
  ValueChanged<BeuiPriceTargetFanActive?>? onActiveChange,
  Widget? child,
}) => BeuiPriceTargetFan(
  current: 178.52,
  targets: targets,
  history: history,
  dates: const BeuiPriceTargetDates(horizon: 'Sep 2027'),
  active: active,
  defaultActive: defaultActive,
  onActiveChange: onActiveChange,
  child: child,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool reduce = true,
}) async {
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(beuiTestApp(child, reduce: reduce, width: 672));
}

double _renderedOpacity(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  for (
    RenderObject? node = tester.renderObject<RenderObject>(finder);
    node != null;
    node = node.parent
  ) {
    if (node is RenderOpacity) {
      opacity *= node.opacity;
    } else if (node is RenderAnimatedOpacity) {
      opacity *= node.opacity.value;
    }
  }
  return opacity;
}

void main() {
  // Source: price-target-fan/context.ts:20-28; plot.tsx:38-44;
  // series.tsx:14-57. The default name is observable even with no history.
  testWidgets('default name and empty history match the source contract', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      const BeuiPriceTargetFan(current: 178.52, targets: _targets, history: []),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'^Price target · 12 months: mean \$205\.00, now \$178\.52$'),
      ),
      findsOneWidget,
    );
    expect(find.text('Mean target'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('price-target-history-slider')),
      findsNothing,
    );
    expect(find.text('205'), findsOneWidget);
    semantics.dispose();
  });

  // Source header.tsx:9-20 prefers the active target color; geometry still
  // consumes the unmodified raw series color.
  testWidgets(
    'selected High header uses its ink color while series stays raw',
    (tester) async {
      await _pump(
        tester,
        _chart(defaultActive: const BeuiPriceTargetFanActive.target('High')),
      );
      await tester.pumpAndSettle();
      final percent = find.text('+30.0%');
      expect(percent, findsOneWidget);
      expect(
        tester.widget<Text>(percent).style!.color,
        const Color(0xFF007E2F),
      );

      final targetPrice = find.text('232');
      expect(targetPrice, findsOneWidget);
      expect(
        tester.widget<Text>(targetPrice).style!.color,
        const Color(0xFF007E2F),
      );
      final geometry = tester.widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(BeuiPriceTargetTargets),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(geometry, isNotEmpty);
    },
  );

  // Source context.ts keeps active controlled independently from its callback;
  // explicitly controlled-null must not silently adopt an internal selection.
  testWidgets('controlled empty selection reports without taking ownership', (
    tester,
  ) async {
    final changes = <BeuiPriceTargetFanActive?>[];
    await _pump(
      tester,
      BeuiPriceTargetFan(
        current: 178.52,
        targets: _targets,
        history: _history,
        active: null,
        activeIsControlled: true,
        onActiveChange: changes.add,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('price-target-target-High')));
    await tester.pump();
    expect(changes, [const BeuiPriceTargetFanActive.target('High')]);
    expect(find.text('Mean target'), findsOneWidget);
    expect(find.text('Analysts'), findsNothing);
  });

  testWidgets('source-aligned parts compose the complete history slider', (
    tester,
  ) async {
    await _pump(
      tester,
      _chart(
        defaultActive: const BeuiPriceTargetFanActive.target('High'),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BeuiPriceTargetFanHeader(child: Text('custom header')),
            BeuiPriceTargetFanPlot(
              child: Stack(
                children: [
                  BeuiPriceTargetFanSvg(
                    children: [
                      BeuiPriceTargetFanAxes(),
                      BeuiPriceTargetFanHistory(),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: BeuiPriceTargetFanTooltip(
                      child: Text('custom tooltip'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump(Duration.zero);
    expect(find.text('custom header'), findsOneWidget);
    expect(find.text('custom tooltip'), findsOneWidget);
    expect(find.byType(BeuiPriceTargetHistoryPoints), findsOneWidget);
    expect(
      find.byKey(const ValueKey('price-target-history-slider')),
      findsOneWidget,
    );
  });

  testWidgets('tooltip builder receives source title, metrics, accent, anchor', (
    tester,
  ) async {
    await _pump(
      tester,
      _chart(
        defaultActive: const BeuiPriceTargetFanActive.target('High'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BeuiPriceTargetFanHeader(),
            BeuiPriceTargetFanPlot(
              child: Stack(
                children: [
                  const BeuiPriceTargetFanSvg(),
                  Positioned(
                    child: BeuiPriceTargetFanTooltip(
                      contentBuilder: (data) => Text(
                        '${data.title}|${data.metrics.map((row) => row.value).join('|')}|${data.accent?.value}|${data.anchor.dx.toStringAsFixed(1)}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump(Duration.zero);
    expect(
      find.text('High target · Sep 2027|\$232.00|9|+30.0%|412.0'),
      findsOneWidget,
    );
  });

  testWidgets('reduced motion snaps geometry and target opacity', (
    tester,
  ) async {
    await _pump(tester, _chart(), reduce: true);
    Rect clip() {
      final rect = tester.widget<ClipRect>(
        find.byKey(const ValueKey('price-target-fan-reveal')),
      );
      return rect.clipper!.getClip(const Size(520, 236));
    }

    expect(clip().width, closeTo(273.44, .001));
    await tester.tap(find.byKey(const ValueKey('price-target-target-High')));
    await tester.pump();
    final meanPriceLabel = find.descendant(
      of: find.byKey(const ValueKey('price-target-target-Mean')),
      matching: find.text('205'),
    );
    expect(_renderedOpacity(tester, meanPriceLabel), .3);
    expect(clip().width, closeTo(273.44, .001));
  });

  testWidgets('target opacity fades over the source 250ms duration', (
    tester,
  ) async {
    await _pump(tester, _chart(), reduce: false);
    final meanPriceLabel = find.descendant(
      of: find.byKey(const ValueKey('price-target-target-Mean')),
      matching: find.text('205'),
    );
    expect(_renderedOpacity(tester, meanPriceLabel), 1);

    await tester.tap(find.byKey(const ValueKey('price-target-target-High')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 125));
    expect(_renderedOpacity(tester, meanPriceLabel), inExclusiveRange(.3, 1));

    await tester.pump(const Duration(milliseconds: 125));
    expect(_renderedOpacity(tester, meanPriceLabel), closeTo(.3, .001));
  });

  testWidgets('fractional target labels retain their source number', (
    tester,
  ) async {
    const targets = [
      BeuiPriceTarget(key: 'High', price: 232.5, analysts: 9),
      BeuiPriceTarget(key: 'Mean', price: 205, analysts: 34),
      BeuiPriceTarget(key: 'Low', price: 168, analysts: 6),
    ];
    await _pump(tester, _chart(targets: targets));

    expect(find.text('232.5'), findsOneWidget);
    expect(find.text('205'), findsOneWidget);
    expect(find.text('168'), findsOneWidget);
  });

  // Source utils.ts defines literal source OKLCH inputs. These fixed outcomes
  // intentionally do not infer source LCH from BeuiColors' quantized sRGB.
  testWidgets('default source inks use exact light and dark literals', (
    tester,
  ) async {
    Future<void> expectInks(Brightness brightness, List<Color> expected) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: brightness,
            extensions: [BeuiColors.of(BeuiColorTheme.defaultMono, brightness)],
          ),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: _chart(
                defaultActive: const BeuiPriceTargetFanActive.target('High'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final prices = ['232', '205', '168'];
      for (var index = 0; index < prices.length; index++) {
        final price = find.text(prices[index]);
        expect(tester.widget<Text>(price).style!.color, expected[index]);
      }
    }

    await expectInks(Brightness.light, const [
      Color(0xFF007E2F),
      Color(0xFF007E83),
      Color(0xFF9C4B00),
    ]);
    await expectInks(Brightness.dark, const [
      Color(0xFF00BE6A),
      Color(0xFF00DFE1),
      Color(0xFFF9A300),
    ]);
  });

  testWidgets('custom source token values remain the consumer ink', (
    tester,
  ) async {
    const customSuccess = Color(0xFFAA22CC);
    final colors = BeuiColors.of(
      BeuiColorTheme.defaultMono,
      Brightness.light,
    ).copyWith(success: customSuccess);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [colors]),
        home: Scaffold(
          body: _chart(
            defaultActive: const BeuiPriceTargetFanActive.target('High'),
          ),
        ),
      ),
    );
    expect(tester.widget<Text>(find.text('232')).style!.color, customSuccess);
  });

  testWidgets('source light ink cap never recolors the raw High projection', (
    tester,
  ) async {
    await _pump(
      tester,
      _chart(defaultActive: const BeuiPriceTargetFanActive.target('High')),
    );
    final customPaint = tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(BeuiPriceTargetTargets),
            matching: find.byType(CustomPaint),
          ),
        )
        .first;
    final canvas = TestRecordingCanvas();
    customPaint.painter!.paint(canvas, const Size(520, 236));
    final pathPaint =
        canvas.invocations
                .firstWhere((call) => call.invocation.memberName == #drawPath)
                .invocation
                .positionalArguments[1]
            as Paint;
    expect(pathPaint.color.toARGB32(), 0xFF00BE6A);
  });

  testWidgets('explicit CSS hex color is capped from its own source value', (
    tester,
  ) async {
    const targets = [
      BeuiPriceTarget(key: 'High', price: 232, analysts: 9, color: '#00C5C7'),
      BeuiPriceTarget(key: 'Mean', price: 205, analysts: 34),
      BeuiPriceTarget(key: 'Low', price: 168, analysts: 6),
    ];
    await _pump(
      tester,
      _chart(
        targets: targets,
        defaultActive: const BeuiPriceTargetFanActive.target('High'),
      ),
    );
    expect(
      tester.widget<Text>(find.text('232')).style!.color,
      const Color(0xFF00787B),
    );
  });

  testWidgets('unsupported alphabetic CSS is not treated as a color literal', (
    tester,
  ) async {
    const targets = [
      BeuiPriceTarget(
        key: 'High',
        price: 232,
        analysts: 9,
        color: 'not-a-css-color',
      ),
      BeuiPriceTarget(key: 'Mean', price: 205, analysts: 34),
      BeuiPriceTarget(key: 'Low', price: 168, analysts: 6),
    ];
    await _pump(
      tester,
      _chart(
        targets: targets,
        defaultActive: const BeuiPriceTargetFanActive.target('High'),
      ),
    );
    final colors = BeuiColors.of(BeuiColorTheme.defaultMono, Brightness.light);
    expect(tester.widget<Text>(find.text('232')).style!.color, colors.success);
  });

  // Source series.tsx gives the slider native keyboard support and source
  // pilot frame 188/241 retains a visible focus outline after Escape.
  testWidgets('history slider focuses, Home and End settle on literal points', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _chart());
    final sliderFinder = find.byKey(
      const ValueKey('price-target-history-slider'),
    );
    final slider = tester.widget<Focus>(sliderFinder);
    final focusNode = slider.focusNode!;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    await tester.pump(Duration.zero);
    expect(find.text('Mon, Sep 14'), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(find.text('Sun, Sep 14'), findsWidgets);

    // Ensure the focus request and its initial selection have settled before
    // dispatching End; this mirrors the source-control test precondition.
    expect(focusNode.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(find.text('Mon, Sep 14'), findsWidgets);
    expect(find.text(r'$178.52'), findsWidgets);
    expect(
      find.byKey(const ValueKey('price-target-history-focus-outline')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 130));
    expect(find.text('Price'), findsNothing);
    expect(
      find.byKey(const ValueKey('price-target-history-focus-outline')),
      findsOneWidget,
    );
    semantics.dispose();
    focusNode.unfocus();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('price-target-history-focus-outline')),
      findsNothing,
    );
  });

  testWidgets('history focus selects latest despite an earlier active point', (
    tester,
  ) async {
    final changes = <BeuiPriceTargetFanActive?>[];
    await _pump(
      tester,
      _chart(
        active: const BeuiPriceTargetFanActive.history('2025-11-14'),
        onActiveChange: changes.add,
      ),
    );
    tester
        .widget<Focus>(
          find.byKey(const ValueKey('price-target-history-slider')),
        )
        .focusNode!
        .requestFocus();
    await tester.pump();
    expect(changes, [const BeuiPriceTargetFanActive.history('2026-09-14')]);
  });

  testWidgets(
    'history outline tracks the painted path bounds and 1.5px stroke',
    (tester) async {
      await _pump(tester, _chart());
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final historyPaint = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(BeuiPriceTargetHistory),
              matching: find.byType(CustomPaint),
            ),
          )
          .single;
      final canvas = TestRecordingCanvas();
      historyPaint.painter!.paint(canvas, const Size(520, 236));
      final draw = canvas.invocations.firstWhere(
        (call) => call.invocation.memberName == #drawPath,
      );
      final path = draw.invocation.positionalArguments[0] as Path;
      final paint = draw.invocation.positionalArguments[1] as Paint;
      expect(paint.strokeWidth, 1.5);
      final expected = path.getBounds().inflate(.75);
      final outline = tester.getRect(
        find.byKey(const ValueKey('price-target-history-focus-outline')),
      );
      final svg = tester.getRect(find.byType(BeuiPriceTargetFanSvg));
      expect(outline.left, closeTo(svg.left + expected.left, .01));
      expect(outline.top, closeTo(svg.top + expected.top, .01));
      expect(outline.width, closeTo(expected.width, .01));
      expect(outline.height, closeTo(expected.height, .01));
    },
  );

  testWidgets('mouse focus does not paint the keyboard history outline', (
    tester,
  ) async {
    await _pump(tester, _chart());
    final point = tester.getCenter(
      find.byKey(const ValueKey('price-target-history-2025-09-14')),
    );
    final mouse = await tester.startGesture(
      point,
      kind: PointerDeviceKind.mouse,
    );
    await mouse.up();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('price-target-history-focus-outline')),
      findsNothing,
    );
  });

  testWidgets('date-only UTC and offset history share chronological geometry', (
    tester,
  ) async {
    const history = [
      BeuiPriceHistoryPoint(date: '2025-01-01', price: 100),
      BeuiPriceHistoryPoint(date: '2025-01-01T03:00:00+02:00', price: 100),
    ];
    await _pump(
      tester,
      BeuiPriceTargetFan(
        current: 100,
        targets: const [
          BeuiPriceTarget(key: 'High', price: 100, analysts: 1),
          BeuiPriceTarget(key: 'Mean', price: 100, analysts: 1),
          BeuiPriceTarget(key: 'Low', price: 100, analysts: 1),
        ],
        history: history,
      ),
    );
    final first = tester.getCenter(
      find.byKey(const ValueKey('price-target-history-2025-01-01')),
    );
    final second = tester.getCenter(
      find.byKey(
        const ValueKey('price-target-history-2025-01-01T03:00:00+02:00'),
      ),
    );
    expect(second.dx, greaterThan(first.dx));
  });

  testWidgets('equal target prices pass while invalid history order fails', (
    tester,
  ) async {
    await _pump(
      tester,
      BeuiPriceTargetFan(
        current: 100,
        targets: const [
          BeuiPriceTarget(key: 'High', price: 100, analysts: 1),
          BeuiPriceTarget(key: 'Mean', price: 100, analysts: 2),
          BeuiPriceTarget(key: 'Low', price: 100, analysts: 3),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      beuiTestApp(
        BeuiPriceTargetFan(
          current: 100,
          targets: const [
            BeuiPriceTarget(key: 'High', price: 100),
            BeuiPriceTarget(key: 'Mean', price: 100),
            BeuiPriceTarget(key: 'Low', price: 100),
          ],
          history: const [
            BeuiPriceHistoryPoint(date: '2025-01-02', price: 100),
            BeuiPriceHistoryPoint(date: '2025-01-01', price: 100),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isA<ArgumentError>());
  });

  testWidgets('history cursor uses the exact source glide spring', (
    tester,
  ) async {
    await _pump(
      tester,
      _chart(
        defaultActive: const BeuiPriceTargetFanActive.history('2025-11-14'),
      ),
    );
    final cursor = tester
        .widgetList<BeuiChartTween>(find.byType(BeuiChartTween))
        .where(
          (tween) =>
              tween.duration == const Duration(milliseconds: 200) &&
              tween.motion is SpringMotion,
        )
        .toList();
    expect(cursor, hasLength(2));
    for (final tween in cursor) {
      final spring = tween.motion! as SpringMotion;
      expect(spring.description.stiffness, 700);
      expect(spring.description.damping, 50);
      expect(spring.description.mass, .5);
    }
    expect(beuiSpringPanel.description.stiffness, 420);
    expect(beuiSpringPanel.description.damping, 40);
    expect(beuiSpringPanel.description.mass, .5);
  });

  // Source plot.tsx:52-58 and series.tsx:32-46. These are frame-pumped
  // assertions; no midpoint golden or run-to-settle shortcut.
  testWidgets('source staged fan draw waits 850ms then draws for 800ms', (
    tester,
  ) async {
    await _pump(tester, _chart(), reduce: false);
    Rect clip() {
      final rect = tester.widget<ClipRect>(
        find.byKey(const ValueKey('price-target-fan-reveal')),
      );
      return rect.clipper!.getClip(const Size(520, 236));
    }

    expect(clip().width, 0);
    await tester.pump(const Duration(milliseconds: 849));
    expect(clip().width, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 99));
    final initialDraw = clip().width;
    expect(initialDraw, inExclusiveRange(0, 273.44));
    await tester.pump(const Duration(milliseconds: 300));
    final continuedDraw = clip().width;
    expect(continuedDraw, greaterThan(initialDraw));
    expect(continuedDraw, lessThan(273.44));
    await tester.pump(const Duration(milliseconds: 400));
    expect(clip().width, closeTo(273.44, .001));
  });

  testWidgets('complete fan respects wide and narrow root bounds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      beuiTestApp(
        Align(child: SizedBox(width: 280, child: _chart())),
        width: 300,
      ),
    );
    final plot = tester.getRect(find.byType(BeuiPriceTargetSvg));
    expect(plot.width, lessThanOrEqualTo(280));
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(900, 900);
    await tester.pump();
    await tester.pumpWidget(beuiTestApp(_chart(), width: 672));
    expect(tester.getRect(find.byType(BeuiPriceTargetPlot)).width, 520);
    expect(tester.getRect(find.byType(BeuiPriceTargetHeader)).width, 520);
  });

  testWidgets(
    'rendered tooltip follows transformed scrolled anchor through resize and disposal',
    (tester) async {
      tester.view.physicalSize = const Size(360, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        beuiTestApp(
          SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                const SizedBox(height: 220),
                Transform.scale(
                  scale: .9,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 320,
                    child: _chart(
                      defaultActive: const BeuiPriceTargetFanActive.target(
                        'High',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 500),
              ],
            ),
          ),
          width: 340,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      final title = find.text('High target · Sep 2027');
      expect(title, findsOneWidget);
      expect(find.text(r'$232.00'), findsOneWidget);
      expect(
        find.descendant(
          of: find
              .ancestor(of: find.text('Analysts'), matching: find.byType(Row))
              .first,
          matching: find.text('9'),
        ),
        findsOneWidget,
      );
      expect(find.text('+30.0%'), findsOneWidget);
      final panel = find.ancestor(
        of: title,
        matching: find.byType(DecoratedBox),
      );
      expect(panel, findsOneWidget);
      final initial = tester.getRect(panel);
      expect(initial.width, closeTo(148, .01));
      expect(initial.height, greaterThan(20));
      expect(initial.left, greaterThanOrEqualTo(0));
      expect(initial.right, lessThanOrEqualTo(360));
      expect(initial.top, greaterThanOrEqualTo(0));

      scroll.jumpTo(80);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      final afterScroll = tester.getRect(panel);
      expect(afterScroll.top, lessThan(initial.top));
      expect(afterScroll.left, greaterThanOrEqualTo(0));
      expect(afterScroll.right, lessThanOrEqualTo(360));

      tester.view.physicalSize = const Size(280, 420);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      final afterResize = tester.getRect(panel);
      expect(afterResize.left, greaterThanOrEqualTo(0));
      expect(afterResize.right, lessThanOrEqualTo(280));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 220));
      expect(tester.takeException(), isNull);
    },
  );
}
