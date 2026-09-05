import 'package:beui/beui.dart';
import 'package:beui/src/motion/shader_background/shader_background.dart'
    show beuiShaderRegistry;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(BeuiShaderVariant variant, {bool reduce = false}) {
  Widget body = SizedBox(
    width: 240,
    height: 240,
    child: BeuiShaderBackground(variant: variant),
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
    home: Scaffold(body: Center(child: body)),
  );
}

void main() {
  test('beuiShaderRegistry has an entry for every variant', () {
    expect(beuiShaderRegistry.keys.toSet(), BeuiShaderVariant.values.toSet());
  });

  // Every variant compiles, loads and paints — texture variants (voronoi,
  // metaballs, smokeRing, warp, godRays, dotOrbit, pulsingBorder,
  // grainGradient, water) additionally decode the shared noise PNG, so all 21
  // run inside runAsync to let that real async work settle; a plain pump
  // never resolves it. `reduce` is a parameter within the same test rather
  // than a separate one, so both motion paths are covered without doubling
  // the suite.
  for (final v in BeuiShaderVariant.values) {
    testWidgets('${v.name} compiles, loads and paints', (tester) async {
      Future<void> pumpAndSettleAsync(bool reduce) async {
        await tester.runAsync(() async {
          await tester.pumpWidget(_app(v, reduce: reduce));
          for (var k = 0; k < 12; k++) {
            await tester.pump(const Duration(milliseconds: 16));
            await Future<void>.delayed(const Duration(milliseconds: 8));
          }
        });
        await tester.pump();
        expect(
          find.descendant(
            of: find.byType(BeuiShaderBackground),
            matching: find.byType(CustomPaint),
          ),
          findsOneWidget,
        );
      }

      await pumpAndSettleAsync(false);
      await pumpAndSettleAsync(true);
    });
  }
}
