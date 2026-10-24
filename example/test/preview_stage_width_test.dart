import 'package:beui/beui.dart';
import 'package:beui_example/explorer/catalog.dart';
import 'package:beui_example/explorer/explorer_app.dart';
import 'package:beui_example/explorer/shell.dart';
import 'package:beui_example/explorer/theme_scope.dart';
import 'package:beui_example/explorer/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('previewWidth accepts only finite positive logical pixels', () {
    for (final (value, expected) in [
      ('592', 592.0),
      ('592.5', 592.5),
      ('1e2', 100.0),
    ]) {
      expect(
        explorerPreviewWidthFromUri(
          Uri(queryParameters: {'previewWidth': value}),
        ),
        expected,
      );
    }
    for (final value in [
      '',
      'wrong',
      '0',
      '-1',
      'NaN',
      'Infinity',
      '-Infinity',
      '1e999',
    ]) {
      expect(
        explorerPreviewWidthFromUri(
          Uri(queryParameters: {'previewWidth': value}),
        ),
        isNull,
      );
    }
    expect(explorerPreviewWidthFromUri(Uri()), isNull);
  });

  for (final scenario in [
    (
      label: 'explicit',
      viewport: 1280.0,
      query: '592',
      inner: 592.0,
      frame: 658.0,
    ),
    (
      label: 'narrow',
      viewport: 390.0,
      query: '592',
      inner: 284.0,
      frame: 350.0,
    ),
    (label: 'default', viewport: 1280.0, query: '', inner: 869.0, frame: 935.0),
    (
      label: 'invalid',
      viewport: 1280.0,
      query: 'NaN',
      inner: 869.0,
      frame: 935.0,
    ),
  ]) {
    testWidgets('${scenario.label} gallery delivers the measured child width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(scenario.viewport, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      BoxConstraints? received;
      const probeKey = ValueKey('stage-probe');
      final entry = ExploreEntry(
        title: 'Stage probe',
        slug: 'stage-probe',
        section: ExploreSection.components,
        blurb: 'Measures available preview content width.',
        builder: (_) => LayoutBuilder(
          builder: (_, constraints) {
            received = constraints;
            return const SizedBox(
              key: probeKey,
              width: double.infinity,
              height: 20,
            );
          },
        ),
      );
      await tester.pumpWidget(
        ThemeScope(
          brightness: Brightness.dark,
          colorTheme: BeuiColorTheme.defaultMono,
          setBrightness: (_) {},
          setColorTheme: (_) {},
          child: MaterialApp(
            theme: beuiGalleryTheme(
              BeuiColorTheme.defaultMono,
              Brightness.dark,
            ),
            home: ExplorerShell(
              initialRoute: DetailRoute(entry),
              previewWidth: explorerPreviewWidthFromUri(
                Uri(queryParameters: {'previewWidth': scenario.query}),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(received!.minWidth, 0);
      expect(received!.maxWidth, scenario.inner);
      expect(tester.getSize(find.byKey(probeKey)).width, scenario.inner);
      final frame = find.descendant(
        of: find.byType(PreviewSurface),
        matching: find.byWidgetPredicate(
          (widget) => widget is Container && widget.decoration is BoxDecoration,
        ),
      );
      expect(tester.getSize(frame).width, scenario.frame);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('explicit width preserves a demo max-width cap', (tester) async {
    const probeKey = ValueKey('capped-probe');
    await tester.pumpWidget(
      MaterialApp(
        theme: beuiGalleryTheme(BeuiColorTheme.defaultMono, Brightness.dark),
        home: Scaffold(
          body: PreviewSurface(
            innerWidth: 592,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: const SizedBox(
                key: probeKey,
                width: double.infinity,
                height: 20,
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(probeKey)).width, 320);
  });
}
