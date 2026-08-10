import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

List<BeuiCitationItem> _sample({int count = 3}) {
  const all = <BeuiCitationItem>[
    BeuiCitationItem(
      id: 'motion',
      title: Text('Motion documentation'),
      domain: Text('motion.dev'),
      url: 'https://motion.dev/docs/react',
    ),
    BeuiCitationItem(
      id: 'wai',
      title: Text('WAI accessibility patterns'),
      domain: Text('w3.org'),
      url: 'https://www.w3.org/WAI/ARIA/apg/',
    ),
    BeuiCitationItem(
      id: 'react',
      title: Text('React documentation'),
      domain: Text('react.dev'),
      url: 'https://react.dev/learn',
    ),
  ];
  return all.take(count).toList(growable: false);
}

Widget _host({
  required List<BeuiCitationItem> citations,
  Widget? title,
  bool? open,
  bool defaultOpen = true,
  ValueChanged<bool>? onOpenChange,
  String? idPrefix,
  bool reduce = false,
  Widget? above,
}) {
  Widget child = Center(
    child: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?above,
          BeuiCitations(
            citations: citations,
            title: title,
            open: open,
            defaultOpen: defaultOpen,
            onOpenChange: onOpenChange,
            idPrefix: idPrefix,
          ),
        ],
      ),
    ),
  );
  if (reduce) {
    final inner = child;
    child = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  group('beuiFaviconUrl', () {
    test('resolves /favicon.ico on the same origin', () {
      expect(
        beuiFaviconUrl('https://motion.dev/docs/react'),
        'https://motion.dev/favicon.ico',
      );
      expect(
        beuiFaviconUrl('https://www.w3.org/WAI/ARIA/apg/'),
        'https://www.w3.org/favicon.ico',
      );
    });

    test('returns null for invalid input', () {
      expect(beuiFaviconUrl('not a url'), isNull);
      expect(beuiFaviconUrl('/relative'), isNull);
    });
  });

  group('citationTargetId', () {
    test('sanitizes non-url-safe characters', () {
      expect(citationTargetId('preview', 'a b/c'), 'preview-a-b-c');
      expect(citationTargetId('p', 'ok_id-1'), 'p-ok_id-1');
    });
  });

  group('BeuiCitations', () {
    testWidgets('renders title, count, and rows when open', (tester) async {
      await tester.pumpWidget(
        _host(
          citations: _sample(),
          title: const Text('References'),
          defaultOpen: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('References'), findsOneWidget);
      expect(find.text('3'), findsWidgets); // count badge + row indices
      expect(find.text('Motion documentation'), findsOneWidget);
      expect(find.text('motion.dev'), findsOneWidget);
      expect(find.text('WAI accessibility patterns'), findsOneWidget);
      expect(find.text('React documentation'), findsOneWidget);
    });

    testWidgets('default title is Sources', (tester) async {
      await tester.pumpWidget(_host(citations: _sample(), defaultOpen: true));
      await tester.pumpAndSettle();
      expect(find.text('Sources'), findsOneWidget);
    });

    // Regression: Tailwind tracking is `normal`. An ambient Material text
    // theme (bodyMedium letterSpacing 0.25 by default) otherwise leaks into
    // every label and widens the panel by ~3.5%.
    testWidgets('header and row labels pin tracking to normal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: [BeuiColors.light()],
            textTheme: const TextTheme(
              bodyMedium: TextStyle(fontSize: 14, letterSpacing: 3),
            ),
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: BeuiCitations(
                  citations: _sample(count: 1),
                  defaultOpen: true,
                  idPrefix: 'tracking-panel',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      for (final label in <String>[
        'Sources',
        'Motion documentation',
        'motion.dev',
      ]) {
        final style = tester
            .renderObject<RenderParagraph>(find.text(label))
            .text
            .style!;
        expect(style.letterSpacing, 0, reason: 'tracking on "$label"');
      }
    });

    testWidgets('tapping header toggles open state (uncontrolled)', (
      tester,
    ) async {
      await tester.pumpWidget(_host(citations: _sample(), defaultOpen: true));
      await tester.pumpAndSettle();
      expect(find.text('Motion documentation'), findsOneWidget);

      await tester.tap(find.text('Sources'));
      await tester.pumpAndSettle();
      expect(find.text('Motion documentation'), findsNothing);

      await tester.tap(find.text('Sources'));
      await tester.pumpAndSettle();
      expect(find.text('Motion documentation'), findsOneWidget);
    });

    testWidgets('controlled open reports onOpenChange', (tester) async {
      var open = true;
      final calls = <bool>[];

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _host(
              citations: _sample(),
              open: open,
              onOpenChange: (v) {
                calls.add(v);
                setState(() => open = v);
              },
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sources'));
      await tester.pumpAndSettle();
      expect(calls, [false]);
      expect(find.text('Motion documentation'), findsNothing);

      await tester.tap(find.text('Sources'));
      await tester.pumpAndSettle();
      expect(calls, [false, true]);
    });

    testWidgets('defaultOpen false starts collapsed', (tester) async {
      await tester.pumpWidget(_host(citations: _sample(), defaultOpen: false));
      await tester.pumpAndSettle();
      expect(find.text('Sources'), findsOneWidget);
      expect(find.text('Motion documentation'), findsNothing);
    });

    testWidgets('progressive list growth shows new rows', (tester) async {
      var count = 1;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _host(
              citations: _sample(count: count),
              defaultOpen: true,
              above: TextButton(
                onPressed: () => setState(() => count = 3),
                child: const Text('Grow'),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Motion documentation'), findsOneWidget);
      expect(find.text('React documentation'), findsNothing);

      await tester.tap(find.text('Grow'));
      await tester.pumpAndSettle();
      expect(find.text('React documentation'), findsOneWidget);
      expect(find.text('WAI accessibility patterns'), findsOneWidget);
    });

    testWidgets('reduced motion still toggles disclosure', (tester) async {
      await tester.pumpWidget(
        _host(citations: _sample(), defaultOpen: true, reduce: true),
      );
      await tester.pump(); // no settle — no infinite animations expected
      expect(find.text('Motion documentation'), findsOneWidget);

      await tester.tap(find.text('Sources'));
      await tester.pump();
      expect(find.text('Motion documentation'), findsNothing);
    });

    testWidgets('row onTap fires when provided', (tester) async {
      final taps = <String>[];
      final items = [
        BeuiCitationItem(
          id: 'motion',
          title: const Text('Motion documentation'),
          domain: const Text('motion.dev'),
          url: 'https://motion.dev/docs/react',
          onTap: () => taps.add('motion'),
        ),
      ];
      await tester.pumpWidget(_host(citations: items, defaultOpen: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Motion documentation'));
      await tester.pump();
      expect(taps, ['motion']);
    });
  });

  group('BeuiCitation', () {
    testWidgets('renders index badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: const Scaffold(
            body: Center(
              child: BeuiCitation(
                citationId: 'motion',
                index: 2,
                idPrefix: 'test',
              ),
            ),
          ),
        ),
      );
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('marker opens collapsed panel and reveals row', (tester) async {
      await tester.pumpWidget(
        _host(
          citations: _sample(count: 1),
          defaultOpen: false,
          idPrefix: 'preview-source',
          above: const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: BeuiCitation(
              citationId: 'motion',
              index: 1,
              idPrefix: 'preview-source',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Motion documentation'), findsNothing);

      // Tap the inline marker (not the Sources header).
      await tester.tap(find.byType(BeuiCitation));
      await tester.pumpAndSettle();
      expect(find.text('Motion documentation'), findsOneWidget);
    });

    testWidgets('onPressed override skips scroll registry', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: Scaffold(
            body: Center(
              child: BeuiCitation(
                citationId: 'x',
                index: 1,
                idPrefix: 'none',
                onPressed: () => pressed = true,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(BeuiCitation));
      await tester.pump();
      expect(pressed, isTrue);
    });

    // Regression: the marker is an inline `<a>` in the source. Container's
    // `alignment:` inserts an unbounded Align, which inside a WidgetSpan takes
    // the whole paragraph width and forces a line break around every marker.
    testWidgets('inline marker shrink-wraps inside a WidgetSpan', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: Text.rich(
                  key: Key('para'),
                  TextSpan(
                    children: [
                      TextSpan(text: 'before '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: BeuiCitation(
                          citationId: 'motion',
                          index: 1,
                          idPrefix: 'inline',
                        ),
                      ),
                      TextSpan(text: ' after'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final marker = tester.getSize(find.byType(BeuiCitation));
      // min-w-4 (16) + mx-0.5 (2+2) = 20; anything near 400 means it grabbed
      // the paragraph width.
      expect(marker.width, lessThan(32));

      // The whole run must still fit on one line.
      final paragraph = tester.renderObject<RenderBox>(
        find.byKey(const Key('para')),
      );
      expect(paragraph.size.height, lessThan(40));
    });

    testWidgets('marker index pins tracking to normal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: [BeuiColors.light()],
            textTheme: const TextTheme(
              bodyMedium: TextStyle(fontSize: 14, letterSpacing: 3),
            ),
          ),
          home: const Scaffold(
            body: Center(
              child: BeuiCitation(
                citationId: 'motion',
                index: 2,
                idPrefix: 'tracking',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final style = tester
          .renderObject<RenderParagraph>(find.text('2'))
          .text
          .style!;
      expect(style.letterSpacing, 0);
    });
  });

  group('BeuiCitationFavicon', () {
    // Regression: the source falls back to lucide `Globe2` (renamed `earth`
    // in flutter_lucide), not `globe` — a visibly different glyph.
    testWidgets('falls back to the Globe2/earth glyph', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          home: const Scaffold(body: Center(child: BeuiCitationFavicon())),
        ),
      );
      await tester.pump();
      expect(find.byIcon(LucideIcons.earth), findsOneWidget);
      expect(find.byIcon(LucideIcons.globe), findsNothing);
    });
  });

  group('BeuiCitationStack', () {
    testWidgets('renders up to limit favicon slots', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: Scaffold(
            body: Center(
              child: BeuiCitationStack(citations: _sample(), limit: 2),
            ),
          ),
        ),
      );
      await tester.pump();
      // Two slots (network images fall back to globe icons offline).
      expect(find.byType(BeuiCitationFavicon), findsNWidgets(2));
    });
  });

  group('BeuiCitationList', () {
    testWidgets('renders rows without a parent panel', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: Scaffold(
            body: Center(
              child: BeuiCitationList(
                citations: _sample(count: 2),
                idPrefix: 'standalone',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Motion documentation'), findsOneWidget);
      expect(find.text('WAI accessibility patterns'), findsOneWidget);
    });
  });
}
