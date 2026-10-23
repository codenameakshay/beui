import 'dart:convert';
import 'dart:io';
import 'dart:ui' show SemanticsRole, SemanticsAction, SemanticsActionEvent;
import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beui/src/motion/_engine.dart';
import 'package:beui/src/charts/_shared.dart';
// The gallery demo is the source dataset under comparison, not a dependency.
// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/sankey_chart_demo.dart';

const nodes = [
  BeuiSankeyNode(id: 'ads', label: 'Ads'),
  BeuiSankeyNode(id: 'search', label: 'Search'),
  BeuiSankeyNode(id: 'signup', label: 'Signup'),
  BeuiSankeyNode(id: 'paid', label: 'Paid'),
  BeuiSankeyNode(id: 'free', label: 'Free'),
];
const links = [
  BeuiSankeyLink(source: 'ads', target: 'signup', value: 30),
  BeuiSankeyLink(source: 'search', target: 'signup', value: 50),
  BeuiSankeyLink(source: 'search', target: 'signup', value: 20),
  BeuiSankeyLink(source: 'signup', target: 'paid', value: 40),
  BeuiSankeyLink(source: 'signup', target: 'free', value: 60),
  BeuiSankeyLink(source: 'paid', target: 'ads', value: 5),
];
Widget wrap(Widget child, {bool reduce = true, double width = 640}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: reduce,
          size: const Size(800, 600),
        ),
        child: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
Finder target(String id) => find.byKey(ValueKey('sankey-target:$id'));
FocusNode focus(WidgetTester t, String id) => t
    .widget<FocusableActionDetector>(
      find.descendant(
        of: target(id),
        matching: find.byType(FocusableActionDetector),
      ),
    )
    .focusNode!;
dynamic flowPainter(WidgetTester t, String id) => t
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .where((p) => p.runtimeType.toString() == '_FlowPainter')
    .cast<dynamic>()
    .firstWhere((p) => p.link.id == id);
void main() {
  test('actual demo cubic centerlines match source SVG interior samples', () {
    final reference = jsonDecode(
      File(
        'docs/proof/v3-parity/charts/sankey/source/curves.json',
      ).readAsStringSync(),
    );
    for (final f in reference['fixtures'] as List) {
      final layout = beuiLayoutSankey(
        beuiCleanSankey(sankeyDemoNodes, sankeyDemoLinks(f['quarter'])),
        size: const Size(768, 320),
      );
      expect(layout.links.length, 9);
      for (var i = 0; i < layout.links.length; i++) {
        final metric = layout.links[i].path.computeMetrics().single,
            expected = f['paths'][i];
        final link = layout.links[i];
        final controls = (expected['d'] as String)
            .split(RegExp(r'[ MC,]+'))
            .where((s) => s.isNotEmpty)
            .map(double.parse)
            .toList();
        final actual = [
          link.start.dx,
          link.start.dy,
          (link.start.dx + link.end.dx) / 2,
          link.start.dy,
          (link.start.dx + link.end.dx) / 2,
          link.end.dy,
          link.end.dx,
          link.end.dy,
        ];
        for (var c = 0; c < actual.length; c++) {
          expect(actual[c], closeTo(controls[c], 1e-9));
        }
        expect(metric.length, closeTo(expected['length'], .1));
        for (final sample in expected['samples']) {
          final point = metric
              .getTangentForOffset(metric.length * (sample['fraction'] as num))!
              .position;
          // Blink and Skia approximate arc-length inversion differently.
          expect(point.dx, closeTo(sample['x'], .5));
          expect(point.dy, closeTo(sample['y'], .5));
        }
      }
    }
  });
  test(
    'source-derived geometry at three sizes matches every node and cubic end',
    () {
      final reference =
          jsonDecode(
                File(
                  'docs/proof/v3-parity/charts/sankey/source/geometry.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final f in reference['fixtures'] as List) {
        final layout = beuiLayoutSankey(
          beuiCleanSankey(nodes, links),
          size: Size(
            (f['width'] as num).toDouble(),
            (f['height'] as num).toDouble(),
          ),
          nodeWidth: (f['nodeWidth'] as num).toDouble(),
          nodePadding: (f['nodePadding'] as num).toDouble(),
        );
        final expected = f['layout'];
        expect(layout.nodes.map((n) => n.id), [
          'ads',
          'search',
          'signup',
          'paid',
          'free',
        ]);
        expect(layout.columns, 3);
        expect(layout.step, expected['step']);
        for (var i = 0; i < layout.nodes.length; i++) {
          final n = layout.nodes[i], e = expected['nodes'][i];
          expect(n.rect.left, closeTo(e['x0'], 1e-9));
          expect(n.rect.right, closeTo(e['x1'], 1e-9));
          expect(n.rect.top, closeTo(e['y0'], 1e-9));
          expect(n.rect.bottom, closeTo(e['y1'], 1e-9));
          expect(n.value, e['value']);
          expect(n.inValue, e['inValue']);
          expect(n.outValue, e['outValue']);
          expect(n.depth, e['depth']);
        }
        expect(layout.links.map((l) => l.value), [30, 70, 40, 60]);
        for (var i = 0; i < layout.links.length; i++) {
          final l = layout.links[i], e = expected['links'][i];
          expect(l.start.dx, closeTo(e['x0'], 1e-9));
          expect(l.start.dy, closeTo(e['y0'], 1e-9));
          expect(l.end.dx, closeTo(e['x1'], 1e-9));
          expect(l.end.dy, closeTo(e['y1'], 1e-9));
          expect(l.width, closeTo(e['width'], 1e-9));
          expect(l.share, closeTo(e['share'], 1e-9));
          final metric = l.path.computeMetrics().single;
          expect(
            metric.getTangentForOffset(0)!.position.dx,
            closeTo(e['x0'], .001),
          );
          expect(
            metric.getTangentForOffset(metric.length)!.position.dy,
            closeTo(e['y1'], .001),
          );
        }
      }
    },
  );
  test(
    'cleans duplicates, unknown and invalid links, explicit ids and loops',
    () {
      final data = beuiCleanSankey(
        [...nodes, const BeuiSankeyNode(id: 'ads', label: 'Ignored')],
        [
          ...links,
          const BeuiSankeyLink(source: 'ads', target: 'ads', value: 1),
          const BeuiSankeyLink(source: 'missing', target: 'paid', value: 9),
          const BeuiSankeyLink(source: 'ads', target: 'free', value: 0),
          const BeuiSankeyLink(
            source: 'ads',
            target: 'free',
            value: double.nan,
          ),
          const BeuiSankeyLink(
            id: 'named',
            source: 'ads',
            target: 'free',
            value: 2,
          ),
          const BeuiSankeyLink(
            id: 'named',
            source: 'ads',
            target: 'free',
            value: 3,
          ),
        ],
      );
      expect(data.nodes.map((n) => n.label), [
        'Ads',
        'Search',
        'Signup',
        'Paid',
        'Free',
      ]);
      expect(data.links.map((l) => l.value), [30, 70, 40, 60, 2]);
      expect(data.invalid.map((l) => l.value).where((v) => v.isFinite), [
        1,
        9,
        0,
        3,
      ]);
      expect(data.cycles.map((l) => l.effectiveId), ['paid:ads']);
    },
  );
  test(
    'sink alignment, source order, isolated omission, and long iterative cycle traversal',
    () {
      final chain = [
        for (var i = 0; i < 1500; i++) BeuiSankeyNode(id: '$i', label: '$i'),
      ];
      final data = beuiCleanSankey(chain, [
        for (var i = 0; i < 1499; i++)
          BeuiSankeyLink(source: '$i', target: '${i + 1}', value: 1),
        const BeuiSankeyLink(source: '1499', target: '0', value: 1),
      ]);
      expect(data.links.length, 1499);
      expect(data.cycles.single.source, '1499');
      final l = beuiLayoutSankey(
        beuiCleanSankey(
          [...nodes, const BeuiSankeyNode(id: 'unused', label: 'Unused')],
          [
            ...links,
            const BeuiSankeyLink(source: 'ads', target: 'free', value: 2),
          ],
        ),
        size: const Size(640, 320),
      );
      expect(l.nodes.map((n) => n.id), [
        'ads',
        'search',
        'signup',
        'paid',
        'free',
      ]);
      expect(l.nodes.last.depth, 2);
      expect(l.nodes.last.rect.right, 640);
    },
  );
  testWidgets(
    'native roving focus, directional columns, Escape and external blur',
    (t) async {
      final changes = <String?>[];
      await t.pumpWidget(
        wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiSankeyChart(
                nodes: nodes,
                links: links,
                onActiveChange: changes.add,
              ),
              const TextButton(onPressed: null, child: Text('Outside')),
            ],
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        nodes.where((n) => !focus(t, n.id).skipTraversal).map((n) => n.id),
        ['ads'],
      );
      focus(t, 'ads').requestFocus();
      await t.pumpAndSettle();
      expect(find.text('To'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pumpAndSettle();
      expect(focus(t, 'signup').hasPrimaryFocus, true);
      expect(changes.last, 'signup');
      expect(find.text('In 100 · Out 100'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pumpAndSettle();
      expect(focus(t, 'free').hasPrimaryFocus, true);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await t.pumpAndSettle();
      expect(focus(t, 'paid').hasPrimaryFocus, true);
      await t.sendKeyEvent(LogicalKeyboardKey.home);
      await t.pumpAndSettle();
      expect(focus(t, 'ads').hasPrimaryFocus, true);
      await t.sendKeyEvent(LogicalKeyboardKey.end);
      await t.pumpAndSettle();
      expect(focus(t, 'free').hasPrimaryFocus, true);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('From'), findsNothing);
      expect(changes.last, 'free');
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pumpAndSettle();
      expect(find.text('From'), findsOneWidget);
      focus(t, 'free').unfocus();
      await t.pumpAndSettle();
      expect(changes.last, null);
      expect(find.text('From'), findsNothing);
    },
  );
  testWidgets(
    'pointer and touch inspect nodes and flows, retain release and dismiss outside',
    (t) async {
      final changes = <String?>[];
      await t.pumpWidget(
        wrap(
          BeuiSankeyChart(
            nodes: nodes,
            links: links,
            onActiveChange: changes.add,
          ),
        ),
      );
      await t.pumpAndSettle();
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(t.getCenter(target('search')));
      await t.pumpAndSettle();
      expect(changes.last, 'search');
      expect(find.text('To'), findsOneWidget);
      await mouse.moveTo(const Offset(1, 1));
      await t.pumpAndSettle();
      expect(changes.last, null);
      await t.tap(target('signup'));
      await t.pumpAndSettle();
      expect(changes.last, 'signup');
      expect(find.text('In 100 · Out 100'), findsOneWidget);
      await t.tapAt(const Offset(1, 1));
      await t.pumpAndSettle();
      expect(changes.last, null);
      await mouse.removePointer();
    },
  );
  testWidgets(
    'native semantic activation focuses a non-current node after external focus',
    (t) async {
      final handle = t.ensureSemantics();
      final external = FocusNode();
      await t.pumpWidget(
        wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                focusNode: external,
                onPressed: () {},
                child: const Text('Quarter'),
              ),
              const BeuiSankeyChart(nodes: nodes, links: links),
            ],
          ),
        ),
      );
      await t.pumpAndSettle();
      focus(t, 'signup').requestFocus();
      await t.pumpAndSettle();
      external.requestFocus();
      await t.pumpAndSettle();
      final semantic = t.getSemantics(
        find
            .descendant(of: target('ads'), matching: find.byType(Semantics))
            .first,
      );
      t.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.tap,
          viewId: t.view.viewId,
          nodeId: semantic.id,
        ),
      );
      await t.pumpAndSettle();
      expect(focus(t, 'ads').hasPrimaryFocus, true);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pumpAndSettle();
      expect(focus(t, 'signup').hasPrimaryFocus, true);
      await t.pumpWidget(const SizedBox.shrink());
      handle.dispose();
      external.dispose();
    },
  );
  testWidgets(
    'controlled null requests selection without rendering it; custom content and stale removal',
    (t) async {
      final changes = <String?>[];
      await t.pumpWidget(
        wrap(
          BeuiSankeyChart(
            nodes: nodes,
            links: links,
            controlled: true,
            onActiveChange: changes.add,
            child: const Column(
              children: [
                BeuiSankeyChartPlot(showValues: false),
                BeuiSankeyChartTooltip(child: Text('Custom')),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      focus(t, 'signup').requestFocus();
      await t.pumpAndSettle();
      expect(changes.last, 'signup');
      expect(find.text('Custom'), findsNothing);
      await t.pumpWidget(
        wrap(
          BeuiSankeyChart(
            nodes: nodes,
            links: links,
            activeId: 'signup',
            child: const Column(
              children: [
                BeuiSankeyChartPlot(),
                BeuiSankeyChartTooltip(child: Text('Custom')),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Custom'), findsOneWidget);
      await t.pumpWidget(
        wrap(
          BeuiSankeyChart(
            nodes: nodes.where((n) => n.id != 'signup').toList(),
            links: const [
              BeuiSankeyLink(source: 'ads', target: 'paid', value: 20),
            ],
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(focus(t, 'ads').hasPrimaryFocus, true);
      expect(find.text('Custom'), findsNothing);
    },
  );
  testWidgets('empty states and exact cleaned flow semantics', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      wrap(
        const BeuiSankeyChart(nodes: nodes, links: links, label: 'Signup flow'),
      ),
    );
    await t.pumpAndSettle();
    final table = find.bySemanticsLabel('Signup flow data');
    expect(t.getSemantics(table).role, SemanticsRole.table);
    final rows = find.descendant(
      of: table,
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.role == SemanticsRole.row,
      ),
    );
    expect(rows, findsNWidgets(5));
    final search = find.descendant(
      of: rows.at(2),
      matching: find.byType(Semantics),
    );
    expect(
      t
          .widgetList<Semantics>(search)
          .map((w) => w.properties.label)
          .whereType<String>(),
      ['Search to Signup', '70', '100.0%'],
    );
    final free = find.descendant(
      of: rows.at(4),
      matching: find.byType(Semantics),
    );
    expect(
      t
          .widgetList<Semantics>(free)
          .map((w) => w.properties.label)
          .whereType<String>(),
      ['Signup to Free', '60', '60.0%'],
    );
    await t.pumpWidget(wrap(const BeuiSankeyChart(nodes: nodes, links: [])));
    await t.pumpAndSettle();
    expect(find.text('No flows to show'), findsOneWidget);
    await t.pumpWidget(wrap(const BeuiSankeyChart(nodes: [], links: [])));
    await t.pumpAndSettle();
    expect(find.text('No sankey data'), findsOneWidget);
    handle.dispose();
  });
  testWidgets(
    'public inspection model and largest four flows preserve overflow and descriptions',
    (t) async {
      late BeuiSankeyChartModel model;
      await t.pumpWidget(
        wrap(
          BeuiSankeyChart(
            nodes: [
              const BeuiSankeyNode(
                id: 'hub',
                label: 'Hub',
                description: 'All channels',
              ),
              for (var i = 1; i <= 6; i++)
                BeuiSankeyNode(id: 'channel-$i', label: 'Channel $i'),
            ],
            links: [
              for (var i = 1; i <= 6; i++)
                BeuiSankeyLink(
                  id: i == 1 ? 'hub' : null,
                  source: 'hub',
                  target: 'channel-$i',
                  value: i.toDouble(),
                ),
            ],
            child: Builder(
              builder: (context) {
                model = BeuiSankeyChart.of(context);
                return const Column(
                  children: [BeuiSankeyChartPlot(), BeuiSankeyChartTooltip()],
                );
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      focus(t, 'hub').requestFocus();
      await t.pumpAndSettle();
      expect(model.active, isA<BeuiSankeyActiveNode>());
      expect(model.active!.node!.value, 21);
      expect(model.layout.nodes.length, 7);
      expect(model.data.links.length, 6);
      expect(model.tooltipOpen, true);
      expect(model.formatValue(1200.25), '1,200.25');
      expect(find.text('All channels'), findsOneWidget);
      expect(find.text('2 more'), findsOneWidget);
      expect(find.text('Channel 6'), findsOneWidget);
      expect(find.text('Channel 3'), findsOneWidget);
      expect(find.text('Channel 2'), findsNothing);
      model.setActive('hub:channel-6');
      await t.pumpAndSettle();
      expect(model.active!.link!.share, 6 / 21);
      expect(find.text('Hub → Channel 6'), findsOneWidget);
      model.setTooltipOpen(false);
      await t.pumpAndSettle();
      expect(find.text('Hub → Channel 6'), findsNothing);
    },
  );
  testWidgets(
    'draw timing and data spring geometry; reduced motion and resize snap',
    (t) async {
      await t.pumpWidget(
        wrap(const BeuiSankeyChart(nodes: nodes, links: links), reduce: false),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(flowPainter(t, 'ads:signup').progress, greaterThan(0));
      expect(flowPainter(t, 'ads:signup').progress, lessThan(1));
      expect(flowPainter(t, 'signup:paid').progress, 0);
      final tweens = t
          .widgetList<BeuiChartTween>(find.byType(BeuiChartTween))
          .toList();
      expect(tweens.where((w) => w.isMovement).map((w) => w.duration).toSet(), {
        const Duration(milliseconds: 700),
      });
      expect(tweens.where((w) => w.isMovement).map((w) => w.delay).toSet(), {
        Duration.zero,
        const Duration(milliseconds: 120),
      });
      await t.pumpAndSettle();
      final before = flowPainter(t, 'search:signup').geometry as Rect;
      final changed = [
        ...links.where((l) => l.source != 'ads'),
        const BeuiSankeyLink(source: 'ads', target: 'signup', value: 80),
      ];
      await t.pumpWidget(
        wrap(BeuiSankeyChart(nodes: nodes, links: changed), reduce: false),
      );
      await t.pump(const Duration(milliseconds: 32));
      final expectedLink = beuiLayoutSankey(
        beuiCleanSankey(nodes, changed),
        size: const Size(640, 320),
      ).links.firstWhere((l) => l.id == 'search:signup');
      final intermediate = flowPainter(t, 'search:signup').geometry as Rect;
      expect(intermediate.top, greaterThan(before.top));
      expect(intermediate.top, lessThan(expectedLink.start.dy));
      expect(intermediate.top, closeTo(219.951946, .001));
      expect(flowPainter(t, 'search:signup').progress, 1);
      final springs = t.widgetList<MotionBuilder<Rect>>(
        find.byType(MotionBuilder<Rect>),
      );
      expect(springs.every((s) => s.motion == beuiSpringLayout), true);
      await t.pumpAndSettle();
      expect(
        (flowPainter(t, 'search:signup').geometry as Rect).top,
        closeTo(expectedLink.start.dy, .001),
      );
      await t.pumpWidget(
        wrap(
          BeuiSankeyChart(nodes: nodes, links: changed),
          reduce: false,
          width: 560,
        ),
      );
      await t.pump();
      expect((flowPainter(t, 'search:signup').geometry as Rect).left, 12);
      expect((flowPainter(t, 'search:signup').geometry as Rect).right, 274);
      expect(flowPainter(t, 'search:signup').progress, 1);
      await t.pumpWidget(
        wrap(
          const BeuiSankeyChart(nodes: nodes, links: links),
          reduce: true,
          width: 360,
        ),
      );
      await t.pump();
      expect(find.byType(MotionBuilder<Rect>), findsNothing);
      expect(flowPainter(t, 'search:signup').progress, 1);
      expect(t.getSize(target('ads')).width, 20);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    },
  );
}
