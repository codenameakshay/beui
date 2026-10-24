import 'dart:ui' show PointerDeviceKind, Tristate;

import 'package:beui/beui.dart';
import 'package:beui/src/motion/_focus_ring.dart' show BeuiFocusRing;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  group('BeuiCard appearance', () {
    testWidgets('outlined and muted variants use their theme surfaces', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiCard(key: ValueKey('outlined'), child: SizedBox(height: 20)),
              BeuiCard(
                key: ValueKey('muted'),
                variant: BeuiCardVariant.muted,
                child: SizedBox(height: 20),
              ),
            ],
          ),
        ),
      );
      final colors = BeuiColors.resolve(
        tester.element(find.byType(BeuiCard).first),
      );
      final surfaces = tester.widgetList<AnimatedContainer>(
        find.descendant(
          of: find.byType(BeuiCard),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(
        (surfaces.first.decoration! as BoxDecoration).color,
        colors.background,
      );
      expect((surfaces.last.decoration! as BoxDecoration).color, colors.muted);
    });

    testWidgets('selected draws a primary visual ring only', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiCard(selected: true, child: Text('Selected option')),
        ),
      );
      final card = tester.widget<BeuiCard>(find.byType(BeuiCard));
      expect(card.selected, isTrue);
      final focus = tester.widget<Focus>(
        find.descendant(
          of: find.byType(BeuiCard),
          matching: find.byType(Focus),
        ),
      );
      expect(focus.canRequestFocus, isFalse);
      final box = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(BeuiCard),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect((box.decoration! as BoxDecoration).boxShadow, isNotEmpty);
      expect(
        tester.getSemantics(find.byType(BeuiCard)).flagsCollection.isFocused,
        Tristate.none,
      );
      handle.dispose();
    });
  });

  group('BeuiCard interaction', () {
    testWidgets('hover changes an interactive card border to borderStrong', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiCard(
            interactive: true,
            child: SizedBox(width: 180, height: 100),
          ),
        ),
      );
      final colors = BeuiColors.resolve(tester.element(find.byType(BeuiCard)));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.byType(BeuiCard)));
      await mouse.moveTo(tester.getCenter(find.byType(BeuiCard)));
      await tester.pumpAndSettle();

      final surface = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(BeuiCard),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(
        (surface.decoration! as BoxDecoration).border!.top.color,
        colors.borderStrong,
      );
      await mouse.removePointer();
    });

    testWidgets('descendant checkbox focus shows the card focus ring', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          FocusTraversalGroup(
            child: BeuiCard(
              interactive: true,
              child: BeuiCheckbox(value: false, onChanged: _ignoreValue),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(
        tester.widget<BeuiFocusRing>(find.byType(BeuiFocusRing)).focused,
        isTrue,
      );
    });

    testWidgets('card action occupies the header trailing slot', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiCard(
            child: BeuiCardHeader(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: BeuiCardTitle(child: Text('Heading'))),
                  BeuiCardAction(child: Text('Edit')),
                ],
              ),
            ),
          ),
        ),
      );
      final actionRect = tester.getRect(find.byType(BeuiCardAction));
      final titleRect = tester.getRect(find.byType(BeuiCardTitle));
      expect(actionRect.center.dx, greaterThan(titleRect.center.dx));
      expect(
        find.ancestor(
          of: find.byType(BeuiCardAction),
          matching: find.byType(Row),
        ),
        findsOneWidget,
      );
    });

    testWidgets('plain card does not scale on pointer press', (tester) async {
      await tester.pumpWidget(
        beuiTestApp(const BeuiCard(child: SizedBox(width: 180, height: 100))),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(BeuiCard)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.descendant(
          of: find.byType(BeuiCard),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
      await gesture.up();
    });

    testWidgets(
      'interactive card scales while pressed and settles on release',
      (tester) async {
        await tester.pumpWidget(
          beuiTestApp(
            const BeuiCard(
              interactive: true,
              child: SizedBox(width: 180, height: 100),
            ),
          ),
        );
        expect(
          MediaQuery.disableAnimationsOf(tester.element(find.byType(BeuiCard))),
          isFalse,
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(BeuiCard)),
        );
        await tester.pump(const Duration(milliseconds: 48));
        expect(
          find.descendant(
            of: find.byType(BeuiCard),
            matching: find.byType(Transform),
          ),
          findsOneWidget,
        );
        await gesture.up();
        await tester.pumpAndSettle();
        final settled = tester.widget<Transform>(
          find.descendant(
            of: find.byType(BeuiCard),
            matching: find.byType(Transform),
          ),
        );
        expect(settled.transform.storage[0], closeTo(1, 0.001));
      },
    );

    testWidgets('reduced motion skips press scale', (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiCard(
            interactive: true,
            child: SizedBox(width: 180, height: 100),
          ),
          reduce: true,
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(BeuiCard)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.descendant(
          of: find.byType(BeuiCard),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
      await gesture.up();
    });
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BeuiCard(
              size: BeuiCardSize.compact,
              child: BeuiCardHeader(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BeuiCardTitle(headingLevel: 2, child: Text('Compact card')),
                    SizedBox(height: 4),
                    BeuiCardDescription(
                      child: Text('With a short description'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12),
            BeuiCard(
              variant: BeuiCardVariant.muted,
              child: BeuiCardContent(child: Text('Muted content')),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Row),
      matchesGoldenFile('goldens/beui_card.png'),
    );
  });
}

void _ignoreValue(bool value) {}
