import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

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
      await tester.pumpWidget(beuiTestApp(const BeuiThinkingShimmer()));
      await tester.pump();
      expect(find.text('Thinking…'), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
      expect(find.byType(BeuiTextShimmer), findsOneWidget);
    });

    testWidgets('accepts a custom message and duration', (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiThinkingShimmer(
            text: 'Reviewing your direction',
            duration: Duration(seconds: 2),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Reviewing your direction'), findsOneWidget);
    });

    testWidgets('forwards text, duration and medium weight to the shimmer', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiThinkingShimmer(
            text: 'Reviewing',
            duration: Duration(seconds: 2),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w300),
          ),
        ),
      );
      await tester.pump();
      final shimmer = tester.widget<BeuiTextShimmer>(
        find.byType(BeuiTextShimmer),
      );
      expect(shimmer.text, 'Reviewing');
      expect(shimmer.duration, const Duration(seconds: 2));
      // The caller's size survives; the weight is forced to the source's medium.
      expect(shimmer.style?.fontSize, 17);
      expect(shimmer.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('reduced motion holds a static highlight', (tester) async {
      await tester.pumpWidget(
        beuiTestApp(const BeuiThinkingShimmer(), reduce: true),
      );
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
        beuiTestApp(
          const BeuiAgentProgress(label: 'Searching', elapsedSeconds: 12.3),
        ),
      );
      await tester.pump();
      expect(find.text('Searching'), findsOneWidget);
      expect(find.text('12.3s'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('formats multi-minute controlled elapsed', (tester) async {
      await tester.pumpWidget(
        beuiTestApp(const BeuiAgentProgress(elapsedSeconds: 151.6)),
      );
      await tester.pump();
      expect(find.text('Churning'), findsOneWidget);
      expect(find.text('2m 31.6s'), findsOneWidget);
    });

    testWidgets('internal timer advances while running', (tester) async {
      // Regression: the timer used to tick on the event loop but read the wall
      // clock (`DateTime.now()`), so under flutter_test's fake async it fired
      // on schedule and reported no elapsed time at all — the counter froze at
      // initialSeconds. Reading `clock.now()` puts both on the same clock, so
      // the displayed value is exact and consumers can drive it in tests.
      await tester.pumpWidget(
        beuiTestApp(const BeuiAgentProgress(initialSeconds: 1.0)),
      );
      await tester.pump();
      expect(find.text('1.0s'), findsOneWidget);

      // Two ticks (100ms each) land inside the window; the frame renders the
      // value from the last one.
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('1.2s'), findsOneWidget);

      // Five more ticks; elapsed accumulates off _startedAt, so it neither
      // drifts nor resets across pumps.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('1.7s'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('paused running freezes the initial value', (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiAgentProgress(initialSeconds: 5.0, running: false),
        ),
      );
      await tester.pump();
      expect(find.text('5.0s'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('5.0s'), findsOneWidget);
    });

    testWidgets('pausing and resuming does not count the paused span', (
      tester,
    ) async {
      // Regression: `running: false` cancelled the timer but left the start
      // instant receding, so resuming jumped the counter forward by however
      // long the pause lasted. The start instant is now re-anchored on every
      // resume, off the seconds already counted.
      Widget build({required bool running}) =>
          beuiTestApp(BeuiAgentProgress(initialSeconds: 1.0, running: running));

      await tester.pumpWidget(build(running: true));
      await tester.pump();
      expect(find.text('1.0s'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('1.5s'), findsOneWidget);

      // Paused: a full second goes by on the clock, none of it counted.
      await tester.pumpWidget(build(running: false));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1.5s'), findsOneWidget);

      // Resumed: counting picks up from 1.5s, not from 2.5s.
      await tester.pumpWidget(build(running: true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('1.8s'), findsOneWidget);
    });

    testWidgets('controlled elapsedSeconds overrides the internal timer', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiAgentProgress(elapsedSeconds: 3, initialSeconds: 40),
        ),
      );
      await tester.pump();
      expect(find.text('3.0s'), findsOneWidget);
      // Running clock, but the controlled value wins on every frame.
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('3.0s'), findsOneWidget);
      expect(find.textContaining('40'), findsNothing);
    });

    testWidgets('exposes an accessible status label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        beuiTestApp(const BeuiAgentProgress(label: 'Indexing')),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Indexing, in progress'), findsOneWidget);
      handle.dispose();
    });
  });

  group('BeuiReasoningText', () {
    testWidgets('renders default phrase and ascii-line loader', (tester) async {
      await tester.pumpWidget(beuiTestApp(const BeuiReasoningText()));
      await tester.pump();
      // Invisible sizer + visible phrase both contain "Thinking…".
      expect(find.textContaining('Thinking'), findsWidgets);
      expect(find.byType(BeuiLoader), findsOneWidget);
      expect(find.byType(BeuiTextShimmer), findsWidgets);
    });

    testWidgets('cycles phrases on the given interval', (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
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

    testWidgets('reduced motion advances without scrambling glyphs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const BeuiReasoningText(
            phrases: ['Alpha', 'Bravo'],
            variant: BeuiReasoningTextVariant.scramble,
            interval: Duration(milliseconds: 600),
          ),
          reduce: true,
        ),
      );
      await tester.pump();
      expect(
        tester.widget<BeuiTextShimmer>(find.byType(BeuiTextShimmer)).text,
        'Alpha…',
      );

      // Only 50ms elapses after the phrase changes. Reduced motion should
      // show the new phrase immediately instead of entering a scramble pass.
      await tester.pump(const Duration(milliseconds: 650));
      expect(
        tester.widget<BeuiTextShimmer>(find.byType(BeuiTextShimmer)).text,
        'Bravo…',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('swap cross-fades the outgoing and incoming phrase', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiReasoningText(
            phrases: ['Alpha', 'Bravo', 'Charlie-the-longest'],
            variant: BeuiReasoningTextVariant.swap,
            interval: Duration(milliseconds: 800),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Alpha'), findsOneWidget);
      expect(find.textContaining('Bravo'), findsNothing);

      // Mid-swap (200ms window): both phrases are on screen at once.
      await tester.pump(const Duration(milliseconds: 810));
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.textContaining('Alpha'), findsOneWidget);
      expect(find.textContaining('Bravo'), findsOneWidget);

      // Settled: the outgoing phrase is gone.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('Alpha'), findsNothing);
      expect(find.textContaining('Bravo'), findsOneWidget);
    });

    testWidgets('scramble mutates glyphs before settling on the phrase', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiReasoningText(
            phrases: ['Alpha', 'Bravo', 'Charlie-the-longest'],
            variant: BeuiReasoningTextVariant.scramble,
            interval: Duration(milliseconds: 800),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Alpha…'), findsOneWidget);

      // Phrase flips, glyphs churn: the target is not readable yet.
      await tester.pump(const Duration(milliseconds: 810));
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('Bravo…'), findsNothing);

      // Settles left-to-right onto the target within its 420ms window.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Bravo…'), findsOneWidget);
    });

    testWidgets('scramble stops its ticker on the ticker clock', (
      tester,
    ) async {
      // Regression: the scramble ticker used to check completion against the
      // wall clock (`DateTime.now()`) while ticking on fake time, so under
      // flutter_test it never reached its stop condition and leaked a live
      // Ticker for the rest of the test. `pumpAndSettle` can't be the probe
      // here — BeuiTextShimmer and BeuiLoader both repeat() forever by design,
      // so a frame is always scheduled — so count transient callbacks instead.
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiReasoningText(
            phrases: ['Alpha', 'Bravo'],
            variant: BeuiReasoningTextVariant.scramble,
            interval: Duration(milliseconds: 800),
          ),
        ),
      );
      await tester.pump();
      // Shimmer + loader loops, no scramble in flight.
      final idle = tester.binding.transientCallbackCount;

      // Phrase flips: the scramble ticker joins the idle loops.
      await tester.pump(const Duration(milliseconds: 810));
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.binding.transientCallbackCount, idle + 1);

      // Past the 420ms scramble window the ticker stops and disposes itself.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Bravo…'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, idle);
    });

    testWidgets('custom indicator replaces the default loader', (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
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
      await tester.pumpWidget(
        beuiTestApp(const BeuiReasoningText(phrases: [])),
      );
      await tester.pump();
      expect(find.textContaining('Thinking'), findsWidgets);
    });

    testWidgets('exposes the active phrase to semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        beuiTestApp(const BeuiReasoningText(phrases: ['Forming a response'])),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Forming a response'), findsOneWidget);
      handle.dispose();
    });
  });
}
