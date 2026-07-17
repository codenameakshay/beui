import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Renders all 21 shader variants into one montage golden for visual inspection.
// Reduced motion freezes each animated variant at t=0 for a deterministic frame.
void main() {
  testWidgets('all shader variants montage', (tester) async {
    tester.view.physicalSize = const Size(1020, 1300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget tile(BeuiShaderVariant v) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 180,
            height: 180,
            child: BeuiShaderBackground(variant: v),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 180,
          child: Text(
            v.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
        ),
      ],
    );

    final grid = MediaQuery(
      // Reduced motion => deterministic t=0 frame for every animated variant.
      data: const MediaQueryData(disableAnimations: true),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: const Color(0xFF202020),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              key: const ValueKey('montage'),
              spacing: 12,
              runSpacing: 12,
              children: [for (final v in BeuiShaderVariant.values) tile(v)],
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(grid);
      // Let every FragmentProgram + the shared noise image finish loading.
      for (var k = 0; k < 20; k++) {
        await tester.pump(const Duration(milliseconds: 16));
        await Future<void>.delayed(const Duration(milliseconds: 8));
      }
    });
    await tester.pump();

    await expectLater(
      find.byKey(const ValueKey('montage')),
      matchesGoldenFile('goldens/beui_shaders_all.png'),
    );
  });
}
