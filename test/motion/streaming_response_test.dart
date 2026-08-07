import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

List<BeuiCitationItem> _sampleSources({int count = 2}) {
  const all = <BeuiCitationItem>[
    BeuiCitationItem(
      id: 'motion',
      title: Text('Motion for React'),
      domain: Text('motion.dev'),
      url: 'https://motion.dev/docs/react',
    ),
    BeuiCitationItem(
      id: 'aria',
      title: Text('ARIA live regions'),
      domain: Text('developer.mozilla.org'),
      url: 'https://developer.mozilla.org/',
    ),
    BeuiCitationItem(
      id: 'react',
      title: Text('React docs'),
      domain: Text('react.dev'),
      url: 'https://react.dev/learn',
    ),
  ];
  return all.take(count).toList(growable: false);
}

Widget _host({
  Widget child = const Text('Hello stream'),
  BeuiStreamingResponseStatus status = BeuiStreamingResponseStatus.complete,
  String? copyText,
  Future<void> Function()? onCopy,
  VoidCallback? onRetry,
  List<BeuiCitationItem> sources = const <BeuiCitationItem>[],
  bool? sourcesOpen,
  bool defaultSourcesOpen = false,
  ValueChanged<bool>? onSourcesOpenChange,
  String? sourceIdPrefix,
  BeuiStreamingResponseFeedback? feedback,
  BeuiStreamingResponseFeedback defaultFeedback =
      BeuiStreamingResponseFeedback.none,
  ValueChanged<BeuiStreamingResponseFeedback>? onFeedbackChange,
  bool announce = true,
  bool showActions = true,
  bool reduce = false,
}) {
  Widget body = Center(
    child: SizedBox(
      width: 400,
      child: BeuiStreamingResponse(
        status: status,
        copyText: copyText,
        onCopy: onCopy,
        onRetry: onRetry,
        sources: sources,
        sourcesOpen: sourcesOpen,
        defaultSourcesOpen: defaultSourcesOpen,
        onSourcesOpenChange: onSourcesOpenChange,
        sourceIdPrefix: sourceIdPrefix,
        feedback: feedback,
        defaultFeedback: defaultFeedback,
        onFeedbackChange: onFeedbackChange,
        announce: announce,
        showActions: showActions,
        child: child,
      ),
    ),
  );
  if (reduce) {
    final inner = body;
    body = Builder(
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
    home: Scaffold(body: body),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BeuiStreamingResponse', () {
    testWidgets('renders children while streaming without actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          status: BeuiStreamingResponseStatus.streaming,
          copyText: 'full text',
          onRetry: () {},
          sources: _sampleSources(),
          child: const Text('partial answer…'),
        ),
      );
      await tester.pump();

      expect(find.text('partial answer…'), findsOneWidget);
      // Actions stay hidden while streaming.
      expect(find.byIcon(LucideIcons.copy), findsNothing);
      expect(find.byIcon(LucideIcons.rotate_ccw), findsNothing);
      expect(find.byIcon(LucideIcons.thumbs_up), findsNothing);
      expect(find.textContaining('source'), findsNothing);
    });

    testWidgets('shows copy, retry, feedback, and sources when complete', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          status: BeuiStreamingResponseStatus.complete,
          copyText: 'full text',
          onRetry: () {},
          sources: _sampleSources(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.copy), findsOneWidget);
      expect(find.byIcon(LucideIcons.rotate_ccw), findsOneWidget);
      expect(find.byIcon(LucideIcons.thumbs_up), findsOneWidget);
      expect(find.byIcon(LucideIcons.thumbs_down), findsOneWidget);
      expect(find.text('2 sources'), findsOneWidget);
    });

    testWidgets('hides feedback thumbs on error status', (tester) async {
      await tester.pumpWidget(
        _host(
          status: BeuiStreamingResponseStatus.error,
          copyText: 'err',
          onRetry: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.copy), findsOneWidget);
      expect(find.byIcon(LucideIcons.rotate_ccw), findsOneWidget);
      expect(find.byIcon(LucideIcons.thumbs_up), findsNothing);
      expect(find.byIcon(LucideIcons.thumbs_down), findsNothing);
    });

    testWidgets('showActions false suppresses the actions row', (tester) async {
      await tester.pumpWidget(
        _host(
          status: BeuiStreamingResponseStatus.complete,
          copyText: 'x',
          onRetry: () {},
          sources: _sampleSources(),
          showActions: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.copy), findsNothing);
      expect(find.textContaining('source'), findsNothing);
    });

    testWidgets('copy writes clipboard and shows check feedback', (
      tester,
    ) async {
      final log = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          log.add(call);
          return null;
        },
      );

      await tester.pumpWidget(
        _host(
          status: BeuiStreamingResponseStatus.complete,
          copyText: 'copied body',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.copy));
      await tester.pump();

      expect(
        log.any(
          (c) =>
              c.method == 'Clipboard.setData' &&
              (c.arguments as Map)['text'] == 'copied body',
        ),
        isTrue,
      );
      expect(find.byIcon(LucideIcons.check), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1700));
      expect(find.byIcon(LucideIcons.copy), findsOneWidget);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    testWidgets('onCopy override is invoked instead of clipboard', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _host(
          status: BeuiStreamingResponseStatus.complete,
          onCopy: () async {
            calls++;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.copy));
      await tester.pump();
      expect(calls, 1);
    });

    testWidgets('onRetry is invoked from the retry control', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _host(
          status: BeuiStreamingResponseStatus.complete,
          onRetry: () => retries++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.rotate_ccw));
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets('feedback toggles up/down/none (uncontrolled)', (tester) async {
      final events = <BeuiStreamingResponseFeedback>[];
      await tester.pumpWidget(
        _host(
          status: BeuiStreamingResponseStatus.complete,
          onFeedbackChange: events.add,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.thumbs_up));
      await tester.pump();
      expect(events, [BeuiStreamingResponseFeedback.up]);

      await tester.tap(find.byIcon(LucideIcons.thumbs_down));
      await tester.pump();
      expect(events.last, BeuiStreamingResponseFeedback.down);

      // Re-tap active vote clears it.
      await tester.tap(find.byIcon(LucideIcons.thumbs_down));
      await tester.pump();
      expect(events.last, BeuiStreamingResponseFeedback.none);
    });

    testWidgets('controlled feedback respects prop and notifies', (
      tester,
    ) async {
      var vote = BeuiStreamingResponseFeedback.none;
      final events = <BeuiStreamingResponseFeedback>[];

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _host(
              status: BeuiStreamingResponseStatus.complete,
              feedback: vote,
              onFeedbackChange: (v) {
                events.add(v);
                setState(() => vote = v);
              },
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.thumbs_up));
      await tester.pumpAndSettle();
      expect(events, [BeuiStreamingResponseFeedback.up]);
      expect(vote, BeuiStreamingResponseFeedback.up);
    });

    testWidgets('sources toggle expands citation list (uncontrolled)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          status: BeuiStreamingResponseStatus.complete,
          sources: _sampleSources(),
          defaultSourcesOpen: false,
        ),
      );
      await tester.pumpAndSettle();

      // Closed: list titles not visible.
      expect(find.text('Motion for React'), findsNothing);

      await tester.tap(find.text('2 sources'));
      await tester.pumpAndSettle();
      expect(find.text('Motion for React'), findsOneWidget);
      expect(find.text('ARIA live regions'), findsOneWidget);

      await tester.tap(find.text('2 sources'));
      await tester.pumpAndSettle();
      expect(find.text('Motion for React'), findsNothing);
    });

    testWidgets('controlled sourcesOpen respects prop', (tester) async {
      var open = false;
      final events = <bool>[];

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _host(
              status: BeuiStreamingResponseStatus.complete,
              sources: _sampleSources(count: 1),
              sourcesOpen: open,
              onSourcesOpenChange: (v) {
                events.add(v);
                setState(() => open = v);
              },
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Motion for React'), findsNothing);
      expect(find.text('1 source'), findsOneWidget);

      await tester.tap(find.text('1 source'));
      await tester.pumpAndSettle();
      expect(events, [true]);
      expect(find.text('Motion for React'), findsOneWidget);
    });

    testWidgets('singular source label when count is 1', (tester) async {
      await tester.pumpWidget(
        _host(
          status: BeuiStreamingResponseStatus.complete,
          sources: _sampleSources(count: 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 source'), findsOneWidget);
      expect(find.text('1 sources'), findsNothing);
    });

    testWidgets('no actions when nothing to show after streaming', (
      tester,
    ) async {
      // complete without copy/retry/sources → feedback still shows because complete.
      await tester.pumpWidget(
        _host(status: BeuiStreamingResponseStatus.complete),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.thumbs_up), findsOneWidget);

      // error without copy/retry/sources → nothing to show.
      await tester.pumpWidget(_host(status: BeuiStreamingResponseStatus.error));
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.copy), findsNothing);
      expect(find.byIcon(LucideIcons.thumbs_up), findsNothing);
    });

    testWidgets('reduced motion still reveals actions when complete', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          status: BeuiStreamingResponseStatus.complete,
          copyText: 'x',
          sources: _sampleSources(),
          reduce: true,
        ),
      );
      await tester.pump();

      expect(find.byIcon(LucideIcons.copy), findsOneWidget);
      expect(find.text('2 sources'), findsOneWidget);

      await tester.tap(find.text('2 sources'));
      await tester.pump();
      expect(find.text('Motion for React'), findsOneWidget);
    });

    testWidgets('transitions from streaming to complete reveals actions', (
      tester,
    ) async {
      var status = BeuiStreamingResponseStatus.streaming;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _host(
              status: status,
              copyText: 'body',
              child: Text(
                status == BeuiStreamingResponseStatus.streaming ? '…' : 'done',
              ),
            );
          },
        ),
      );
      await tester.pump();
      expect(find.byIcon(LucideIcons.copy), findsNothing);

      status = BeuiStreamingResponseStatus.complete;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _host(
              status: status,
              copyText: 'body',
              child: const Text('done'),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.copy), findsOneWidget);
      expect(find.text('done'), findsOneWidget);
    });
  });
}
