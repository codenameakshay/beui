import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

Widget _wrap(Widget child, {bool reduce = false}) =>
    beuiTestApp(child, width: 400, reduce: reduce);

void main() {
  group('BeuiMessageBubble', () {
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
      // Alignment is logical, so a user bubble sits at the *end* — the
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

    // Under reduced motion both the height reveal and the chevron were
    // driven by `SingleMotionBuilder`s handed `const NoMotion()`, which holds
    // its seeded value forever instead of snapping to the target (see
    // `_no_motion_semantics_test.dart`). The label swapped to "Show less" but
    // the body stayed clipped at the collapsed height and the chevron stayed
    // pointing down — the control looked broken.
    //
    // These assert the RENDERED outcome (box height, rotation matrix), not the
    // label, because the label was the one thing that always worked.
    testWidgets('reduced motion: expanding actually grows the rendered body', (
      tester,
    ) async {
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
                  'Line four of a long reply.\n'
                  'Line five of a long reply.\n'
                  'Line six of a long reply.',
                ),
              ),
            ),
          ),
          reduce: true,
        ),
      );
      await tester.pumpAndSettle();

      final collapsed = tester
          .getSize(find.byType(BeuiMessageBubbleCollapsible))
          .height;

      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();
      // Past any plausible transition, reduced or not.
      await tester.pump(const Duration(milliseconds: 400));

      final expanded = tester
          .getSize(find.byType(BeuiMessageBubbleCollapsible))
          .height;

      expect(find.text('Show less'), findsOneWidget);
      expect(
        expanded,
        greaterThan(collapsed + 20),
        reason:
            'the body must actually reveal under reduced motion, not just '
            'swap its label (collapsed=$collapsed expanded=$expanded)',
      );

      // And it must collapse again.
      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.getSize(find.byType(BeuiMessageBubbleCollapsible)).height,
        closeTo(collapsed, 1),
      );
    });

    testWidgets('reduced motion: chevron reaches its rotated target', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiMessageBubble(
            child: BeuiMessageBubbleContent(
              child: BeuiMessageBubbleCollapsible(
                collapsedLines: 2,
                child: Text('One\nTwo\nThree\nFour'),
              ),
            ),
          ),
          reduce: true,
        ),
      );
      await tester.pumpAndSettle();

      // The innermost Transform above the chevron icon is the rotate; the
      // outer one is the press scale.
      double chevronAngle() {
        final t = tester.widget<Transform>(
          find
              .ancestor(of: find.byType(Icon), matching: find.byType(Transform))
              .first,
        );
        final m = t.transform;
        return math.atan2(m.entry(1, 0), m.entry(0, 0));
      }

      expect(chevronAngle(), closeTo(0, 0.01));

      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        chevronAngle().abs(),
        closeTo(math.pi, 0.01),
        reason:
            'the chevron must reach 180° under reduced motion, not freeze at '
            'its mount angle',
      );
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
