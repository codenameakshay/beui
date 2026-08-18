import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _sampleLines = <BeuiFileDiffLine>[
  BeuiFileDiffLine(
    id: '1',
    oldLine: 18,
    newLine: 18,
    content: 'export async function runTask() {',
  ),
  BeuiFileDiffLine(
    id: '2',
    type: BeuiFileDiffLineType.removed,
    oldLine: 19,
    content: '  return execute(task);',
  ),
  BeuiFileDiffLine(
    id: '3',
    type: BeuiFileDiffLineType.added,
    newLine: 19,
    content: '  const result = await execute(task);',
  ),
  BeuiFileDiffLine(
    id: '4',
    type: BeuiFileDiffLineType.added,
    newLine: 20,
    content: '  return normalize(result);',
  ),
  BeuiFileDiffLine(id: '5', oldLine: 20, newLine: 21, content: '}'),
];

/// Advances [count] frames of 20ms.
///
/// The streaming chrome spins forever, so `pumpAndSettle` never returns on any
/// streaming path; scroll animations still need real frames to tick, so one
/// long `pump(400ms)` does not stand in for them either.
Future<void> pumpFrames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Widget _host({
  Key? key,
  String? file = 'src/runner.ts',
  Widget? fileWidget,
  List<BeuiFileDiffLine> lines = _sampleLines,
  BeuiFileDiffStatus status = BeuiFileDiffStatus.streaming,
  bool? open,
  bool defaultOpen = true,
  ValueChanged<bool>? onOpenChange,
  bool collapseOnComplete = true,
  String? copyText,
  bool copyable = true,
  Future<void> Function()? onCopy,
  bool reduce = false,
}) {
  Widget child = Center(
    child: SizedBox(
      width: 400,
      child: BeuiFileDiff(
        key: key,
        file: fileWidget == null ? file : null,
        fileWidget: fileWidget,
        lines: lines,
        status: status,
        open: open,
        defaultOpen: defaultOpen,
        onOpenChange: onOpenChange,
        collapseOnComplete: collapseOnComplete,
        copyText: copyText,
        copyable: copyable,
        onCopy: onCopy,
        maxHeight: 150,
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BeuiFileDiff', () {
    testWidgets('renders file path, change counts, and line content', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(status: BeuiFileDiffStatus.complete, defaultOpen: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('src/runner.ts'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.textContaining('−1'), findsOneWidget);
      expect(
        find.textContaining('export async function runTask()'),
        findsOneWidget,
      );
      expect(find.textContaining('return execute(task);'), findsOneWidget);
      expect(
        find.textContaining('const result = await execute(task);'),
        findsOneWidget,
      );
    });

    testWidgets('hides zero change counts', (tester) async {
      await tester.pumpWidget(
        _host(
          lines: const [
            BeuiFileDiffLine(
              id: 'a',
              content: 'unchanged',
              oldLine: 1,
              newLine: 1,
            ),
          ],
          status: BeuiFileDiffStatus.complete,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('+0'), findsNothing);
      expect(find.textContaining('−0'), findsNothing);
    });

    testWidgets('tapping header toggles open state (uncontrolled)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(status: BeuiFileDiffStatus.complete, defaultOpen: true),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('export async function'), findsOneWidget);

      await tester.tap(find.text('src/runner.ts'));
      await tester.pumpAndSettle();
      expect(find.textContaining('export async function'), findsNothing);

      await tester.tap(find.text('src/runner.ts'));
      await tester.pumpAndSettle();
      expect(find.textContaining('export async function'), findsOneWidget);
    });

    testWidgets('controlled open reports onOpenChange', (tester) async {
      var open = true;
      final calls = <bool>[];

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _host(
              open: open,
              status: BeuiFileDiffStatus.complete,
              onOpenChange: (v) {
                calls.add(v);
                setState(() => open = v);
              },
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('src/runner.ts'));
      await tester.pumpAndSettle();
      expect(calls, [false]);
      expect(find.textContaining('export async function'), findsNothing);

      await tester.tap(find.text('src/runner.ts'));
      await tester.pumpAndSettle();
      expect(calls, [false, true]);
    });

    testWidgets('collapseOnComplete closes when streaming finishes', (
      tester,
    ) async {
      // GlobalKey keeps State across pumps so the status edge is observed.
      // Avoid pumpAndSettle while streaming — the loader spins forever.
      final key = GlobalKey();
      await tester.pumpWidget(
        _host(
          key: key,
          status: BeuiFileDiffStatus.streaming,
          defaultOpen: true,
          collapseOnComplete: true,
        ),
      );
      await tester.pump();
      expect(find.textContaining('export async function'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          key: key,
          status: BeuiFileDiffStatus.complete,
          defaultOpen: true,
          collapseOnComplete: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('export async function'), findsNothing);
    });

    testWidgets('collapseOnComplete false keeps panel open on complete', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        _host(
          key: key,
          status: BeuiFileDiffStatus.streaming,
          defaultOpen: true,
          collapseOnComplete: false,
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        _host(
          key: key,
          status: BeuiFileDiffStatus.complete,
          defaultOpen: true,
          collapseOnComplete: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('export async function'), findsOneWidget);
    });

    testWidgets('resuming streaming re-opens collapsed panel', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        _host(
          key: key,
          status: BeuiFileDiffStatus.complete,
          defaultOpen: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('export async function'), findsNothing);

      await tester.pumpWidget(
        _host(
          key: key,
          status: BeuiFileDiffStatus.streaming,
          defaultOpen: false,
        ),
      );
      // Spinner is infinite — pump frames instead of pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('export async function'), findsOneWidget);
    });

    testWidgets('copy button writes clipboard and shows feedback', (
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
          status: BeuiFileDiffStatus.complete,
          defaultOpen: true,
          copyText: 'diff body',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.copy));
      await tester.pump();

      expect(
        log.any(
          (c) =>
              c.method == 'Clipboard.setData' &&
              (c.arguments as Map)['text'] == 'diff body',
        ),
        isTrue,
      );
      expect(find.byIcon(LucideIcons.check), findsWidgets);

      await tester.pump(const Duration(milliseconds: 1700));
      expect(find.byIcon(LucideIcons.copy), findsOneWidget);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    testWidgets('onCopy override is invoked', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _host(
          status: BeuiFileDiffStatus.complete,
          defaultOpen: true,
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

    testWidgets('copyable: false hides the copy control', (tester) async {
      await tester.pumpWidget(
        _host(
          status: BeuiFileDiffStatus.complete,
          defaultOpen: true,
          copyable: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.copy), findsNothing);
    });

    testWidgets(
      'copyText defaults to the diff the widget already holds, as a unified '
      'diff body',
      (tester) async {
        final log = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            log.add(call);
            return null;
          },
        );

        await tester.pumpWidget(
          _host(status: BeuiFileDiffStatus.complete, defaultOpen: true),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(LucideIcons.copy));
        await tester.pump();

        final call = log.firstWhere((c) => c.method == 'Clipboard.setData');
        final text = (call.arguments as Map)['text'] as String;
        // ASCII prefixes, so the payload survives a paste into `git apply`.
        expect(text, contains(' export async function runTask() {'));
        expect(text, contains('-  return execute(task);'));
        expect(text, contains('+  const result = await execute(task);'));
        expect(text, isNot(contains('−')));

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      },
    );

    testWidgets('accepts a Widget file label through fileWidget', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          fileWidget: const Text('custom.ts', key: Key('file-label')),
          status: BeuiFileDiffStatus.complete,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('file-label')), findsOneWidget);
    });

    testWidgets('shows loader while streaming and check when complete', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(status: BeuiFileDiffStatus.streaming, defaultOpen: true),
      );
      await tester.pump();
      expect(find.byIcon(LucideIcons.loader_circle), findsOneWidget);

      await tester.pumpWidget(
        _host(status: BeuiFileDiffStatus.complete, defaultOpen: true),
      );
      await tester.pumpAndSettle();
      // Header check (applied) — may also see copy check if present; here no copy.
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      expect(find.byIcon(LucideIcons.loader_circle), findsNothing);
    });

    testWidgets('reduced motion still toggles disclosure', (tester) async {
      await tester.pumpWidget(
        _host(
          status: BeuiFileDiffStatus.complete,
          defaultOpen: true,
          reduce: true,
        ),
      );
      await tester.pump();
      expect(find.textContaining('export async function'), findsOneWidget);

      await tester.tap(find.text('src/runner.ts'));
      await tester.pump();
      // The shared disclosure keeps the opacity channel under reduced motion —
      // movement is what gets dropped — so the panel outlives the toggle by one
      // short cross-fade before it unmounts.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('export async function'), findsNothing);
    });

    testWidgets('live change counts update as lines grow', (tester) async {
      await tester.pumpWidget(
        _host(
          lines: _sampleLines.take(1).toList(),
          status: BeuiFileDiffStatus.streaming,
          defaultOpen: true,
        ),
      );
      await tester.pump();
      expect(find.text('+2'), findsNothing);
      expect(find.textContaining('−1'), findsNothing);

      await tester.pumpWidget(
        _host(
          lines: _sampleLines.take(3).toList(),
          status: BeuiFileDiffStatus.streaming,
          defaultOpen: true,
        ),
      );
      await tester.pump();
      expect(find.text('+1'), findsOneWidget);
      expect(find.textContaining('−1'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------
  // UX remediation — R1, R7, R8, R12, R17, R19, R21, R22, R28, R36
  // ---------------------------------------------------------------------

  group('BeuiFileDiff wide lines (R1)', () {
    const wide = <BeuiFileDiffLine>[
      BeuiFileDiffLine(
        id: 'w',
        type: BeuiFileDiffLineType.added,
        newLine: 1,
        content:
            'const configuration = buildConfiguration({ retries: 3, timeout: '
            '30000, backoff: "exponential", onFailure: reportToSentry });',
      ),
    ];

    Widget frame(double width, {BeuiFileDiffWrap? wrap}) => MaterialApp(
      theme: BeuiTextTheme.trackingNormal(
        ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: BeuiFileDiff(
              file: 'src/config.ts',
              lines: wide,
              status: BeuiFileDiffStatus.complete,
              collapseOnComplete: false,
              wrap: wrap ?? BeuiFileDiffWrap.adaptive,
            ),
          ),
        ),
      ),
    );

    /// Every horizontal scroll view inside the diff body.
    Finder horizontalScrollers() => find.byWidgetPredicate(
      (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
    );

    testWidgets('the code text is never ellipsised', (tester) async {
      await tester.pumpWidget(frame(600));
      await tester.pumpAndSettle();
      final texts = tester.widgetList<Text>(
        find.descendant(
          of: find.byType(BeuiFileDiff),
          matching: find.byType(Text),
        ),
      );
      // Truncating the end of a changed line hides the part that changed.
      expect(texts.every((t) => t.overflow != TextOverflow.ellipsis), isTrue);
    });

    testWidgets('scroll mode nests a horizontal scroller', (tester) async {
      await tester.pumpWidget(frame(600, wrap: BeuiFileDiffWrap.scroll));
      await tester.pumpAndSettle();
      expect(horizontalScrollers(), findsOneWidget);
    });

    testWidgets('wrap mode does not', (tester) async {
      await tester.pumpWidget(frame(600, wrap: BeuiFileDiffWrap.wrap));
      await tester.pumpAndSettle();
      expect(horizontalScrollers(), findsNothing);
    });

    testWidgets('adaptive scrolls above the breakpoint', (tester) async {
      await tester.pumpWidget(frame(600));
      await tester.pumpAndSettle();
      expect(horizontalScrollers(), findsOneWidget);
    });

    testWidgets('adaptive wraps below the breakpoint', (tester) async {
      await tester.pumpWidget(frame(320));
      await tester.pumpAndSettle();
      expect(horizontalScrollers(), findsNothing);
    });

    testWidgets('the row track fills the viewport so tints span it', (
      tester,
    ) async {
      await tester.pumpWidget(frame(600, wrap: BeuiFileDiffWrap.scroll));
      await tester.pumpAndSettle();
      final constrained = tester
          .widgetList<ConstrainedBox>(
            find.descendant(
              of: horizontalScrollers(),
              matching: find.byType(ConstrainedBox),
            ),
          )
          .where((c) => c.constraints.minWidth > 0);
      expect(constrained, isNotEmpty);
    });
  });

  group('BeuiFileDiff change encoding (R19)', () {
    /// The row tint behind [content], or null when the row is untinted.
    ///
    /// Narrowed to translucent washes on purpose: the transparent leading bar
    /// and the host's own `Material` are both `ColoredBox` ancestors too.
    Color? tintOf(WidgetTester tester, String content) {
      final boxes = tester.widgetList<ColoredBox>(
        find.ancestor(
          of: find.textContaining(content),
          matching: find.descendant(
            of: find.byType(BeuiFileDiff),
            matching: find.byType(ColoredBox),
          ),
        ),
      );
      for (final box in boxes) {
        if (box.color.a > 0.02 && box.color.a < 0.5) return box.color;
      }
      return null;
    }

    testWidgets('added and removed rows are tinted well apart', (tester) async {
      await tester.pumpWidget(
        _host(status: BeuiFileDiffStatus.complete, defaultOpen: true),
      );
      await tester.pumpAndSettle();
      final added = tintOf(tester, 'const result = await execute');
      final removed = tintOf(tester, 'return execute(task);');
      expect(added, isNotNull);
      expect(removed, isNotNull);
      // 0.14, not the old 0.07 — at 0.07 the two washes were 1.04:1 apart.
      expect(added!.a, closeTo(0.14, 0.005));
      expect(removed!.a, closeTo(0.14, 0.005));
      expect(added, isNot(removed));
    });

    testWidgets('context rows are untinted', (tester) async {
      await tester.pumpWidget(
        _host(status: BeuiFileDiffStatus.complete, defaultOpen: true),
      );
      await tester.pumpAndSettle();
      expect(tintOf(tester, 'export async function runTask'), isNull);
    });

    testWidgets(
      'every row reserves the leading bar, so nothing shifts between them',
      (tester) async {
        await tester.pumpWidget(
          _host(status: BeuiFileDiffStatus.complete, defaultOpen: true),
        );
        await tester.pumpAndSettle();
        final addedLeft = tester
            .getRect(find.textContaining('const result = await execute'))
            .left;
        final contextLeft = tester
            .getRect(find.textContaining('export async function runTask'))
            .left;
        expect(addedLeft, closeTo(contextLeft, 0.5));
      },
    );

    testWidgets('the +/− markers survive alongside the tint', (tester) async {
      await tester.pumpWidget(
        _host(status: BeuiFileDiffStatus.complete, defaultOpen: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('+'), findsWidgets);
      expect(find.text('−'), findsWidgets);
    });
  });

  group('BeuiFileDiff gutters (R8)', () {
    testWidgets('line numbers are legible, not a 1.78:1 hairline', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(status: BeuiFileDiffStatus.complete, defaultOpen: true),
      );
      await tester.pumpAndSettle();
      final gutter = tester.widget<Text>(find.text('18').first);
      expect(gutter.style!.color!.a, closeTo(0.75, 0.01));
    });
  });

  group('BeuiFileDiff path truncation (R17)', () {
    Widget longPath() => MaterialApp(
      theme: BeuiTextTheme.trackingNormal(
        ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
      ),
      home: const Scaffold(
        body: Center(
          child: SizedBox(
            width: 340,
            child: BeuiFileDiff(
              file: 'apps/web/src/components/agents/file-diff.tsx',
              lines: _sampleLines,
              status: BeuiFileDiffStatus.complete,
              collapseOnComplete: false,
            ),
          ),
        ),
      ),
    );

    testWidgets('the basename survives a path too long for the header', (
      tester,
    ) async {
      await tester.pumpWidget(longPath());
      await tester.pumpAndSettle();
      final painted = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .firstWhere((d) => d.contains('…'), orElse: () => '');
      expect(painted, isNotEmpty, reason: 'the path should have truncated');
      // The end — which identifies the file — is what survives. End-ellipsis
      // gave `src/compon…`, which names nothing.
      expect(painted, endsWith('file-diff.tsx'));
    });

    testWidgets('the leading directories survive when there is room', (
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
                width: 560,
                child: BeuiFileDiff(
                  file: 'apps/web/src/components/agents/inner/file-diff.tsx',
                  lines: _sampleLines,
                  status: BeuiFileDiffStatus.complete,
                  collapseOnComplete: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final painted = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .firstWhere((d) => d.contains('…'), orElse: () => '');
      expect(painted, isNotEmpty);
      expect(painted, startsWith('apps'));
      expect(painted, endsWith('file-diff.tsx'));
    });

    testWidgets('a path that fits is left alone', (tester) async {
      await tester.pumpWidget(
        _host(status: BeuiFileDiffStatus.complete, defaultOpen: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('src/runner.ts'), findsOneWidget);
    });

    testWidgets('the full path is what assistive technology hears', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(longPath());
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(
          RegExp(r'apps/web/src/components/agents/file-diff\.tsx'),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('BeuiFileDiff copy in the header (R21, R28)', () {
    testWidgets('copy is reachable while the panel is collapsed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(status: BeuiFileDiffStatus.complete, defaultOpen: false),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('export async function'), findsNothing);
      // collapseOnComplete hides the diff at the moment of interest; the copy
      // control must not go with it.
      expect(find.byIcon(LucideIcons.copy), findsOneWidget);
    });

    testWidgets('the copied confirmation is announced, not just relabelled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          status: BeuiFileDiffStatus.complete,
          defaultOpen: true,
          onCopy: () async {},
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Copy diff')),
        isSemantics(isLiveRegion: false),
      );

      await tester.tap(find.byIcon(LucideIcons.copy));
      await tester.pump();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Copied')),
        isSemantics(isLiveRegion: true, isButton: true),
      );
      handle.dispose();
    });
  });

  group('BeuiFileDiff hunks and navigation (R22)', () {
    const gapped = <BeuiFileDiffLine>[
      BeuiFileDiffLine(
        id: 'a',
        oldLine: 10,
        newLine: 10,
        content: 'const a=1;',
      ),
      BeuiFileDiffLine(
        id: 'b',
        type: BeuiFileDiffLineType.added,
        oldLine: 40,
        newLine: 40,
        content: 'const b=2;',
      ),
    ];

    testWidgets('a line-number gap renders a hunk separator', (tester) async {
      await tester.pumpWidget(
        _host(
          lines: gapped,
          status: BeuiFileDiffStatus.complete,
          defaultOpen: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('29 hidden lines'), findsOneWidget);
    });

    testWidgets('contiguous rows render no separator', (tester) async {
      await tester.pumpWidget(
        _host(status: BeuiFileDiffStatus.complete, defaultOpen: true),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('hidden lines'), findsNothing);
    });

    testWidgets('the separator promises nothing it cannot do', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          lines: gapped,
          status: BeuiFileDiffStatus.complete,
          defaultOpen: true,
        ),
      );
      await tester.pumpAndSettle();
      // Without a handler the widget cannot produce the missing lines, so it
      // states the gap instead of offering to expand it.
      expect(find.text('29 hidden lines'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Expand')), findsNothing);
      handle.dispose();
    });

    testWidgets('onExpandContext makes it a button and reports the gap', (
      tester,
    ) async {
      BeuiFileDiffHunkGap? seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: BeuiFileDiff(
                  file: 'src/runner.ts',
                  lines: gapped,
                  status: BeuiFileDiffStatus.complete,
                  collapseOnComplete: false,
                  onExpandContext: (gap) => seen = gap,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expand 29 hidden lines'));
      await tester.pump();
      expect(seen, isNotNull);
      expect(seen!.hiddenCount, 29);
      expect(seen!.before.id, 'a');
      expect(seen!.after.id, 'b');
    });

    testWidgets(
      'change navigation appears only when changes outrun the viewport',
      (tester) async {
        final handle = tester.ensureSemantics();
        // Two changes in a 150px viewport of 20px rows: they both fit.
        await tester.pumpWidget(
          _host(status: BeuiFileDiffStatus.complete, defaultOpen: true),
        );
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsLabel(RegExp('(first|last|Next|Previous) change')),
          findsNothing,
        );

        final many = <BeuiFileDiffLine>[
          for (var i = 0; i < 40; i++)
            BeuiFileDiffLine(
              id: '$i',
              oldLine: i + 1,
              newLine: i + 1,
              type: i.isEven
                  ? BeuiFileDiffLineType.added
                  : BeuiFileDiffLineType.context,
              content: 'line $i',
            ),
        ];
        await tester.pumpWidget(
          _host(
            lines: many,
            status: BeuiFileDiffStatus.complete,
            defaultOpen: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel(RegExp('first change')), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('last change')), findsOneWidget);
        handle.dispose();
      },
    );
  });

  group('BeuiFileDiff hidden content and following (R7, R12)', () {
    List<BeuiFileDiffLine> longDiff(int n) => [
      for (var i = 0; i < n; i++)
        BeuiFileDiffLine(
          id: '$i',
          oldLine: i + 1,
          newLine: i + 1,
          content: 'line $i',
        ),
    ];

    testWidgets('a capped viewport says how much it is hiding', (tester) async {
      await tester.pumpWidget(
        _host(
          lines: longDiff(40),
          status: BeuiFileDiffStatus.complete,
          defaultOpen: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('more lines'), findsOneWidget);
    });

    testWidgets('a diff that fits says nothing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 700,
                child: BeuiFileDiff(
                  file: 'src/runner.ts',
                  lines: _sampleLines,
                  status: BeuiFileDiffStatus.complete,
                  collapseOnComplete: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('more lines'), findsNothing);
    });

    testWidgets(
      'scrolling away from the live edge stops the follow and offers a way '
      'back',
      (tester) async {
        await tester.pumpWidget(
          _host(
            lines: longDiff(40),
            status: BeuiFileDiffStatus.streaming,
            defaultOpen: true,
          ),
        );
        // The streaming spinner repeats forever, so settle is never an
        // option here — drive the follow's 220ms frame by frame instead.
        await pumpFrames(tester, 20);
        expect(find.text('Jump to latest'), findsNothing);

        final controller = tester
            .widget<SingleChildScrollView>(
              find
                  .descendant(
                    of: find.byType(BeuiFileDiff),
                    matching: find.byWidgetPredicate(
                      (w) =>
                          w is SingleChildScrollView &&
                          w.scrollDirection == Axis.vertical &&
                          w.controller != null,
                    ),
                  )
                  .first,
            )
            .controller!;

        // The reader scrolls back to re-read something.
        controller.jumpTo(controller.position.maxScrollExtent - 120);
        await pumpFrames(tester, 20);
        expect(find.text('Jump to latest'), findsOneWidget);
        final pinnedAt = controller.offset;

        // More content arrives; the viewport stays where the reader put it.
        await tester.pumpWidget(
          _host(
            lines: longDiff(60),
            status: BeuiFileDiffStatus.streaming,
            defaultOpen: true,
          ),
        );
        await pumpFrames(tester, 20);
        expect(controller.offset, closeTo(pinnedAt, 1));

        // And the pill takes them back.
        await tester.tap(find.text('Jump to latest'));
        await pumpFrames(tester, 30);
        expect(
          controller.offset,
          closeTo(controller.position.maxScrollExtent, 1),
        );
        expect(find.text('Jump to latest'), findsNothing);
      },
    );
  });

  group('BeuiFileDiff API shape (R36)', () {
    test('a label is required, in one form or another', () {
      expect(
        () => BeuiFileDiff(lines: _sampleLines),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('the empty state is a state, not a blank box', (tester) async {
      await tester.pumpWidget(
        _host(
          lines: const [],
          status: BeuiFileDiffStatus.complete,
          defaultOpen: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No changes in this file'), findsOneWidget);
    });
  });

  // The settled diff: 0.14 row tints well apart from each other, a 2px leading
  // colour bar on every changed row, gutters at 0.75, and the copy control up
  // in the header where `collapseOnComplete` cannot take it away.
  testWidgets('settled golden (complete, open, tinted rows)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BeuiTextTheme.trackingNormal(
          ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        ),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 520,
              child: BeuiFileDiff(
                file: 'src/runner.ts',
                lines: _sampleLines,
                status: BeuiFileDiffStatus.complete,
                collapseOnComplete: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiFileDiff),
      matchesGoldenFile('goldens/beui_file_diff.png'),
    );
  });
}
