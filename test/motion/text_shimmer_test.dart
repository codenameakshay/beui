import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool reduce = false}) {
  Widget body = child;
  if (reduce) {
    body = MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: body,
    );
  }
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: Center(child: body)),
  );
}

void main() {
  testWidgets('shimmer sweep advances continuously over time', (tester) async {
    await tester.pumpWidget(_app(
      const BeuiTextShimmer(
        'Loading',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
      ),
    ));
    await tester.pump();

    // The shimmer loops, so the sweep keeps repainting frame after frame.
    expect(tester.binding.hasScheduledFrame, isTrue,
        reason: 'shimmer should be animating on mount');

    // Advancing time keeps it scheduling frames — a continuous sweep.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.hasScheduledFrame, isTrue,
          reason: 'the sweep should still be advancing at step $i');
    }
  });

  testWidgets('paints text through a srcIn ShaderMask', (tester) async {
    await tester.pumpWidget(_app(const BeuiTextShimmer('Shimmer')));
    await tester.pump();
    final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));
    expect(mask.blendMode, BlendMode.srcIn);
    expect(find.text('Shimmer'), findsOneWidget);
  });

  testWidgets('the shader callback produces a valid shader each frame',
      (tester) async {
    await tester.pumpWidget(_app(const BeuiTextShimmer('Loading')));
    await tester.pump();
    final maskEarly = tester.widget<ShaderMask>(find.byType(ShaderMask));
    const rect = Rect.fromLTWH(0, 0, 120, 24);
    expect(() => maskEarly.shaderCallback(rect), returnsNormally);

    await tester.pump(const Duration(milliseconds: 900));
    final maskLater = tester.widget<ShaderMask>(find.byType(ShaderMask));
    expect(() => maskLater.shaderCallback(rect), returnsNormally);
  });

  testWidgets('reduced motion holds a static highlight (no looping)',
      (tester) async {
    await tester.pumpWidget(_app(
      const BeuiTextShimmer('Loading'),
      reduce: true,
    ));
    // settle is safe here: with no repeating controller there is no infinite
    // animation to wait on.
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse,
        reason: 'shimmer should hold static under reduced motion');
    expect(find.text('Loading'), findsOneWidget);

    final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));
    expect(mask.blendMode, BlendMode.srcIn);
  });
}
