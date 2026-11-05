import 'dart:async';
import 'dart:io';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/citations_demo.dart';

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
  home: Scaffold(body: Center(child: child)),
);

class _RequestCountingClient implements HttpClient {
  _RequestCountingClient(this.onRequest);

  final VoidCallback onRequest;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    onRequest();
    throw const SocketException('request counted by test');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PendingImageClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) =>
      Completer<HttpClientRequest>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StatefulIcon extends StatefulWidget {
  const _StatefulIcon({
    required this.color,
    required this.onDispose,
    super.key,
  });

  final Color color;
  final VoidCallback onDispose;

  @override
  State<_StatefulIcon> createState() => _StatefulIconState();
}

class _StatefulIconState extends State<_StatefulIcon> {
  int _presses = 0;

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => _presses++),
    child: Text('icon $_presses', style: TextStyle(color: widget.color)),
  );
}

void main() {
  testWidgets(
    'old constructors compile and retain executed fallback behavior',
    (tester) async {
      final semantics = tester.ensureSemantics();
      const item = BeuiCitationItem(
        id: 'old',
        title: Text('Old source'),
        url: 'https://example.test/path',
      );
      await tester.pumpWidget(
        _app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BeuiCitationFavicon(url: 'invalid relative URL'),
              const BeuiCitation(
                citationId: 'unregistered',
                index: 8,
                idPrefix: 'old-api',
              ),
              const BeuiCitations(citations: [item], defaultOpen: true),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('8'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('View citation 8')),
        isSemantics(label: 'View citation 8', isButton: true),
      );
      expect(find.text('Old source'), findsOneWidget);
      expect(find.byIcon(LucideIcons.earth), findsWidgets);
      semantics.dispose();
    },
  );

  testWidgets('marker label override is literal and default uses derived row', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const item = BeuiCitationItem(id: 'first', title: Text('First'));
    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            BeuiCitation(
              citationId: 'first',
              idPrefix: 'label-api',
              label: 'Open the first source',
            ),
            BeuiCitation(citationId: 'first', idPrefix: 'label-api'),
            BeuiCitations(
              citations: [item],
              idPrefix: 'label-api',
              defaultOpen: true,
            ),
            BeuiCitation(citationId: 'orphan', idPrefix: 'orphan-api'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    SemanticsNode markerSemantics(String label) =>
        tester.getSemantics(find.bySemanticsLabel(label));
    expect(
      markerSemantics('Open the first source'),
      isSemantics(label: 'Open the first source', isButton: true),
    );
    expect(
      markerSemantics('View citation 1'),
      isSemantics(label: 'View citation 1', isButton: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('View citation')),
      isSemantics(label: 'View citation', isButton: true),
    );
    semantics.dispose();
  });

  testWidgets('custom favicon icon is the exact decorative child', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const custom = Text('decorative source mark', key: Key('custom-icon'));
    await tester.pumpWidget(
      _app(
        const BeuiCitationFavicon(
          url: 'https://example.test/article',
          icon: custom,
        ),
      ),
    );

    expect(
      identical(tester.widget(find.byKey(const Key('custom-icon'))), custom),
      isTrue,
    );
    expect(find.byType(Image), findsNothing);
    expect(find.bySemanticsLabel('decorative source mark'), findsNothing);
    semantics.dispose();
  });

  testWidgets('item icon is forwarded through a row and stack', (tester) async {
    const icon = Icon(LucideIcons.file_text, key: Key('file-icon'));
    const rowItem = BeuiCitationItem(
      id: 'pdf-row',
      title: Text('PDF source'),
      url: 'https://example.test/paper.pdf',
      icon: icon,
    );
    const stackItem = BeuiCitationItem(
      id: 'pdf-stack',
      title: Text('PDF stack'),
      url: 'https://example.test/other.pdf',
      icon: icon,
    );
    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            BeuiCitations(citations: [rowItem], defaultOpen: true),
            BeuiCitationStack(citations: [stackItem]),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.file_text), findsNWidgets(2));
    expect(find.byType(Image), findsNothing);
  });

  testWidgets(
    'custom icon skips image acquisition while URL fallback requests',
    (tester) async {
      final previousProvider = debugNetworkImageHttpClientProvider;
      var requests = 0;
      debugNetworkImageHttpClientProvider = () =>
          _RequestCountingClient(() => requests++);
      addTearDown(() {
        debugNetworkImageHttpClientProvider = previousProvider;
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      });

      await tester.pumpWidget(
        _app(
          const BeuiCitationFavicon(
            url: 'https://example.test/custom',
            icon: Icon(LucideIcons.file_text),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(requests, 0);
      expect(find.byType(Image), findsNothing);

      await tester.pumpWidget(
        _app(const BeuiCitationFavicon(url: 'https://example.test/default')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(requests, 1);
      expect(find.byType(Image), findsOneWidget);
      debugNetworkImageHttpClientProvider = previousProvider;
    },
  );

  testWidgets(
    'unconfigured icon receives the source-size muted theme default',
    (tester) async {
      await tester.pumpWidget(
        _app(const BeuiCitationFavicon(icon: Icon(LucideIcons.file_text))),
      );
      final iconContext = tester.element(find.byIcon(LucideIcons.file_text));
      final iconTheme = IconTheme.of(iconContext);
      expect(iconTheme.size, 14);
      expect(iconTheme.color, BeuiColors.light().mutedForeground);
    },
  );

  testWidgets('explicit icon size and color remain caller-owned', (
    tester,
  ) async {
    const icon = Icon(
      LucideIcons.file_text,
      size: 29,
      color: Colors.deepPurple,
    );
    await tester.pumpWidget(_app(const BeuiCitationFavicon(icon: icon)));
    final rendered = tester.widget<Icon>(find.byIcon(LucideIcons.file_text));
    expect(rendered.size, 29);
    expect(rendered.color, Colors.deepPurple);
  });

  testWidgets('stale favicon errors cannot poison a switched custom icon', (
    tester,
  ) async {
    final previousProvider = debugNetworkImageHttpClientProvider;
    debugNetworkImageHttpClientProvider = () => _RequestCountingClient(() {});
    addTearDown(() {
      debugNetworkImageHttpClientProvider = previousProvider;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });

    const url = 'https://example.test/same';
    await tester.pumpWidget(_app(const BeuiCitationFavicon(url: url)));
    final image = tester.widget<Image>(find.byType(Image));
    final context = tester.element(find.byType(Image));
    image.errorBuilder!(context, StateError('old request'), StackTrace.current);

    await tester.pumpWidget(
      _app(
        const BeuiCitationFavicon(url: url, icon: Icon(LucideIcons.file_text)),
      ),
    );
    expect(find.byIcon(LucideIcons.file_text), findsOneWidget);

    await tester.pumpWidget(_app(const BeuiCitationFavicon(url: url)));
    expect(find.byType(Image), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
    debugNetworkImageHttpClientProvider = previousProvider;
  });

  testWidgets(
    'marker label supports pointer and keyboard activation without reflow',
    (tester) async {
      var activations = 0;
      final semantics = tester.ensureSemantics();

      Widget marker() => _app(
        SizedBox(
          width: 300,
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Sources '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: BeuiCitation(
                    citationId: 'source',
                    index: 1,
                    idPrefix: 'activation',
                    label: 'Open source one',
                    onPressed: () => activations++,
                  ),
                ),
                const TextSpan(text: ' verified'),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(marker());
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byType(BeuiCitation));
      final markerSemantics = tester.getSemantics(
        find.bySemanticsLabel('Open source one'),
      );
      expect(
        markerSemantics,
        isSemantics(label: 'Open source one', isButton: true),
      );
      expect(
        markerSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      markerSemantics.owner!.performAction(
        markerSemantics.id,
        SemanticsAction.tap,
      );
      await tester.pump();
      expect(activations, 1);
      await tester.tap(find.byType(BeuiCitation));
      await tester.pump();
      expect(activations, 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(BeuiCitation)), before);
      expect(Focus.of(tester.element(find.text('1'))).hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(activations, 3);
      semantics.dispose();
    },
  );

  testWidgets(
    'custom-icon row activates with exact item for pointer and keyboard',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final activations = <String>[];
      final item = BeuiCitationItem(
        id: 'custom-row',
        title: const Text('Custom source'),
        url: 'https://example.test/source',
        icon: const Text('decorative row icon'),
        onTap: () => activations.add('item:custom-row'),
      );
      await tester.pumpWidget(
        _app(
          BeuiCitations(
            citations: [item],
            defaultOpen: true,
            onCitationTap: (citation) =>
                activations.add('panel:${citation.id}'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('decorative row icon'), findsNothing);

      await tester.tap(find.text('Custom source'));
      await tester.pump();
      expect(activations, ['item:custom-row', 'panel:custom-row']);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        Focus.of(tester.element(find.text('Custom source'))).hasFocus,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(activations, [
        'item:custom-row',
        'panel:custom-row',
        'item:custom-row',
        'panel:custom-row',
      ]);
      semantics.dispose();
    },
  );

  testWidgets('keyed custom icon state survives updates and disposes once', (
    tester,
  ) async {
    var disposed = 0;
    var color = Colors.red;
    var url = 'https://example.test/one';

    Widget host() => _app(
      BeuiCitationFavicon(
        key: const Key('favicon'),
        url: url,
        icon: _StatefulIcon(
          key: const Key('custom-state'),
          color: color,
          onDispose: () => disposed++,
        ),
      ),
    );

    await tester.pumpWidget(host());
    await tester.tap(find.text('icon 0'));
    await tester.pump();
    expect(find.text('icon 1'), findsOneWidget);

    color = Colors.blue;
    url = 'https://example.test/two';
    await tester.pumpWidget(host());
    expect(find.text('icon 1'), findsOneWidget);
    expect(tester.widget<Text>(find.text('icon 1')).style!.color, Colors.blue);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(disposed, 1);
  });

  testWidgets(
    'URL changes replace a failure and icon toggles retain known failure',
    (tester) async {
      final previousProvider = debugNetworkImageHttpClientProvider;
      debugNetworkImageHttpClientProvider = () => _RequestCountingClient(() {});
      addTearDown(() {
        debugNetworkImageHttpClientProvider = previousProvider;
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      });

      await tester.pumpWidget(
        _app(const BeuiCitationFavicon(url: 'https://first.test/article')),
      );
      final firstImage = tester.widget<Image>(find.byType(Image));
      firstImage.errorBuilder!(
        tester.element(find.byType(Image)),
        StateError('first URL failed'),
        StackTrace.current,
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(LucideIcons.earth), findsOneWidget);

      await tester.pumpWidget(
        _app(
          const BeuiCitationFavicon(
            url: 'https://first.test/article',
            icon: Icon(LucideIcons.file_text),
          ),
        ),
      );
      await tester.pumpWidget(
        _app(const BeuiCitationFavicon(url: 'https://first.test/article')),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(LucideIcons.earth), findsOneWidget);

      await tester.pumpWidget(
        _app(const BeuiCitationFavicon(url: 'https://second.test/article')),
      );
      expect(find.byType(Image), findsOneWidget);
      final secondImage = tester.widget<Image>(find.byType(Image));
      expect(
        (secondImage.image as NetworkImage).url,
        'https://second.test/favicon.ico',
      );
      debugNetworkImageHttpClientProvider = previousProvider;
    },
  );

  testWidgets('queued image failure after favicon disposal is ignored', (
    tester,
  ) async {
    final previousProvider = debugNetworkImageHttpClientProvider;
    debugNetworkImageHttpClientProvider = () => _RequestCountingClient(() {});
    addTearDown(() {
      debugNetworkImageHttpClientProvider = previousProvider;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
    await tester.pumpWidget(
      _app(const BeuiCitationFavicon(url: 'https://dispose.test/article')),
    );
    final image = tester.widget<Image>(find.byType(Image));
    final context = tester.element(find.byType(Image));
    image.errorBuilder!(
      context,
      StateError('late failure'),
      StackTrace.current,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
    debugNetworkImageHttpClientProvider = previousProvider;
  });

  testWidgets('old image failure cannot invalidate a later same-URL image', (
    tester,
  ) async {
    final previousProvider = debugNetworkImageHttpClientProvider;
    debugNetworkImageHttpClientProvider = _PendingImageClient.new;
    addTearDown(() {
      debugNetworkImageHttpClientProvider = previousProvider;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
    const url = 'https://late.test/article';
    await tester.pumpWidget(_app(const BeuiCitationFavicon(url: url)));
    final faviconState = tester.state(find.byType(BeuiCitationFavicon));
    final oldImage = tester.widget<Image>(find.byType(Image));

    await tester.pumpWidget(
      _app(const BeuiCitationFavicon(icon: Icon(LucideIcons.file_text))),
    );
    expect(find.byIcon(LucideIcons.file_text), findsOneWidget);
    expect(tester.state(find.byType(BeuiCitationFavicon)), same(faviconState));
    await tester.pumpWidget(_app(const BeuiCitationFavicon(url: url)));
    expect(tester.state(find.byType(BeuiCitationFavicon)), same(faviconState));
    final currentImage = tester.widget<Image>(find.byType(Image));
    oldImage.errorBuilder!(
      tester.element(find.byType(Image)),
      StateError('released image failed'),
      StackTrace.current,
    );
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)), same(currentImage));
    expect(
      (currentImage.image as NetworkImage).url,
      'https://late.test/favicon.ico',
    );
    currentImage.errorBuilder!(
      tester.element(find.byType(Image)),
      StateError('current image failed'),
      StackTrace.current,
    );
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(LucideIcons.earth), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    debugNetworkImageHttpClientProvider = previousProvider;
  });

  testWidgets('replacing or removing an icon releases only that child', (
    tester,
  ) async {
    final disposed = <String>[];
    Widget host(String? name) => _app(
      BeuiCitationFavicon(
        key: const Key('persistent-favicon'),
        icon: name == null
            ? null
            : _StatefulIcon(
                key: ValueKey(name),
                color: Colors.red,
                onDispose: () => disposed.add(name),
              ),
      ),
    );

    await tester.pumpWidget(host('first'));
    await tester.tap(find.text('icon 0'));
    await tester.pump();
    expect(find.text('icon 1'), findsOneWidget);
    await tester.pumpWidget(host('second'));
    expect(disposed, ['first']);
    expect(find.text('icon 0'), findsOneWidget);
    await tester.pumpWidget(host(null));
    expect(disposed, ['first', 'second']);
    expect(find.byIcon(LucideIcons.earth), findsOneWidget);
    await tester.pumpWidget(host('second'));
    expect(find.text('icon 0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(disposed, ['first', 'second', 'second']);
  });

  testWidgets('canonical demo retains PDF icon, markers, and static row', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(builder: citationsDemo),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Motion documentation'), findsOneWidget);
    expect(find.text('WAI accessibility patterns'), findsOneWidget);
    expect(find.text('Motion guidelines'), findsOneWidget);
    expect(find.text('Design handbook · PDF'), findsOneWidget);
    expect(find.text('React documentation'), findsNothing);
    expect(find.byIcon(LucideIcons.file_text), findsOneWidget);
    expect(find.byIcon(LucideIcons.external_link), findsNWidgets(2));
    final prose = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.textSpan != null,
      ),
    );
    expect(
      prose.textSpan!.toPlainText(),
      'Use layout-aware motion for newly appended results \uFFFC and preserve accessible disclosure behavior \uFFFC as the list grows, keeping exits shorter than entrances \uFFFC.',
    );
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);
    expect(find.text('3'), findsWidgets);
    expect(
      find.bySemanticsLabel('Citation 3: Motion guidelines'),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.text('Motion guidelines')),
      isSemantics(isButton: false),
    );

    await tester.tap(find.text('Motion documentation'));
    await tester.pumpAndSettle();
    expect(
      find.text('Would open https://motion.dev/docs/react'),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
