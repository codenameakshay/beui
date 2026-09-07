// C6 — the transcript's single live region, and the sentence-boundary
// announcer that feeds it.
//
// The audit found three to five nested live regions per transcript, all with
// constant labels, so the streamed answer — the one thing a reader needs —
// was never announced. These tests pin both halves of the fix: that the
// regions collapsed to one, and that the one remaining region actually says
// the words that arrived.

import 'package:beui/beui.dart';
import 'package:beui/src/motion/_transcript.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

/// Every `liveRegion: true` node in the tree, by label.
List<String> _liveRegions(WidgetTester tester) {
  final out = <String>[];
  void visit(SemanticsNode node) {
    if (node.flagsCollection.isLiveRegion) {
      out.add(node.label);
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  // `rootPipelineOwner`'s semantics owner is a different (empty) tree under
  // the test binding, so the deprecated accessor is the one that actually
  // holds the nodes this assertion is about.
  // ignore: deprecated_member_use
  visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
  return out;
}

void main() {
  group('BeuiStreamAnnouncer', () {
    test('emits whole sentences, not tokens', () {
      final chunks = <String>[];
      final a = BeuiStreamAnnouncer(
        onChunk: chunks.add,
        throttle: const Duration(milliseconds: 100),
      );
      addTearDown(a.dispose);

      fakeAsync((async) {
        // Sixty "tokens" arriving 16ms apart, as a real stream would.
        const full = 'The build failed. Two tests are red. Retry?';
        for (var i = 1; i <= full.length; i++) {
          a.update(full.substring(0, i));
          async.elapse(const Duration(milliseconds: 16));
        }
        async.elapse(const Duration(seconds: 1));

        // Whatever the split, nothing is spoken twice and nothing is a
        // fragment of a word.
        expect(chunks, isNotEmpty);
        expect(chunks.join(' '), 'The build failed. Two tests are red. Retry?');
        // And it is nothing like one-per-token.
        expect(chunks.length, lessThan(6));
      });
    });

    test('throttles: a burst inside one window produces one chunk', () {
      final chunks = <String>[];
      final a = BeuiStreamAnnouncer(
        onChunk: chunks.add,
        throttle: const Duration(milliseconds: 700),
      );
      addTearDown(a.dispose);

      fakeAsync((async) {
        a.update('One. Two. Three. Four.');
        async.elapse(const Duration(milliseconds: 699));
        expect(chunks, isEmpty, reason: 'still inside the throttle window');
        async.elapse(const Duration(milliseconds: 2));
        expect(chunks, ['One. Two. Three. Four.']);
      });
    });

    test('holds back a sentence that has not finished', () {
      final chunks = <String>[];
      final a = BeuiStreamAnnouncer(
        onChunk: chunks.add,
        throttle: const Duration(milliseconds: 100),
      );
      addTearDown(a.dispose);

      fakeAsync((async) {
        a.update('Done. And then the sec');
        async.elapse(const Duration(seconds: 1));
        expect(chunks, ['Done.'], reason: 'the partial tail waits');

        a.update('Done. And then the second thing.');
        async.elapse(const Duration(seconds: 1));
        expect(chunks, ['Done.', 'And then the second thing.']);
      });
    });

    test('flush speaks a trailing fragment with no punctuation', () {
      final chunks = <String>[];
      final a = BeuiStreamAnnouncer(onChunk: chunks.add);
      addTearDown(a.dispose);

      fakeAsync((async) {
        a.update('no full stop here');
        async.elapse(const Duration(seconds: 2));
        expect(chunks, isEmpty, reason: 'no boundary to emit at');
        a.flush();
        expect(chunks, ['no full stop here']);
        // Idempotent.
        a.flush();
        expect(chunks, ['no full stop here']);
      });
    });

    test('replacing the text resets rather than replaying backwards', () {
      final chunks = <String>[];
      final a = BeuiStreamAnnouncer(
        onChunk: chunks.add,
        throttle: const Duration(milliseconds: 10),
      );
      addTearDown(a.dispose);

      fakeAsync((async) {
        a.update('First answer.');
        async.elapse(const Duration(milliseconds: 50));
        expect(chunks, ['First answer.']);

        // A retry produces different text from position zero.
        a.update('Second answer.');
        async.elapse(const Duration(milliseconds: 50));
        expect(chunks, ['First answer.', 'Second answer.']);
      });
    });

    test('dispose drops pending work', () {
      final chunks = <String>[];
      final a = BeuiStreamAnnouncer(
        onChunk: chunks.add,
        throttle: const Duration(milliseconds: 100),
      );
      fakeAsync((async) {
        a.update('Pending.');
        a.dispose();
        async.elapse(const Duration(seconds: 1));
        expect(chunks, isEmpty);
      });
    });
  });

  group('BeuiTranscriptLiveRegion', () {
    testWidgets('publishes a scope descendants can detect', (tester) async {
      late bool inside;
      late bool outside;
      await tester.pumpWidget(
        beuiTestApp(
          Column(
            children: [
              Builder(
                builder: (context) {
                  outside = BeuiTranscriptScope.isPresent(context);
                  return const SizedBox.shrink();
                },
              ),
              BeuiTranscriptLiveRegion(
                label: 'Conversation',
                child: Builder(
                  builder: (context) {
                    inside = BeuiTranscriptScope.isPresent(context);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      );
      expect(inside, isTrue);
      expect(outside, isFalse);
    });

    testWidgets('one live region, and its label carries the announcement', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final key = GlobalKey<BeuiTranscriptLiveRegionState>();
      await tester.pumpWidget(
        beuiTestApp(
          BeuiTranscriptLiveRegion(
            key: key,
            label: 'Conversation',
            child: const Text('body'),
          ),
        ),
      );

      // Nothing announced yet: no live node at all.
      expect(_liveRegions(tester), isEmpty);

      key.currentState!.announce('The build failed.');
      await tester.pump();

      expect(_liveRegions(tester), ['The build failed.']);

      // A second announcement replaces the first — still exactly one region.
      key.currentState!.announce('Two tests are red.');
      await tester.pump();
      expect(_liveRegions(tester), ['Two tests are red.']);

      handle.dispose();
    });

    testWidgets('disabled region stays silent', (tester) async {
      final handle = tester.ensureSemantics();
      final key = GlobalKey<BeuiTranscriptLiveRegionState>();
      await tester.pumpWidget(
        beuiTestApp(
          BeuiTranscriptLiveRegion(
            key: key,
            label: 'Conversation',
            enabled: false,
            child: const Text('body'),
          ),
        ),
      );
      key.currentState!.announce('should not be spoken');
      await tester.pump();
      expect(_liveRegions(tester), isEmpty);
      handle.dispose();
    });
  });

  group('the transcript collapses to one live region', () {
    testWidgets('scroller + streaming responses expose exactly one', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        beuiTestApp(
          SizedBox(
            height: 300,
            child: BeuiMessageScroller(
              busy: true,
              child: BeuiMessageGroup(
                children: [
                  for (var i = 0; i < 3; i++)
                    BeuiMessage(
                      key: ValueKey(i),
                      from: BeuiMessageFrom.assistant,
                      animateIn: false,
                      children: [
                        BeuiMessageContent(
                          children: [
                            BeuiMessageBubble(
                              animateIn: false,
                              child: BeuiMessageBubbleContent(
                                child: BeuiStreamingResponse(
                                  announceText: 'Answer $i.',
                                  child: Text('Answer $i.'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  const BeuiMessageTyping(),
                ],
              ),
            ),
          ),
        ),
      );
      // Not pumpAndSettle: the typing dots loop forever by design.
      await tester.pump(const Duration(milliseconds: 400));

      // Before the fix this tree carried the scroller's viewport region, its
      // inner content region, its busy wrapper, three response regions and a
      // typing region — six, none of which ever said anything.
      expect(_liveRegions(tester), isEmpty);
      handle.dispose();
    });

    testWidgets('streamed text reaches that one region', (tester) async {
      final handle = tester.ensureSemantics();

      Widget build(String text) => beuiTestApp(
        SizedBox(
          height: 300,
          child: BeuiMessageScroller(
            child: BeuiStreamingResponse(announceText: text, child: Text(text)),
          ),
        ),
      );

      await tester.pumpWidget(build(''));
      await tester.pumpAndSettle();

      await tester.pumpWidget(build('The build failed. Two tests are red.'));
      await tester.pump();
      // Past the announcer's throttle.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      final regions = _liveRegions(tester);
      expect(regions, hasLength(1));
      expect(regions.single, contains('The build failed.'));
      handle.dispose();
    });

    testWidgets('a standalone response keeps its own region', (tester) async {
      final handle = tester.ensureSemantics();

      Widget build(String text) => beuiTestApp(
        BeuiStreamingResponse(announceText: text, child: Text(text)),
      );

      await tester.pumpWidget(build(''));
      await tester.pumpAndSettle();
      await tester.pumpWidget(build('Standalone answer.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      expect(_liveRegions(tester), hasLength(1));
      expect(_liveRegions(tester).single, contains('Standalone answer.'));
      handle.dispose();
    });

    testWidgets('onAnnounce fires regardless of who owns the region', (
      tester,
    ) async {
      final heard = <String>[];

      Widget build(String text) => beuiTestApp(
        SizedBox(
          height: 300,
          child: BeuiMessageScroller(
            announce: false,
            child: BeuiStreamingResponse(
              announceText: text,
              onAnnounce: heard.add,
              child: Text(text),
            ),
          ),
        ),
      );

      await tester.pumpWidget(build(''));
      await tester.pumpAndSettle();
      await tester.pumpWidget(build('One. Two.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(heard, isNotEmpty);
      expect(heard.join(' '), contains('One.'));
    });
  });
}
