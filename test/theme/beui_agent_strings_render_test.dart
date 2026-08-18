/// Sentinel-value tests: every new [BeuiAgentStrings] field is asserted to
/// *reach* a render path, not merely to exist.
///
/// A theme field that nothing reads is worse than a hardcoded literal — it
/// looks localized and is not. That is exactly the class of bug the
/// verification pass found (six dead approval-card fields, five widget
/// parameters whose English defaults beat the role to the fallback slot), so
/// each field here is overridden with a value no widget could produce on its
/// own and then looked for on screen.
library;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {required BeuiAgentStrings strings, Size? surface}) {
  final size = surface ?? const Size(400, 400);
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(
        extensions: [
          BeuiColors.light(),
          BeuiAgentTheme(strings: strings),
        ],
      ),
    ),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: size.width, height: size.height, child: child),
      ),
    ),
  );
}

/// True when any [Semantics] widget in the tree carries [label] verbatim.
bool _labelled(WidgetTester tester, String label) => tester
    .widgetList<Semantics>(find.byType(Semantics))
    .any((s) => s.properties.label == label);

/// True when any [Tooltip] in the tree carries [message].
bool _tooltipped(WidgetTester tester, String message) => tester
    .widgetList<Tooltip>(find.byType(Tooltip))
    .any((t) => t.message == message);

String _lines(int n) =>
    [for (var i = 0; i < n; i++) 'const line$i = $i;'].join('\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('code block and file diff copy (F21)', () {
    testWidgets('copyCode reaches the code block copy control', (tester) async {
      await tester.pumpWidget(
        _host(
          BeuiCodeBlock(code: 'x', onCopy: () async {}),
          strings: const BeuiAgentStrings(copyCode: 'SENTINEL copy code'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_labelled(tester, 'SENTINEL copy code'), isTrue);
    });

    testWidgets('copyDiff reaches the diff copy control', (tester) async {
      await tester.pumpWidget(
        _host(
          BeuiFileDiff(
            file: 'src/a.ts',
            lines: const [
              BeuiFileDiffLine(
                id: 'a',
                type: BeuiFileDiffLineType.added,
                newLine: 1,
                content: 'const a = 1;',
              ),
            ],
            status: BeuiFileDiffStatus.complete,
            collapseOnComplete: false,
            onCopy: () async {},
          ),
          strings: const BeuiAgentStrings(copyDiff: 'SENTINEL copy diff'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_labelled(tester, 'SENTINEL copy diff'), isTrue);
    });
  });

  group('hidden-content copy (F13)', () {
    testWidgets('hiddenLines reaches a capped code block', (tester) async {
      await tester.pumpWidget(
        _host(
          BeuiCodeBlock(code: _lines(60), maxHeight: 120),
          strings: BeuiAgentStrings(hiddenLines: (n) => 'SENTINEL hidden $n'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('SENTINEL hidden'), findsOneWidget);
    });

    testWidgets('hiddenLines reaches a capped tool result', (tester) async {
      await tester.pumpWidget(
        _host(
          BeuiToolResult(
            tool: 'terminal.run',
            title: 'Checks',
            status: BeuiToolResultStatus.success,
            collapseOnComplete: false,
            maxHeight: 120,
            child: BeuiToolResultOutput(code: _lines(60)),
          ),
          strings: BeuiAgentStrings(hiddenLines: (n) => 'SENTINEL hidden $n'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('SENTINEL hidden'), findsWidgets);
    });

    testWidgets('expandHiddenLines reaches an expandable hunk', (tester) async {
      await tester.pumpWidget(
        _host(
          BeuiFileDiff(
            file: 'src/a.ts',
            lines: const [
              BeuiFileDiffLine(
                id: 'a',
                type: BeuiFileDiffLineType.context,
                oldLine: 1,
                newLine: 1,
                content: 'a',
              ),
              BeuiFileDiffLine(
                id: 'b',
                type: BeuiFileDiffLineType.context,
                oldLine: 31,
                newLine: 31,
                content: 'b',
              ),
            ],
            status: BeuiFileDiffStatus.complete,
            collapseOnComplete: false,
            onExpandContext: (_) {},
          ),
          strings: BeuiAgentStrings(
            expandHiddenLines: (n) => 'SENTINEL expand $n',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SENTINEL expand 29'), findsOneWidget);
    });

    testWidgets('hiddenLinesCollapsed reaches a static hunk', (tester) async {
      await tester.pumpWidget(
        _host(
          const BeuiFileDiff(
            file: 'src/a.ts',
            lines: [
              BeuiFileDiffLine(
                id: 'a',
                type: BeuiFileDiffLineType.context,
                oldLine: 1,
                newLine: 1,
                content: 'a',
              ),
              BeuiFileDiffLine(
                id: 'b',
                type: BeuiFileDiffLineType.context,
                oldLine: 31,
                newLine: 31,
                content: 'b',
              ),
            ],
            status: BeuiFileDiffStatus.complete,
            collapseOnComplete: false,
          ),
          strings: BeuiAgentStrings(
            hiddenLinesCollapsed: _sentinelHiddenCollapsed,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SENTINEL static 29'), findsOneWidget);
    });
  });

  group('streaming response screen-reader names (F22)', () {
    Future<void> pumpStatus(
      WidgetTester tester,
      BeuiStreamingResponseStatus status,
    ) async {
      await tester.pumpWidget(
        _host(
          BeuiStreamingResponse(status: status, child: const Text('hello')),
          strings: const BeuiAgentStrings(
            responseSemantics: 'SENTINEL settled',
            responseBusySemantics: 'SENTINEL busy',
            responseFailedSemantics: 'SENTINEL failed',
            responseStoppedSemantics: 'SENTINEL stopped',
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('streaming', (tester) async {
      await pumpStatus(tester, BeuiStreamingResponseStatus.streaming);
      expect(_labelled(tester, 'SENTINEL busy'), isTrue);
    });

    testWidgets('complete', (tester) async {
      await pumpStatus(tester, BeuiStreamingResponseStatus.complete);
      expect(_labelled(tester, 'SENTINEL settled'), isTrue);
    });

    testWidgets('error', (tester) async {
      await pumpStatus(tester, BeuiStreamingResponseStatus.error);
      expect(_labelled(tester, 'SENTINEL failed'), isTrue);
    });

    testWidgets('stopped', (tester) async {
      await pumpStatus(tester, BeuiStreamingResponseStatus.stopped);
      expect(_labelled(tester, 'SENTINEL stopped'), isTrue);
    });
  });

  group('message scroller (F20)', () {
    Widget tallMessages(int count) => BeuiMessageGroup(
      children: [
        for (var i = 0; i < count; i++)
          BeuiMessageScrollerAnchor(
            id: 'm$i',
            label: 'Message $i',
            from: i.isEven ? BeuiMessageFrom.user : BeuiMessageFrom.assistant,
            child: BeuiMessage(
              from: i.isEven ? BeuiMessageFrom.user : BeuiMessageFrom.assistant,
              children: [
                BeuiMessageContent(
                  children: [
                    BeuiMessageBubble(
                      child: BeuiMessageBubbleContent(
                        child: SizedBox(height: 72, child: Text('body $i')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );

    testWidgets('conversation reaches the transcript label', (tester) async {
      await tester.pumpWidget(
        _host(
          BeuiMessageScroller(smooth: false, child: tallMessages(4)),
          strings: const BeuiAgentStrings(conversation: 'SENTINEL transcript'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_labelled(tester, 'SENTINEL transcript'), isTrue);
    });

    testWidgets('messageNavigation reaches the rail label', (tester) async {
      await tester.pumpWidget(
        _host(
          BeuiMessageScroller(
            navigation: BeuiMessageScrollerNavigation.rail,
            smooth: false,
            child: tallMessages(10),
          ),
          strings: const BeuiAgentStrings(messageNavigation: 'SENTINEL rail'),
          surface: const Size(400, 320),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('SENTINEL rail'), findsOneWidget);
    });
  });

  group('image generation and prompt input (F20)', () {
    testWidgets('stopGenerating reaches the cancel control', (tester) async {
      await tester.pumpWidget(
        _host(
          BeuiImageGeneration(
            status: BeuiImageGenerationStatus.generating,
            onCancel: () {},
          ),
          strings: const BeuiAgentStrings(stopGenerating: 'SENTINEL stop'),
        ),
      );
      // A generating frame shimmers forever, so settle is not available.
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _labelled(tester, 'SENTINEL stop') ||
            _tooltipped(tester, 'SENTINEL stop'),
        isTrue,
      );
    });

    testWidgets('promptPlaceholder and promptSemanticLabel reach the field', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BeuiPromptInput(),
          strings: const BeuiAgentStrings(
            promptPlaceholder: 'SENTINEL placeholder',
            promptSemanticLabel: 'SENTINEL field',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SENTINEL placeholder'), findsOneWidget);
      expect(_labelled(tester, 'SENTINEL field'), isTrue);
    });
  });

  group('approval card fields that had gone dead (F19)', () {
    testWidgets('approvalCardTitle reaches the header', (tester) async {
      await tester.pumpWidget(
        _host(
          const BeuiApprovalCard(),
          strings: const BeuiAgentStrings(
            approvalCardTitle: 'SENTINEL approval title',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SENTINEL approval title'), findsOneWidget);
    });

    testWidgets('dismiss reaches the close control', (tester) async {
      await tester.pumpWidget(
        _host(
          BeuiApprovalCard(onDismiss: () {}),
          strings: const BeuiAgentStrings(dismiss: 'SENTINEL dismiss'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_labelled(tester, 'SENTINEL dismiss'), isTrue);
    });

    testWidgets(
      'previousQuestion, nextQuestion and customAnswerPlaceholder reach the '
      'question flow',
      (tester) async {
        await tester.pumpWidget(
          _host(
            const BeuiApprovalCard(
              questions: [
                BeuiApprovalCardQuestion(
                  id: 'q1',
                  title: 'First?',
                  allowCustom: true,
                ),
                BeuiApprovalCardQuestion(id: 'q2', title: 'Second?'),
              ],
            ),
            strings: const BeuiAgentStrings(
              previousQuestion: 'SENTINEL prev',
              nextQuestion: 'SENTINEL next',
              customAnswerPlaceholder: 'SENTINEL custom',
            ),
            surface: const Size(400, 500),
          ),
        );
        await tester.pumpAndSettle();
        expect(_tooltipped(tester, 'SENTINEL prev'), isTrue);
        expect(_tooltipped(tester, 'SENTINEL next'), isTrue);
        expect(find.text('SENTINEL custom'), findsOneWidget);
      },
    );
  });
}

String _sentinelHiddenCollapsed(int n) => 'SENTINEL static $n';
