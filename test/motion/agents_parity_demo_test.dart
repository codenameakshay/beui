import 'package:beui/beui.dart';
import 'package:beui/src/motion/voice_orb.dart' show beuiVoiceOrbErrorKey;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/voice_orb_demo.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/agents_chat_preview.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/prompt_input_demo.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/image_generation_demo.dart';
import '../support.dart';

void main() {
  testWidgets('image preview follows the source cycle and replay', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(Builder(builder: imageGenerationDemo)));
    expect(find.byType(BeuiImageGeneration), findsOneWidget);
    expect(find.text('Waiting to generate'), findsOneWidget);
    expect(find.text('Statuses'), findsNothing);
    expect(find.bySemanticsLabel('Cancel generation'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Generating image'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text('Refining details'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2200));
    expect(find.text('Image ready'), findsOneWidget);
    await tester.tap(find.text('Replay'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Waiting to generate'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('prompt preview starts without unsourced attachments', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(Builder(builder: promptInputDemo)));
    expect(find.text('architecture.png'), findsNothing);
    expect(find.text('review-notes.md'), findsNothing);
    expect(find.text('bundle.zip'), findsNothing);
    expect(
      find.text(
        'Review the current implementation and suggest the next improvement.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shared chat preview hides completion actions like source', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(beuiTestApp(const ChatPreview()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text('Start with the smallest workflow that still feels complete.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Copy response'), findsNothing);
    expect(find.bySemanticsLabel('Retry'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  testWidgets('reduced-motion chat delivers its full reply without a delay', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(const ChatPreview(), reduce: true));
    await tester.enterText(find.byType(EditableText), 'Release plan');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text(kChatPreviewDefaultReply), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('chat prepares for 420ms then streams once into its answer', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(const ChatPreview()));
    await tester.enterText(find.byType(EditableText), 'Release plan');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.byKey(const ValueKey('pending-assistant')), findsOneWidget);
    expect(find.byKey(const ValueKey('sent-assistant-0')), findsNothing);
    await tester.pump(const Duration(milliseconds: 419));
    expect(find.byKey(const ValueKey('pending-assistant')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(const ValueKey('pending-assistant')), findsNothing);
    expect(find.byKey(const ValueKey('sent-assistant-0')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('I’d include co'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2200));
    expect(find.text(kChatPreviewDefaultReply), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final viewport in [
    (width: 390.0, orbSize: 256.0),
    (width: 639.0, orbSize: 256.0),
    (width: 640.0, orbSize: 288.0),
    (width: 1440.0, orbSize: 288.0),
  ]) {
    testWidgets('voice preview matches source at ${viewport.width}px', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(viewport.width, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        beuiTestApp(Builder(builder: voiceOrbDemo), reduce: true),
      );
      expect(find.byType(BeuiVoiceOrb), findsOneWidget);
      expect(
        tester.getSize(find.byType(BeuiVoiceOrb)),
        Size.square(viewport.orbSize),
      );
      expect(find.text('CUSTOM PIGMENTS'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('orb failure stays stationary at full activity', (tester) async {
    BeuiVoiceOrb.debugLoadError = StateError('GPU unavailable');
    addTearDown(() => BeuiVoiceOrb.debugLoadError = null);
    await tester.pumpWidget(beuiTestApp(const BeuiVoiceOrb(activity: 1)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final orb = tester.getRect(find.byType(BeuiVoiceOrb));
    final fallback = tester.getRect(find.byKey(beuiVoiceOrbErrorKey));
    expect(find.text('Orb rendering unavailable'), findsOneWidget);
    expect(fallback, orb);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
