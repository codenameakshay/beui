import 'dart:ui' as ui;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  testWidgets('the positional string API keeps its public values and Text', (
    tester,
  ) async {
    const style = TextStyle(fontSize: 23, fontWeight: FontWeight.w600);
    const base = Color(0xFF123456);
    const highlight = Color(0xFFABCDEF);
    const shimmer = BeuiTextShimmer(
      'Loading',
      duration: Duration(milliseconds: 1700),
      style: style,
      textAlign: TextAlign.end,
      baseColor: base,
      highlightColor: highlight,
    );

    expect(shimmer.text, 'Loading');
    expect(shimmer.duration, const Duration(milliseconds: 1700));
    expect(shimmer.style, style);
    expect(shimmer.textAlign, TextAlign.end);
    expect(shimmer.baseColor, base);
    expect(shimmer.highlightColor, highlight);

    await tester.pumpWidget(beuiTestApp(shimmer));
    final text = tester.widget<Text>(find.text('Loading'));
    expect(text.data, 'Loading');
    expect(text.style, style);
    expect(text.textAlign, TextAlign.end);
  });

  testWidgets('child constructor exposes empty compatibility text', (
    tester,
  ) async {
    const shimmer = BeuiTextShimmer.child(Text('Thinking…'));

    expect(shimmer.text, '');
    expect(shimmer.duration, const Duration(milliseconds: 2500));
    await tester.pumpWidget(beuiTestApp(shimmer));
    expect(find.text('Thinking…'), findsOneWidget);
    expect(find.text(''), findsNothing);
  });

  testWidgets(
    'rich child text composes and inherits merged style and alignment',
    (tester) async {
      DefaultTextStyle? observed;
      await tester.pumpWidget(
        beuiTestApp(
          DefaultTextStyle(
            style: const TextStyle(fontSize: 18, color: Colors.green),
            textAlign: TextAlign.right,
            child: BeuiTextShimmer.child(
              Builder(
                builder: (context) {
                  observed = DefaultTextStyle.of(context);
                  return const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Thinking '),
                        TextSpan(
                          text: 'deeply',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  );
                },
              ),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ),
      );

      expect(find.text('Thinking deeply'), findsOneWidget);
      expect(observed!.style.fontSize, 18);
      expect(observed!.style.color, Colors.green);
      expect(observed!.style.fontWeight, FontWeight.w500);
      expect(observed!.textAlign, TextAlign.right);
    },
  );

  testWidgets('explicit child text style takes normal Flutter precedence', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        DefaultTextStyle(
          style: const TextStyle(fontSize: 20, color: Colors.green),
          child: const BeuiTextShimmer.child(
            Text(
              'Explicit',
              style: TextStyle(fontSize: 12, color: Colors.blue),
            ),
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText));
    expect(richText.text.style!.fontSize, 12);
    expect(richText.text.style!.color, Colors.blue);
    expect(richText.text.style!.fontWeight, FontWeight.bold);
    expect(richText.textAlign, TextAlign.center);
  });

  testWidgets('child layout constraints and semantics pass through the mask', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        beuiTestApp(
          SizedBox(
            width: 90,
            child: BeuiTextShimmer.child(
              Semantics(
                key: const ValueKey('child-semantics'),
                label: 'Loading account details',
                child: const Text('A long child-owned loading message'),
              ),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(BeuiTextShimmer)).width, 90);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('child-semantics'))),
        matchesSemantics(
          label: 'Loading account details\nA long child-owned loading message',
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('interactive child retains focus and callback ownership', (
    tester,
  ) async {
    final focusNode = FocusNode(debugLabel: 'shimmer child');
    var activations = 0;
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      beuiTestApp(
        BeuiTextShimmer.child(
          ElevatedButton(
            focusNode: focusNode,
            onPressed: () => activations++,
            child: const Text('Activate child'),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusNode.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(activations, 1);
    await tester.tap(find.text('Activate child'));
    expect(activations, 2);
  });

  testWidgets('keyed child replacement paints only the replacement', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiTextShimmer.child(
          Text('First child', key: ValueKey('first')),
          key: ValueKey('shimmer'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiTextShimmer.child(
          Text('Replacement child', key: ValueKey('replacement')),
          key: ValueKey('shimmer'),
        ),
      ),
    );

    expect(find.text('First child'), findsNothing);
    expect(find.text('Replacement child'), findsOneWidget);
  });

  testWidgets('string and child content can replace each other on one state', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiTextShimmer('String child', key: ValueKey('same-state')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiTextShimmer.child(
          Text('Widget child'),
          key: ValueKey('same-state'),
        ),
      ),
    );
    expect(find.text('String child'), findsNothing);
    expect(find.text('Widget child'), findsOneWidget);

    await tester.pumpWidget(
      beuiTestApp(
        const BeuiTextShimmer('String again', key: ValueKey('same-state')),
      ),
    );
    expect(find.text('Widget child'), findsNothing);
    expect(find.text('String again'), findsOneWidget);
  });

  testWidgets('duration and reduced-motion updates keep one live child path', (
    tester,
  ) async {
    const child = Text('Updated duration');
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiTextShimmer.child(
          child,
          duration: Duration(milliseconds: 2500),
          style: TextStyle(fontSize: 14),
          baseColor: Colors.black,
          highlightColor: Colors.white,
          key: ValueKey('duration-state'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiTextShimmer.child(
          child,
          duration: Duration(milliseconds: 1800),
          style: TextStyle(fontSize: 20),
          baseColor: Colors.blue,
          highlightColor: Colors.yellow,
          key: ValueKey('duration-state'),
        ),
      ),
    );
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiTextShimmer.child(
          child,
          duration: Duration(milliseconds: 1800),
          style: TextStyle(fontSize: 20),
          baseColor: Colors.blue,
          highlightColor: Colors.yellow,
          key: ValueKey('duration-state'),
        ),
        reduce: true,
      ),
    );
    await tester.pump();
    expect(find.text('Updated duration'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('disposing during a normal sweep releases the controller', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiTextShimmer.child(Text('Disposing'))),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(beuiTestApp(const SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Disposing'), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
    'equivalent constructors rasterize identical fixed-time shaders',
    (tester) async {
      const base = Color(0xFF000000);
      const highlight = Color(0xFFFFFFFF);
      const bounds = Rect.fromLTWH(0, 0, 200, 24);

      Future<List<int>> raster(Widget widget) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(beuiTestApp(widget));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 625));
        final shader = tester
            .widget<ShaderMask>(find.byType(ShaderMask))
            .shaderCallback(bounds);
        late List<int> red;
        await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          Canvas(recorder, bounds).drawRect(bounds, Paint()..shader = shader);
          final image = await recorder.endRecording().toImage(200, 24);
          final data = (await image.toByteData())!;
          image.dispose();
          red = [
            for (var x = 0; x < 200; x++) data.getUint8((12 * 200 + x) * 4),
          ];
        });
        return red;
      }

      final stringPixels = await raster(
        const BeuiTextShimmer(
          'Loading',
          style: TextStyle(fontSize: 16),
          baseColor: base,
          highlightColor: highlight,
        ),
      );
      final childPixels = await raster(
        const BeuiTextShimmer.child(
          Text('Loading', style: TextStyle(fontSize: 16)),
          baseColor: base,
          highlightColor: highlight,
        ),
      );

      expect(childPixels, stringPixels);
      expect(stringPixels[0], closeTo(253, 2));
      expect(stringPixels[40], closeTo(133, 3));
      expect(stringPixels[80], closeTo(13, 3));
      expect(stringPixels[100], 0);
      expect(stringPixels.toSet().length, greaterThan(20));
      expect(
        stringPixels.reduce((a, b) => a > b ? a : b) -
            stringPixels.reduce((a, b) => a < b ? a : b),
        greaterThan(40),
      );
    },
  );
}
