import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  Widget child, {
  BeuiColors? colors,
  BeuiAgentTheme? agent,
  String? fontFamily,
  bool reduce = false,
}) {
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
  final palette = colors ?? BeuiColors.light();
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData(
        brightness: Brightness.light,
        fontFamily: fontFamily,
        useMaterial3: true,
      ).copyWith(extensions: [palette, ?agent]),
    ),
    home: Scaffold(body: body),
  );
}

BoxDecoration? _bubbleDecoration(WidgetTester tester) {
  final boxes = tester.widgetList<DecoratedBox>(
    find.descendant(
      of: find.byType(BeuiMessageBubbleContent),
      matching: find.byType(DecoratedBox),
    ),
  );
  for (final box in boxes) {
    final d = box.decoration;
    if (d is BoxDecoration && d.borderRadius != null) return d;
  }
  return null;
}

void main() {
  testWidgets('default agent theme matches current bubble metrics', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const BeuiMessageBubble(
          child: BeuiMessageBubbleContent(child: Text('Hello')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final decoration = _bubbleDecoration(tester);
    expect(decoration, isNotNull);
    expect(decoration!.borderRadius, BorderRadius.circular(16));

    final padding = tester.widget<Padding>(
      find
          .descendant(
            of: find.byType(BeuiMessageBubbleContent),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(
      padding.padding,
      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    );

    final style = tester
        .widget<DefaultTextStyle>(
          find
              .descendant(
                of: find.byType(BeuiMessageBubbleContent),
                matching: find.byType(DefaultTextStyle),
              )
              .first,
        )
        .style;
    expect(style.fontSize, 14);
  });

  testWidgets('custom colors reach agent cards', (tester) async {
    final custom = BeuiColors.light().copyWith(
      muted: const Color(0xFFCCFFCC),
      foreground: const Color(0xFF113311),
    );
    await tester.pumpWidget(
      _host(
        BeuiApprovalCard(title: 'Approve transfer?', onApprove: () {}),
        colors: custom,
      ),
    );
    await tester.pumpAndSettle();

    final boxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
    expect(
      boxes.any((b) {
        final d = b.decoration;
        return d is BoxDecoration && d.color == const Color(0xFFCCFFCC);
      }),
      isTrue,
    );
  });

  testWidgets('custom typography is applied to bubble body', (tester) async {
    const agent = BeuiAgentTheme(
      typography: BeuiAgentTypography(
        assistantBody: TextStyle(fontSize: 20, height: 1.2),
      ),
    );
    await tester.pumpWidget(
      _host(
        const BeuiMessageBubble(
          child: BeuiMessageBubbleContent(child: Text('Big type')),
        ),
        agent: agent,
        fontFamily: 'serif',
      ),
    );
    await tester.pumpAndSettle();

    final style = tester
        .widget<DefaultTextStyle>(
          find
              .descendant(
                of: find.byType(BeuiMessageBubbleContent),
                matching: find.byType(DefaultTextStyle),
              )
              .first,
        )
        .style;
    expect(style.fontSize, 20);
  });

  testWidgets('custom bubble radius and padding are applied', (tester) async {
    const agent = BeuiAgentTheme(
      shapes: BeuiAgentShapes(
        assistantBubble: BorderRadius.all(Radius.circular(4)),
      ),
      layout: BeuiAgentLayout(bubblePadding: EdgeInsets.all(2)),
    );
    await tester.pumpWidget(
      _host(
        const BeuiMessageBubble(
          child: BeuiMessageBubbleContent(child: Text('Tight')),
        ),
        agent: agent,
      ),
    );
    await tester.pumpAndSettle();

    expect(_bubbleDecoration(tester)!.borderRadius, BorderRadius.circular(4));
    final padding = tester.widget<Padding>(
      find
          .descendant(
            of: find.byType(BeuiMessageBubbleContent),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(padding.padding, const EdgeInsets.all(2));
  });

  testWidgets('custom card radius and padding are applied', (tester) async {
    const agent = BeuiAgentTheme(
      shapes: BeuiAgentShapes(card: BorderRadius.all(Radius.circular(2))),
      layout: BeuiAgentLayout(cardPadding: EdgeInsets.all(4)),
    );
    await tester.pumpWidget(
      _host(
        BeuiApprovalCard(title: 'Card', onApprove: () {}),
        agent: agent,
      ),
    );
    await tester.pumpAndSettle();

    final padding = tester.widget<Padding>(
      find
          .descendant(
            of: find.byType(BeuiApprovalCard),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(padding.padding, const EdgeInsets.all(4));
  });

  testWidgets('custom icons replace Lucide defaults', (tester) async {
    const agent = BeuiAgentTheme(
      icons: BeuiAgentIcons(pendingApproval: Icons.verified_outlined),
    );
    await tester.pumpWidget(
      _host(
        BeuiApprovalCard(title: 'Icon slot', onApprove: () {}),
        agent: agent,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
    expect(find.byIcon(LucideIcons.message_square_text), findsNothing);
  });

  testWidgets('user vs assistant bubble radii resolve independently', (
    tester,
  ) async {
    const agent = BeuiAgentTheme(
      shapes: BeuiAgentShapes(
        userBubble: BorderRadius.all(Radius.circular(20)),
        assistantBubble: BorderRadius.all(Radius.circular(6)),
      ),
    );
    await tester.pumpWidget(
      _host(
        const BeuiMessage(
          from: BeuiMessageFrom.user,
          children: [
            BeuiMessageContent(
              children: [
                BeuiMessageBubble(
                  variant: BeuiMessageBubbleVariant.solid,
                  child: BeuiMessageBubbleContent(child: Text('User')),
                ),
              ],
            ),
          ],
        ),
        agent: agent,
      ),
    );
    await tester.pumpAndSettle();
    expect(_bubbleDecoration(tester)!.borderRadius, BorderRadius.circular(20));
  });
}
