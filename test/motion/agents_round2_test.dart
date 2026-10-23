import 'dart:io';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/approval_card_demo.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/chat_app_demo.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/file_diff_demo.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/prompt_input_demo.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/agent_activity_demo.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/message_bubble_demo.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/loading_states_demo.dart';
import '../support.dart';

void main() {
  testWidgets('stopped response exposes Continue as its own named action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var continued = 0;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiStreamingResponse(
          status: BeuiStreamingResponseStatus.stopped,
          continueLabel: 'Continue generating',
          onContinue: () => continued++,
          child: const Text('Partial reply'),
        ),
        reduce: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final action = find.bySemanticsLabel('Continue generating');
    expect(action, findsOneWidget);
    await tester.tap(action);
    expect(continued, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });
  testWidgets('mobile chat opens the actual rail and restores trigger focus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      beuiTestApp(
        Builder(builder: chatAppDemo),
        reduce: true,
        fontFamily: 'Geist',
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Projects').hitTestable(), findsNothing);
    final trigger = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Show sidebar',
    );
    expect(tester.getSize(find.byType(BeuiChatApp)).width, 366);
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(find.text('Projects').hitTestable(), findsOneWidget);
    final scrim = tester.getRect(find.bySemanticsLabel('Close navigation'));
    await tester.tapAt(Offset(scrim.right - 12, scrim.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('Projects').hitTestable(), findsNothing);
    expect(tester.widget<IconButton>(trigger).focusNode!.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('checkbox option description selects its associated value', (
    tester,
  ) async {
    Map<String, BeuiApprovalCardAnswer>? submitted;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiApprovalCard(
          questions: const [
            BeuiApprovalCardQuestion(
              id: 'checks',
              title: 'Choose checks',
              multiple: true,
              options: [
                BeuiApprovalCardOption(
                  value: 'access',
                  label: 'Accessibility',
                  description: 'Check every keyboard path.',
                ),
              ],
            ),
          ],
          onSubmit: (answers) => submitted = answers,
        ),
        reduce: true,
      ),
    );
    await tester.tap(find.text('Check every keyboard path.'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Submit response'));
    await tester.pump();
    expect(submitted!['checks']!.selected, ['access']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final reduce in [false, true]) {
    testWidgets(
      'prompt notice enters from source 3px or immediately reduced=$reduce',
      (tester) async {
        await tester.pumpWidget(
          beuiTestApp(Builder(builder: promptInputDemo), reduce: reduce),
        );
        await tester.tap(find.byType(EditableText));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));
        final notice = find.text('Prompt sent to the selected model.');
        expect(notice, findsOneWidget);
        if (reduce) {
          expect(
            find.ancestor(
              of: notice,
              matching: find.byType(TweenAnimationBuilder<double>),
            ),
            findsNothing,
          );
        } else {
          await tester.pump();
          final translation = tester.widget<Transform>(
            find.ancestor(of: notice, matching: find.byType(Transform)).first,
          );
          expect(translation.transform.entry(1, 3), 3);
          await tester.pump(const Duration(milliseconds: 180));
          final settled = tester.widget<Transform>(
            find.ancestor(of: notice, matching: find.byType(Transform)).first,
          );
          expect(settled.transform.entry(1, 3), 0);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  setUpAll(() async {
    final font = FontLoader('Geist')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            await File('example/assets/fonts/Geist-Regular.ttf').readAsBytes(),
          ),
        ),
      );
    await font.load();
  });
  testWidgets('source 600px shell-fit threshold keeps the 728px docked rail', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const SizedBox(
          width: 728,
          height: 500,
          child: BeuiChatApp(
            sidebar: Text('Docked rail'),
            body: Text('Conversation'),
          ),
        ),
      ),
    );
    expect(find.text('Docked rail'), findsOneWidget);
    expect(find.text('Docked rail').hitTestable(), findsOneWidget);
    expect(find.text('Conversation'), findsOneWidget);
  });

  testWidgets(
    'orb silhouette samples match pinned Motion 12.43 glide generator',
    (tester) async {
      await tester.pumpWidget(beuiTestApp(const BeuiVoiceOrb(activity: 1)));
      final transforms = find.descendant(
        of: find.byType(BeuiVoiceOrb),
        matching: find.byType(Transform),
      );
      for (final sample in [
        (16, 0.10933376491222979),
        (16, 0.28612575220873226),
        (48, 0.6742231682553257),
        (80, 0.9151816723216841),
        (160, 0.994261968029108),
      ]) {
        await tester.pump(Duration(milliseconds: sample.$1));
        final level =
            (tester
                    .widgetList<Transform>(transforms)
                    .last
                    .transform
                    .entry(0, 0) -
                1) /
            0.04;
        expect(level, closeTo(sample.$2, 0.0002));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'orb springs a nonzero initial activity from the source rest silhouette',
    (tester) async {
      await tester.pumpWidget(beuiTestApp(const BeuiVoiceOrb(activity: 1)));
      final transforms = find.descendant(
        of: find.byType(BeuiVoiceOrb),
        matching: find.byType(Transform),
      );
      expect(
        tester.widgetList<Transform>(transforms).last.transform.entry(0, 0),
        1,
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        tester.widgetList<Transform>(transforms).last.transform.entry(0, 0),
        inExclusiveRange(1, 1.04),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        tester.widgetList<Transform>(transforms).last.transform.entry(0, 0),
        closeTo(1.04, 0.0001),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('each loading source example is isolated', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        Builder(
          builder: (context) =>
              loadingStatesDemo(context, example: 'reasoning-text'),
        ),
        fontFamily: 'Geist',
      ),
    );
    expect(find.byType(BeuiReasoningText), findsNWidgets(3));
    expect(find.byType(BeuiThinkingShimmer), findsNothing);
    await tester.pumpWidget(
      beuiTestApp(
        Builder(
          builder: (context) =>
              loadingStatesDemo(context, example: 'thinking-shimmer'),
        ),
      ),
    );
    expect(find.text('Thinking…'), findsOneWidget);
    expect(find.byType(BeuiReasoningText), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('avatar source example mounts at 650ms and 1550ms', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        Builder(
          builder: (context) => messageBubbleDemo(context, example: 'avatars'),
        ),
      ),
    );
    expect(
      find.text('Can you turn these notes into a launch update?'),
      findsOneWidget,
    );
    expect(
      find.text('Absolutely. I’ll keep it concise and lead with what changed.'),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 650));
    expect(
      find.text('Absolutely. I’ll keep it concise and lead with what changed.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(
      find.text(
        'Do you want the tone to feel more technical or more customer-facing?',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final example in [
    'reasoning-steps',
    'web-search',
    'tool-calls',
    'agent-trace',
    'mixed-activity',
  ]) {
    testWidgets('activity source $example reaches its terminal summary', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          Builder(
            builder: (context) => agentActivityDemo(context, example: example),
          ),
          reduce: true,
        ),
      );
      await tester.pump();
      final activity = tester.widget<BeuiAgentActivity>(
        find.byType(BeuiAgentActivity),
      );
      expect(activity.status, BeuiAgentActivityStatus.complete);
      expect(activity.items.length, switch (example) {
        'reasoning-steps' => 4,
        'web-search' => 1,
        'tool-calls' => 3,
        'agent-trace' => 5,
        _ => 6,
      });
      expect(find.text('Replay'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'chat-app streams at 92 cps, stops, resumes without duplicate turns',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(beuiTestApp(Builder(builder: chatAppDemo)));
      await tester.enterText(
        find.byType(EditableText),
        'Exercise the streaming phase',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 420));
      expect(find.text('Reviewing your direction'), findsNothing);
      await tester.pump(const Duration(milliseconds: 320));
      expect(find.text('I’ll keep the patch focused, '), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Stop generating'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Response stopped before it finished.'), findsOneWidget);
      await tester.ensureVisible(find.text('Continue generating'));
      await tester.tap(find.text('Continue generating'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2000));
      expect(
        find.text(
          'I’ll keep the patch focused, preserve the current checkout layout, and run the same validation path before preparing the release.',
        ),
        findsOneWidget,
      );
      expect(find.text('Exercise the streaming phase'), findsOneWidget);
      expect(
        tester.widget<BeuiPromptInput>(find.byType(BeuiPromptInput)).loading,
        false,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('source diff has five rows without an invented context gap', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(Builder(builder: fileDiffDemo)));
    await tester.pump(const Duration(milliseconds: 1700));
    final diff = tester.widget<BeuiFileDiff>(find.byType(BeuiFileDiff));
    expect(diff.lines.length, 5);
    expect(diff.lines.last.oldLine, 20);
    expect(diff.lines.last.newLine, 21);
    expect(find.textContaining('hidden lines'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('source questions show all three option descriptions', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(Builder(builder: approvalCardDemo)));
    expect(find.text('Ship a few polished pieces first.'), findsOneWidget);
    expect(find.text('Cover more ground with lighter depth.'), findsOneWidget);
    expect(
      find.text('Pour everything into a single showcase.'),
      findsOneWidget,
    );
    expect(find.byType(BeuiApprovalCard), findsOneWidget);
    await tester.tap(find.text('A focused starter set'));
    await tester.pump(const Duration(milliseconds: 240));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Which checks should block publishing?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final reduce in [false, true]) {
    testWidgets('sent prompt notice wins over later action, reduce=$reduce', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(Builder(builder: promptInputDemo), reduce: reduce),
      );
      await tester.tap(find.byType(EditableText));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.text('Prompt sent to the selected model.'), findsNothing);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Prompt sent to the selected model.'), findsOneWidget);
      tester.widget<BeuiPromptInput>(find.byType(BeuiPromptInput)).onAction!(
        'image',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Prompt sent to the selected model.'), findsOneWidget);
      expect(find.text('Attach image selected.'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('chat-app pending stop does not fabricate an assistant reply', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(beuiTestApp(Builder(builder: chatAppDemo)));
    await tester.enterText(
      find.byType(EditableText),
      'Round two actual composer',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Round two actual composer'), findsOneWidget);
    expect(find.text('Reviewing your direction'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 419));
    expect(find.text('Reviewing your direction'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Stop generating'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.text('Reviewing your direction'), findsNothing);
    expect(find.text('Response stopped before it finished.'), findsNothing);
    expect(
      tester.widget<BeuiPromptInput>(find.byType(BeuiPromptInput)).loading,
      false,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
