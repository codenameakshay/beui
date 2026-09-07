// Regression tests for the conversation-core UX remediation (audit C1–C34).
//
// One file rather than six, because these assertions are about the *findings*
// — each group names the finding it pins, so a future reader can go from a
// failing test back to the reason the behaviour exists.

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(
  Widget child, {
  bool reduce = false,
  Brightness brightness = Brightness.light,
  TextDirection direction = TextDirection.ltr,
}) {
  return MaterialApp(
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
    home: Builder(
      builder: (context) {
        final base = MediaQuery.of(context);
        return MediaQuery(
          data: base.copyWith(disableAnimations: reduce),
          child: Directionality(
            textDirection: direction,
            child: Scaffold(body: child),
          ),
        );
      },
    ),
  );
}

/// Every semantics node in the tree, flattened.
List<SemanticsNode> _nodes(WidgetTester tester) {
  final out = <SemanticsNode>[];
  void visit(SemanticsNode n) {
    out.add(n);
    n.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  // `rootPipelineOwner`'s semantics owner is a different (empty) tree under
  // the test binding.
  // ignore: deprecated_member_use
  visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
  return out;
}

/// The first node whose label *contains* [label].
///
/// Substring, not equality: Flutter merges a `Semantics` label with its
/// descendants' text into one node, so an exact match would assert on the
/// merging rather than on the label under test. Where exactness is the point
/// (C22's "named once, not twice") the test compares labels directly instead.
SemanticsNode? _nodeWithLabel(WidgetTester tester, Pattern label) {
  for (final n in _nodes(tester)) {
    if (n.label.contains(label)) return n;
  }
  return null;
}

void main() {
  // -------------------------------------------------------------------------
  group('C1/C13 — a failed or stopped response is not a finished one', () {
    Widget response(
      BeuiStreamingResponseStatus status, {
      VoidCallback? onRetry,
      VoidCallback? onContinue,
      Brightness brightness = Brightness.light,
    }) => _app(
      brightness: brightness,
      BeuiStreamingResponse(
        status: status,
        onRetry: onRetry,
        onContinue: onContinue,
        copyText: 'partial answer',
        child: const Text('partial answer'),
      ),
    );

    testWidgets('error names itself in semantics; complete does not', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(response(BeuiStreamingResponseStatus.complete));
      await tester.pumpAndSettle();
      expect(_nodeWithLabel(tester, 'Response'), isNotNull);
      expect(_nodeWithLabel(tester, 'Response, failed'), isNull);

      await tester.pumpWidget(response(BeuiStreamingResponseStatus.error));
      await tester.pumpAndSettle();
      expect(_nodeWithLabel(tester, 'Response, failed'), isNotNull);

      await tester.pumpWidget(response(BeuiStreamingResponseStatus.stopped));
      await tester.pumpAndSettle();
      expect(_nodeWithLabel(tester, 'Response, stopped'), isNotNull);

      handle.dispose();
    });

    testWidgets('error shows a destructive notice; complete shows none', (
      tester,
    ) async {
      await tester.pumpWidget(response(BeuiStreamingResponseStatus.complete));
      await tester.pumpAndSettle();
      expect(find.text('Response failed'), findsNothing);
      expect(find.byIcon(LucideIcons.triangle_alert), findsNothing);

      await tester.pumpWidget(response(BeuiStreamingResponseStatus.error));
      await tester.pumpAndSettle();
      expect(find.text('Response failed'), findsOneWidget);
      expect(find.byIcon(LucideIcons.triangle_alert), findsOneWidget);
    });

    testWidgets('stopped shows its own affordance, not the error one', (
      tester,
    ) async {
      await tester.pumpWidget(response(BeuiStreamingResponseStatus.stopped));
      await tester.pumpAndSettle();
      expect(find.text('Response stopped'), findsOneWidget);
      expect(find.byIcon(LucideIcons.circle_stop), findsOneWidget);
      expect(find.byIcon(LucideIcons.triangle_alert), findsNothing);
    });

    testWidgets('retry is surfaced as a labelled control on error', (
      tester,
    ) async {
      var retried = 0;
      await tester.pumpWidget(
        response(BeuiStreamingResponseStatus.error, onRetry: () => retried++),
      );
      await tester.pumpAndSettle();

      // A *labelled* control, not just the 14px icon in the action row.
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, 1);
    });

    testWidgets('continue is surfaced on stopped and fires', (tester) async {
      var continued = 0;
      await tester.pumpWidget(
        response(
          BeuiStreamingResponseStatus.stopped,
          onContinue: () => continued++,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      expect(continued, 1);
    });

    testWidgets('the notice is keyboard-activatable', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        response(BeuiStreamingResponseStatus.error, onRetry: () => retried++),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      // Walk focus until the retry control has it, then activate.
      for (var i = 0; i < 8 && retried == 0; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        if (retried > 0) break;
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }
      expect(retried, greaterThan(0), reason: 'reachable and activatable');
    });

    testWidgets('the notice tints from the themeable status palette', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          response(BeuiStreamingResponseStatus.error, brightness: brightness),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<Icon>(
          find.byIcon(LucideIcons.triangle_alert),
        );
        final expected = BeuiAgentStatusColors.of(brightness).failed.foreground;
        expect(
          icon.color,
          expected,
          reason: 'status colour must be rethemeable, not a hex literal',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  group('C2 — the focus ring is visible and costs no layout', () {
    Widget bubble() => _app(
      Center(
        child: SizedBox(
          width: 300,
          child: BeuiMessageBubble(
            animateIn: false,
            child: BeuiMessageBubbleContent(
              semanticLabel: 'Open trace',
              onTap: () {},
              child: const Text('tap me'),
            ),
          ),
        ),
      ),
    );

    testWidgets('focusing does not move or resize the content', (tester) async {
      await tester.pumpWidget(bubble());
      await tester.pumpAndSettle();

      final before = tester.getRect(find.text('tap me'));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      final after = tester.getRect(find.text('tap me'));
      // The old implementation put a 2px border in the BoxDecoration, so the
      // child inset by 2px on every side the moment it took focus.
      expect(after, before);
    });

    testWidgets('the ring paints in focusRing, never the hairline ring token', (
      tester,
    ) async {
      await tester.pumpWidget(bubble());
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      final colors = BeuiColors.light();
      // `ring` composites to 1.29:1 — the token this must not use.
      expect(colors.focusRing, isNot(colors.ring));

      final found = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.border != null)
          .map((d) => d.border!.top.color)
          .toList();
      expect(
        found,
        contains(colors.focusRing),
        reason: 'focus indicator uses the dedicated >=3:1 role',
      );
      expect(found, isNot(contains(colors.ring)));
    });
  });

  // -------------------------------------------------------------------------
  group('C3 — narrow shells do not produce impossible constraints', () {
    testWidgets('bubble clamps maxWidth to its own minimum', (tester) async {
      // 0.82 x 28 = 23, below the 36px min-w-9 — this asserted before the fix.
      await tester.pumpWidget(
        _app(
          const Center(
            child: SizedBox(
              width: 28,
              child: BeuiMessageBubble(
                animateIn: false,
                child: BeuiMessageBubbleContent(child: Text('x')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('chat app keeps the sidebar inline above the breakpoint', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 900,
            height: 400,
            child: BeuiChatApp(
              sidebar: Text('rail'),
              body: Text('conversation'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('rail'), findsOneWidget);
      expect(
        tester.getSize(find.text('conversation')).width,
        lessThan(900 - 200),
      );
    });

    testWidgets('below the breakpoint the sidebar leaves the flow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 320,
            height: 400,
            child: BeuiChatApp(
              sidebar: Text('rail'),
              body: Text('conversation'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Hidden, not crushing the transcript into 48px.
      expect(find.text('rail'), findsNothing);
      expect(find.text('conversation'), findsOneWidget);
    });

    testWidgets('sidebarOpen shows a dismissible drawer when collapsed', (
      tester,
    ) async {
      var dismissed = 0;
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 320,
            height: 400,
            child: BeuiChatApp(
              sidebar: const Text('rail'),
              sidebarOpen: true,
              onSidebarDismiss: () => dismissed++,
              body: const Text('conversation'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('rail'), findsOneWidget);

      // Tap the scrim past the 272px panel, not at the scrim's centre — the
      // panel sits on top there.
      await tester.tapAt(const Offset(300, 200));
      await tester.pumpAndSettle();
      expect(dismissed, 1);
    });

    testWidgets('the composer lifts clear of the keyboard', (tester) async {
      // No Scaffold: it consumes `viewInsets` for its body by default, so the
      // harness would measure Scaffold's resize instead of BeuiChatApp's.
      Future<double> promptTop(double inset) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: BeuiTextTheme.trackingNormal(
              ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
            ),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(viewInsets: EdgeInsets.only(bottom: inset)),
                child: const Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 600,
                    height: 500,
                    child: BeuiChatApp(
                      body: Text('body'),
                      prompt: Text('composer'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester.getRect(find.text('composer')).top;
      }

      final flat = await promptTop(0);
      final lifted = await promptTop(180);
      expect(
        lifted,
        lessThan(flat - 100),
        reason: 'viewInsets must raise the composer',
      );
    });
  });

  // -------------------------------------------------------------------------
  group('C4 — jump to latest', () {
    Widget scroller({
      bool showJumpToLatest = true,
      ScrollController? controller,
      int count = 40,
    }) => _app(
      SizedBox(
        height: 240,
        width: 300,
        child: BeuiMessageScroller(
          controller: controller,
          showJumpToLatest: showJumpToLatest,
          child: Column(
            children: [
              for (var i = 0; i < count; i++)
                SizedBox(height: 40, child: Text('row $i')),
            ],
          ),
        ),
      ),
    );

    testWidgets('hidden while following, shown once the reader leaves', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(scroller(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Jump to latest'), findsNothing);

      controller.jumpTo(0);
      await tester.pump();
      await tester.drag(find.text('row 1'), const Offset(0, 30));
      await tester.pumpAndSettle();

      expect(find.text('Jump to latest'), findsOneWidget);
    });

    testWidgets('tapping it returns to the live edge', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(scroller(controller: controller));
      await tester.pumpAndSettle();

      controller.jumpTo(0);
      await tester.pump();
      await tester.drag(find.text('row 1'), const Offset(0, 30));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Jump to latest'));
      await tester.pumpAndSettle();

      expect(
        controller.offset,
        closeTo(controller.position.maxScrollExtent, 1),
      );
    });

    testWidgets('opt-out renders nothing', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        scroller(showJumpToLatest: false, controller: controller),
      );
      await tester.pumpAndSettle();
      controller.jumpTo(0);
      await tester.pump();
      await tester.drag(find.text('row 1'), const Offset(0, 30));
      await tester.pumpAndSettle();
      expect(find.text('Jump to latest'), findsNothing);
    });

    testWidgets('counts messages that arrive while detached', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final counts = <int>[];

      Widget build(int n) => _app(
        SizedBox(
          height: 200,
          width: 300,
          child: BeuiMessageScroller(
            controller: controller,
            onUnreadCountChange: counts.add,
            child: Column(
              children: [
                for (var i = 0; i < n; i++)
                  BeuiMessageScrollerAnchor(
                    id: 'm$i',
                    label: 'row $i',
                    child: SizedBox(height: 40, child: Text('row $i')),
                  ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(build(10));
      await tester.pumpAndSettle();
      counts.clear();

      // Leave the live edge.
      controller.jumpTo(0);
      await tester.pump();
      await tester.drag(find.text('row 1'), const Offset(0, 30));
      await tester.pumpAndSettle();

      await tester.pumpWidget(build(13));
      await tester.pumpAndSettle();

      expect(counts, isNotEmpty);
      expect(counts.last, 3);
      expect(find.text('Jump to latest'), findsOneWidget);
    });

    testWidgets('has the full interactive contract', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(scroller(controller: controller));
      await tester.pumpAndSettle();
      controller.jumpTo(0);
      await tester.pump();
      await tester.drag(find.text('row 1'), const Offset(0, 30));
      await tester.pumpAndSettle();

      final node = _nodeWithLabel(tester, 'Jump to latest');
      expect(node, isNotNull);
      expect(node!.flagsCollection.isButton, isTrue);
      // Every tappable carries a name.
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  // -------------------------------------------------------------------------
  group('C5 — follow does not chase the live edge forever', () {
    testWidgets('a growth inside the glide window jumps instead of animating', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      Widget build(int n) => _app(
        SizedBox(
          height: 200,
          width: 300,
          child: BeuiMessageScroller(
            controller: controller,
            child: Column(
              children: [
                for (var i = 0; i < n; i++)
                  SizedBox(height: 40, child: Text('row $i')),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(build(10));
      await tester.pumpAndSettle();

      // Simulate token cadence: grow repeatedly, far faster than 320ms.
      for (var n = 11; n < 24; n++) {
        await tester.pumpWidget(build(n));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // One more frame is enough to be pinned, because the follows jumped
      // rather than each restarting a 320ms animation that never completed.
      await tester.pump(const Duration(milliseconds: 16));

      expect(
        controller.offset,
        closeTo(controller.position.maxScrollExtent, 1.5),
        reason: 'the viewport must not trail the live edge during a stream',
      );
    });

    testWidgets('the reader can still leave mid-stream', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final follows = <bool>[];

      Widget build(int n) => _app(
        SizedBox(
          height: 200,
          width: 300,
          child: BeuiMessageScroller(
            controller: controller,
            onFollowChange: follows.add,
            child: Column(
              children: [
                for (var i = 0; i < n; i++)
                  SizedBox(height: 40, child: Text('row $i')),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(build(20));
      await tester.pumpAndSettle();

      for (var n = 21; n < 26; n++) {
        await tester.pumpWidget(build(n));
        await tester.pump(const Duration(milliseconds: 16));
      }

      // The programmatic guard used to be re-armed every tick, so a user drag
      // during a stream was swallowed for the whole stream.
      await tester.drag(find.text('row 22'), const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(follows, contains(false));
    });
  });

  // -------------------------------------------------------------------------
  group('C7 — an interactive bubble is a button', () {
    testWidgets('reports role and label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          Center(
            child: BeuiMessageBubble(
              animateIn: false,
              child: BeuiMessageBubbleContent(
                semanticLabel: 'Open pricing trace',
                onTap: () {},
                child: const Text('Open pricing trace'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final node = _nodeWithLabel(tester, 'Open pricing trace');
      expect(node, isNotNull);
      expect(node!.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('a non-interactive bubble is not a button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const Center(
            child: BeuiMessageBubble(
              animateIn: false,
              child: BeuiMessageBubbleContent(child: Text('just text')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final buttons = _nodes(
        tester,
      ).where((n) => n.flagsCollection.isButton).toList();
      expect(buttons, isEmpty);
      handle.dispose();
    });

    testWidgets('Enter and Space activate it', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          Center(
            child: BeuiMessageBubble(
              animateIn: false,
              child: BeuiMessageBubbleContent(
                semanticLabel: 'Activate',
                onTap: () => taps++,
                child: const Text('Activate'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(taps, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(taps, 2);
    });
  });

  // -------------------------------------------------------------------------
  group('C8 — touch targets and spacing', () {
    testWidgets('response actions meet the tap-target guideline', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          Center(
            child: SizedBox(
              width: 400,
              child: BeuiStreamingResponse(
                status: BeuiStreamingResponseStatus.complete,
                copyText: 'x',
                onRetry: () {},
                child: const Text('answer'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Every tappable is named — the half of the tap-target contract the
      // guidelines can see.
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      // The other half has to be asserted by hit testing. `BeuiMinHitTarget`
      // widens the accepted pointer region without widening the painted box,
      // and the semantics rect follows the paint — so
      // `androidTapTargetGuideline` measures 28x28 and fails even though a
      // finger 8px outside the icon lands on it. Assert the behaviour the
      // guideline is a proxy for.
      handle.dispose();
    });

    testWidgets('a press 8px outside the painted icon still lands', (
      tester,
    ) async {
      var copied = 0;
      await tester.pumpWidget(
        _app(
          Center(
            child: SizedBox(
              width: 400,
              child: BeuiStreamingResponse(
                status: BeuiStreamingResponseStatus.complete,
                onCopy: () => copied++,
                child: const Text('answer'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.getRect(find.byIcon(LucideIcons.copy));
      // Above the 28px control, inside the 44px slop. The visual is
      // source-exact; only the hit region grew.
      await tester.tapAt(Offset(icon.center.dx, icon.top - 8));
      await tester.pumpAndSettle();
      expect(copied, 1);
    });

    testWidgets('adjacent actions are spaced, not merely slop-padded', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Center(
            child: SizedBox(
              width: 400,
              child: BeuiStreamingResponse(
                status: BeuiStreamingResponseStatus.complete,
                copyText: 'x',
                onRetry: () {},
                child: const Text('answer'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final copy = tester.getRect(find.byIcon(LucideIcons.copy));
      final retry = tester.getRect(find.byIcon(LucideIcons.rotate_ccw));
      // 2px was the audited gap; overlapping 44px slop at that pitch means the
      // wrong control wins the hit test.
      expect((retry.left - copy.right).abs(), greaterThanOrEqualTo(6));
    });
  });

  // -------------------------------------------------------------------------
  group('C9 — outline is visible, danger is not colour-only', () {
    testWidgets('outline gets a card fill and a full-strength edge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const Center(
            child: BeuiMessageBubble(
              variant: BeuiMessageBubbleVariant.outline,
              animateIn: false,
              child: BeuiMessageBubbleContent(child: Text('outlined')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final colors = BeuiColors.light();
      final decorations = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .toList();

      expect(
        decorations.any((d) => d.color == colors.card),
        isTrue,
        reason: 'a surface, not a transparent box behind a 1.1:1 hairline',
      );
      expect(
        decorations.any((d) => d.border?.top.color == colors.borderStrong),
        isTrue,
      );
    });

    testWidgets('danger carries a glyph as well as a tint', (tester) async {
      await tester.pumpWidget(
        _app(
          const Center(
            child: BeuiMessageBubble(
              variant: BeuiMessageBubbleVariant.danger,
              animateIn: false,
              child: BeuiMessageBubbleContent(child: Text('that failed')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.triangle_alert), findsOneWidget);
    });

    testWidgets('danger text uses the destructive status tier, both modes', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          _app(
            brightness: brightness,
            const Center(
              child: BeuiMessageBubble(
                variant: BeuiMessageBubbleVariant.danger,
                animateIn: false,
                child: BeuiMessageBubbleContent(child: Text('that failed')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final style = tester.widget<Text>(find.text('that failed')).style;
        final resolved =
            style?.color ??
            DefaultTextStyle.of(
              tester.element(find.text('that failed')),
            ).style.color;
        expect(
          resolved,
          BeuiAgentStatusColors.of(brightness).destructive.foreground,
        );
      }
    });

    testWidgets('bubble text meets the contrast guideline', (tester) async {
      final handle = tester.ensureSemantics();
      // Six bubbles do not fit the default 800x600 test surface.
      tester.view.physicalSize = const Size(700, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          _app(
            brightness: brightness,
            Center(
              child: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final v in BeuiMessageBubbleVariant.values)
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: BeuiMessageBubble(
                          variant: v,
                          animateIn: false,
                          child: BeuiMessageBubbleContent(
                            child: Text('Readable body copy for $v'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
      handle.dispose();
    });
  });

  // -------------------------------------------------------------------------
  group('C10/C11 — heights animate instead of snapping', () {
    testWidgets('completion actions grow the response over time', (
      tester,
    ) async {
      Widget build(BeuiStreamingResponseStatus status) => _app(
        Center(
          child: SizedBox(
            width: 360,
            child: BeuiStreamingResponse(
              status: status,
              copyText: 'x',
              child: const Text('answer'),
            ),
          ),
        ),
      );

      await tester.pumpWidget(build(BeuiStreamingResponseStatus.streaming));
      await tester.pumpAndSettle();
      final collapsed = tester
          .getSize(find.byType(BeuiStreamingResponse))
          .height;

      await tester.pumpWidget(build(BeuiStreamingResponseStatus.complete));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final mid = tester.getSize(find.byType(BeuiStreamingResponse)).height;

      await tester.pumpAndSettle();
      final settled = tester.getSize(find.byType(BeuiStreamingResponse)).height;

      expect(settled, greaterThan(collapsed));
      // The whole point: an intermediate height exists. Before the fix the
      // actions appeared at full height in one frame, shoving the transcript.
      expect(mid, greaterThan(collapsed));
      expect(mid, lessThan(settled));
    });

    testWidgets('a collapsible bubble expands through intermediate heights', (
      tester,
    ) async {
      const long =
          'One two three four five six seven eight nine ten. Eleven twelve '
          'thirteen fourteen fifteen sixteen seventeen eighteen nineteen. '
          'Twenty twentyone twentytwo twentythree twentyfour twentyfive.';

      await tester.pumpWidget(
        _app(
          Center(
            child: SizedBox(
              width: 240,
              child: BeuiMessageBubble(
                animateIn: false,
                child: BeuiMessageBubbleContent(
                  child: BeuiMessageBubbleCollapsible(
                    collapsedLines: 2,
                    child: Text(long),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final collapsed = tester
          .getSize(find.byType(BeuiMessageBubbleCollapsible))
          .height;

      await tester.tap(find.text('Show more'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final mid = tester
          .getSize(find.byType(BeuiMessageBubbleCollapsible))
          .height;

      await tester.pumpAndSettle();
      final open = tester
          .getSize(find.byType(BeuiMessageBubbleCollapsible))
          .height;

      expect(open, greaterThan(collapsed));
      expect(mid, greaterThan(collapsed));
      expect(mid, lessThan(open));
    });

    testWidgets('reduced motion snaps the collapse without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          reduce: true,
          const Center(
            child: SizedBox(
              width: 240,
              child: BeuiMessageBubble(
                animateIn: false,
                child: BeuiMessageBubbleContent(
                  child: BeuiMessageBubbleCollapsible(
                    collapsedLines: 2,
                    child: Text('a b c d e f g h i j k l m n o p q r s t'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();
      expect(find.text('Show less'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('C12 — motion is on by default and derived from key identity', () {
    testWidgets('a message animates in without being asked', (tester) async {
      await tester.pumpWidget(
        _app(
          const Center(
            child: BeuiMessage(
              from: BeuiMessageFrom.user,
              children: [
                BeuiMessageContent(children: [Text('hi')]),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final opacity = tester
          .widgetList<Opacity>(
            find.descendant(
              of: find.byType(BeuiMessage),
              matching: find.byType(Opacity),
            ),
          )
          .map((o) => o.opacity)
          .toList();
      expect(
        opacity.any((o) => o < 1.0),
        isTrue,
        reason: 'the entrance plays by default',
      );
      await tester.pumpAndSettle();
    });

    testWidgets('an existing row does not replay when siblings append', (
      tester,
    ) async {
      Widget build(int n) => _app(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < n; i++)
                BeuiMessage(
                  key: ValueKey(i),
                  from: BeuiMessageFrom.assistant,
                  children: [
                    BeuiMessageContent(children: [Text('row $i')]),
                  ],
                ),
            ],
          ),
        ),
      );

      double opacityOf(String text) => tester
          .widgetList<Opacity>(
            find.ancestor(of: find.text(text), matching: find.byType(Opacity)),
          )
          .map((o) => o.opacity)
          .fold<double>(1, (a, b) => a * b);

      await tester.pumpWidget(build(1));
      await tester.pumpAndSettle();
      expect(opacityOf('row 0'), 1.0);

      await tester.pumpWidget(build(2));
      await tester.pump();
      // Row 0 keeps its key, so its mount-only entrance does not replay while
      // the appended row 1 plays its own.
      expect(opacityOf('row 0'), 1.0);
      expect(opacityOf('row 1'), lessThan(1.0));
      await tester.pumpAndSettle();
    });

    testWidgets('the bubble seed is no longer one-shot', (tester) async {
      // The audited bug: `_seeded` was set on the first
      // `didChangeDependencies` and every later change to the ambient
      // `animateIn` was dropped on the floor, so a bubble told mid-entrance to
      // stop animating carried on regardless.
      Widget build(bool animate) => _app(
        Center(
          child: SizedBox(
            width: 300,
            child: BeuiMessageBubble(
              key: const ValueKey('bubble'),
              animateIn: animate,
              child: const BeuiMessageBubbleContent(child: Text('hi')),
            ),
          ),
        ),
      );

      await tester.pumpWidget(build(true));
      await tester.pump();
      await tester.pumpWidget(build(false));
      await tester.pump();

      // Movement is dropped the moment the entrance is switched off: the
      // surface is no longer scaled.
      final scales = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(BeuiMessageBubbleContent),
              matching: find.byType(Transform),
            ),
          )
          .map((t) => t.transform.getMaxScaleOnAxis());
      expect(scales.every((s) => (s - 1.0).abs() < 0.001), isTrue);

      // And it comes to rest fully opaque rather than freezing part-faded.
      await tester.pumpAndSettle();
      final opacities = tester
          .widgetList<Opacity>(
            find.descendant(
              of: find.byType(BeuiMessageBubbleContent),
              matching: find.byType(Opacity),
            ),
          )
          .map((o) => o.opacity);
      expect(opacities.every((o) => o == 1.0), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  group('C14 — one indicator identity across pending and streaming', () {
    testWidgets('placeholder shows until content, then the content does', (
      tester,
    ) async {
      Widget build(String text) => _app(
        Center(
          child: SizedBox(
            width: 300,
            child: BeuiStreamingResponse(
              announceText: text,
              placeholder: const BeuiMessageTyping(),
              hasContent: text.isNotEmpty,
              child: Text(text),
            ),
          ),
        ),
      );

      await tester.pumpWidget(build(''));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(BeuiMessageTyping), findsOneWidget);

      await tester.pumpWidget(build('first tokens'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('first tokens'), findsOneWidget);
      // Cross-faded out, not swapped for an empty box.
      expect(find.byType(BeuiMessageTyping), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  group('C15 — a lazy transcript', () {
    testWidgets('builder only builds what is near the viewport', (
      tester,
    ) async {
      final built = <int>[];
      Widget build(int count) => _app(
        SizedBox(
          height: 200,
          width: 300,
          child: BeuiMessageScroller.builder(
            // Following the live edge on mount necessarily walks the list to
            // find its extent; the cost C15 is about is the *per-token* one.
            followOutput: false,
            itemCount: count,
            itemBuilder: (context, i) {
              built.add(i);
              return SizedBox(height: 40, child: Text('row $i'));
            },
          ),
        ),
      );

      await tester.pumpWidget(build(2000));
      await tester.pumpAndSettle();
      final onMount = built.length;
      expect(
        onMount,
        lessThan(60),
        reason: 'only the viewport and its cache extent',
      );

      // A streamed token rebuilds the scroller; the eager path re-measured the
      // whole transcript here.
      built.clear();
      await tester.pumpWidget(build(2001));
      await tester.pumpAndSettle();
      expect(built.length, lessThan(60));
      expect(find.text('row 0'), findsOneWidget);
    });

    testWidgets('the eager constructor still works', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            height: 200,
            width: 300,
            child: BeuiMessageScroller(child: Text('eager')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('eager'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('C16 — the rail stays reachable as the transcript grows', () {
    Widget rail(int n, {double height = 300}) => _app(
      SizedBox(
        height: height,
        width: 320,
        child: BeuiMessageScroller(
          navigation: BeuiMessageScrollerNavigation.rail,
          child: Column(
            children: [
              for (var i = 0; i < n; i++)
                BeuiMessageScrollerAnchor(
                  id: 'm$i',
                  label: 'Message $i',
                  child: SizedBox(height: 60, child: Text('row $i')),
                ),
            ],
          ),
        ),
      ),
    );

    testWidgets('every tick is rendered at 60 messages', (tester) async {
      await tester.pumpWidget(rail(60));
      await tester.pumpAndSettle();

      // At the source's fixed 14px pitch, 60 x 14 = 840 in a ~276px rail: the
      // ticks past ~19 were silently clipped away. Compression keeps them all.
      final ticks = find.bySemanticsLabel(RegExp('^Go to '));
      expect(tester.widgetList(ticks).length, 60);
    });

    testWidgets('no overflow at 200 messages', (tester) async {
      await tester.pumpWidget(rail(200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('C17 — RTL', () {
    testWidgets('user bubbles sit on the left in RTL', (tester) async {
      Future<Rect> bubbleRect(TextDirection d) async {
        await tester.pumpWidget(
          _app(
            direction: d,
            const Center(
              child: SizedBox(
                width: 400,
                child: BeuiMessage(
                  from: BeuiMessageFrom.user,
                  animateIn: false,
                  children: [
                    BeuiMessageContent(
                      children: [
                        BeuiMessageBubble(
                          variant: BeuiMessageBubbleVariant.solid,
                          animateIn: false,
                          child: BeuiMessageBubbleContent(child: Text('hi')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester.getRect(find.text('hi'));
      }

      final ltr = await bubbleRect(TextDirection.ltr);
      final rtl = await bubbleRect(TextDirection.rtl);
      expect(rtl.center.dx, lessThan(ltr.center.dx));
    });

    testWidgets('the rail mirrors to the leading edge in RTL', (tester) async {
      Future<double> railX(TextDirection d) async {
        await tester.pumpWidget(
          _app(
            direction: d,
            SizedBox(
              height: 300,
              width: 320,
              child: BeuiMessageScroller(
                navigation: BeuiMessageScrollerNavigation.rail,
                child: Column(
                  children: [
                    for (var i = 0; i < 8; i++)
                      BeuiMessageScrollerAnchor(
                        id: 'm$i',
                        label: 'Message $i',
                        child: SizedBox(height: 60, child: Text('row $i')),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester
            .getRect(find.bySemanticsLabel(RegExp('^Go to ')).first)
            .center
            .dx;
      }

      expect(
        await railX(TextDirection.rtl),
        lessThan(await railX(TextDirection.ltr)),
      );
    });

    testWidgets('the chat app divider is on the trailing edge of the rail', (
      tester,
    ) async {
      for (final d in TextDirection.values) {
        await tester.pumpWidget(
          _app(
            direction: d,
            const SizedBox(
              width: 900,
              height: 300,
              child: BeuiChatApp(sidebar: Text('rail'), body: Text('body')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final railX = tester.getRect(find.text('rail')).center.dx;
        final bodyX = tester.getRect(find.text('body')).center.dx;
        if (d == TextDirection.ltr) {
          expect(railX, lessThan(bodyX));
        } else {
          expect(railX, greaterThan(bodyX));
        }
      }
    });
  });

  // -------------------------------------------------------------------------
  group('C21 — reduced motion stops tickers, it does not just hide them', () {
    testWidgets('the typing dots and the agent progress grid stop ticking', (
      tester,
    ) async {
      for (final ticker in [
        const BeuiMessageTyping(),
        const BeuiAgentProgress(running: false),
      ]) {
        await tester.pumpWidget(_app(reduce: true, Center(child: ticker)));
        // If the controller were still repeating this would time out, exactly
        // as it does (by design) without reduced motion.
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });

  // -------------------------------------------------------------------------
  group('C22/C23/C24/C26 — the small semantics debts', () {
    testWidgets('C22 an action is named once, not twice', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          Center(
            child: SizedBox(
              width: 360,
              child: BeuiStreamingResponse(
                status: BeuiStreamingResponseStatus.complete,
                copyText: 'x',
                child: const Text('answer'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final copies = _nodes(
        tester,
      ).where((n) => n.label == 'Copy response').toList();
      expect(copies, hasLength(1), reason: 'Tooltip must not double the name');
      handle.dispose();
    });

    testWidgets('C23 Copied is announced', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          Center(
            child: SizedBox(
              width: 360,
              child: BeuiStreamingResponse(
                status: BeuiStreamingResponseStatus.complete,
                onCopy: () {},
                child: const Text('answer'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        _nodeWithLabel(tester, 'Copy response')!.flagsCollection.isLiveRegion,
        isFalse,
      );

      await tester.tap(find.bySemanticsLabel('Copy response'));
      await tester.pumpAndSettle();

      final copied = _nodeWithLabel(tester, 'Copied');
      expect(copied, isNotNull);
      expect(copied!.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('C24 the sources toggle has a resting surface', (tester) async {
      await tester.pumpWidget(
        _app(
          Center(
            child: SizedBox(
              width: 400,
              child: BeuiStreamingResponse(
                status: BeuiStreamingResponseStatus.complete,
                sources: const [
                  BeuiCitationItem(
                    id: 's1',
                    title: Text('Source'),
                    domain: Text('example.com'),
                  ),
                ],
                child: const Text('answer'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final colors = BeuiColors.light();
      final chevron = tester
          .widgetList<Icon>(find.byIcon(LucideIcons.chevron_down))
          .last;
      // Was `mutedForeground @ 0.5` at rest — invisible until hover.
      expect(chevron.color, colors.mutedForeground);
    });

    testWidgets('C26 the collapsible trigger reports expanded', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          Center(
            child: SizedBox(
              width: 240,
              child: BeuiMessageBubble(
                animateIn: false,
                child: BeuiMessageBubbleContent(
                  child: BeuiMessageBubbleCollapsible(
                    collapsedLines: 2,
                    child: Text('a b c d e f g h i j k l m n o p q r s t u v'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // `isExpanded` is a tri-state: `none` means the node does not model
      // expansion at all, which is exactly what this control used to report.
      SemanticsNode trigger() => _nodes(
        tester,
      ).firstWhere((n) => n.flagsCollection.isExpanded.toBoolOrNull() != null);

      expect(trigger().flagsCollection.isExpanded.toBoolOrNull(), isFalse);
      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();
      expect(trigger().flagsCollection.isExpanded.toBoolOrNull(), isTrue);
      handle.dispose();
    });
  });

  // -------------------------------------------------------------------------
  group('C27 — the transcript has a real default gutter', () {
    testWidgets('content is not flush against the viewport edge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            height: 200,
            width: 300,
            child: BeuiMessageScroller(child: Text('hello')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scroller = tester.getRect(find.byType(BeuiMessageScroller));
      final text = tester.getRect(find.text('hello'));
      expect(text.left - scroller.left, greaterThanOrEqualTo(12));
      expect(text.top - scroller.top, greaterThanOrEqualTo(16));
    });
  });

  // -------------------------------------------------------------------------
  group('C34 — no timer outlives its widget', () {
    testWidgets('disposing mid-entrance leaves nothing pending', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const Center(
            child: BeuiMessageBubble(
              child: BeuiMessageBubbleContent(child: Text('bye')),
            ),
          ),
        ),
      );
      // Inside the 40ms content-reveal delay.
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpWidget(_app(const SizedBox.shrink()));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  });
}
