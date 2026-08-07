import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  Object tool = 'terminal.run',
  Object title = 'Running checks',
  Widget? child,
  BeuiToolResultStatus status = BeuiToolResultStatus.running,
  BeuiToolResultKind kind = BeuiToolResultKind.terminal,
  Object? meta,
  Widget? icon,
  bool? open,
  bool defaultOpen = true,
  ValueChanged<bool>? onOpenChange,
  bool collapseOnComplete = true,
  String? copyText,
  Future<void> Function()? onCopy,
  VoidCallback? onRetry,
  bool reduce = false,
}) {
  Widget body = Center(
    child: SizedBox(
      width: 400,
      child: BeuiToolResult(
        tool: tool,
        title: title,
        status: status,
        kind: kind,
        meta: meta,
        icon: icon,
        open: open,
        defaultOpen: defaultOpen,
        onOpenChange: onOpenChange,
        collapseOnComplete: collapseOnComplete,
        copyText: copyText,
        onCopy: onCopy,
        onRetry: onRetry,
        child:
            child ??
            const BeuiToolResultOutput(code: 'line one\nline two\nline three'),
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
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: body),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BeuiToolResult', () {
    testWidgets('renders title, tool, status label, and body when open', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          title: 'Running accessibility tests',
          tool: 'terminal.run',
          meta: 'Live',
          status: BeuiToolResultStatus.running,
        ),
      );
      // Running status spins forever — avoid pumpAndSettle.
      await tester.pump();

      expect(find.text('Running accessibility tests'), findsOneWidget);
      expect(find.text('terminal.run'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Running'), findsWidgets);
      expect(find.textContaining('line one'), findsOneWidget);
    });

    testWidgets('status label maps each lifecycle value', (tester) async {
      for (final entry in {
        BeuiToolResultStatus.running: 'Running',
        BeuiToolResultStatus.success: 'Completed',
        BeuiToolResultStatus.error: 'Failed',
        BeuiToolResultStatus.cancelled: 'Cancelled',
      }.entries) {
        await tester.pumpWidget(
          _host(
            status: entry.key,
            defaultOpen: true,
            collapseOnComplete: false,
          ),
        );
        // Infinite spin while running; pump once is enough for labels.
        await tester.pump();
        expect(find.text(entry.value), findsWidgets);
      }
    });

    testWidgets('tapping header toggles open state (uncontrolled)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          title: 'Toggle me',
          defaultOpen: true,
          status: BeuiToolResultStatus.success,
          collapseOnComplete: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('line one'), findsOneWidget);

      await tester.tap(find.text('Toggle me'));
      await tester.pumpAndSettle();
      expect(find.textContaining('line one'), findsNothing);

      await tester.tap(find.text('Toggle me'));
      await tester.pumpAndSettle();
      expect(find.textContaining('line one'), findsOneWidget);
    });

    testWidgets('controlled open respects prop and notifies onOpenChange', (
      tester,
    ) async {
      var open = true;
      final events = <bool>[];

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _host(
              title: 'Controlled',
              open: open,
              onOpenChange: (v) {
                events.add(v);
                setState(() => open = v);
              },
              status: BeuiToolResultStatus.success,
              collapseOnComplete: false,
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('line one'), findsOneWidget);

      await tester.tap(find.text('Controlled'));
      await tester.pumpAndSettle();
      expect(events, [false]);
      expect(find.textContaining('line one'), findsNothing);
    });

    testWidgets('collapseOnComplete closes when leaving running', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          title: 'Will collapse',
          status: BeuiToolResultStatus.running,
          collapseOnComplete: true,
        ),
      );
      await tester.pump();
      expect(find.textContaining('line one'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          title: 'Will collapse',
          status: BeuiToolResultStatus.success,
          collapseOnComplete: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('line one'), findsNothing);
      expect(find.text('Completed'), findsWidgets);
    });

    testWidgets('re-entering running expands the panel', (tester) async {
      await tester.pumpWidget(
        _host(
          title: 'Re-run',
          status: BeuiToolResultStatus.success,
          defaultOpen: false,
          collapseOnComplete: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('line one'), findsNothing);

      await tester.pumpWidget(
        _host(
          title: 'Re-run',
          status: BeuiToolResultStatus.running,
          defaultOpen: false,
          collapseOnComplete: true,
        ),
      );
      // Spinning loader — pump frames for the disclosure open animation.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('line one'), findsOneWidget);
    });

    testWidgets('copy action writes clipboard and shows feedback', (
      tester,
    ) async {
      final logs = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          logs.add(call);
          return null;
        },
      );

      await tester.pumpWidget(
        _host(
          status: BeuiToolResultStatus.success,
          collapseOnComplete: false,
          copyText: 'copied-output',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Copy result'));
      await tester.pump();
      expect(
        logs.any(
          (c) =>
              c.method == 'Clipboard.setData' &&
              (c.arguments as Map)['text'] == 'copied-output',
        ),
        isTrue,
      );
      expect(find.byTooltip('Copied'), findsOneWidget);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    testWidgets('onRetry is invoked from the action button', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _host(
          status: BeuiToolResultStatus.error,
          collapseOnComplete: false,
          onRetry: () => retries++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Run again'));
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets('kind and custom icon render without throwing', (tester) async {
      for (final kind in BeuiToolResultKind.values) {
        await tester.pumpWidget(
          _host(
            kind: kind,
            status: BeuiToolResultStatus.success,
            collapseOnComplete: false,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BeuiToolResult), findsOneWidget);
      }

      await tester.pumpWidget(
        _host(
          icon: const Icon(Icons.star, size: 16),
          status: BeuiToolResultStatus.success,
          collapseOnComplete: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('reduced motion still toggles open without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          title: 'Reduced',
          defaultOpen: true,
          status: BeuiToolResultStatus.success,
          collapseOnComplete: false,
          reduce: true,
        ),
      );
      await tester.pump();
      expect(find.textContaining('line one'), findsOneWidget);

      await tester.tap(find.text('Reduced'));
      await tester.pump();
      expect(find.textContaining('line one'), findsNothing);
    });
  });

  group('BeuiToolResultOutput', () {
    testWidgets('renders code text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          home: const Scaffold(
            body: BeuiToolResultOutput(
              code: 'echo hello',
              language: BeuiCodeLanguage.bash,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('echo hello'), findsOneWidget);
    });

    testWidgets('JSON property names take the theme green, not keyword red', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          status: BeuiToolResultStatus.error,
          child: const BeuiToolResultOutput(
            code: '{\n  "error": "rate_limit_exceeded"\n}',
            language: BeuiCodeLanguage.json,
          ),
        ),
      );
      // Fixed pumps, not pumpAndSettle: the running spinner is indefinite and
      // a stray ~397ms ticker keeps the tree busy even at a terminal status.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      Color? colorOf(String text) {
        Color? found;
        for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
          rt.text.visitChildren((span) {
            if (span is TextSpan && span.text == text) {
              found = span.style?.color;
              return false;
            }
            return true;
          });
          if (found != null) break;
        }
        return found;
      }

      // Shiki scopes a property name as `support.type.property-name.json`,
      // which github-*-high-contrast paints green. Painting it with the keyword
      // red was the divergence measured against beui.dev.
      expect(colorOf('"error"'), const Color(0xFF024C1A));
      expect(colorOf('"rate_limit_exceeded"'), const Color(0xFF032563));
    });
  });
}
