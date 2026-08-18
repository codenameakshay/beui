import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _models = <BeuiPromptModel>[
  BeuiPromptModel(value: 'gpt', label: 'GPT'),
  BeuiPromptModel(value: 'claude', label: 'Claude'),
];

const _actions = <BeuiPromptAction>[
  BeuiPromptAction(
    value: 'image',
    label: 'Attach image',
    description: 'Add a screenshot.',
  ),
  BeuiPromptAction(value: 'skill', label: 'Use a skill'),
];

Widget _app(Widget child, {bool reduce = false}) {
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
  group('BeuiPromptInput text', () {
    testWidgets('uncontrolled seeds defaultValue and reports edits', (
      tester,
    ) async {
      String? last;
      await tester.pumpWidget(
        _app(
          BeuiPromptInput(
            defaultValue: 'hello',
            onValueChange: (v) => last = v,
          ),
        ),
      );
      expect(find.text('hello'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'world');
      expect(last, 'world');
    });

    testWidgets('controlled reflects external value', (tester) async {
      await tester.pumpWidget(_app(const BeuiPromptInput(value: 'abc')));
      expect(find.text('abc'), findsOneWidget);
      await tester.pumpWidget(_app(const BeuiPromptInput(value: 'xyz')));
      await tester.pump();
      expect(find.text('xyz'), findsOneWidget);
    });

    testWidgets('empty trim cannot submit', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _app(BeuiPromptInput(defaultValue: '   ', onSubmit: (_, _) => calls++)),
      );
      await tester.pumpAndSettle();
      // Send button is disabled — primary icon button with null onPressed.
      await tester.tap(find.byIcon(LucideIcons.arrow_up), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(calls, 0);
    });
  });

  group('BeuiPromptInput submit', () {
    testWidgets('send button submits trimmed value and model', (tester) async {
      String? prompt;
      String? model;
      await tester.pumpWidget(
        _app(
          BeuiPromptInput(
            defaultValue: '  ship it  ',
            models: _models,
            defaultModel: 'claude',
            onSubmit: (v, m) {
              prompt = v;
              model = m;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.arrow_up));
      await tester.pumpAndSettle();
      expect(prompt, 'ship it');
      expect(model, 'claude');
    });

    testWidgets('uncontrolled clears after submit', (tester) async {
      await tester.pumpWidget(
        _app(BeuiPromptInput(defaultValue: 'clear me', onSubmit: (_, _) {})),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.arrow_up));
      await tester.pumpAndSettle();
      expect(find.text('clear me'), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text ?? '', isEmpty);
    });

    testWidgets('Enter submits without Shift', (tester) async {
      String? prompt;
      await tester.pumpWidget(
        _app(
          BeuiPromptInput(
            defaultValue: 'via enter',
            onSubmit: (v, _) => prompt = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(prompt, 'via enter');
    });

    testWidgets('loading shows stop and calls onStop', (tester) async {
      var stopped = false;
      await tester.pumpWidget(
        _app(
          BeuiPromptInput(
            defaultValue: 'busy',
            loading: true,
            onStop: () => stopped = true,
            onSubmit: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The stop mark is `<Square className="fill-current" />`, painted rather
      // than an icon glyph, so it is matched through its semantics label.
      expect(find.bySemanticsLabel('Stop generating'), findsOneWidget);
      expect(find.byIcon(LucideIcons.arrow_up), findsNothing);
      await tester.tap(find.bySemanticsLabel('Stop generating'));
      await tester.pumpAndSettle();
      expect(stopped, isTrue);
    });

    testWidgets('loading without onStop shows a busy spinner, not a stop', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const BeuiPromptInput(defaultValue: 'busy', loading: true)),
      );
      // Not pumpAndSettle: the spinner repeats forever by design.
      await tester.pump(const Duration(milliseconds: 400));
      // A stop square that cannot stop anything is a lie — with no `onStop`
      // the control presents as the busy indicator it actually is.
      expect(find.bySemanticsLabel('Stop generating'), findsNothing);
      expect(find.bySemanticsLabel('Generating'), findsOneWidget);
      await tester.tap(
        find.bySemanticsLabel('Generating'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Generating'), findsOneWidget);
    });

    testWidgets('reduced motion keeps the busy mark static', (tester) async {
      await tester.pumpWidget(
        _app(
          const BeuiPromptInput(defaultValue: 'busy', loading: true),
          reduce: true,
        ),
      );
      // Settles, because reduced motion stops the rotation entirely.
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Generating'), findsOneWidget);
    });
  });

  group('BeuiPromptInput actions', () {
    testWidgets('plus opens the actions menu and reports onAction', (
      tester,
    ) async {
      String? action;
      await tester.pumpWidget(
        _app(BeuiPromptInput(actions: _actions, onAction: (v) => action = v)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.plus));
      await tester.pumpAndSettle();
      expect(find.text('Attach image'), findsOneWidget);
      expect(find.text('Add a screenshot.'), findsOneWidget);
      await tester.tap(find.text('Attach image'));
      await tester.pumpAndSettle();
      expect(action, 'image');
    });
  });

  group('BeuiPromptInput models', () {
    testWidgets('selecting a model reports onModelChange', (tester) async {
      String? model;
      await tester.pumpWidget(
        _app(
          BeuiPromptInput(
            models: _models,
            defaultModel: 'gpt',
            onModelChange: (v) => model = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Icon-less models use BeuiSelect.
      await tester.tap(find.text('GPT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Claude'));
      await tester.pumpAndSettle();
      expect(model, 'claude');
    });

    testWidgets('icon models open a morph menu', (tester) async {
      String? model;
      await tester.pumpWidget(
        _app(
          BeuiPromptInput(
            models: const [
              BeuiPromptModel(
                value: 'gpt',
                label: 'GPT',
                icon: Icon(LucideIcons.bot),
              ),
              BeuiPromptModel(
                value: 'claude',
                label: 'Claude',
                icon: Icon(LucideIcons.bot),
              ),
            ],
            defaultModel: 'gpt',
            onModelChange: (v) => model = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('GPT'));
      await tester.pumpAndSettle();
      // Menu shows both options; pick Claude.
      final claude = find.text('Claude');
      expect(claude, findsWidgets);
      await tester.tap(claude.last);
      await tester.pumpAndSettle();
      expect(model, 'claude');
    });
  });

  group('BeuiPromptInput reduced motion', () {
    testWidgets('send/stop swap under reduced motion does not throw', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const BeuiPromptInput(defaultValue: 'x', loading: false),
          reduce: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.arrow_up), findsOneWidget);

      await tester.pumpWidget(
        _app(
          BeuiPromptInput(defaultValue: 'x', loading: true, onStop: () {}),
          reduce: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Stop generating'), findsOneWidget);
    });
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BeuiTextTheme.trackingNormal(
          ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: const ValueKey('golden'),
              width: 400,
              child: BeuiPromptInput(
                models: _models,
                actions: _actions,
                defaultModel: 'gpt',
                defaultValue: 'Review the current implementation.',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('golden')),
      matchesGoldenFile('goldens/beui_prompt_input.png'),
    );
  });
}
