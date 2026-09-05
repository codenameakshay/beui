import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool reduce = false, bool dark = false}) {
  Widget body = child;
  if (reduce) {
    body = MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: body,
    );
  }
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      dark
          ? ThemeData.dark().copyWith(extensions: [BeuiColors.dark()])
          : ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(
      body: Center(child: SizedBox(width: 400, child: body)),
    ),
  );
}

const _failedTool = BeuiAgentActivityTool(
  id: 'run',
  action: 'run',
  target: 'bun test launch',
);

void main() {
  group('beuiFormatAgentActivityDuration', () {
    test('formats sub-minute whole seconds', () {
      expect(beuiFormatAgentActivityDuration(0), '0s');
      expect(beuiFormatAgentActivityDuration(5.1), '5s');
      expect(beuiFormatAgentActivityDuration(59.4), '59s');
    });

    test('formats minutes with optional remainder', () {
      expect(beuiFormatAgentActivityDuration(60), '1m');
      expect(beuiFormatAgentActivityDuration(125), '2m 5s');
    });

    test('clamps negatives', () {
      expect(beuiFormatAgentActivityDuration(-3), '0s');
    });
  });

  group('BeuiAgentActivity', () {
    testWidgets('shows thinking shimmer while working', (tester) async {
      await tester.pumpWidget(
        _app(
          const BeuiAgentActivity(
            items: [
              BeuiAgentActivityStep(
                id: '1',
                label: 'Reading brief',
                status: BeuiAgentStepStatus.active,
              ),
            ],
            status: BeuiAgentActivityStatus.working,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(BeuiThinkingShimmer), findsOneWidget);
      expect(find.text('Thinking…'), findsOneWidget);
      expect(find.text('Reading brief'), findsOneWidget);
    });

    testWidgets('uses content-type active label', (tester) async {
      await tester.pumpWidget(
        _app(
          const BeuiAgentActivity(
            items: [
              BeuiAgentActivitySearch(id: 's', query: 'coffee in portland'),
            ],
            status: BeuiAgentActivityStatus.working,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Searching the web…'), findsOneWidget);
      expect(find.text('coffee in portland'), findsOneWidget);
    });

    testWidgets('respects custom activeLabel', (tester) async {
      await tester.pumpWidget(
        _app(
          const BeuiAgentActivity(
            items: [],
            contentType: BeuiAgentActivityContentType.mixed,
            activeLabel: 'Churning through notes…',
            status: BeuiAgentActivityStatus.working,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Churning through notes…'), findsOneWidget);
    });

    testWidgets('shows step summary when complete', (tester) async {
      await tester.pumpWidget(
        _app(
          const BeuiAgentActivity(
            items: [
              BeuiAgentActivityStep(
                id: '1',
                label: 'Parse',
                status: BeuiAgentStepStatus.complete,
              ),
              BeuiAgentActivityStep(
                id: '2',
                label: 'Draft',
                status: BeuiAgentStepStatus.complete,
              ),
            ],
            status: BeuiAgentActivityStatus.complete,
            duration: 5.1,
            defaultOpen: false,
            collapseOnComplete: true,
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Thought for'), findsOneWidget);
      expect(find.textContaining('5s'), findsOneWidget);
      // Collapsed — step labels not visible in the clipped panel.
      expect(find.text('Parse'), findsNothing);
    });

    testWidgets('expands completed stream on summary tap', (tester) async {
      await tester.pumpWidget(
        _app(
          const BeuiAgentActivity(
            items: [
              BeuiAgentActivityStep(
                id: '1',
                label: 'Parse the request',
                status: BeuiAgentStepStatus.complete,
              ),
            ],
            status: BeuiAgentActivityStatus.complete,
            duration: 3,
            defaultOpen: false,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Parse the request'), findsNothing);

      await tester.tap(find.textContaining('Thought for'));
      await tester.pumpAndSettle();
      expect(find.text('Parse the request'), findsOneWidget);
    });

    testWidgets('reports open changes via onOpenChange', (tester) async {
      final opens = <bool>[];
      await tester.pumpWidget(
        _app(
          BeuiAgentActivity(
            items: const [
              BeuiAgentActivityText(id: 't', content: 'hello activity'),
            ],
            status: BeuiAgentActivityStatus.complete,
            defaultOpen: false,
            onOpenChange: opens.add,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.textContaining('Thought for'));
      await tester.pumpAndSettle();
      expect(opens, [true]);
      expect(find.text('hello activity'), findsOneWidget);
    });

    testWidgets('collapseOnComplete collapses after working→complete', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const BeuiAgentActivity(
            items: [
              BeuiAgentActivityStep(
                id: '1',
                label: 'Still visible while working',
                status: BeuiAgentStepStatus.active,
              ),
            ],
            status: BeuiAgentActivityStatus.working,
            collapseOnComplete: true,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Still visible while working'), findsOneWidget);

      await tester.pumpWidget(
        _app(
          const BeuiAgentActivity(
            items: [
              BeuiAgentActivityStep(
                id: '1',
                label: 'Still visible while working',
                status: BeuiAgentStepStatus.complete,
              ),
            ],
            status: BeuiAgentActivityStatus.complete,
            duration: 2,
            collapseOnComplete: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Thought for'), findsOneWidget);
      expect(find.text('Still visible while working'), findsNothing);
    });

    testWidgets('renders tool row with diff counts', (tester) async {
      await tester.pumpWidget(
        _app(
          const BeuiAgentActivity(
            items: [
              BeuiAgentActivityTool(
                id: 'edit',
                action: 'edit',
                target: 'launch-plan.ts',
                additions: 42,
                deletions: 8,
              ),
            ],
            status: BeuiAgentActivityStatus.complete,
            defaultOpen: true,
            collapseOnComplete: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('launch-plan.ts'), findsOneWidget);
      expect(find.text('+42'), findsOneWidget);
      expect(find.text('−8'), findsOneWidget);
      expect(find.textContaining('Ran 1 tool'), findsOneWidget);
    });

    testWidgets('renders search results and more count', (tester) async {
      await tester.pumpWidget(
        _app(
          const BeuiAgentActivity(
            items: [
              BeuiAgentActivitySearch(
                id: 's',
                query: 'portland coffee',
                results: [
                  BeuiAgentSearchResult(
                    id: 'r1',
                    title: 'Heart Coffee',
                    domain: 'heartroasters.com',
                  ),
                ],
                moreCount: 5,
              ),
            ],
            status: BeuiAgentActivityStatus.complete,
            defaultOpen: true,
            collapseOnComplete: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('portland coffee'), findsOneWidget);
      expect(find.text('Heart Coffee'), findsOneWidget);
      expect(find.text('heartroasters.com'), findsOneWidget);
      expect(find.text('+5 more'), findsOneWidget);
      expect(find.text('Searched the web'), findsOneWidget);
    });

    testWidgets('renders trace rows', (tester) async {
      await tester.pumpWidget(
        _app(
          const BeuiAgentActivity(
            items: [
              BeuiAgentActivityTrace(
                id: 't1',
                kind: BeuiAgentTraceKind.run,
                label: 'Shell',
                detail: 'bun test',
              ),
            ],
            status: BeuiAgentActivityStatus.complete,
            defaultOpen: true,
            collapseOnComplete: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Shell'), findsOneWidget);
      expect(find.text('bun test'), findsOneWidget);
    });

    testWidgets('mixed summary counts steps', (tester) async {
      await tester.pumpWidget(
        _app(
          const BeuiAgentActivity(
            items: [
              BeuiAgentActivityStep(
                id: '1',
                label: 'A',
                status: BeuiAgentStepStatus.complete,
              ),
              BeuiAgentActivityTool(id: '2', action: 'read', target: 'a.md'),
            ],
            status: BeuiAgentActivityStatus.complete,
            defaultOpen: false,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Completed 2 steps'), findsOneWidget);
    });

    testWidgets('reduced motion keeps content and summary', (tester) async {
      await tester.pumpWidget(
        _app(
          const BeuiAgentActivity(
            items: [
              BeuiAgentActivityStep(
                id: '1',
                label: 'Done step',
                status: BeuiAgentStepStatus.complete,
              ),
            ],
            status: BeuiAgentActivityStatus.complete,
            duration: 1,
            defaultOpen: true,
            collapseOnComplete: false,
          ),
          reduce: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Done step'), findsOneWidget);
      expect(find.textContaining('Thought for'), findsOneWidget);
    });

    // Regression: Tailwind tracking is `normal`. Material's bodyMedium
    // letterSpacing (0.25 by default) was leaking into every row and widening
    // the stream by ~4% against beui.dev.
    testWidgets('pins tracking to normal against an ambient text theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: [BeuiColors.light()],
            textTheme: const TextTheme(
              bodyMedium: TextStyle(fontSize: 14, letterSpacing: 4),
            ),
          ),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: BeuiAgentActivity(
                  items: [
                    BeuiAgentActivityStep(
                      id: '1',
                      label: 'Reading the launch brief',
                      status: BeuiAgentStepStatus.complete,
                    ),
                  ],
                  status: BeuiAgentActivityStatus.complete,
                  duration: 1,
                  defaultOpen: true,
                  collapseOnComplete: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final style = tester
          .renderObject<RenderParagraph>(find.text('Reading the launch brief'))
          .text
          .style!;
      expect(style.letterSpacing, 0);
    });

    // Regression: the source uses lucide `Globe2` (renamed `earth` in
    // flutter_lucide), not `globe` — different glyph entirely.
    testWidgets('search results fall back to the Globe2/earth glyph', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const BeuiAgentActivity(
            items: [
              BeuiAgentActivitySearch(
                id: 's',
                query: 'coffee',
                results: [
                  BeuiAgentSearchResult(id: 'r', title: 'Heart Coffee'),
                ],
              ),
            ],
            status: BeuiAgentActivityStatus.complete,
            defaultOpen: true,
            collapseOnComplete: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(LucideIcons.earth), findsOneWidget);
      expect(find.byIcon(LucideIcons.globe), findsNothing);
    });
  });

  // A20 — a crashed run must never summarise as a clean one.
  group('BeuiAgentActivity failure states', () {
    testWidgets('failed prefixes the outcome and shows a warning glyph', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const BeuiAgentActivity(
            items: [_failedTool],
            status: BeuiAgentActivityStatus.failed,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Failed · Ran 1 tool'), findsOneWidget);
      expect(find.byIcon(const BeuiAgentIcons().warning), findsOneWidget);
    });

    testWidgets('cancelled prefixes the outcome and shows a close glyph', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const BeuiAgentActivity(
            items: [_failedTool],
            status: BeuiAgentActivityStatus.cancelled,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Cancelled · Ran 1 tool'), findsOneWidget);
      expect(find.byIcon(const BeuiAgentIcons().close), findsOneWidget);
    });

    testWidgets('complete stays bare — no prefix, no glyph', (tester) async {
      await tester.pumpWidget(
        _app(
          const BeuiAgentActivity(
            items: [_failedTool],
            status: BeuiAgentActivityStatus.complete,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Ran 1 tool'), findsOneWidget);
      expect(find.byIcon(const BeuiAgentIcons().warning), findsNothing);
      expect(find.byIcon(const BeuiAgentIcons().close), findsNothing);
    });

    testWidgets('failed renders a card that complete does not', (tester) async {
      Widget activity(BeuiAgentActivityStatus status) =>
          _app(BeuiAgentActivity(items: const [_failedTool], status: status));

      await tester.pumpWidget(activity(BeuiAgentActivityStatus.complete));
      await tester.pump();
      final cleanBoxes = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where((b) => (b.decoration as BoxDecoration).border != null)
          .length;

      await tester.pumpWidget(activity(BeuiAgentActivityStatus.failed));
      await tester.pump();
      final failedBorders = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where((b) => (b.decoration as BoxDecoration).border != null)
          .toList();

      expect(cleanBoxes, 0, reason: 'a clean finish gets no card');
      expect(failedBorders, hasLength(1));
      // Emphasis width, in the failed tier — not a hairline.
      final border = failedBorders.single.decoration as BoxDecoration;
      expect(
        border.border!.top.width,
        const BeuiAgentStructure().emphasisBorderWidth,
      );
      expect(
        border.border!.top.color,
        BeuiAgentStatusColors.light.failed.border,
      );
    });

    testWidgets('cancelled takes the neutral tier at hairline width', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const BeuiAgentActivity(
            items: [_failedTool],
            status: BeuiAgentActivityStatus.cancelled,
          ),
        ),
      );
      await tester.pump();

      final box = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((b) => b.decoration as BoxDecoration)
          .firstWhere((d) => d.border != null);
      expect(box.border!.top.width, const BeuiAgentStructure().borderWidth);
      expect(box.border!.top.color, BeuiAgentStatusColors.light.neutral.border);
    });

    testWidgets('a failure force-opens even with collapseOnComplete', (
      tester,
    ) async {
      Widget activity(BeuiAgentActivityStatus status) => _app(
        BeuiAgentActivity(
          items: const [
            BeuiAgentActivityStep(
              id: '1',
              label: 'Ran the migration',
              status: BeuiAgentStepStatus.complete,
            ),
          ],
          status: status,
        ),
      );

      await tester.pumpWidget(activity(BeuiAgentActivityStatus.working));
      await tester.pump();
      await tester.pumpWidget(activity(BeuiAgentActivityStatus.failed));
      await tester.pumpAndSettle();

      // collapseOnComplete defaults to true; the failure overrides it, because
      // hiding the steps that led to a crash is the bug, not the feature.
      expect(find.text('Ran the migration'), findsOneWidget);
    });

    testWidgets('per-instance failedSummary replaces the whole line', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const BeuiAgentActivity(
            items: [_failedTool],
            status: BeuiAgentActivityStatus.failed,
            failedSummary: 'Failed · rate limited after 1 tool',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Failed · rate limited after 1 tool'), findsOneWidget);
      expect(find.text('Failed · Ran 1 tool'), findsNothing);
    });
  });

  // A27/A29 — every user-facing literal goes through BeuiAgentStrings.
  group('BeuiAgentActivity strings', () {
    testWidgets('a themed BeuiAgentStrings re-spells the whole surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: [
              BeuiColors.light(),
              BeuiAgentTheme(
                strings: BeuiAgentStrings(
                  statusFailed: 'Échec',
                  activityRanTools: _frenchRanTools,
                  activityMoreResults: _frenchMore,
                  // The failure summary's "Failed · <detail>" composition is
                  // its own themeable role (BeuiAgentStrings.
                  // activityFailedSummary) rather than being assembled from
                  // statusFailed at call time — so a full re-spelling
                  // supplies both.
                  activityFailedSummary: (detail) => 'Échec · $detail',
                ),
              ),
            ],
          ),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: BeuiAgentActivity(
                  items: [_failedTool],
                  status: BeuiAgentActivityStatus.failed,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Échec · 1 outil'), findsOneWidget);
    });
  });

  // A36 — no status color literals; both role sets resolve.
  group('BeuiAgentActivity status colors', () {
    Future<void> pumpTool(WidgetTester tester, {required bool dark}) {
      return tester.pumpWidget(
        _app(
          dark: dark,
          const BeuiAgentActivity(
            items: [
              BeuiAgentActivityTool(
                id: 'edit',
                action: 'edit',
                target: 'launch-plan.ts',
                additions: 42,
                deletions: 8,
              ),
            ],
            status: BeuiAgentActivityStatus.complete,
            defaultOpen: true,
            collapseOnComplete: false,
          ),
        ),
      );
    }

    testWidgets('light mode diff counts take the 700 tier', (tester) async {
      await pumpTool(tester, dark: false);
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        tester.widget<Text>(find.text('+42')).style!.color,
        BeuiAgentStatusColors.light.success.foreground,
      );
      expect(
        tester.widget<Text>(find.text('−8')).style!.color,
        BeuiAgentStatusColors.light.failed.foreground,
      );
    });

    // There was no dark-mode test in this cluster at all, despite the widgets
    // branching on brightness.
    testWidgets('dark mode diff counts take the 400 tier', (tester) async {
      await pumpTool(tester, dark: true);
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        tester.widget<Text>(find.text('+42')).style!.color,
        BeuiAgentStatusColors.dark.success.foreground,
      );
      expect(
        tester.widget<Text>(find.text('−8')).style!.color,
        BeuiAgentStatusColors.dark.failed.foreground,
      );
      expect(
        BeuiAgentStatusColors.dark.success.foreground,
        isNot(BeuiAgentStatusColors.light.success.foreground),
      );
    });

    testWidgets('a retinted success tier moves the additions count', (
      tester,
    ) async {
      const teal = Color(0xFF0F766E);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: [
              BeuiColors.light(),
              BeuiAgentTheme(
                statusLight: BeuiAgentStatusColors.light.copyWith(
                  success: BeuiAgentStatusColors.light.success.copyWith(
                    foreground: teal,
                  ),
                ),
              ),
            ],
          ),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: BeuiAgentActivity(
                  items: [
                    BeuiAgentActivityTool(
                      id: 'edit',
                      action: 'edit',
                      target: 'a.ts',
                      additions: 3,
                    ),
                  ],
                  status: BeuiAgentActivityStatus.complete,
                  defaultOpen: true,
                  collapseOnComplete: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<Text>(find.text('+3')).style!.color, teal);
    });
  });

  // A16 — reduced motion drops movement, never the opacity channel.
  group('BeuiAgentActivity reduced motion', () {
    testWidgets('the disclosure cross-fades out instead of hard-cutting', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          reduce: true,
          const BeuiAgentActivity(
            items: [
              BeuiAgentActivityStep(
                id: '1',
                label: 'Parse the request',
                status: BeuiAgentStepStatus.complete,
              ),
            ],
            status: BeuiAgentActivityStatus.complete,
            duration: 3,
            defaultOpen: true,
            collapseOnComplete: false,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Parse the request'), findsOneWidget);

      await tester.tap(find.text('Thought for 3s'));
      await tester.pump();

      // Mid-fade: still mounted and still painting, at a partial opacity. The
      // private copy this replaced returned SizedBox.shrink() on the first
      // frame of a close — a hard cut, which is what the project rule forbids.
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Parse the request'), findsOneWidget);
      final opacity = tester
          .widgetList<Opacity>(
            find.ancestor(
              of: find.text('Parse the request'),
              matching: find.byType(Opacity),
            ),
          )
          .map((o) => o.opacity)
          .fold<double>(1, (a, b) => a * b);
      expect(opacity, greaterThan(0.0));
      expect(opacity, lessThan(1.0));

      // And it does finish.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Parse the request'), findsNothing);
    });
  });

  // A32 / A30 / A31 — the summary trigger is a real disclosure button.
  group('BeuiAgentActivity accessibility', () {
    testWidgets('the summary trigger is a labelled, expandable button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const BeuiAgentActivity(
            items: [
              BeuiAgentActivityStep(
                id: '1',
                label: 'Parse',
                status: BeuiAgentStepStatus.complete,
              ),
            ],
            status: BeuiAgentActivityStatus.complete,
            duration: 3,
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Thought for 3s')),
        isSemantics(
          label: 'Thought for 3s',
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.text('Thought for 3s'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Thought for 3s')),
        isSemantics(hasExpandedState: true, isExpanded: true),
      );
      handle.dispose();
    });

    testWidgets('a terminal outcome announces through a live region', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      Widget activity(BeuiAgentActivityStatus status) =>
          _app(BeuiAgentActivity(items: const [_failedTool], status: status));

      await tester.pumpWidget(activity(BeuiAgentActivityStatus.working));
      await tester.pump();
      // While working, the live region carries the active label.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Running tools…')),
        isSemantics(label: 'Running tools…', isLiveRegion: true),
      );

      await tester.pumpWidget(activity(BeuiAgentActivityStatus.failed));
      await tester.pumpAndSettle();

      // The old `liveRegion: _working` switched off at exactly this moment, so
      // "Failed" was never spoken.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Failed')),
        isSemantics(label: 'Failed', isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('completion announces too', (tester) async {
      final handle = tester.ensureSemantics();
      Widget activity(BeuiAgentActivityStatus status) =>
          _app(BeuiAgentActivity(items: const [_failedTool], status: status));
      await tester.pumpWidget(activity(BeuiAgentActivityStatus.working));
      await tester.pump();
      await tester.pumpWidget(activity(BeuiAgentActivityStatus.complete));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Completed')),
        isSemantics(label: 'Completed', isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('every tappable target carries a label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const BeuiAgentActivity(
            items: [_failedTool],
            status: BeuiAgentActivityStatus.complete,
            duration: 3,
          ),
        ),
      );
      await tester.pump();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    // The visual stays at the source's 28px `h-7`; BeuiMinHitTarget grows
    // only the hit area, so this is asserted by tapping outside the paint.
    // `androidTapTargetGuideline` measures the *semantics* rect, which follows
    // the paint, so it cannot see hit slop and is not the instrument here.
    //
    // The slop overhangs into whatever is adjacent, which means it only buys
    // anything where there is adjacent space to take: with the panel open, the
    // 8px below the trigger falls in the stream's own `py-2` padding, where
    // nothing else is interactive.
    testWidgets('the trigger accepts a tap below its painted box', (
      tester,
    ) async {
      final opens = <bool>[];
      await tester.pumpWidget(
        _app(
          BeuiAgentActivity(
            items: const [_failedTool],
            status: BeuiAgentActivityStatus.complete,
            duration: 3,
            defaultOpen: true,
            collapseOnComplete: false,
            onOpenChange: opens.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final trigger = tester.getRect(find.text('Ran 1 tool'));
      final panelTop = tester.getRect(find.byType(BeuiAgentActivity)).top + 28;
      // 4px into the panel's padding — outside the 28px visual, inside the
      // 44px slop.
      await tester.tapAt(Offset(trigger.left + 4, panelTop + 4));
      await tester.pumpAndSettle();
      expect(opens, [false]);
    });
  });

  // A32 — keyboard operability.
  group('BeuiAgentActivity keyboard', () {
    Future<List<bool>> activate(
      WidgetTester tester,
      LogicalKeyboardKey key,
    ) async {
      final opens = <bool>[];
      await tester.pumpWidget(
        _app(
          BeuiAgentActivity(
            items: const [_failedTool],
            status: BeuiAgentActivityStatus.complete,
            duration: 3,
            onOpenChange: opens.add,
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      return opens;
    }

    testWidgets('Tab then Enter toggles', (tester) async {
      expect(await activate(tester, LogicalKeyboardKey.enter), [true]);
    });

    testWidgets('Tab then Space toggles', (tester) async {
      expect(await activate(tester, LogicalKeyboardKey.space), [true]);
    });
  });

  // A24 — a short run must not reserve a screenful of blank.
  testWidgets('a working viewport sizes to its content, not to maxHeight', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const BeuiAgentActivity(
          items: [BeuiAgentActivityText(id: 't', content: 'One short line')],
          maxHeight: 208,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final height = tester.getSize(find.byType(BeuiAgentActivity)).height;
    // Header (28) + one padded row (~44) — nowhere near 28 + 208.
    expect(height, lessThan(120));
  });

  testWidgets('a long working stream still pins at maxHeight', (tester) async {
    await tester.pumpWidget(
      _app(
        BeuiAgentActivity(
          items: [
            for (var i = 0; i < 20; i++)
              BeuiAgentActivityText(id: '$i', content: 'Line $i'),
          ],
          maxHeight: 120,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final height = tester.getSize(find.byType(BeuiAgentActivity)).height;
    expect(height, lessThanOrEqualTo(28 + 120 + 1));
    expect(height, greaterThan(120));
  });

  testWidgets('golden — complete summary, open stream, and a failed card', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(460, 460));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: BeuiTextTheme.trackingNormal(
          ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        ),
        home: const Scaffold(
          body: Center(child: RepaintBoundary(child: _ActivityGolden())),
        ),
      ),
    );
    // Two fixed advances, never pumpAndSettle: the step pulse is an indefinite
    // ticker. The first pump lets the item entrances start (they are armed in
    // a post-frame callback, so a ticker started there takes the following
    // frame as its zero); the second settles them.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(_ActivityGolden),
      matchesGoldenFile('goldens/beui_agent_activity.png'),
    );
  });

  // While `working`, `canScroll` is false — the stream is an OverflowBox
  // inside a ClipRect, and the `streamOffset` translate is the ONLY thing that
  // brings newly appended rows up into view. That translate was driven by a
  // `SingleMotionBuilder` handed `const NoMotion()` under reduced motion, and
  // NoMotion holds its seeded value forever rather than snapping to the target
  // (see `_no_motion_semantics_test.dart`). It therefore stayed at 0, and
  // every row past the first screenful was clipped away permanently — the
  // stream appeared to stop updating.
  group('BeuiAgentActivity reduced-motion stream reveal', () {
    testWidgets('keeps the newest row inside the viewport while working', (
      tester,
    ) async {
      const rows = 18;
      Widget stream(int count) => _app(
        BeuiAgentActivity(
          items: [
            for (var i = 0; i < count; i++)
              BeuiAgentActivityText(id: 'step-$i', content: 'Step $i'),
          ],
          maxHeight: 120,
          defaultOpen: true,
        ),
        reduce: true,
      );

      // Three stages, and all three matter.
      //
      // Mounting straight into the final list hides the bug entirely, and so
      // does a single append: the frame on which the stream FIRST overflows is
      // also the frame `capped` flips true, which inserts the scroll fade mask
      // above the stream and so remounts the motion builder underneath it. A
      // fresh controller is seeded with `initialValue == value`, which renders
      // the correct offset even under NoMotion.
      //
      // The defect is in every append AFTER that: the stream is already
      // capped, nothing remounts, and the frozen translate simply stops
      // tracking. That is the real usage — rows arrive one at a time for the
      // whole run.
      await tester.pumpWidget(stream(3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Stage 2: first overflow (this one remounts).
      await tester.pumpWidget(stream(8));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      // Stage 3: append to an already-capped stream — no remount, no excuse.
      await tester.pumpWidget(stream(rows));
      // `_measure` runs in a post-frame callback, so the new layout only
      // exists from the following frame on.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      // The clipped viewport: the OverflowBox the rows actually live inside
      // (the widget has others, e.g. in the working header).
      final overflow = find
          .ancestor(of: find.text('Step 0'), matching: find.byType(OverflowBox))
          .first;
      final viewport = tester.getRect(overflow);

      final last = tester.getRect(find.text('Step ${rows - 1}'));

      expect(
        last.bottom,
        lessThanOrEqualTo(viewport.bottom + 1),
        reason:
            'the newest row is clipped below the fold — the stream translate '
            'froze at 0 (viewport=$viewport last=$last)',
      );
      expect(
        last.top,
        greaterThanOrEqualTo(viewport.top - 1),
        reason: 'the newest row must not be pushed above the viewport either',
      );
    });
  });
}

String _frenchRanTools(int count) =>
    '$count ${count == 1 ? 'outil' : 'outils'}';
String _frenchMore(int count) => '+$count de plus';

/// The golden subject: a clean finish over a failed run, so one image locks
/// both the source-fidelity summary and the new failure card.
class _ActivityGolden extends StatelessWidget {
  const _ActivityGolden();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BeuiAgentActivity(
            items: [
              BeuiAgentActivityStep(
                id: 'a',
                label: 'Parse the request',
                status: BeuiAgentStepStatus.complete,
              ),
              BeuiAgentActivityTool(
                id: 'b',
                action: 'edit',
                target: 'launch-plan.ts',
                additions: 42,
                deletions: 8,
              ),
            ],
            status: BeuiAgentActivityStatus.complete,
            duration: 4.6,
            defaultOpen: true,
            collapseOnComplete: false,
            maxHeight: 160,
          ),
          const SizedBox(height: 24),
          BeuiAgentActivity(
            items: const [
              BeuiAgentActivityTrace(
                id: 'c',
                kind: BeuiAgentTraceKind.run,
                label: 'Shell',
                detail: 'bun test launch',
              ),
            ],
            status: BeuiAgentActivityStatus.failed,
            defaultOpen: true,
            maxHeight: 120,
          ),
          const SizedBox(height: 24),
          const BeuiAgentActivity(
            items: [
              BeuiAgentActivityTrace(
                id: 'd',
                kind: BeuiAgentTraceKind.thinking,
                label: 'Plan',
              ),
            ],
            status: BeuiAgentActivityStatus.cancelled,
            defaultOpen: false,
            maxHeight: 120,
          ),
        ],
      ),
    );
  }
}
