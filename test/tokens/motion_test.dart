import 'package:beui/beui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

/// Pumps a widget under a [MediaQuery] with the given [disableAnimations] value
/// and returns whatever [motionFor] resolves [input] to in that context, given
/// the [isMovement] / [reducedFallback] arguments.
Future<Motion> _resolve(
  WidgetTester tester, {
  required bool disableAnimations,
  required Motion input,
  required bool isMovement,
  Motion? reducedFallback,
}) async {
  late Motion resolved;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Builder(
        builder: (context) {
          resolved = motionFor(
            context,
            input,
            isMovement: isMovement,
            reducedFallback: reducedFallback,
          );
          return const SizedBox();
        },
      ),
    ),
  );
  return resolved;
}

void main() {
  group('spring tokens carry the source ease.ts physics verbatim', () {
    test('beuiSpringPress — press feedback', () {
      expect(beuiSpringPress.description.mass, 0.6);
      expect(beuiSpringPress.description.stiffness, 500);
      expect(beuiSpringPress.description.damping, 30);
    });

    test('beuiSpringSwap — content swaps', () {
      expect(beuiSpringSwap.description.mass, 0.55);
      expect(beuiSpringSwap.description.stiffness, 460);
      expect(beuiSpringSwap.description.damping, 30);
    });

    test('beuiSpringPanel — overlay panels', () {
      expect(beuiSpringPanel.description.mass, 0.5);
      expect(beuiSpringPanel.description.stiffness, 420);
      expect(beuiSpringPanel.description.damping, 40);
    });

    test('beuiSpringLayout — shared-layout glides', () {
      expect(beuiSpringLayout.description.mass, 0.6);
      expect(beuiSpringLayout.description.stiffness, 360);
      expect(beuiSpringLayout.description.damping, 32);
    });

    test('beuiSpringMouse — cursor-follow physics', () {
      expect(beuiSpringMouse.description.mass, 0.3);
      expect(beuiSpringMouse.description.stiffness, 200);
      expect(beuiSpringMouse.description.damping, 15);
    });
  });

  group('easing curves carry the source ease.ts cubic-beziers verbatim', () {
    test('beuiEaseOut', () {
      expect(beuiEaseOut.a, 0.16);
      expect(beuiEaseOut.b, 1);
      expect(beuiEaseOut.c, 0.3);
      expect(beuiEaseOut.d, 1);
    });

    test('beuiEaseInOut', () {
      expect(beuiEaseInOut.a, 0.77);
      expect(beuiEaseInOut.b, 0);
      expect(beuiEaseInOut.c, 0.175);
      expect(beuiEaseInOut.d, 1);
    });

    test('beuiEaseDrawer', () {
      expect(beuiEaseDrawer.a, 0.32);
      expect(beuiEaseDrawer.b, 0.72);
      expect(beuiEaseDrawer.c, 0);
      expect(beuiEaseDrawer.d, 1);
    });
  });

  group('motionFor gates movement on reduced motion', () {
    testWidgets('movement token → NoMotion when animations are disabled', (
      tester,
    ) async {
      final resolved = await _resolve(
        tester,
        disableAnimations: true,
        input: beuiSpringMouse,
        isMovement: true,
      );
      expect(resolved, isA<NoMotion>());
    });

    testWidgets(
      'movement token → reducedFallback when one is supplied (drawer case)',
      (tester) async {
        const fallback = CurvedMotion(Duration(milliseconds: 190), beuiEaseOut);
        final resolved = await _resolve(
          tester,
          disableAnimations: true,
          input: beuiSpringPanel,
          isMovement: true,
          reducedFallback: fallback,
        );
        expect(resolved, same(fallback));
      },
    );

    testWidgets(
      'opacity/color token (isMovement: false) is preserved under reduced motion',
      (tester) async {
        final resolved = await _resolve(
          tester,
          disableAnimations: true,
          input: beuiSpringSwap,
          isMovement: false,
        );
        expect(resolved, same(beuiSpringSwap));
      },
    );

    testWidgets('movement token is untouched when animations are enabled', (
      tester,
    ) async {
      final resolved = await _resolve(
        tester,
        disableAnimations: false,
        input: beuiSpringMouse,
        isMovement: true,
      );
      expect(resolved, same(beuiSpringMouse));
    });
  });
}
