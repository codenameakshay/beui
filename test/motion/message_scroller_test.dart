import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

Widget _wrap(
  Widget child, {
  bool reduce = false,
  Size surface = const Size(400, 360),
}) => beuiTestApp(
  SizedBox(height: surface.height, child: child),
  width: surface.width,
  reduce: reduce,
);

Widget _tallMessages(int count) {
  return BeuiMessageGroup(
    spacing: BeuiMessageSpacing.standard,
    children: [
      for (var i = 0; i < count; i++)
        BeuiMessageScrollerAnchor(
          id: 'm$i',
          label: 'Message $i — ${i.isEven ? 'user prompt' : 'assistant reply'}',
          description: i.isEven ? 'Assistant reply $i' : null,
          from: i.isEven ? BeuiMessageFrom.user : BeuiMessageFrom.assistant,
          child: BeuiMessage(
            from: i.isEven ? BeuiMessageFrom.user : BeuiMessageFrom.assistant,
            children: [
              BeuiMessageContent(
                children: [
                  BeuiMessageBubble(
                    variant: i.isEven
                        ? BeuiMessageBubbleVariant.solid
                        : BeuiMessageBubbleVariant.soft,
                    child: BeuiMessageBubbleContent(
                      child: SizedBox(
                        height: 72,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            i.isEven
                                ? 'User message number $i with enough height'
                                : 'Assistant message number $i with enough height',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
    ],
  );
}

void main() {
  group('BeuiMessageScroller', () {
    testWidgets('renders conversation content', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiMessageScroller(
            child: BeuiMessageGroup(
              children: const [
                BeuiMessage(
                  from: BeuiMessageFrom.user,
                  children: [
                    BeuiMessageContent(
                      children: [
                        BeuiMessageBubble(
                          variant: BeuiMessageBubbleVariant.solid,
                          child: BeuiMessageBubbleContent(
                            child: Text('Hello from user'),
                          ),
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
                          child: BeuiMessageBubbleContent(
                            child: Text('Hello from assistant'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Hello from user'), findsOneWidget);
      expect(find.text('Hello from assistant'), findsOneWidget);
      expect(find.byType(BeuiMessageScroller), findsOneWidget);
    });

    testWidgets('exposes conversation semantics label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiMessageScroller(
            label: 'Transcript',
            child: SizedBox(height: 40, child: Text('x')),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Transcript'), findsWidgets);
    });

    testWidgets('sticks to bottom when content grows while following', (
      tester,
    ) async {
      final key = GlobalKey<BeuiMessageScrollerState>();
      var count = 4;

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  Expanded(
                    child: BeuiMessageScroller(
                      key: key,
                      followOutput: true,
                      smooth: false,
                      child: _tallMessages(count),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => count += 2),
                    child: const Text('append'),
                  ),
                ],
              );
            },
          ),
          surface: const Size(400, 400),
        ),
      );
      await tester.pumpAndSettle();

      final state = key.currentState!;
      expect(state.isFollowing, isTrue);

      // Grow content.
      await tester.tap(find.text('append'));
      await tester.pumpAndSettle();

      expect(state.isFollowing, isTrue);
      // Last message should be visible (near bottom).
      expect(
        find.textContaining('User message number ${count - 2}'),
        findsOneWidget,
      );
    });

    testWidgets('releases follow when user scrolls away from live edge', (
      tester,
    ) async {
      final key = GlobalKey<BeuiMessageScrollerState>();
      final followLog = <bool>[];

      await tester.pumpWidget(
        _wrap(
          BeuiMessageScroller(
            key: key,
            followOutput: true,
            followThreshold: 56,
            smooth: false,
            onFollowChange: followLog.add,
            child: _tallMessages(12),
          ),
          surface: const Size(400, 320),
        ),
      );
      await tester.pumpAndSettle();

      final state = key.currentState!;
      expect(state.isFollowing, isTrue);

      // Drag content down → scroll offset decreases (read history).
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 400),
      );
      await tester.pumpAndSettle();

      expect(state.isFollowing, isFalse);
      expect(followLog, contains(false));
    });

    testWidgets('rail appears when overflowing with multiple anchors', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BeuiMessageScroller(
            navigation: BeuiMessageScrollerNavigation.rail,
            smooth: false,
            child: _tallMessages(10),
          ),
          surface: const Size(400, 320),
        ),
      );
      await tester.pumpAndSettle();

      // Rail semantics label.
      expect(find.bySemanticsLabel('Message navigation'), findsOneWidget);
      // Tick buttons for messages.
      expect(
        find.bySemanticsLabel(RegExp(r'Go to (user|assistant) message')),
        findsWidgets,
      );
    });

    testWidgets('rail hidden when content fits without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BeuiMessageScroller(
            navigation: BeuiMessageScrollerNavigation.rail,
            smooth: false,
            child: BeuiMessageGroup(
              children: [
                BeuiMessageScrollerAnchor(
                  id: 'only',
                  label: 'Only message',
                  child: BeuiMessage(
                    from: BeuiMessageFrom.assistant,
                    children: const [
                      BeuiMessageContent(
                        children: [
                          BeuiMessageBubble(
                            child: BeuiMessageBubbleContent(
                              child: Text('Short'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          surface: const Size(400, 400),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Message navigation'), findsNothing);
    });

    testWidgets('selecting last rail item re-attaches follow', (tester) async {
      final key = GlobalKey<BeuiMessageScrollerState>();

      await tester.pumpWidget(
        _wrap(
          BeuiMessageScroller(
            key: key,
            navigation: BeuiMessageScrollerNavigation.rail,
            smooth: false,
            child: _tallMessages(10),
          ),
          surface: const Size(400, 320),
        ),
      );
      await tester.pumpAndSettle();

      final state = key.currentState!;
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 400),
      );
      await tester.pumpAndSettle();
      expect(state.isFollowing, isFalse);

      state.scrollToId('m9');
      await tester.pumpAndSettle();
      expect(state.isFollowing, isTrue);
    });

    testWidgets('busy flag surfaces on conversation semantics', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiMessageScroller(
            busy: true,
            label: 'Conversation',
            child: SizedBox(height: 20, child: Text('streaming')),
          ),
        ),
      );
      expect(find.bySemanticsLabel(RegExp(r'busy')), findsWidgets);
    });

    testWidgets('reduced motion still follows without throwing', (
      tester,
    ) async {
      final key = GlobalKey<BeuiMessageScrollerState>();
      await tester.pumpWidget(
        _wrap(
          BeuiMessageScroller(
            key: key,
            followOutput: true,
            smooth: true,
            child: _tallMessages(8),
          ),
          reduce: true,
          surface: const Size(400, 320),
        ),
      );
      await tester.pumpAndSettle();
      key.currentState!.scrollToEnd(smooth: true);
      await tester.pumpAndSettle();
      expect(key.currentState!.isFollowing, isTrue);
      // Off-stage content still exists in the tree; assert the viewport is
      // pinned to the live edge instead of searching for missing text.
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(
        scrollable.position.pixels,
        closeTo(scrollable.position.maxScrollExtent, 1),
      );
    });

    testWidgets('explicit railItems override anchor labels', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiMessageScroller(
            navigation: BeuiMessageScrollerNavigation.rail,
            smooth: false,
            railItems: const [
              BeuiMessageScrollerRailItem(
                id: 'm0',
                label: 'Custom A',
                from: BeuiMessageFrom.user,
              ),
              BeuiMessageScrollerRailItem(
                id: 'm1',
                label: 'Custom B',
                from: BeuiMessageFrom.assistant,
              ),
              BeuiMessageScrollerRailItem(
                id: 'm2',
                label: 'Custom C',
                from: BeuiMessageFrom.user,
              ),
              BeuiMessageScrollerRailItem(
                id: 'm3',
                label: 'Custom D',
                from: BeuiMessageFrom.assistant,
              ),
              BeuiMessageScrollerRailItem(
                id: 'm4',
                label: 'Custom E',
                from: BeuiMessageFrom.user,
              ),
              BeuiMessageScrollerRailItem(
                id: 'm5',
                label: 'Custom F',
                from: BeuiMessageFrom.assistant,
              ),
            ],
            child: _tallMessages(6),
          ),
          surface: const Size(400, 280),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(RegExp(r'Go to user message: Custom A')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Go to assistant message: Custom B')),
        findsOneWidget,
      );
    });

    testWidgets('followOutput false never auto-pins', (tester) async {
      final key = GlobalKey<BeuiMessageScrollerState>();
      await tester.pumpWidget(
        _wrap(
          BeuiMessageScroller(
            key: key,
            followOutput: false,
            smooth: false,
            child: _tallMessages(10),
          ),
          surface: const Size(400, 320),
        ),
      );
      await tester.pumpAndSettle();
      expect(key.currentState!.isFollowing, isFalse);
      // First message still reachable near top.
      expect(find.textContaining('User message number 0'), findsOneWidget);
    });

    testWidgets(
      'stays pinned at the live edge while an approval card expands',
      (tester) async {
        final key = GlobalKey<BeuiMessageScrollerState>();
        var expanded = false;

        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (context, setState) {
                return BeuiMessageScroller(
                  key: key,
                  followOutput: true,
                  smooth: false,
                  child: BeuiMessageGroup(
                    spacing: BeuiMessageSpacing.standard,
                    children: [
                      ...List<Widget>.generate(
                        6,
                        (i) => BeuiMessage(
                          from: i.isEven
                              ? BeuiMessageFrom.user
                              : BeuiMessageFrom.assistant,
                          children: [
                            BeuiMessageContent(
                              children: [
                                BeuiMessageBubble(
                                  variant: i.isEven
                                      ? BeuiMessageBubbleVariant.solid
                                      : BeuiMessageBubbleVariant.soft,
                                  child: BeuiMessageBubbleContent(
                                    child: SizedBox(
                                      height: 48,
                                      child: Text('row $i'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      BeuiMessage(
                        from: BeuiMessageFrom.assistant,
                        children: [
                          BeuiMessageContent(
                            children: [
                              BeuiApprovalCard(
                                title: 'Confirm this step?',
                                onApprove: () {},
                                expanded: expanded,
                                onExpandedChanged: (v) =>
                                    setState(() => expanded = v),
                                compactChild: const Text('Compact proposal'),
                                expandedChild: const SizedBox(
                                  height: 220,
                                  child: Text('Expanded editor'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            surface: const Size(400, 360),
          ),
        );
        await tester.pumpAndSettle();
        expect(key.currentState!.isFollowing, isTrue);

        await tester.tap(find.byKey(const ValueKey('beui-approval-expand')));
        await tester.pumpAndSettle();
        expect(expanded, isTrue);
        expect(key.currentState!.isFollowing, isTrue);
        expect(find.text('Expanded editor'), findsWidgets);
      },
    );

    testWidgets(
      'does not re-pin when an approval card expands after the reader left',
      (tester) async {
        final key = GlobalKey<BeuiMessageScrollerState>();
        var expanded = false;

        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => expanded = true),
                      child: const Text('expand-card'),
                    ),
                    Expanded(
                      child: BeuiMessageScroller(
                        key: key,
                        followOutput: true,
                        smooth: false,
                        child: BeuiMessageGroup(
                          spacing: BeuiMessageSpacing.standard,
                          children: [
                            ...List<Widget>.generate(
                              8,
                              (i) => BeuiMessage(
                                from: i.isEven
                                    ? BeuiMessageFrom.user
                                    : BeuiMessageFrom.assistant,
                                children: [
                                  BeuiMessageContent(
                                    children: [
                                      BeuiMessageBubble(
                                        variant: i.isEven
                                            ? BeuiMessageBubbleVariant.solid
                                            : BeuiMessageBubbleVariant.soft,
                                        child: BeuiMessageBubbleContent(
                                          child: SizedBox(
                                            height: 64,
                                            child: Text('history $i'),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            BeuiMessage(
                              from: BeuiMessageFrom.assistant,
                              children: [
                                BeuiMessageContent(
                                  children: [
                                    BeuiApprovalCard(
                                      title: 'Confirm this step?',
                                      onApprove: () {},
                                      expanded: expanded,
                                      compactChild: const Text(
                                        'Compact proposal',
                                      ),
                                      expandedChild: const SizedBox(
                                        height: 220,
                                        child: Text('Expanded editor'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            surface: const Size(400, 360),
          ),
        );
        await tester.pumpAndSettle();
        expect(key.currentState!.isFollowing, isTrue);

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, 500),
        );
        await tester.pumpAndSettle();
        expect(key.currentState!.isFollowing, isFalse);

        await tester.tap(find.text('expand-card'));
        await tester.pumpAndSettle();
        expect(key.currentState!.isFollowing, isFalse);
      },
    );
  });
}
