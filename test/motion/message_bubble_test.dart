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
  group('BeuiMessageBubble', () {
    testWidgets('renders soft content by default', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiMessageBubble(
            child: BeuiMessageBubbleContent(child: Text('Soft hello')),
          ),
        ),
      );
      expect(find.text('Soft hello'), findsOneWidget);
    });

    for (final variant in BeuiMessageBubbleVariant.values) {
      testWidgets('renders $variant', (tester) async {
        await tester.pumpWidget(
          _wrap(
            BeuiMessageBubble(
              variant: variant,
              child: BeuiMessageBubbleContent(child: Text('v-${variant.name}')),
            ),
          ),
        );
        expect(find.text('v-${variant.name}'), findsOneWidget);
      });
    }

    testWidgets('inherits align from BeuiMessageSideScope', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiMessage(
            from: BeuiMessageFrom.user,
            children: [
              BeuiMessageContent(
                children: [
                  BeuiMessageBubble(
                    variant: BeuiMessageBubbleVariant.solid,
                    child: BeuiMessageBubbleContent(child: Text('End-aligned')),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(find.text('End-aligned'), findsOneWidget);
      // C17: alignment is logical, so a user bubble sits at the *end* — the
      // right in LTR, the left in RTL — rather than at a hardcoded right.
      final align = tester.widget<Align>(
        find
            .descendant(
              of: find.byType(BeuiMessageBubble),
              matching: find.byType(Align),
            )
            .first,
      );
      expect(align.alignment, AlignmentDirectional.centerEnd);
    });

    testWidgets('explicit align overrides message side', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiMessage(
            from: BeuiMessageFrom.user,
            children: [
              BeuiMessageContent(
                children: [
                  BeuiMessageBubble(
                    align: BeuiMessageBubbleSide.start,
                    child: BeuiMessageBubbleContent(
                      child: Text('Forced start'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      final align = tester.widget<Align>(
        find
            .descendant(
              of: find.byType(BeuiMessageBubble),
              matching: find.byType(Align),
            )
            .first,
      );
      expect(align.alignment, AlignmentDirectional.centerStart);
    });

    testWidgets('animateIn settles', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiMessageBubble(
            animateIn: true,
            child: BeuiMessageBubbleContent(child: Text('Pop in')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Pop in'), findsOneWidget);
    });

    testWidgets('reduced motion animateIn still shows content', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiMessageBubble(
            animateIn: true,
            child: BeuiMessageBubbleContent(child: Text('Reduced')),
          ),
          reduce: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Reduced'), findsOneWidget);
    });
  });

  group('BeuiMessageBubbleContent', () {
    testWidgets('onTap fires for interactive bubble', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiMessageBubble(
            child: BeuiMessageBubbleContent(
              onTap: () => taps++,
              child: const Text('Tap me'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Tap me'));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('BeuiMessageBubbleGroup', () {
    testWidgets('stacks multiple bubbles', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiMessageBubbleGroup(
            children: [
              BeuiMessageBubble(
                child: BeuiMessageBubbleContent(child: Text('One')),
              ),
              BeuiMessageBubble(
                child: BeuiMessageBubbleContent(child: Text('Two')),
              ),
            ],
          ),
        ),
      );
      expect(find.text('One'), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);
    });
  });

  group('BeuiMessageBubbleCollapsible', () {
    testWidgets('starts collapsed and expands on show more', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiMessageBubble(
            child: BeuiMessageBubbleContent(
              child: BeuiMessageBubbleCollapsible(
                collapsedLines: 2,
                child: Text(
                  'Line one of a long reply.\n'
                  'Line two of a long reply.\n'
                  'Line three of a long reply.\n'
                  'Line four of a long reply.',
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Show more'), findsOneWidget);
      await tester.tap(find.text('Show more'));
      await tester.pump();
      expect(find.text('Show less'), findsOneWidget);
      await tester.tap(find.text('Show less'));
      await tester.pump();
      expect(find.text('Show more'), findsOneWidget);
    });

    testWidgets('controlled open respects open flag', (tester) async {
      var open = false;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              return BeuiMessageBubble(
                child: BeuiMessageBubbleContent(
                  child: BeuiMessageBubbleCollapsible(
                    open: open,
                    onOpenChange: (v) => setState(() => open = v),
                    child: const Text('Controlled body'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      expect(find.text('Show more'), findsOneWidget);
      await tester.tap(find.text('Show more'));
      await tester.pump();
      expect(open, isTrue);
      expect(find.text('Show less'), findsOneWidget);
    });

    testWidgets('defaultOpen starts expanded', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiMessageBubble(
            child: BeuiMessageBubbleContent(
              child: BeuiMessageBubbleCollapsible(
                defaultOpen: true,
                child: Text('Already open'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Show less'), findsOneWidget);
    });
  });
}
