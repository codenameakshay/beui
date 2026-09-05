import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _theme({Brightness brightness = Brightness.light}) {
  final base = brightness == Brightness.dark
      ? ThemeData.dark().copyWith(extensions: [BeuiColors.dark()])
      : ThemeData.light().copyWith(extensions: [BeuiColors.light()]);
  return BeuiTextTheme.trackingNormal(base);
}

Widget _host({
  String? tool = 'terminal.run',
  Widget? toolWidget,
  String? title = 'Running checks',
  Widget? titleWidget,
  Widget? child,
  BeuiToolResultStatus status = BeuiToolResultStatus.running,
  BeuiToolResultKind kind = BeuiToolResultKind.terminal,
  String? meta,
  Widget? icon,
  bool? open,
  bool defaultOpen = true,
  ValueChanged<bool>? onOpenChange,
  bool collapseOnComplete = true,
  bool keepActionsVisibleWhenCollapsed = true,
  double maxHeight = 220,
  int? hiddenLineCount,
  String? copyText,
  Future<void> Function()? onCopy,
  VoidCallback? onRetry,
  bool reduce = false,
  double width = 400,
  Brightness brightness = Brightness.light,
}) {
  Widget body = Center(
    child: SizedBox(
      width: width,
      child: BeuiToolResult(
        tool: tool,
        toolWidget: toolWidget,
        title: title,
        titleWidget: titleWidget,
        status: status,
        kind: kind,
        meta: meta,
        icon: icon,
        open: open,
        defaultOpen: defaultOpen,
        onOpenChange: onOpenChange,
        collapseOnComplete: collapseOnComplete,
        keepActionsVisibleWhenCollapsed: keepActionsVisibleWhenCollapsed,
        maxHeight: maxHeight,
        hiddenLineCount: hiddenLineCount,
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
    theme: _theme(brightness: brightness),
    home: Scaffold(body: body),
  );
}

/// Every node in the semantics tree at or below the app root.
List<SemanticsNode> _semanticsNodes(WidgetTester tester) {
  final root = tester.getSemantics(find.byType(MaterialApp));
  final out = <SemanticsNode>[];
  void walk(SemanticsNode node) {
    out.add(node);
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  walk(root);
  return out;
}

/// Whether [node] is a live region (the non-deprecated flag read).
bool _isLiveRegion(SemanticsNode node) =>
    node.getSemanticsData().flagsCollection.isLiveRegion;

/// The first painted colour of [text] inside any [RichText] in the tree.
Color? _spanColor(WidgetTester tester, String text) {
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

    testWidgets('per-instance and theme string overrides win in order', (
      tester,
    ) async {
      // Theme strings replace the defaults…
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(
              extensions: [
                BeuiColors.light(),
                const BeuiAgentTheme(
                  strings: BeuiAgentStrings(
                    statusFailed: 'Échec',
                    copyResult: 'Copier',
                    runAgain: 'Relancer',
                  ),
                ),
              ],
            ),
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: BeuiToolResult(
                  tool: 'terminal.run',
                  title: 'Localised',
                  status: BeuiToolResultStatus.error,
                  collapseOnComplete: false,
                  copyText: 'x',
                  onRetry: () {},
                  child: const BeuiToolResultOutput(code: 'x'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Échec'), findsWidgets);
      expect(find.byTooltip('Copier'), findsOneWidget);
      expect(find.byTooltip('Relancer'), findsOneWidget);

      // …and a per-instance label beats the theme.
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(
              extensions: [
                BeuiColors.light(),
                const BeuiAgentTheme(
                  strings: BeuiAgentStrings(copyResult: 'Copier'),
                ),
              ],
            ),
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: BeuiToolResult(
                  tool: 'terminal.run',
                  title: 'Localised',
                  status: BeuiToolResultStatus.error,
                  collapseOnComplete: false,
                  copyText: 'x',
                  copyLabel: 'Kopieren',
                  child: const BeuiToolResultOutput(code: 'x'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Kopieren'), findsOneWidget);
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

    testWidgets('copying announces "Copied" through a live region', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
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

      final announced = _semanticsNodes(
        tester,
      ).where((n) => n.label == 'Copied').toList();
      expect(announced, isNotEmpty);
      expect(announced.any(_isLiveRegion), isTrue);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      handle.dispose();
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

    testWidgets('widget-form tool / title / meta render', (tester) async {
      await tester.pumpWidget(
        _host(
          tool: null,
          toolWidget: const Text('slug-widget'),
          title: null,
          titleWidget: const Text('title-widget'),
          status: BeuiToolResultStatus.success,
          collapseOnComplete: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('slug-widget'), findsOneWidget);
      expect(find.text('title-widget'), findsOneWidget);
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
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('line one'), findsNothing);
    });

    testWidgets('reduced motion keeps an opacity fade, not a hard cut', (
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

      await tester.tap(find.text('Reduced'));
      await tester.pump();
      // Mid-exit: the shared disclosure drops movement but keeps the ~120ms
      // cross-fade, so a partial Opacity must exist over the panel.
      await tester.pump(const Duration(milliseconds: 55));

      final opacities = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((o) => o.opacity)
          .where((v) => v > 0.001 && v < 0.999);
      expect(
        opacities,
        isNotEmpty,
        reason: 'reduced motion must fade the disclosure, not cut it',
      );
    });

    testWidgets('status colours resolve from the dark role set', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          title: 'Dark',
          status: BeuiToolResultStatus.error,
          collapseOnComplete: false,
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpAndSettle();

      final failed = BeuiAgentTheme.standard
          .statusColorsFor(Brightness.dark)
          .palette(BeuiAgentStatus.failed);
      final label = tester.widgetList<Text>(find.text('Failed')).first;
      expect(label.style?.color, failed.foreground);

      // …and light mode uses the light role, not the same value.
      await tester.pumpWidget(
        _host(
          title: 'Light',
          status: BeuiToolResultStatus.error,
          collapseOnComplete: false,
        ),
      );
      await tester.pumpAndSettle();
      final lightFailed = BeuiAgentTheme.standard
          .statusColorsFor(Brightness.light)
          .palette(BeuiAgentStatus.failed);
      expect(
        tester.widgetList<Text>(find.text('Failed')).first.style?.color,
        lightFailed.foreground,
      );
      expect(lightFailed.foreground, isNot(failed.foreground));
    });

    testWidgets('terminal status is announced through a live region', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _host(
          title: 'Will fail',
          status: BeuiToolResultStatus.running,
          collapseOnComplete: false,
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        _host(
          title: 'Will fail',
          status: BeuiToolResultStatus.error,
          collapseOnComplete: false,
        ),
      );
      await tester.pumpAndSettle();

      final failing = _semanticsNodes(
        tester,
      ).where((n) => n.label.contains('Failed')).toList();
      expect(
        failing,
        isNotEmpty,
        reason: 'the terminal outcome must reach the semantics tree',
      );
      expect(
        failing.any(_isLiveRegion),
        isTrue,
        reason: 'liveRegion must survive the transition to a terminal status',
      );

      handle.dispose();
    });

    testWidgets('header toggle is reachable and activatable by keyboard', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          title: 'Keyboard',
          defaultOpen: true,
          status: BeuiToolResultStatus.success,
          collapseOnComplete: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('line one'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, isNotNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.textContaining('line one'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.textContaining('line one'), findsOneWidget);
    });

    testWidgets('actions stay reachable while the panel is collapsed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          title: 'Collapsed',
          defaultOpen: false,
          status: BeuiToolResultStatus.success,
          collapseOnComplete: true,
          copyText: 'out',
          onRetry: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('line one'), findsNothing);
      expect(find.byTooltip('Copy result'), findsOneWidget);
      expect(find.byTooltip('Run again'), findsOneWidget);
    });

    testWidgets(
      'keepActionsVisibleWhenCollapsed: false hides them with the panel',
      (tester) async {
        await tester.pumpWidget(
          _host(
            title: 'Legacy',
            defaultOpen: false,
            status: BeuiToolResultStatus.success,
            collapseOnComplete: true,
            keepActionsVisibleWhenCollapsed: false,
            copyText: 'out',
            onRetry: () {},
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Copy result'), findsNothing);
      },
    );

    testWidgets('header wraps onto two lines below 400px', (tester) async {
      await tester.pumpWidget(
        _host(
          title: 'Narrow header',
          tool: 'terminal.run',
          meta: '2.9s',
          width: 360,
          status: BeuiToolResultStatus.success,
          collapseOnComplete: false,
        ),
      );
      await tester.pumpAndSettle();

      final titleY = tester.getTopLeft(find.text('Narrow header')).dy;
      final toolY = tester.getTopLeft(find.text('terminal.run')).dy;
      expect(
        toolY - titleY,
        greaterThan(8),
        reason: 'the slug must drop to a second line under 400px',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('header stays on one line at 500px', (tester) async {
      await tester.pumpWidget(
        _host(
          title: 'Wide header',
          tool: 'terminal.run',
          meta: '2.9s',
          width: 500,
          status: BeuiToolResultStatus.success,
          collapseOnComplete: false,
        ),
      );
      await tester.pumpAndSettle();

      final titleY = tester.getTopLeft(find.text('Wide header')).dy;
      final toolY = tester.getTopLeft(find.text('terminal.run')).dy;
      expect((toolY - titleY).abs(), lessThan(8));
      expect(
        tester.getTopLeft(find.text('terminal.run')).dx,
        greaterThan(tester.getTopRight(find.text('Wide header')).dx),
      );
    });

    testWidgets('actions do not overflow at 320px', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _host(
          title: 'Very narrow tool result header label',
          meta: '2.9s',
          width: 320,
          status: BeuiToolResultStatus.error,
          collapseOnComplete: false,
          copyText: 'out',
          onRetry: () {},
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('capped output shows a fade and a hidden-line count', (
      tester,
    ) async {
      final long = List<String>.generate(60, (i) => 'line $i').join('\n');
      await tester.pumpWidget(
        _host(
          title: 'Long output',
          status: BeuiToolResultStatus.success,
          collapseOnComplete: false,
          maxHeight: 120,
          copyText: long,
          child: BeuiToolResultOutput(code: long),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ShaderMask), findsOneWidget);
      expect(find.textContaining('more'), findsOneWidget);
    });

    testWidgets('short output shows neither fade nor count', (tester) async {
      await tester.pumpWidget(
        _host(
          title: 'Short output',
          status: BeuiToolResultStatus.success,
          collapseOnComplete: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ShaderMask), findsNothing);
      expect(find.textContaining('more'), findsNothing);
    });

    testWidgets('hiddenLineCount overrides the derived count', (tester) async {
      final long = List<String>.generate(60, (i) => 'line $i').join('\n');
      await tester.pumpWidget(
        _host(
          title: 'Explicit count',
          status: BeuiToolResultStatus.success,
          collapseOnComplete: false,
          maxHeight: 120,
          hiddenLineCount: 1234,
          child: BeuiToolResultOutput(code: long),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('1234'), findsOneWidget);
    });

    testWidgets('action buttons meet the tap-target guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          title: 'Targets',
          defaultOpen: false,
          status: BeuiToolResultStatus.success,
          collapseOnComplete: true,
          copyText: 'out',
          onRetry: () {},
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('golden — completed result with actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(520, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: const ValueKey('golden'),
                child: SizedBox(
                  width: 460,
                  child: BeuiToolResult(
                    tool: 'terminal.run',
                    title: 'Tests passed',
                    meta: '2.9s',
                    kind: BeuiToolResultKind.terminal,
                    status: BeuiToolResultStatus.success,
                    collapseOnComplete: false,
                    copyText: '49 pass · 0 fail',
                    onRetry: _noop,
                    child: const BeuiToolResultOutput(
                      code:
                          r'$ bun test tests/a11y.test.tsx'
                          '\n49 pass · 0 fail',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // Fixed pumps, never pumpAndSettle: the header labels roll in through
      // an AnimatedSwitcher, so frame one would capture them mid-entrance
      // (clipped out of their slot). 600ms lands well past every entrance and
      // is exactly reproducible at a terminal status.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await expectLater(
        find.byKey(const ValueKey('golden')),
        matchesGoldenFile('goldens/beui_tool_result.png'),
      );
    });
  });

  group('BeuiToolResultOutput', () {
    testWidgets('renders code text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
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

      // Shiki scopes a property name as `support.type.property-name.json`,
      // which github-*-high-contrast paints green. Painting it with the keyword
      // red was the divergence measured against beui.dev.
      expect(_spanColor(tester, '"error"'), const Color(0xFF024C1A));
      expect(
        _spanColor(tester, '"rate_limit_exceeded"'),
        const Color(0xFF032563),
      );
    });

    testWidgets('body text is not alpha-multiplied', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: const Scaffold(
            body: BeuiToolResultOutput(
              code: 'plain output',
              language: BeuiCodeLanguage.text,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The base text colour is the un-multiplied foreground. (The painted
      // spans then take their Shiki colours on top of it — A8 is about the
      // base, which used to be `foreground @ 0.8`.)
      final base = tester.widget<DefaultTextStyle>(
        find
            .descendant(
              of: find.byType(BeuiToolResultOutput),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      );
      expect(base.style.color, BeuiColors.light().foreground);
      expect(base.style.color!.a, 1.0);
    });
  });

  // The last streaming viewport in the library with no pin concept. It
  // now shares BeuiLiveEdgeFollower with the code block and the file diff.
  group('BeuiToolResult live edge', () {
    String longOutput(int n) =>
        [for (var i = 0; i < n; i++) 'line $i'].join('\n');

    Future<void> frames(WidgetTester tester, int count) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    ScrollController controllerOf(WidgetTester tester) => tester
        .widget<SingleChildScrollView>(
          find
              .descendant(
                of: find.byType(BeuiToolResult),
                matching: find.byWidgetPredicate(
                  (w) => w is SingleChildScrollView && w.controller != null,
                ),
              )
              .first,
        )
        .controller!;

    testWidgets('an unpinned viewport follows arriving output', (tester) async {
      await tester.pumpWidget(
        _host(
          child: BeuiToolResultOutput(code: longOutput(20)),
          maxHeight: 120,
        ),
      );
      await frames(tester, 20);

      await tester.pumpWidget(
        _host(
          child: BeuiToolResultOutput(code: longOutput(60)),
          maxHeight: 120,
        ),
      );
      await frames(tester, 30);
      final controller = controllerOf(tester);
      expect(
        controller.offset,
        closeTo(controller.position.maxScrollExtent, 1),
      );
    });

    testWidgets(
      'scrolling away mid-stream keeps the reader put and offers a way back',
      (tester) async {
        await tester.pumpWidget(
          _host(
            child: BeuiToolResultOutput(code: longOutput(60)),
            maxHeight: 120,
          ),
        );
        await frames(tester, 30);
        expect(find.text('Jump to latest'), findsNothing);

        final controller = controllerOf(tester);
        controller.jumpTo(controller.position.maxScrollExtent - 200);
        await frames(tester, 20);
        expect(find.text('Jump to latest'), findsOneWidget);
        final pinnedAt = controller.offset;

        // The tool keeps writing; the viewport must not yank.
        await tester.pumpWidget(
          _host(
            child: BeuiToolResultOutput(code: longOutput(90)),
            maxHeight: 120,
          ),
        );
        await frames(tester, 20);
        expect(controller.offset, closeTo(pinnedAt, 1));

        await tester.tap(find.text('Jump to latest'));
        await frames(tester, 30);
        expect(
          controller.offset,
          closeTo(controller.position.maxScrollExtent, 1),
        );
        expect(find.text('Jump to latest'), findsNothing);
      },
    );

    testWidgets('a settled result never offers the pill', (tester) async {
      await tester.pumpWidget(
        _host(
          child: BeuiToolResultOutput(code: longOutput(60)),
          status: BeuiToolResultStatus.success,
          collapseOnComplete: false,
          maxHeight: 120,
        ),
      );
      await tester.pumpAndSettle();
      final controller = controllerOf(tester);
      controller.jumpTo(0);
      await frames(tester, 20);
      // Nothing is arriving, so there is no live edge to return to.
      expect(find.text('Jump to latest'), findsNothing);
    });

    testWidgets('the overflow cue speaks the shared hidden-lines copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          child: BeuiToolResultOutput(code: longOutput(60)),
          status: BeuiToolResultStatus.success,
          collapseOnComplete: false,
          maxHeight: 120,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('more lines'), findsOneWidget);
    });
  });
}

void _noop() {}
