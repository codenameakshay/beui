import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(BeuiShaderVariant variant, {bool reduce = false}) {
  Widget body = const SizedBox(width: 240, height: 240);
  body = SizedBox(
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
  return MaterialApp(home: Scaffold(body: Center(child: body)));
}

void main() {
  testWidgets('simplex-noise compiles, loads and paints', (tester) async {
    await tester.pumpWidget(_app(BeuiShaderVariant.simplexNoise));
    // Async FragmentProgram.fromAsset resolves, then the shader paints.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(BeuiShaderBackground), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('reduced motion does not throw and still paints', (tester) async {
    await tester.pumpWidget(_app(BeuiShaderVariant.simplexNoise, reduce: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(CustomPaint), findsWidgets);
  });

  for (final v in const [
    BeuiShaderVariant.dotGrid,
    BeuiShaderVariant.meshGradient,
    BeuiShaderVariant.staticMeshGradient,
    BeuiShaderVariant.perlinNoise,
    BeuiShaderVariant.swirl,
    BeuiShaderVariant.waves,
    BeuiShaderVariant.spiral,
    BeuiShaderVariant.staticRadialGradient,
    BeuiShaderVariant.neuroNoise,
    BeuiShaderVariant.dithering,
  ]) {
    testWidgets('${v.name} compiles, loads and paints', (tester) async {
      await tester.pumpWidget(_app(v));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(BeuiShaderBackground), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  }

  // Texture-driven variants also decode the shared noise PNG asynchronously,
  // so they need real async (runAsync) before the shader paints.
  for (final v in const [
    BeuiShaderVariant.voronoi,
    BeuiShaderVariant.metaballs,
    BeuiShaderVariant.smokeRing,
    BeuiShaderVariant.warp,
    BeuiShaderVariant.godRays,
    BeuiShaderVariant.dotOrbit,
  ]) {
    testWidgets('${v.name} compiles, loads and paints (texture)', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(_app(v));
        // Let FragmentProgram.fromAsset + the noise image codec resolve.
        for (var k = 0; k < 12; k++) {
          await tester.pump(const Duration(milliseconds: 16));
          await Future<void>.delayed(const Duration(milliseconds: 8));
        }
      });
      await tester.pump();
      expect(find.byType(BeuiShaderBackground), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  }
}
