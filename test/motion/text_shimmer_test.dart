import 'dart:ui' as ui;

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
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(body: Center(child: body)),
  );
}

void main() {
  testWidgets('shimmer sweep advances continuously over time', (tester) async {
    await tester.pumpWidget(
      _app(
        const BeuiTextShimmer(
          'Loading',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        ),
      ),
    );
    await tester.pump();

    // The shimmer loops, so the sweep keeps repainting frame after frame.
    expect(
      tester.binding.hasScheduledFrame,
      isTrue,
      reason: 'shimmer should be animating on mount',
    );

    // Advancing time keeps it scheduling frames — a continuous sweep.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.binding.hasScheduledFrame,
        isTrue,
        reason: 'the sweep should still be advancing at step $i',
      );
    }
  });

  testWidgets('paints text through a srcIn ShaderMask', (tester) async {
    await tester.pumpWidget(_app(const BeuiTextShimmer('Shimmer')));
    await tester.pump();
    final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));
    expect(mask.blendMode, BlendMode.srcIn);
    expect(find.text('Shimmer'), findsOneWidget);
  });

  testWidgets('the shader callback produces a valid shader each frame', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const BeuiTextShimmer('Loading')));
    await tester.pump();
    final maskEarly = tester.widget<ShaderMask>(find.byType(ShaderMask));
    const rect = Rect.fromLTWH(0, 0, 120, 24);
    expect(() => maskEarly.shaderCallback(rect), returnsNormally);

    await tester.pump(const Duration(milliseconds: 900));
    final maskLater = tester.widget<ShaderMask>(find.byType(ShaderMask));
    expect(() => maskLater.shaderCallback(rect), returnsNormally);
  });

  testWidgets('the gradient tile repeats (source background-repeat default)', (
    tester,
  ) async {
    // The source never sets `background-repeat`, so it keeps the CSS default of
    // `repeat`: the 200%-wide tile repeats across the text, putting two
    // highlights through the glyphs per cycle instead of one with a dead half.
    //
    // The checkable consequence: the 2W tile travels from -2W to +2W, so at
    // t = 0 it lies entirely left of the text and for t > 0.75 entirely right of
    // it. A clamped gradient floods the text with one flat colour at exactly
    // those phases — the stall. A repeating one always has a neighbouring tile
    // over the glyphs, so the row is never flat.
    const base = Color(0xFF000000);
    const highlight = Color(0xFFFFFFFF);
    await tester.pumpWidget(
      _app(
        const BeuiTextShimmer(
          'Loading',
          baseColor: base,
          highlightColor: highlight,
        ),
      ),
    );
    await tester.pump();

    const rect = Rect.fromLTWH(0, 0, 200, 24);
    Future<List<int>> row() async {
      final shader = tester
          .widget<ShaderMask>(find.byType(ShaderMask))
          .shaderCallback(rect);
      late List<int> pixels;
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder, rect).drawRect(rect, Paint()..shader = shader);
        final image = await recorder.endRecording().toImage(200, 24);
        final data = (await image.toByteData())!;
        image.dispose();
        // Row 12 (mid-height), red channel; RGBA8888 is 4 bytes per pixel.
        pixels = [
          for (var x = 0; x < 200; x++) data.getUint8(((12 * 200) + x) * 4),
        ];
      });
      return pixels;
    }

    int contrast(List<int> px) =>
        px.reduce((a, b) => a > b ? a : b) - px.reduce((a, b) => a < b ? a : b);

    expect(
      contrast(await row()),
      greaterThan(40),
      reason:
          'at t=0 the tile lies entirely left of the text; with the source\'s '
          'repeat the neighbouring tile still paints a ramp, so the row cannot '
          'be flat',
    );

    // t = 0.8 of the 2.5s default cycle: the tile is now entirely right of the
    // text — the other phase a clamped gradient would flood flat.
    await tester.pump(const Duration(milliseconds: 2000));
    expect(
      contrast(await row()),
      greaterThan(40),
      reason: 'at t=0.8 the tile lies entirely right of the text; same reason',
    );
  });

  testWidgets('reduced motion holds a static highlight (no looping)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const BeuiTextShimmer('Loading'), reduce: true),
    );
    // settle is safe here: with no repeating controller there is no infinite
    // animation to wait on.
    await tester.pumpAndSettle();
    expect(
      tester.binding.hasScheduledFrame,
      isFalse,
      reason: 'shimmer should hold static under reduced motion',
    );
    expect(find.text('Loading'), findsOneWidget);

    final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));
    expect(mask.blendMode, BlendMode.srcIn);
  });
}
