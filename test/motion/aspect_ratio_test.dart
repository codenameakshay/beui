import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// The barrel export is owned by the integration pass, outside this task's scope.
// ignore: implementation_imports
import 'package:beui/src/motion/aspect_ratio.dart';

import '../support.dart';

Widget _app({
  required double ratio,
  bool animated = true,
  bool reduce = false,
}) => beuiTestApp(
  SizedBox(
    width: 200,
    child: BeuiAspectRatio(
      ratio: ratio,
      animated: animated,
      child: const ColoredBox(color: Color(0xFF2678C8)),
    ),
  ),
  reduce: reduce,
);

void main() {
  testWidgets('ratio changes morph the frame with a spring', (tester) async {
    await tester.pumpWidget(_app(ratio: 1));
    expect(tester.getSize(find.byKey(beuiAspectRatioFrameKey)).height, 200);

    await tester.pumpWidget(_app(ratio: 2));
    await tester.pump(const Duration(milliseconds: 80));
    final intermediate = tester
        .getSize(find.byKey(beuiAspectRatioFrameKey))
        .height;
    expect(intermediate, lessThan(200));
    expect(intermediate, greaterThan(100));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(beuiAspectRatioFrameKey)).height,
      closeTo(100, 0.001),
    );
  });

  testWidgets('animated false applies a new ratio immediately', (tester) async {
    await tester.pumpWidget(_app(ratio: 1, animated: false));
    await tester.pumpWidget(_app(ratio: 2, animated: false));
    expect(tester.getSize(find.byKey(beuiAspectRatioFrameKey)).height, 100);
  });

  testWidgets('reduced motion applies a new ratio immediately', (tester) async {
    await tester.pumpWidget(_app(ratio: 1, reduce: true));
    await tester.pumpWidget(_app(ratio: 2, reduce: true));
    expect(tester.getSize(find.byKey(beuiAspectRatioFrameKey)).height, 100);
  });

  testWidgets('image is cover-cropped and exposes its alt text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beuiTestApp(
        SizedBox(
          width: 120,
          child: BeuiAspectRatio(
            ratio: 16 / 9,
            child: BeuiAspectRatioImage(
              image: MemoryImage(
                base64Decode(
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
                ),
              ),
              alt: 'Mountain lake',
              width: 300,
              height: 200,
            ),
          ),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.cover);
    expect(
      tester.getSemantics(find.byType(BeuiAspectRatioImage)),
      matchesSemantics(label: 'Mountain lake', isImage: true),
    );
    semantics.dispose();
  });

  testWidgets('rest-state golden (solid-color frame)', (tester) async {
    await tester.pumpWidget(_app(ratio: 4 / 3, animated: false));
    await expectLater(
      find.byKey(beuiAspectRatioFrameKey),
      matchesGoldenFile('goldens/beui_aspect_ratio.png'),
    );
  });
}
