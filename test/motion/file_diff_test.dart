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

Widget _host({
  Key? key,
  Object file = 'src/runner.ts',
  List<BeuiFileDiffLine> lines = _sampleLines,
  BeuiFileDiffStatus status = BeuiFileDiffStatus.streaming,
  bool? open,
  bool defaultOpen = true,
  ValueChanged<bool>? onOpenChange,
  bool collapseOnComplete = true,
  String? copyText,
  Future<void> Function()? onCopy,
  bool reduce = false,
}) {
  Widget child = Center(
    child: SizedBox(
      width: 400,
      child: BeuiFileDiff(
        key: key,
        file: file,
        lines: lines,
        status: status,
        open: open,
        defaultOpen: defaultOpen,
        onOpenChange: onOpenChange,
        collapseOnComplete: collapseOnComplete,
        copyText: copyText,
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
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
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

    testWidgets('hides copy button when neither copyText nor onCopy set', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(status: BeuiFileDiffStatus.complete, defaultOpen: true),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.copy), findsNothing);
    });

    testWidgets('accepts Widget file label', (tester) async {
      await tester.pumpWidget(
        _host(
          file: const Text('custom.ts', key: Key('file-label')),
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
}
