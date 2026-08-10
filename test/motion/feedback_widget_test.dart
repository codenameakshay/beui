import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps a [BeuiFeedbackWidget] in a themed, bounded corner box. [reduce] forces
/// reduced motion.
Widget _app({
  FutureOr<void> Function(BeuiFeedbackData)? onSubmit,
  bool reduce = false,
}) {
  // A device-frame surface tall enough for the open form to render fully (the
  // component anchors itself to a corner and grows upward out of it).
  Widget child = Center(
    child: SizedBox(
      width: 380,
      height: 460,
      child: Stack(
        children: [
          Positioned.fill(child: BeuiFeedbackWidget(onSubmit: onSubmit)),
        ],
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

Finder _trigger() => find.byIcon(LucideIcons.message_square);

void main() {
  group('BeuiFeedbackWidget interaction', () {
    testWidgets('tap trigger morphs into the form', (tester) async {
      await tester.pumpWidget(_app());
      expect(_trigger(), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(_trigger());
      await tester.pump(const Duration(milliseconds: 500)); // morph + focus

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('submit calls onSubmit and shows the success view', (
      tester,
    ) async {
      String? received;
      await tester.pumpWidget(
        _app(onSubmit: (data) => received = data.message),
      );

      await tester.tap(_trigger());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.byType(TextField), 'Love it');
      await tester.pump();

      await tester.tap(find.byType(BeuiStatefulButton));
      await tester.pump(); // sending → await resolves
      await tester.pump(const Duration(milliseconds: 600)); // sent view

      expect(received, 'Love it');
      expect(find.text('Thanks!'), findsOneWidget);
    });

    testWidgets('empty message does not submit', (tester) async {
      var called = false;
      await tester.pumpWidget(_app(onSubmit: (_) => called = true));

      await tester.tap(_trigger());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byType(BeuiStatefulButton), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));

      expect(called, isFalse);
      expect(find.text('Thanks!'), findsNothing);
    });

    testWidgets('a thrown submit routes to the retry view', (tester) async {
      await tester.pumpWidget(_app(onSubmit: (_) => throw StateError('nope')));

      await tester.tap(_trigger());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.byType(TextField), 'Broken');
      await tester.pump();

      await tester.tap(find.byType(BeuiStatefulButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('tapping outside closes the panel', (tester) async {
      await tester.pumpWidget(_app());

      await tester.tap(_trigger());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextField), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(TextField), findsNothing);
      expect(_trigger(), findsOneWidget);
    });

    testWidgets('Escape closes the panel', (tester) async {
      await tester.pumpWidget(_app());

      await tester.tap(_trigger());
      await tester.pump(const Duration(milliseconds: 500));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('success view auto-dismisses back to the trigger', (
      tester,
    ) async {
      await tester.pumpWidget(_app(onSubmit: (_) {}));

      await tester.tap(_trigger());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.byType(TextField), 'Done');
      await tester.pump();
      await tester.tap(find.byType(BeuiStatefulButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Thanks!'), findsOneWidget);

      // SUCCESS_DURATION_MS (1.6s) + close morph.
      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Thanks!'), findsNothing);
      expect(_trigger(), findsOneWidget);
    });
  });

  group('BeuiFeedbackWidget motion fidelity', () {
    testWidgets('content morph blurs under normal motion', (tester) async {
      // The open (trigger→form) blur resolves within a single frame, so exercise
      // the inner view swap (form → sent), which morphs with a 4px blur-up over
      // ~240ms and is reliably observable mid-transition.
      await tester.pumpWidget(_app(onSubmit: (_) {}));
      await tester.tap(_trigger());
      await tester.pump(const Duration(milliseconds: 500)); // form shown
      await tester.enterText(find.byType(TextField), 'Nice');
      await tester.pump();

      await tester.tap(find.byType(BeuiStatefulButton));
      await tester.pump(); // sending → onSubmit resolves, view begins swapping
      await tester.pump(const Duration(milliseconds: 30)); // mid view-swap

      expect(find.byType(ImageFiltered), findsWidgets);
      expect(find.byType(AnimatedSize), findsWidgets);

      await tester.pump(const Duration(milliseconds: 600)); // land on sent view
    });

    testWidgets('reduced motion drops the morph blur', (tester) async {
      await tester.pumpWidget(_app(reduce: true));
      await tester.tap(_trigger());
      await tester.pump(const Duration(milliseconds: 100)); // mid-morph

      expect(find.byType(ImageFiltered), findsNothing);
    });

    testWidgets('reduced motion still reaches the success view', (
      tester,
    ) async {
      await tester.pumpWidget(_app(reduce: true, onSubmit: (_) {}));

      await tester.tap(_trigger());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'Quick');
      await tester.pump();
      await tester.tap(find.byType(BeuiStatefulButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Thanks!'), findsOneWidget);
    });
  });

  testWidgets('rest-state golden (collapsed trigger)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BeuiTextTheme.trackingNormal(
          ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: const ValueKey('feedback-box'),
              width: 200,
              height: 160,
              child: const Stack(
                children: [Positioned.fill(child: BeuiFeedbackWidget())],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('feedback-box')),
      matchesGoldenFile('goldens/beui_feedback_widget.png'),
    );
  });
}
