import 'dart:ui' as ui;
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

void main() {
  testWidgets('collapsed rules scroll while header content stays fixed', (
    tester,
  ) async {
    const boundaryKey = ValueKey('grid paint');
    await tester.pumpWidget(
      beuiTestApp(
        RepaintBoundary(
          key: boundaryKey,
          child: BeuiTable<String>(
            data: List.generate(30, (i) => 'row $i'),
            height: 220,
            rowHeight: 52,
            sizing: BeuiTableSizing.intrinsic,
            columns: [
              BeuiTableColumn(key: 'name', header: 'Name', value: (r) => r),
            ],
            intrinsicSamples: (_, _) => const [
              BeuiTableIntrinsicSample.explicit('name', (
                minimum: 240,
                maximum: 240,
              )),
            ],
          ),
        ),
        width: 300,
        reduce: true,
      ),
    );
    final colors = Theme.of(
      tester.element(find.byType(BeuiTable<String>)),
    ).extension<BeuiColors>()!;
    final header = Color.alphaBlend(colors.border, colors.background);
    final body = Color.alphaBlend(
      colors.border.withValues(alpha: colors.border.a * .6),
      colors.background,
    );
    Future<void> check(Map<int, Color> expected) async {
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      final image = (await tester.runAsync(() => render.toImage()))!;
      final bytes = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      for (final entry in expected.entries) {
        final at = (entry.key * image.width + 200) * 4;
        final actual = [for (var i = 0; i < 3; i++) bytes.getUint8(at + i)];
        expect(actual, [
          (entry.value.r * 255).round(),
          (entry.value.g * 255).round(),
          (entry.value.b * 255).round(),
        ], reason: 'pixel row ${entry.key}');
      }
      image.dispose();
    }

    await check({53: header, 105: body});
    final controller = tester
        .widget<ListView>(find.byType(ListView))
        .controller!;
    controller.jumpTo(26);
    await tester.pump();
    await check({53: colors.background, 79: body});
    controller.jumpTo(52);
    await tester.pump();
    await check({53: body, 105: body});
    controller.jumpTo(52.75);
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    final image = (await tester.runAsync(() => boundary.toImage()))!;
    final bytes = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    expect(
      bytes.getUint8((53 * image.width + 200) * 4),
      lessThan((colors.background.r * 255).round()),
      reason: 'the final quarter pixel of the clipped rule remains visible',
    );
    image.dispose();
    expect(tester.takeException(), isNull);
  });

  for (final intrinsic in [true, false]) {
    testWidgets(
      '${intrinsic ? 'intrinsic collapsed' : 'legacy flex'} vertical grid',
      (tester) async {
        await tester.pumpWidget(
          beuiTestApp(
            BeuiTable<String>(
              data: const ['first', 'second', 'third'],
              height: 220,
              rowHeight: 52,
              selectable: true,
              resizable: true,
              sizing: intrinsic
                  ? BeuiTableSizing.intrinsic
                  : BeuiTableSizing.flex,
              columns: [
                BeuiTableColumn(key: 'name', header: 'Name', value: (r) => r),
              ],
              intrinsicSamples: (_, _) => const [
                BeuiTableIntrinsicSample.selectionWidths(24, 24),
                BeuiTableIntrinsicSample.explicit('name', (
                  minimum: 120,
                  maximum: 120,
                )),
              ],
            ),
            width: 300,
            reduce: true,
          ),
        );
        final handle = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Resize name column',
        );
        final headerTop = tester.getTopLeft(handle).dy;
        final viewport = tester.getRect(find.byType(ListView));
        final advance = intrinsic ? 52.5 : 52.0;
        expect(viewport.top - headerTop, advance);
        expect(viewport.height, 220 - advance);
        expect(tester.getSize(handle).height, intrinsic ? 52 : 51);
        final checkboxes = find.byType(BeuiCheckbox);
        expect(
          tester.getCenter(checkboxes.first).dy - headerTop,
          intrinsic ? 26 : 25.5,
        );
        for (var i = 0; i < 3; i++) {
          expect(
            tester.getCenter(checkboxes.at(i + 1)).dy - viewport.top,
            i * 52 + (intrinsic ? 26 : 25.5),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
