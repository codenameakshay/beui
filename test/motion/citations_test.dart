import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  ValueChanged<BeuiCitationItem>? onCitationTap,
  String? idPrefix,
  bool reduce = false,
  List<Widget> above = const [],
}) {
  Widget child = Center(
    child: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...above,
          BeuiCitations(
            citations: citations,
            title: title,
            open: open,
            defaultOpen: defaultOpen,
            onOpenChange: onOpenChange,
            onCitationTap: onCitationTap,
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
              above: [
                TextButton(
                  onPressed: () => setState(() => count = 3),
                  child: const Text('Grow'),
                ),
              ],
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
      // The shared disclosure keeps the opacity channel under reduced motion,
      // so the panel is still mounted mid-cross-fade — movement is what gets
      // dropped, not the transition. It unmounts once the fade lands.
      await tester.pump(const Duration(milliseconds: 200));
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
    testWidgets('marker opens collapsed panel and reveals row', (tester) async {
      await tester.pumpWidget(
        _host(
          citations: _sample(count: 1),
          defaultOpen: false,
          idPrefix: 'preview-source',
          above: const [
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: BeuiCitation(
                citationId: 'motion',
                index: 1,
                idPrefix: 'preview-source',
              ),
            ),
          ],
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

  group('BeuiCitations row interactivity', () {
    testWidgets('a url alone does not make a row interactive', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(citations: _sample(count: 1)));
      await tester.pumpAndSettle();
      // The package does not open URLs, so the row has nothing to do when
      // activated — and must not advertise otherwise.
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('Citation 1'))),
        isSemantics(isButton: false),
      );
      handle.dispose();
    });

    testWidgets('nor does it get the link glyph that promises one', (
      tester,
    ) async {
      await tester.pumpWidget(_host(citations: _sample(count: 1)));
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.external_link), findsNothing);
    });

    testWidgets('onCitationTap makes the row live and fires with the item', (
      tester,
    ) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        _host(
          citations: _sample(count: 2),
          onCitationTap: (c) => tapped.add(c.id),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.external_link), findsNWidgets(2));
      await tester.tap(find.text('WAI accessibility patterns'));
      await tester.pump();
      expect(tapped, ['wai']);
    });

    testWidgets('a per-item onTap is enough on its own', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _host(
          citations: [
            BeuiCitationItem(
              id: 'only',
              title: const Text('Only one'),
              url: 'https://example.com',
              onTap: () => calls++,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Only one'));
      await tester.pump();
      expect(calls, 1);
    });
  });

  group('BeuiCitations row legibility', () {
    testWidgets('the domain is not alpha-multiplied into illegibility', (
      tester,
    ) async {
      await tester.pumpWidget(_host(citations: _sample(count: 1)));
      await tester.pumpAndSettle();
      final style = DefaultTextStyle.of(
        tester.element(find.text('motion.dev')),
      ).style;
      // Full-strength mutedForeground: the domain is how a reader decides
      // whether to trust the source, and at 0.6 alpha it measured 2.55:1.
      expect(style.color!.a, 1.0);
    });

    testWidgets('the link glyph is legible at rest', (tester) async {
      await tester.pumpWidget(
        _host(citations: _sample(count: 1), onCitationTap: (_) {}),
      );
      await tester.pumpAndSettle();
      final icon = tester.widget<Icon>(find.byIcon(LucideIcons.external_link));
      // 0.7, not the 0.4 that measured 1.79:1.
      expect(icon.color!.a, closeTo(0.7, 0.01));
    });

    testWidgets('hovering an interactive row fills it at the declared radius', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(citations: _sample(count: 1), onCitationTap: (_) {}),
      );
      await tester.pumpAndSettle();

      BoxDecoration rowDecoration() {
        final containers = tester.widgetList<AnimatedContainer>(
          find.ancestor(
            of: find.text('Motion documentation'),
            matching: find.byType(AnimatedContainer),
          ),
        );
        return containers.first.decoration! as BoxDecoration;
      }

      expect(rowDecoration().color, Colors.transparent);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('Motion documentation')));
      await tester.pumpAndSettle();

      final hovered = rowDecoration();
      // A real affordance, not a foreground 0.8 → 1.0 title shift.
      expect(hovered.color!.a, closeTo(0.5, 0.01));
      expect(
        hovered.borderRadius,
        BorderRadius.circular(6),
        reason: 'the 6px radius the row already declared',
      );
    });
  });

  group('BeuiCitation numbering', () {
    testWidgets('the marker derives its number from the rendered order', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          citations: _sample(),
          idPrefix: 'derive',
          above: const [BeuiCitation(citationId: 'react', idPrefix: 'derive')],
        ),
      );
      await tester.pumpAndSettle();
      // `react` is row 3, so the marker reads 3 — nobody had to count.
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('it follows the list when the order changes', (tester) async {
      await tester.pumpWidget(
        _host(
          citations: _sample(),
          idPrefix: 'reorder',
          above: const [BeuiCitation(citationId: 'react', idPrefix: 'reorder')],
        ),
      );
      await tester.pumpAndSettle();

      // Filter the first source out; every later row shifts up by one.
      await tester.pumpWidget(
        _host(
          citations: _sample().sublist(1),
          idPrefix: 'reorder',
          above: const [BeuiCitation(citationId: 'react', idPrefix: 'reorder')],
        ),
      );
      await tester.pumpAndSettle();
      final marker = tester.widget<Text>(
        find.descendant(
          of: find.byType(BeuiCitation),
          matching: find.byType(Text),
        ),
      );
      // [3] pointing at row 2 is exactly the desync this replaces.
      expect(marker.data, '2');
    });

    testWidgets('an explicit index that disagrees with the list asserts', (
      tester,
    ) async {
      // Collected off FlutterError rather than through takeException: the
      // marker asserts on every rebuild, and the binding coalesces repeats
      // into one opaque "multiple exceptions" report.
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);

      await tester.pumpWidget(
        _host(
          citations: _sample(),
          idPrefix: 'clash',
          above: const [
            BeuiCitation(citationId: 'react', index: 1, idPrefix: 'clash'),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      FlutterError.onError = previous;

      expect(errors, isNotEmpty);
      expect(errors.first.exception, isA<AssertionError>());
      expect(
        errors.first.exception.toString(),
        contains('it is row 3 of the list under idPrefix "clash"'),
      );
    });

    testWidgets('an explicit index still seeds the frames before the list '
        'renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: const Scaffold(
            body: Center(
              child: BeuiCitation(
                citationId: 'orphan',
                index: 7,
                idPrefix: 'nothing-registered-here',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('7'), findsOneWidget);
    });
  });

  group('BeuiCitation marker', () {
    Widget marker() => MaterialApp(
      theme: BeuiTextTheme.trackingNormal(
        ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
      ),
      home: const Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Grounded in the docs'),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: BeuiCitation(
                      citationId: 'm',
                      index: 1,
                      idPrefix: 'inline',
                    ),
                  ),
                  TextSpan(text: ' and elsewhere.'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('focusing it does not reflow the paragraph', (tester) async {
      await tester.pumpWidget(marker());
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byType(BeuiCitation));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // The ring is painted outside layout, so the badge — and the text either
      // side of it — stay exactly where they were.
      expect(tester.getRect(find.byType(BeuiCitation)), before);
    });
  });

  group('BeuiCitations reduced motion', () {
    testWidgets('rows fade in rather than appearing from nowhere', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(citations: _sample(count: 1), reduce: true),
      );
      await tester.pump();
      final opacity = tester
          .widgetList<Opacity>(
            find.ancestor(
              of: find.text('Motion documentation'),
              matching: find.byType(Opacity),
            ),
          )
          .map((o) => o.opacity)
          .fold<double>(1, (a, b) => a * b);
      // The opacity channel survives; only the 6px rise is dropped.
      expect(opacity, lessThan(1.0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Motion documentation'), findsOneWidget);
    });

    testWidgets('and they do not move while doing it', (tester) async {
      await tester.pumpWidget(
        _host(citations: _sample(count: 1), reduce: true),
      );
      await tester.pump();
      final start = tester.getRect(find.text('Motion documentation'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getRect(find.text('Motion documentation')), start);
    });
  });

  group('BeuiCitations empty state', () {
    testWidgets('no sources is a state, not a blank panel', (tester) async {
      await tester.pumpWidget(_host(citations: const []));
      await tester.pumpAndSettle();
      expect(find.text('No sources for this answer'), findsOneWidget);
    });

    testWidgets('the placeholder is overridable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: const Scaffold(
            body: Center(
              child: BeuiCitations(
                citations: [],
                defaultOpen: true,
                emptyPlaceholder: Text('Answered from memory'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Answered from memory'), findsOneWidget);
    });
  });

  // An open panel with rows that have no activation path: static entries, with
  // no link glyph promising a navigation the package will not perform, and the
  // domain at full strength.
  testWidgets('settled golden (open panel, static rows)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BeuiTextTheme.trackingNormal(
          ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 420,
              child: BeuiCitations(
                citations: _sample(),
                defaultOpen: true,
                idPrefix: 'golden',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiCitations),
      matchesGoldenFile('goldens/beui_citations.png'),
    );
  });
}
