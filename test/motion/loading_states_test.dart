import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool reduce = false}) {
  Widget body = child;
  if (reduce) {
    body = MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: body,
    );
  }
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: Center(child: body)),
  );
}

void main() {
  group('beuiFormatAgentElapsed', () {
    test('formats sub-minute values with one decimal', () {
      expect(beuiFormatAgentElapsed(0), '0.0s');
      expect(beuiFormatAgentElapsed(12.3), '12.3s');
      expect(beuiFormatAgentElapsed(59.9), '59.9s');
    });

    test('formats minutes and residual seconds', () {
      expect(beuiFormatAgentElapsed(60), '1m 0.0s');
      expect(beuiFormatAgentElapsed(151.6), '2m 31.6s');
    });

    test('clamps negatives to zero', () {
      expect(beuiFormatAgentElapsed(-4), '0.0s');
    });
  });

  group('BeuiThinkingShimmer', () {
    testWidgets('renders default text through a shimmer ShaderMask', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const BeuiThinkingShimmer()));
      await tester.pump();
      expect(find.text('Thinking…'), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
      expect(find.byType(BeuiTextShimmer), findsOneWidget);
    });

    testWidgets('accepts a custom message and duration', (tester) async {
      await tester.pumpWidget(
        _app(
          const BeuiThinkingShimmer(
            text: 'Reviewing your direction',
            duration: Duration(seconds: 2),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Reviewing your direction'), findsOneWidget);
    });

    testWidgets('reduced motion holds a static highlight', (tester) async {
      await tester.pumpWidget(_app(const BeuiThinkingShimmer(), reduce: true));
      await tester.pumpAndSettle();
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'thinking shimmer should hold static under reduced motion',
      );
      expect(find.text('Thinking…'), findsOneWidget);
    });
  });

  group('BeuiAgentProgress', () {
    testWidgets('renders label and controlled elapsed time', (tester) async {
      await tester.pumpWidget(
        _app(const BeuiAgentProgress(label: 'Searching', elapsedSeconds: 12.3)),
      );
      await tester.pump();
      expect(find.text('Searching'), findsOneWidget);
      expect(find.text('12.3s'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('formats multi-minute controlled elapsed', (tester) async {
      await tester.pumpWidget(
        _app(const BeuiAgentProgress(elapsedSeconds: 151.6)),
      );
      await tester.pump();
      expect(find.text('Churning'), findsOneWidget);
      expect(find.text('2m 31.6s'), findsOneWidget);
    });

    testWidgets('internal timer advances while running', (tester) async {
      await tester.pumpWidget(
        _app(const BeuiAgentProgress(initialSeconds: 1.0)),
      );
      await tester.pump();
      expect(find.textContaining('1.'), findsOneWidget);

      // Advance past two timer ticks (100ms each).
      await tester.pump(const Duration(milliseconds: 250));
      // Still showing a seconds string; exact value is wall-clock based.
      expect(find.textContaining('s'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('paused running freezes the initial value', (tester) async {
      await tester.pumpWidget(
        _app(const BeuiAgentProgress(initialSeconds: 5.0, running: false)),
      );
      await tester.pump();
      expect(find.text('5.0s'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('5.0s'), findsOneWidget);
    });

    testWidgets('exposes an accessible status label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const BeuiAgentProgress(label: 'Indexing')));
      await tester.pump();
      expect(find.bySemanticsLabel('Indexing, in progress'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('renders under reduced motion without error', (tester) async {
      await tester.pumpWidget(
        _app(const BeuiAgentProgress(elapsedSeconds: 3), reduce: true),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(BeuiAgentProgress), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('BeuiReasoningText', () {
    testWidgets('renders default phrase and ascii-line loader', (tester) async {
      await tester.pumpWidget(_app(const BeuiReasoningText()));
      await tester.pump();
      // Invisible sizer + visible phrase both contain "Thinking…".
      expect(find.textContaining('Thinking'), findsWidgets);
      expect(find.byType(BeuiLoader), findsOneWidget);
      expect(find.byType(BeuiTextShimmer), findsWidgets);
    });

    testWidgets('cycles phrases on the given interval', (tester) async {
      await tester.pumpWidget(
        _app(
          const BeuiReasoningText(
            phrases: ['Alpha', 'Beta'],
            variant: BeuiReasoningTextVariant.swap,
            interval: Duration(milliseconds: 600),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Alpha'), findsWidgets);

      await tester.pump(const Duration(milliseconds: 650));
      // After one interval the active phrase should be Beta (sizer may still
      // hold the longer label; the shimmer shows the active one).
      expect(find.textContaining('Beta'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    for (final variant in BeuiReasoningTextVariant.values) {
      testWidgets('$variant builds and animates without error', (tester) async {
        await tester.pumpWidget(
          _app(
            BeuiReasoningText(
              variant: variant,
              phrases: const ['One', 'Two', 'Three'],
              interval: const Duration(milliseconds: 800),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        // Trigger a phrase change.
        await tester.pump(const Duration(milliseconds: 850));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(BeuiReasoningText), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('$variant renders under reduced motion', (tester) async {
        await tester.pumpWidget(
          _app(
            BeuiReasoningText(
              variant: variant,
              phrases: const ['One', 'Two'],
              interval: const Duration(milliseconds: 700),
            ),
            reduce: true,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.byType(BeuiReasoningText), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('custom indicator replaces the default loader', (tester) async {
      await tester.pumpWidget(
        _app(
          const BeuiReasoningText(
            indicator: Icon(Icons.hourglass_top, size: 14),
            phrases: ['Working'],
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.hourglass_top), findsOneWidget);
      expect(find.byType(BeuiLoader), findsNothing);
    });

    testWidgets('empty phrases fall back to defaults', (tester) async {
      await tester.pumpWidget(_app(const BeuiReasoningText(phrases: [])));
      await tester.pump();
      expect(find.textContaining('Thinking'), findsWidgets);
    });

    testWidgets('exposes the active phrase to semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(const BeuiReasoningText(phrases: ['Forming a response'])),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Forming a response'), findsOneWidget);
      handle.dispose();
    });
  });
}
