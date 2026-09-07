// Goldens for the conversation core.
//
// The audit noted that no golden existed for any component in this cluster, so
// both of its contrast findings — `outline` at ~1.1:1 and `danger` at 3.43:1 —
// shipped without anyone ever looking at a rendered pixel. These two files are
// the cheapest guard against that happening again.
//
// Golden comparison is a macOS-local gate; CI sets BEUI_SKIP_GOLDENS=1. See
// test/flutter_test_config.dart.

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BeuiTextTheme.trackingNormal(
      (brightness == Brightness.light ? ThemeData.light() : ThemeData.dark())
          .copyWith(
            extensions: [
              brightness == Brightness.light
                  ? BeuiColors.light()
                  : BeuiColors.dark(),
            ],
          ),
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

/// One bubble per variant, both sides, with no entrance motion so the golden
/// is the resting truth rather than a frame of a spring.
Widget _variantSheet() => SizedBox(
  width: 420,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final variant in BeuiMessageBubbleVariant.values) ...[
        if (variant != BeuiMessageBubbleVariant.values.first)
          const SizedBox(height: 10),
        BeuiMessage(
          key: ValueKey(variant),
          from: variant == BeuiMessageBubbleVariant.solid
              ? BeuiMessageFrom.user
              : BeuiMessageFrom.assistant,
          animateIn: false,
          children: [
            BeuiMessageContent(
              children: [
                BeuiMessageBubble(
                  variant: variant,
                  animateIn: false,
                  child: BeuiMessageBubbleContent(child: Text(variant.name)),
                ),
              ],
            ),
          ],
        ),
      ],
    ],
  ),
);

void main() {
  testWidgets('message bubble variants (light)', (tester) async {
    await tester.pumpWidget(_app(_variantSheet()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Column).first,
      matchesGoldenFile('goldens/beui_message_bubble_variants.png'),
    );
  });

  testWidgets('message bubble variants (dark)', (tester) async {
    await tester.pumpWidget(_app(_variantSheet(), brightness: Brightness.dark));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Column).first,
      matchesGoldenFile('goldens/beui_message_bubble_variants_dark.png'),
    );
  });

  testWidgets('streaming response endings', (tester) async {
    // C1/C13 in one frame: complete, failed and stopped side by side is the
    // comparison the audit says nobody could previously make.
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final status in [
                BeuiStreamingResponseStatus.complete,
                BeuiStreamingResponseStatus.error,
                BeuiStreamingResponseStatus.stopped,
              ]) ...[
                if (status != BeuiStreamingResponseStatus.complete)
                  const SizedBox(height: 16),
                BeuiStreamingResponse(
                  key: ValueKey(status),
                  status: status,
                  copyText: 'The pricing call happens inside the transaction.',
                  onRetry: () {},
                  onContinue: () {},
                  announce: false,
                  child: const Text(
                    'The pricing call happens inside the transaction.',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Column).first,
      matchesGoldenFile('goldens/beui_streaming_response_endings.png'),
    );
  });

  testWidgets('chat app shell', (tester) async {
    await tester.pumpWidget(
      _app(
        const SizedBox(
          // Comfortably above the 768px sidebar breakpoint, so this golden is
          // the two-column shell; the narrow one below is the collapsed shell.
          width: 900,
          height: 400,
          child: BeuiChatApp(
            sidebar: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Conversations'),
                  SizedBox(height: 8),
                  Text('Checkout release'),
                ],
              ),
            ),
            header: Padding(
              padding: EdgeInsets.all(12),
              child: Text('Checkout release'),
            ),
            body: Padding(
              padding: EdgeInsets.all(12),
              child: BeuiMessageGroup(
                spacing: BeuiMessageSpacing.standard,
                children: [
                  BeuiMessage(
                    from: BeuiMessageFrom.user,
                    animateIn: false,
                    children: [
                      BeuiMessageContent(
                        children: [
                          BeuiMessageBubble(
                            variant: BeuiMessageBubbleVariant.solid,
                            animateIn: false,
                            child: BeuiMessageBubbleContent(
                              child: Text('Audit the checkout flow.'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  BeuiMessage(
                    from: BeuiMessageFrom.assistant,
                    animateIn: false,
                    children: [
                      BeuiMessageContent(
                        children: [
                          BeuiMessageBubble(
                            animateIn: false,
                            child: BeuiMessageBubbleContent(
                              child: Text('Starting with the pricing call.'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            prompt: Padding(
              padding: EdgeInsets.all(12),
              child: Text('Send a message…'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiChatApp),
      matchesGoldenFile('goldens/beui_chat_app.png'),
    );
  });

  testWidgets('chat app shell below the sidebar breakpoint', (tester) async {
    // The same shell at 360px wide. The sidebar is out of the flow rather
    // than leaving the conversation 88px.
    await tester.pumpWidget(
      _app(
        const SizedBox(
          width: 360,
          height: 320,
          child: BeuiChatApp(
            sidebar: Text('Conversations'),
            header: Padding(
              padding: EdgeInsets.all(12),
              child: Text('Checkout release'),
            ),
            body: Padding(
              padding: EdgeInsets.all(12),
              child: BeuiMessage(
                from: BeuiMessageFrom.assistant,
                animateIn: false,
                children: [
                  BeuiMessageContent(
                    children: [
                      BeuiMessageBubble(
                        animateIn: false,
                        child: BeuiMessageBubbleContent(
                          child: Text('The conversation keeps its width.'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            prompt: Padding(
              padding: EdgeInsets.all(12),
              child: Text('Send a message…'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiChatApp),
      matchesGoldenFile('goldens/beui_chat_app_narrow.png'),
    );
  });
}
