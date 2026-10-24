import 'dart:convert';

import 'package:beui/beui.dart';
import 'package:beui_example/explorer/explorer_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared families lay out the bundled source fonts', (
    tester,
  ) async {
    const fonts = BeuiTextTheme();
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    final monoAssets = manifest.singleWhere(
      (dynamic entry) => entry['family'] == 'Geist Mono',
    );
    final aliasAssets = manifest.singleWhere(
      (dynamic entry) => entry['family'] == 'monospace',
    );
    expect(monoAssets['fonts'], aliasAssets['fonts']);
    await tester.pumpWidget(
      MaterialApp(
        theme: BeuiTextTheme.trackingNormal(
          ThemeData(fontFamily: fonts.sansFamily),
        ),
        home: Scaffold(
          body: Column(
            children: [
              const Text(
                'Build something great. 0123456789 Wiil',
                key: Key('sans'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
              ),
              Text(
                'iiiiiiiiii',
                key: const Key('mono-narrow'),
                style: TextStyle(
                  fontFamily: fonts.monoFamily,
                  fontFamilyFallback: fonts.monoFamilyFallback,
                  fontSize: 14,
                ),
              ),
              Text(
                'WWWWWWWWWW',
                key: const Key('mono-wide'),
                style: TextStyle(fontFamily: fonts.monoFamily, fontSize: 14),
              ),
              const Text(
                'iiiiiiiiii',
                key: Key('mono-alias'),
                style: TextStyle(fontFamily: 'monospace', fontSize: 14),
              ),
              Text(
                'iiiiiiiiii',
                key: const Key('agent-mono'),
                style: const BeuiAgentTypography().mono,
              ),
            ],
          ),
        ),
      ),
    );
    RenderParagraph paragraph(String key) =>
        tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(RichText),
          ),
        );
    final sans = paragraph('sans');
    final mono = paragraph('mono-narrow');
    expect(sans.text.style!.fontFamily, 'Geist');
    expect(mono.text.style!.fontFamily, 'Geist Mono');
    expect(sans.size.width, closeTo(253.96, 0.02));
    expect(mono.size.width, closeTo(84, 0.02));
    expect(paragraph('mono-wide').size.width, closeTo(84, 0.02));
    expect(paragraph('mono-alias').size.width, closeTo(84, 0.02));
    expect(paragraph('agent-mono').text.style!.fontFamily, 'monospace');
    expect(paragraph('agent-mono').size.width, closeTo(72, 0.02));
    debugPrint(
      'Rendered font widths at 14px: Geist=${sans.size.width}, '
      'Geist Mono narrow=${mono.size.width}, '
      'Geist Mono wide=${paragraph('mono-wide').size.width}, '
      'monospace alias=${paragraph('mono-alias').size.width}; '
      'agent mono at 12px=${paragraph('agent-mono').size.width}',
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('gallery applies Geist in ${brightness.name}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: beuiGalleryTheme(BeuiColorTheme.defaultMono, brightness),
          home: const Scaffold(
            body: Text('Build something great. 0123456789 Wiil'),
          ),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText).last,
      );
      expect(paragraph.text.style!.fontFamily, 'Geist');
      expect(paragraph.text.style!.letterSpacing, 0);
      expect(paragraph.size.width, closeTo(253.96, 0.02));
    });
  }
}
