import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

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

Widget _app(Widget child, {bool reduce = false}) =>
    beuiTestApp(child, width: 400, reduce: reduce);

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

  group('BeuiPromptInput keyboard & semantics', () {
    testWidgets('Shift+Enter inserts a newline instead of submitting', (
      tester,
    ) async {
      var submits = 0;
      await tester.pumpWidget(
        _app(
          BeuiPromptInput(defaultValue: 'one', onSubmit: (_, _) => submits++),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(submits, 0);
    });

    testWidgets('Enter mid-stream does not submit and does not vanish', (
      tester,
    ) async {
      var submits = 0;
      final blocked = <BeuiPromptBlockedReason>[];
      await tester.pumpWidget(
        _app(
          BeuiPromptInput(
            defaultValue: 'drafting the next one',
            loading: true,
            onStop: () {},
            onSubmit: (_, _) => submits++,
            onSubmitBlocked: blocked.add,
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));

      expect(submits, 0);
      // Not silence: the press is reported, and the stop button flashes.
      expect(blocked, [BeuiPromptBlockedReason.loading]);
    });

    testWidgets('Enter on an empty composer reports rather than swallowing', (
      tester,
    ) async {
      final blocked = <BeuiPromptBlockedReason>[];
      await tester.pumpWidget(
        _app(
          BeuiPromptInput(onSubmit: (_, _) {}, onSubmitBlocked: blocked.add),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(blocked, [BeuiPromptBlockedReason.empty]);
    });

    testWidgets('Enter is ignored while an IME composition is active', (
      tester,
    ) async {
      var submits = 0;
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          BeuiPromptInput(
            controller: controller,
            onSubmit: (_, _) => submits++,
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Mid-composition the Enter belongs to the IME candidate window, not to
      // the composer. This is the most-missed chat-composer detail.
      controller.value = const TextEditingValue(
        text: 'にほん',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 0, end: 3),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(submits, 0);

      // Composition committed → Enter sends.
      controller.value = const TextEditingValue(
        text: 'にほん',
        selection: TextSelection.collapsed(offset: 3),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(submits, 1);
    });

    testWidgets('a disabled composer submits nothing', (tester) async {
      var submits = 0;
      await tester.pumpWidget(
        _app(
          BeuiPromptInput(
            defaultValue: 'ready',
            enabled: false,
            onSubmit: (_, _) => submits++,
          ),
        ),
      );
      await tester.tap(find.byType(TextField), warnIfMissed: false);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(submits, 0);
    });

    testWidgets('pasting a large block does not throw and clamps to maxRows', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(BeuiPromptInput(maxRows: 4, onSubmit: (_, _) {})),
      );
      // The measurement used to lay out the whole document on every keystroke;
      // it is memoised and capped at maxRows now.
      await tester.enterText(
        find.byType(TextField),
        List.generate(400, (i) => 'line $i').join('\n'),
      );
      await tester.pump();

      final field = tester.getRect(find.byType(TextField));
      // Four rows at the 24px source line height, never the full 400.
      expect(field.height, lessThanOrEqualTo(4 * 24 + 1));
    });

    testWidgets('the + menu opens, roves and activates from the keyboard', (
      tester,
    ) async {
      String? action;
      await tester.pumpWidget(
        _app(BeuiPromptInput(actions: _actions, onAction: (v) => action = v)),
      );
      await tester.pumpAndSettle();

      // Keyboard only, no pointer anywhere: Tab to the field, Tab again to
      // the + trigger, then open it.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Use a skill'), findsOneWidget);

      // The first row takes focus on open; Down moves to the second.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(action, 'skill');
    });

    testWidgets('Esc closes the + menu — the overlay does not trap focus', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const BeuiPromptInput(actions: _actions)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.plus));
      await tester.pumpAndSettle();
      expect(find.text('Use a skill'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Use a skill'), findsNothing);
    });

    testWidgets('the composer is one edit box, not two', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const BeuiPromptInput()));
      await tester.pumpAndSettle();

      // The wrapper used to declare textField over a TextField that already
      // did, so the tree carried two edit-box nodes and a screen reader
      // announced the composer twice. The name now merges into the field's own
      // node instead of sitting on a second one above it.
      final node = tester.getSemantics(find.byType(TextField));
      // One node carrying the name — not a bare wrapper node above an
      // anonymous field. (Merged labels are newline-joined, hence `contains`.)
      expect(node.label, contains('Prompt'));
      expect(find.byType(TextField), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the + trigger is a button that reports its expanded state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const BeuiPromptInput(actions: _actions)));
      await tester.pumpAndSettle();

      // Was a bare Semantics > GestureDetector with no button role, no
      // focusability and no expanded state.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Add to prompt')),
        matchesSemantics(
          label: 'Add to prompt',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
          hasExpandedState: true,
        ),
      );
      handle.dispose();
    });
  });

  group('BeuiPromptInput attachments', () {
    const attachments = [
      BeuiPromptAttachment(id: 'a', name: 'diagram.png'),
      BeuiPromptAttachment(
        id: 'b',
        name: 'notes.md',
        status: BeuiPromptAttachmentStatus.uploading,
        progress: 0.4,
      ),
      BeuiPromptAttachment(
        id: 'c',
        name: 'huge.zip',
        status: BeuiPromptAttachmentStatus.failed,
        error: 'Too large',
      ),
    ];

    testWidgets('a chip carries a remove control that fires', (tester) async {
      final removed = <String>[];
      await tester.pumpWidget(
        _app(
          BeuiPromptInput(
            attachments: const [BeuiPromptAttachment(id: 'a', name: 'a.png')],
            onAttachmentRemoved: (a) => removed.add(a.id),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('a.png'), findsOneWidget);
      expect(find.bySemanticsLabel('Remove a.png'), findsOneWidget);
      // A ready chip offers no retry.
      expect(find.bySemanticsLabel('Retry a.png'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Remove a.png'));
      await tester.pump();
      expect(removed, ['a']);
    });

    testWidgets('a failed chip offers retry only when it is wired', (
      tester,
    ) async {
      const failed = BeuiPromptAttachment(
        id: 'c',
        name: 'z.zip',
        status: BeuiPromptAttachmentStatus.failed,
        error: 'Too large',
      );
      await tester.pumpWidget(
        _app(const BeuiPromptInput(attachments: [failed])),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.bySemanticsLabel('Retry z.zip'), findsNothing);

      final retried = <String>[];
      await tester.pumpWidget(
        _app(
          BeuiPromptInput(
            attachments: const [failed],
            onAttachmentRetry: (a) => retried.add(a.id),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.bySemanticsLabel('Retry z.zip'));
      await tester.pump();
      expect(retried, ['c']);
    });

    testWidgets('attachments ride along with the submission', (tester) async {
      BeuiPromptSubmission? full;
      String? legacy;
      await tester.pumpWidget(
        _app(
          BeuiPromptInput(
            defaultValue: 'have a look',
            models: _models,
            defaultModel: 'gpt',
            attachments: attachments,
            onSubmit: (text, _) => legacy = text,
            onSubmitFull: (s) => full = s,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.bySemanticsLabel('Send prompt'));
      await tester.pump();

      // Additive: the old callback still fires, unchanged.
      expect(legacy, 'have a look');
      expect(full?.text, 'have a look');
      expect(full?.model, 'gpt');
      expect(full?.attachments.map((a) => a.id), ['a', 'b', 'c']);
    });

    testWidgets('an attachment alone is enough to send', (tester) async {
      var submits = 0;
      await tester.pumpWidget(
        _app(
          BeuiPromptInput(
            attachments: const [
              BeuiPromptAttachment(id: 'a', name: 'photo.png'),
            ],
            onSubmit: (_, _) => submits++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // An image with no caption is a real message.
      await tester.tap(find.bySemanticsLabel('Send prompt'));
      await tester.pump();
      expect(submits, 1);
    });

    testWidgets('an uploading chip announces its percentage', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const BeuiPromptInput(
            attachments: [
              BeuiPromptAttachment(
                id: 'b',
                name: 'notes.md',
                status: BeuiPromptAttachmentStatus.uploading,
                progress: 0.4,
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // `first`: the chip's own node, above the excluded decoration beneath it.
      final node = tester.getSemantics(find.bySemanticsLabel('notes.md').first);
      // A percentage, not a moving colour nobody can read.
      expect(node.value, 'Uploading, 40%');
      handle.dispose();
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
