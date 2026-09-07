import 'package:beui/beui.dart';
// The shared highlighter is package-internal; these tests pin the migration
// away from this widget's old private fork.
import 'package:beui/src/motion/_syntax.dart' show BeuiSyntaxPalette;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '_follow_contract.dart';

Widget _wrap(Widget child, {bool reduce = false}) {
  Widget body = Center(child: SizedBox(width: 400, child: child));
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
  group('BeuiCodeBlock', () {
    testWidgets('renders code, filename, and language label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiCodeBlock(
            code: 'const x = 1;',
            filename: 'app.ts',
            language: BeuiCodeLanguage.typescript,
          ),
        ),
      );
      expect(find.text('const x = 1;'), findsOneWidget);
      expect(find.text('app.ts'), findsOneWidget);
      expect(find.text('TYPESCRIPT'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
    });

    testWidgets('shows Writing status while streaming', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiCodeBlock(
            code: 'line one',
            status: BeuiCodeBlockStatus.streaming,
          ),
        ),
      );
      expect(find.text('Writing'), findsOneWidget);
      expect(find.text('Ready'), findsNothing);
    });

    testWidgets('renders line numbers by default', (tester) async {
      await tester.pumpWidget(_wrap(const BeuiCodeBlock(code: 'a\nb\nc')));
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('hides line numbers when showLineNumbers is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const BeuiCodeBlock(code: 'only', showLineNumbers: false)),
      );
      // Gutter "1" should be gone; code text remains.
      expect(find.text('only'), findsOneWidget);
      // The only "1" would have been the gutter — none now.
      expect(find.text('1'), findsNothing);
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
        _wrap(const BeuiCodeBlock(code: 'hello copy', filename: 'x.ts')),
      );

      await tester.tap(find.byIcon(LucideIcons.copy));
      await tester.pump();

      expect(
        log.any(
          (c) =>
              c.method == 'Clipboard.setData' &&
              (c.arguments as Map)['text'] == 'hello copy',
        ),
        isTrue,
      );
      expect(find.byIcon(LucideIcons.check), findsWidgets);
      // Status Ready check + copy feedback check.

      // Wait out the 1600ms feedback window.
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
        _wrap(
          BeuiCodeBlock(
            code: 'no clip',
            onCopy: () {
              calls++;
            },
          ),
        ),
      );
      await tester.tap(find.byIcon(LucideIcons.copy));
      await tester.pump();
      expect(calls, 1);
    });

    testWidgets('hides copy button when copyable is false', (tester) async {
      await tester.pumpWidget(
        _wrap(const BeuiCodeBlock(code: 'secret', copyable: false)),
      );
      expect(find.byIcon(LucideIcons.copy), findsNothing);
    });

    testWidgets('accepts a Widget filename through filenameWidget', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiCodeBlock(
            code: 'x',
            filenameWidget: Text('custom.tsx', key: Key('fn')),
          ),
        ),
      );
      expect(find.byKey(const Key('fn')), findsOneWidget);
    });

    testWidgets('the deprecated untyped slot still renders both shapes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiCodeBlock(
            code: 'x',
            // ignore: deprecated_member_use_from_same_package
            filenameNode: Text('legacy.tsx', key: Key('legacy')),
          ),
        ),
      );
      expect(find.byKey(const Key('legacy')), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          const BeuiCodeBlock(
            code: 'x',
            // ignore: deprecated_member_use_from_same_package
            filenameNode: 'legacy-string.tsx',
          ),
        ),
      );
      expect(find.text('legacy-string.tsx'), findsOneWidget);
    });

    testWidgets('highlight lines paint the fill and leading bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiCodeBlock(code: 'one\ntwo\nthree', highlightLines: [2]),
        ),
      );
      expect(find.text('two'), findsOneWidget);
      // A highlighted row carries two channels, not one: a ~0.10 fill (the old
      // 0.07 wash measured 1.08:1) and a 2px leading bar at 0.6.
      final decorated = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(BeuiCodeBlock),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.border != null && d.color != null)
          .toList();
      expect(decorated, isNotEmpty);
      final highlight = decorated.first;
      expect(highlight.color!.a, closeTo(0.10, 0.005));
      final bar = (highlight.border! as BorderDirectional).start;
      expect(bar.width, 2);
      expect(bar.color.a, closeTo(0.6, 0.005));
    });
  });

  // ---------------------------------------------------------------------
  // UX remediation — R7, R8, R12, R14, R26, R28, R33, R36
  // ---------------------------------------------------------------------

  group('BeuiCodeBlock gutters', () {
    testWidgets('line numbers are legible, not a 1.63:1 hairline', (
      tester,
    ) async {
      await expectLegibleGutterNumber(
        tester,
        _wrap(const BeuiCodeBlock(code: 'a\nb\nc')),
        lineNumberText: '2',
      );
    });

    testWidgets('the language label is not alpha-multiplied either', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const BeuiCodeBlock(code: 'a')));
      await tester.pumpAndSettle();
      final label = tester.widget<Text>(find.text('TYPESCRIPT'));
      expect(label.style!.color!.a, 1.0);
    });
  });

  group('BeuiCodeBlock empty state', () {
    testWidgets('an empty finished block says so', (tester) async {
      await tester.pumpWidget(_wrap(const BeuiCodeBlock(code: '')));
      await tester.pumpAndSettle();
      // Not a lone gutter `1` next to nothing, which reads as a bug.
      expect(find.text('No code to show'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('the placeholder is overridable', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiCodeBlock(
            code: '',
            emptyPlaceholder: Text('Nothing was written'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nothing was written'), findsOneWidget);
    });

    testWidgets('a streaming block keeps its blank line — content is coming', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiCodeBlock(code: '', status: BeuiCodeBlockStatus.streaming),
        ),
      );
      await tester.pump();
      expect(find.text('No code to show'), findsNothing);
    });
  });

  group('BeuiCodeBlock copy control', () {
    testWidgets('the copied confirmation is announced', (tester) async {
      await expectCopyConfirmationAnnounced(
        tester,
        _wrap(BeuiCodeBlock(code: 'x', onCopy: () async {})),
        copyLabel: 'Copy code',
      );
    });

    testWidgets('press scales to 0.97, the library token', (tester) async {
      await tester.pumpWidget(
        _wrap(BeuiCodeBlock(code: 'x', onCopy: () async {})),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(LucideIcons.copy)),
      );
      // The press spring needs frames, not one long jump: the state flip and
      // the animation's first frame are the same frame, which renders `from`.
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final scale = tester
          .widgetList<Transform>(
            find.ancestor(
              of: find.byIcon(LucideIcons.copy),
              matching: find.byType(Transform),
            ),
          )
          .map((t) => t.transform.storage[0])
          .reduce((a, b) => a * b);
      // 0.97, not the 0.9 this widget used to undercut the library with.
      expect(scale, lessThan(1.0));
      expect(scale, greaterThan(0.93));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('keyboard activation copies', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiCodeBlock(
            code: 'x',
            onCopy: () async {
              calls++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(calls, 1);
    });
  });

  group('BeuiCodeBlock hidden content and following', () {
    String longCode(int n) =>
        [for (var i = 0; i < n; i++) 'const line$i = $i;'].join('\n');

    testWidgets('the follow contract', (tester) async {
      await runFollowContract(
        tester,
        rootType: BeuiCodeBlock,
        growLineCount: 90,
        build: ({required lineCount, required streaming}) => _wrap(
          BeuiCodeBlock(
            code: longCode(lineCount),
            maxHeight: 120,
            status: streaming
                ? BeuiCodeBlockStatus.streaming
                : BeuiCodeBlockStatus.complete,
          ),
        ),
      );
    });
  });

  group('BeuiCodeBlock shared highlighter', () {
    testWidgets('JSON property names take the property colour, not number', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiCodeBlock(
            code: '{"name": 42}',
            language: BeuiCodeLanguage.json,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final palette = BeuiSyntaxPalette.of(Brightness.light);
      final span = tester.widget<Text>(find.byType(Text).last).textSpan!;
      final colours = <Color>[];
      span.visitChildren((child) {
        if (child is TextSpan && child.style?.color != null) {
          colours.add(child.style!.color!);
        }
        return true;
      });
      // The key is green (Shiki scopes it support.type.property-name.json);
      // the value stays the number blue. The old fork painted both blue.
      expect(colours, contains(palette.property));
      expect(colours, contains(palette.number));
    });

    testWidgets('bash tokenises positionally: command, then arguments', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiCodeBlock(
            code: 'cd packages/beui',
            language: BeuiCodeLanguage.bash,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final palette = BeuiSyntaxPalette.of(Brightness.light);
      final span = tester.widget<Text>(find.byType(Text).last).textSpan!;
      final byText = <String, Color>{};
      span.visitChildren((child) {
        if (child is TextSpan && child.style?.color != null) {
          byText[child.text ?? ''] = child.style!.color!;
        }
        return true;
      });
      // `cd` is the command word, not a keyword painted red mid-line.
      expect(byText['cd'], palette.variable);
      expect(byText['packages/beui'], palette.string);
    });
  });

  // A settled, complete block: the gutter at its new 0.75 strength, the
  // highlighted rows carrying both a fill and a leading bar, and the chrome's
  // un-multiplied language label.
  testWidgets('settled golden (complete, line numbers, highlight)', (
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
              width: 520,
              child: BeuiCodeBlock(
                code:
                    'import { generateText } from "ai";\n'
                    '\n'
                    'export async function summarize(input: string) {\n'
                    '  const { text } = await generateText({\n'
                    '    model: "openai/gpt-5",\n'
                    '  });\n'
                    '  return text;\n'
                    '}',
                filename: 'summarize.ts',
                highlightLines: [4, 5, 6],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiCodeBlock),
      matchesGoldenFile('goldens/beui_code_block.png'),
    );
  });
}
