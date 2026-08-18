import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

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
      expect(find.byTooltip('Copied'), findsNothing); // we use Semantics label

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

    testWidgets('reduced motion still renders streaming chrome', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiCodeBlock(
            code: 'stream\nmore',
            status: BeuiCodeBlockStatus.streaming,
            maxHeight: 80,
          ),
          reduce: true,
        ),
      );
      expect(find.text('Writing'), findsOneWidget);
      expect(find.text('stream'), findsOneWidget);
    });

    testWidgets('highlight lines paint without error', (tester) async {
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
}
