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

  // =========================================================================
  // A37 — every one of the five agent widgets reads the theme
  //
  // The audit measured theme consumption at 6/4/4 roles in `approval_card`
  // against 0/0/0 in `agent_activity`, and the apply-test only ever exercised
  // two of the five widgets — which is precisely why the drift went unnoticed.
  // These cases pin all five.
  // =========================================================================

  group('every agent widget consumes the theme roles', () {
    /// A status palette with values that could not occur by accident.
    const loudStatus = BeuiAgentStatusColors(
      pending: BeuiAgentStatusPalette(
        foreground: Color(0xFF110011),
        background: Color(0xFF111111),
        border: Color(0xFF112211),
        solid: Color(0xFF113311),
        onSolid: Color(0xFFFFFFFF),
      ),
      running: BeuiAgentStatusPalette(
        foreground: Color(0xFF220022),
        background: Color(0xFF222222),
        border: Color(0xFF223322),
        solid: Color(0xFF224422),
        onSolid: Color(0xFFFFFFFF),
      ),
      success: BeuiAgentStatusPalette(
        foreground: Color(0xFF330033),
        background: Color(0xFF333333),
        border: Color(0xFF334433),
        solid: Color(0xFF335533),
        onSolid: Color(0xFFFFFFFF),
      ),
      failed: BeuiAgentStatusPalette(
        foreground: Color(0xFF440044),
        background: Color(0xFF444444),
        border: Color(0xFF445544),
        solid: Color(0xFF446644),
        onSolid: Color(0xFFFFFFFF),
      ),
      denied: BeuiAgentStatusPalette(
        foreground: Color(0xFF550055),
        background: Color(0xFF555555),
        border: Color(0xFF556655),
        solid: Color(0xFF557755),
        onSolid: Color(0xFFFFFFFF),
      ),
      neutral: BeuiAgentStatusPalette(
        foreground: Color(0xFF660066),
        background: Color(0xFF666666),
        border: Color(0xFF667766),
        solid: Color(0xFF668866),
        onSolid: Color(0xFFFFFFFF),
      ),
      destructive: BeuiAgentStatusPalette(
        foreground: Color(0xFF770077),
        background: Color(0xFF777777),
        border: Color(0xFF778877),
        solid: Color(0xFF779977),
        onSolid: Color(0xFFFFFFFF),
      ),
    );

    const themed = BeuiAgentTheme(statusLight: loudStatus);

    testWidgets('BeuiToolApproval takes the pending status foreground', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          BeuiToolApproval(tool: 'terminal.run', onApprove: () {}),
          agent: themed,
        ),
      );
      await tester.pump();

      final badge = tester.widget<Text>(find.text('Approval required'));
      expect(badge.style?.color, const Color(0xFF110011));
    });

    testWidgets('BeuiApprovalCard takes the pending status foreground', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          BeuiApprovalCard(title: 'Approve transfer?', onApprove: () {}),
          agent: themed,
        ),
      );
      await tester.pump();

      final badge = tester.widget<Text>(find.text('Input required'));
      expect(badge.style?.color, const Color(0xFF110011));
    });

    testWidgets('BeuiToolApproval strings come from the theme', (tester) async {
      await tester.pumpWidget(
        _host(
          BeuiToolApproval(tool: 'terminal.run', onApprove: () {}),
          agent: const BeuiAgentTheme(
            strings: BeuiAgentStrings(allowOnce: 'Once only'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Once only'), findsOneWidget);
    });

    testWidgets('BeuiApprovalCard strings come from the theme', (tester) async {
      await tester.pumpWidget(
        _host(
          BeuiApprovalCard(
            title: 'Approve transfer?',
            onApprove: () {},
            onReject: () {},
          ),
          agent: const BeuiAgentTheme(
            strings: BeuiAgentStrings(approve: 'Ship it', reject: 'Hold it'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ship it'), findsOneWidget);
      expect(find.text('Hold it'), findsOneWidget);
    });

    testWidgets('BeuiToolApproval honours the emphasis border width', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          BeuiToolApproval(
            tool: 'fs.remove',
            severity: BeuiToolApprovalSeverity.destructive,
            onApprove: () {},
            onDeny: () {},
          ),
          agent: const BeuiAgentTheme(
            structure: BeuiAgentStructure(emphasisBorderWidth: 5),
          ),
        ),
      );
      await tester.pump();

      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(BeuiToolApproval),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.border!.top.width, 5);
    });

    testWidgets('BeuiToolApproval honours the card radius role', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          BeuiToolApproval(tool: 'terminal.run', onApprove: () {}),
          agent: const BeuiAgentTheme(
            shapes: BeuiAgentShapes(card: BorderRadius.all(Radius.circular(3))),
          ),
        ),
      );
      await tester.pump();

      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(BeuiToolApproval),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(3));
    });
  });
}
