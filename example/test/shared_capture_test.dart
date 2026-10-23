import 'package:beui/beui.dart';
import 'package:beui_example/explorer/capture_probe.dart';
import 'package:beui_example/explorer/explorer_app.dart';
import 'package:beui_example/explorer/widgets.dart';
import 'package:beui_example/visual_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scenario in [
    (query: '592', viewport: 1280.0, expected: 592.0),
    (query: '592', viewport: 390.0, expected: 294.0),
    (query: '', viewport: 1280.0, expected: 1184.0),
    (query: 'NaN', viewport: 1280.0, expected: 1184.0),
  ]) {
    testWidgets('visual launch URI delivers $scenario', (tester) async {
      tester.view.physicalSize = Size(scenario.viewport, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        VisualHarnessApp(
          uri: Uri(
            queryParameters: {
              'slug': 'tooltip',
              'theme': 'light',
              'previewWidth': scenario.query,
              'captureProbe': '1',
            },
          ),
        ),
      );
      final probe = tester.renderObject<RenderBox>(find.byType(CaptureProbe));
      expect(probe.constraints.minWidth, 0);
      expect(probe.constraints.maxWidth, scenario.expected);
      expect(find.text('Top'), findsOneWidget);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        const Color(0xFFFCFCFC),
      );
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('preview paints the $brightness page background', (
      tester,
    ) async {
      final colors = BeuiColors.of(BeuiColorTheme.defaultMono, brightness);
      await tester.pumpWidget(
        MaterialApp(
          theme: beuiGalleryTheme(BeuiColorTheme.defaultMono, brightness),
          home: const Scaffold(
            body: PreviewSurface(child: SizedBox.square(dimension: 20)),
          ),
        ),
      );
      final frame = tester.widget<Container>(
        find.descendant(
          of: find.byType(PreviewSurface),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration,
          ),
        ),
      );
      expect((frame.decoration! as BoxDecoration).color, colors.background);
    });
  }

  for (final scenario in [
    (width: 592.0, viewport: 1280.0, expected: 592.0),
    (width: 592.0, viewport: 390.0, expected: 294.0),
    (width: null, viewport: 1280.0, expected: 1184.0),
  ]) {
    testWidgets('visual stage delivers $scenario', (tester) async {
      tester.view.physicalSize = Size(scenario.viewport, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late BoxConstraints received;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(48),
              child: VisualCaptureStage(
                innerWidth: scenario.width,
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    received = constraints;
                    return const SizedBox(
                      key: ValueKey('probe'),
                      width: double.infinity,
                      height: 20,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(received.minWidth, 0);
      expect(received.maxWidth, scenario.expected);
      expect(
        tester.getSize(find.byKey(const ValueKey('probe'))).width,
        scenario.expected,
      );
    });
  }

  testWidgets('visual stage preserves the demo width cap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VisualCaptureStage(
            innerWidth: 592,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: const SizedBox(
                key: ValueKey('capped'),
                width: double.infinity,
                height: 20,
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('capped'))).width, 320);
  });

  for (final reduced in [false, true]) {
    testWidgets('probe preserves effective motion preference $reduced', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: reduced);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      late bool effective;
      late BoxConstraints received;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CaptureProbe(
                enabled: true,
                background: Colors.white,
                child: Builder(
                  builder: (context) {
                    effective = MediaQuery.disableAnimationsOf(context);
                    return LayoutBuilder(
                      builder: (_, constraints) {
                        received = constraints;
                        return const SizedBox(
                          key: ValueKey('motion'),
                          width: 80,
                          height: 40,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(effective, reduced);
      expect(received.minWidth, 0);
      expect(received.maxWidth, 800);
      expect(
        tester.getSize(find.byKey(const ValueKey('motion'))),
        const Size(80, 40),
      );
    });
  }
}
