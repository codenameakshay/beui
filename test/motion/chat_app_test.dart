import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(
  Widget child, {
  bool reduce = false,
  Size surface = const Size(900, 640),
}) {
  Widget body = Center(
    child: SizedBox(width: surface.width, height: surface.height, child: child),
  );
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
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: body),
  );
}

void main() {
  group('BeuiChatApp', () {
    testWidgets('renders body content', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiChatApp(body: Center(child: Text('Conversation body'))),
        ),
      );

      expect(find.text('Conversation body'), findsOneWidget);
      expect(find.byType(BeuiChatApp), findsOneWidget);
    });

    testWidgets('lays out sidebar, header, body, and prompt', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiChatApp(
            sidebar: const ColoredBox(
              color: Colors.red,
              child: Center(child: Text('Sidebar')),
            ),
            header: const SizedBox(
              height: 48,
              child: Center(child: Text('Header')),
            ),
            body: const Center(child: Text('Body')),
            prompt: const SizedBox(
              height: 56,
              child: Center(child: Text('Prompt')),
            ),
          ),
        ),
      );

      expect(find.text('Sidebar'), findsOneWidget);
      expect(find.text('Header'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
      expect(find.text('Prompt'), findsOneWidget);
    });

    testWidgets('omits sidebar when null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiChatApp(
            header: SizedBox(height: 40, child: Text('Only header')),
            body: Center(child: Text('Only body')),
            prompt: SizedBox(height: 40, child: Text('Only prompt')),
          ),
        ),
      );

      expect(find.text('Sidebar'), findsNothing);
      expect(find.text('Only body'), findsOneWidget);
      expect(find.text('Only header'), findsOneWidget);
      expect(find.text('Only prompt'), findsOneWidget);
    });

    testWidgets('uses custom sidebar width', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiChatApp(
            sidebarWidth: 200,
            sidebar: const ColoredBox(
              color: Colors.blue,
              child: Text('Wide sidebar'),
            ),
            body: const Center(child: Text('Main')),
          ),
        ),
      );

      final sized = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final sidebarBox = sized.where((s) => s.width == 200).toList();
      expect(sidebarBox, isNotEmpty);
      expect(find.text('Wide sidebar'), findsOneWidget);
    });

    testWidgets('exposes workspace semantics label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiChatApp(
            semanticLabel: 'Release workspace',
            body: Center(child: Text('Body')),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Release workspace'), findsOneWidget);
    });

    testWidgets('composes message scroller and prompt input', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiChatApp(
            header: const SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Checkout release'),
              ),
            ),
            body: BeuiMessageScroller(
              child: BeuiMessageGroup(
                spacing: BeuiMessageSpacing.standard,
                children: const [
                  BeuiMessage(
                    from: BeuiMessageFrom.user,
                    children: [
                      BeuiMessageContent(
                        children: [
                          BeuiMessageBubble(
                            variant: BeuiMessageBubbleVariant.solid,
                            child: BeuiMessageBubbleContent(
                              child: Text('Audit the checkout flow'),
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
                              child: Text('Preparing the patch'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            prompt: const Padding(
              padding: EdgeInsets.all(8),
              child: BeuiPromptInput(
                minRows: 1,
                maxRows: 2,
                placeholder: 'Ask the agent to continue…',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Checkout release'), findsOneWidget);
      expect(find.text('Audit the checkout flow'), findsOneWidget);
      expect(find.text('Preparing the patch'), findsOneWidget);
      expect(find.byType(BeuiPromptInput), findsOneWidget);
      expect(find.byType(BeuiMessageScroller), findsOneWidget);
    });

    testWidgets('works under reduced motion', (tester) async {
      await tester.pumpWidget(
        _wrap(
          reduce: true,
          BeuiChatApp(
            sidebar: const Center(child: Text('Nav')),
            body: BeuiMessageScroller(
              child: BeuiMessageGroup(
                children: const [
                  BeuiMessage(
                    from: BeuiMessageFrom.assistant,
                    animateIn: true,
                    children: [
                      BeuiMessageContent(
                        children: [
                          BeuiMessageBubble(
                            child: BeuiMessageBubbleContent(
                              child: Text('Reduced motion reply'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            prompt: const BeuiPromptInput(minRows: 1, maxRows: 1),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Reduced motion reply'), findsOneWidget);
      expect(find.text('Nav'), findsOneWidget);
    });
  });
}
