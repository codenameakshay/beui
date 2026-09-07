import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduce = false}) {
  Widget body = Center(child: SizedBox(width: 400, child: child));
  if (reduce) {
    final inner = body;
    body = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(body: body),
  );
}

void main() {
  group('BeuiMessage', () {
    testWidgets('renders from-labeled row with content', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiMessage(
            from: BeuiMessageFrom.assistant,
            children: [
              BeuiMessageContent(
                children: [
                  BeuiMessageBubble(
                    child: BeuiMessageBubbleContent(
                      child: Text('Hello assistant'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(find.text('Hello assistant'), findsOneWidget);
      expect(find.byType(BeuiMessage), findsOneWidget);
      expect(find.bySemanticsLabel('assistant message'), findsOneWidget);
    });

    testWidgets('user row exposes user message semantics', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiMessage(
            from: BeuiMessageFrom.user,
            children: [
              BeuiMessageContent(
                children: [
                  BeuiMessageBubble(
                    variant: BeuiMessageBubbleVariant.solid,
                    child: BeuiMessageBubbleContent(child: Text('Hi')),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(find.bySemanticsLabel('user message'), findsOneWidget);
    });

    testWidgets('publishes side scope for bubbles', (tester) async {
      BeuiMessageBubbleSide? side;
      await tester.pumpWidget(
        _wrap(
          BeuiMessage(
            from: BeuiMessageFrom.user,
            children: [
              BeuiMessageContent(
                children: [
                  Builder(
                    builder: (context) {
                      side = BeuiMessageSideScope.maybeOf(context);
                      return const BeuiMessageBubble(
                        child: BeuiMessageBubbleContent(child: Text('x')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(side, BeuiMessageBubbleSide.end);
    });
  });

  group('BeuiMessageGroup', () {
    testWidgets('stacks rows with compact gap', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiMessageGroup(
            children: [
              BeuiMessage(
                from: BeuiMessageFrom.user,
                children: [
                  BeuiMessageContent(
                    children: [
                      BeuiMessageBubble(
                        variant: BeuiMessageBubbleVariant.solid,
                        child: BeuiMessageBubbleContent(child: Text('A')),
                      ),
                    ],
                  ),
                ],
              ),
              BeuiMessage(
                from: BeuiMessageFrom.assistant,
                children: [
                  BeuiMessageContent(
                    children: [
                      BeuiMessageBubble(
                        child: BeuiMessageBubbleContent(child: Text('B')),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      // Measured between the row widgets themselves (not their bubble text)
      // so bubble padding doesn't leak into the gap being measured.
      final rows = find.byType(BeuiMessage);
      final gap =
          tester.getTopLeft(rows.at(1)).dy -
          tester.getBottomLeft(rows.at(0)).dy;
      // Compact spacing: default BeuiAgentLayout.groupedMessageSpacing = 6.
      expect(gap, moreOrLessEquals(6, epsilon: 0.5));
    });
  });

  group('BeuiMessageAvatar', () {
    testWidgets('placeholder reserves space but hides content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: const Scaffold(
            body: Center(
              child: BeuiMessageAvatar(placeholder: true, child: Text('AK')),
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(BeuiMessageAvatar));
      expect(size.width, 28);
      expect(size.height, 28);
    });
  });

  group('BeuiMessageTyping', () {
    testWidgets('exposes label to semantics', (tester) async {
      await tester.pumpWidget(
        _wrap(const BeuiMessageTyping(label: 'Thinking')),
      );
      expect(find.bySemanticsLabel('Thinking'), findsOneWidget);
    });
  });
}
