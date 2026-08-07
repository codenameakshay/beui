import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool reduce = false}) {
  Widget body = child;
  if (reduce) {
    body = MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: body,
    );
  }
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(
      body: Center(child: SizedBox(width: 400, child: body)),
    ),
  );
}

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
}
