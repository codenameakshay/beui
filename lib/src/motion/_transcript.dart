/// Transcript announcement plumbing — one live region per conversation.
///
/// Package-internal. Not exported from `lib/beui.dart`.
///
/// A live region only announces when its label changes, so nesting several
/// `liveRegion` nodes with constant labels around the scroller, its streaming
/// responses, and its typing indicators would announce nothing while a reader
/// waits for the text arriving. This file is a single ambient announcer
/// instead:
///
/// * [BeuiTranscriptLiveRegion] owns exactly one live node and is mounted once,
///   by [BeuiMessageScroller], above the whole transcript.
/// * [BeuiTranscriptScope] publishes its `announce` callback to descendants.
/// * [BeuiStreamAnnouncer] turns a growing string into whole-sentence chunks,
///   throttled so a 16ms token cadence cannot flood the speech queue.
///
/// Components that stream text (today: `BeuiStreamingResponse`) push into the
/// scope when one is present and fall back to their own live region when it is
/// not, so a bare response outside a scroller still announces.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

/// Default gap between announcements.
///
/// Tokens arrive about every 16ms. Announcing per token is unusable, and pure
/// debouncing never fires at all while a stream is running, so this is a
/// *throttle with a trailing edge*: the first update arms a timer, and whatever
/// whole sentences have accumulated when it fires are spoken together.
///
/// 700ms is roughly the time a screen reader takes to speak a short sentence,
/// so the queue stays about one sentence deep rather than growing without
/// bound.
const Duration kBeuiAnnounceThrottle = Duration(milliseconds: 700);

/// Characters that end an announceable chunk.
///
/// A newline counts: streamed markdown puts list items and headings on their
/// own lines, and waiting for a full stop would hold a whole list back.
const String _kBoundaryChars = '.!?\n;:';

/// Turns a monotonically growing string into whole-sentence announcements.
///
/// Feed it the full text so far with [update] as often as you like; it emits
/// through `onChunk` at most once per [throttle], and only ever emits complete
/// sentences. Call [flush] when the stream reaches a terminal state to speak
/// the trailing fragment (a response that ends without punctuation still needs
/// to be read).
///
/// Not a widget and not tied to one: [BeuiTranscriptLiveRegion] and
/// `BeuiStreamingResponse` both drive one.
class BeuiStreamAnnouncer {
  /// Creates an announcer that reports chunks through [onChunk].
  BeuiStreamAnnouncer({
    required this.onChunk,
    this.throttle = kBeuiAnnounceThrottle,
  });

  /// Called with each announceable chunk. Never called with an empty string.
  final ValueChanged<String> onChunk;

  /// Minimum gap between chunks. See [kBeuiAnnounceThrottle].
  final Duration throttle;

  String _text = '';
  int _emitted = 0;
  // How far into `_text` a previous `_boundary()` scan already confirmed
  // there is no boundary character — so the next scan only has to look at
  // text appended since, instead of rescanning from `_emitted` every time.
  int _scanFrom = 0;
  Timer? _timer;
  bool _disposed = false;

  /// Feeds the full text produced so far.
  ///
  /// Shrinking text (a retry, or a different response reusing this announcer)
  /// resets the cursor rather than emitting the difference backwards.
  void update(String text) {
    if (_disposed) return;
    if (text == _text) return;
    if (!text.startsWith(_text)) {
      // Not an append — the content was replaced. Start over, and do not speak
      // the part the reader has already heard.
      _emitted = 0;
      _scanFrom = 0;
    }
    _text = text;
    _arm();
  }

  /// Speaks whatever is left, immediately, ignoring the throttle.
  ///
  /// Call on completion / error / stop. Safe to call repeatedly; it is a no-op
  /// once everything has been emitted.
  void flush() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    final rest = _text.substring(_emitted).trim();
    if (rest.isEmpty) {
      _emitted = _text.length;
      return;
    }
    _emitted = _text.length;
    onChunk(rest);
  }

  /// Drops pending work without emitting. Call from `dispose`.
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }

  void _arm() {
    if (_timer != null) return;
    if (_boundary() < 0) return;
    _timer = Timer(throttle, _fire);
  }

  void _fire() {
    _timer = null;
    if (_disposed) return;
    final end = _boundary();
    if (end < 0) return;
    final chunk = _text.substring(_emitted, end).trim();
    _emitted = end;
    if (chunk.isNotEmpty) onChunk(chunk);
    // More sentences may have landed while the throttle was running.
    _arm();
  }

  /// Index just past the last sentence terminator after [_emitted], or -1.
  ///
  /// Only the text appended since the previous no-match scan is rescanned —
  /// `_scanFrom` remembers that everything before it was already checked.
  int _boundary() {
    if (_scanFrom < _emitted) _scanFrom = _emitted;
    for (var i = _text.length - 1; i >= _scanFrom; i--) {
      if (_kBoundaryChars.contains(_text[i])) return i + 1;
    }
    _scanFrom = _text.length;
    return -1;
  }
}

/// Publishes a transcript's announcement sink to its descendants.
///
/// Descendants that stream text call [announce] instead of opening a live
/// region of their own. Presence of the scope is itself meaningful: it is how
/// `BeuiStreamingResponse.announce` resolves to false by default inside a
/// scroller and true outside one.
class BeuiTranscriptScope extends InheritedWidget {
  /// Creates a scope publishing [announce].
  const BeuiTranscriptScope({
    required this.announce,
    required super.child,
    super.key,
  });

  /// Speaks [text] through the transcript's single live region.
  final ValueChanged<String> announce;

  /// The nearest scope, registering a dependency.
  static BeuiTranscriptScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BeuiTranscriptScope>();

  /// Whether a scope exists above [context], *without* depending on it.
  ///
  /// Used for the `announce` default so a response does not rebuild merely
  /// because the transcript's announcer identity changed.
  static bool isPresent(BuildContext context) =>
      context.getInheritedWidgetOfExactType<BeuiTranscriptScope>() != null;

  @override
  bool updateShouldNotify(BeuiTranscriptScope oldWidget) =>
      announce != oldWidget.announce;
}

/// The transcript's one and only live region.
///
/// Wraps [child] in a [BeuiTranscriptScope] and renders a single zero-size
/// `Semantics(liveRegion: true)` node whose label is the most recent
/// announcement. Changing that label is what makes VoiceOver / TalkBack speak;
/// the node carries no visual weight and is excluded from the reading order
/// beyond its own announcement.
///
/// [label] names the region itself (`'Conversation'`) and is *static* — it is
/// deliberately kept off the live node, because a live region whose name
/// changes re-reads its whole subtree.
class BeuiTranscriptLiveRegion extends StatefulWidget {
  /// Creates the transcript live region around [child].
  const BeuiTranscriptLiveRegion({
    required this.child,
    required this.label,
    this.enabled = true,
    super.key,
  });

  /// The transcript.
  final Widget child;

  /// Static accessible name for the transcript container.
  final String label;

  /// When false the scope is still published (so descendants keep their
  /// `announce: false` default and stay quiet) but nothing is spoken.
  final bool enabled;

  @override
  State<BeuiTranscriptLiveRegion> createState() =>
      BeuiTranscriptLiveRegionState();
}

/// State for [BeuiTranscriptLiveRegion]. Public only so tests can drive
/// [announce] directly.
class BeuiTranscriptLiveRegionState extends State<BeuiTranscriptLiveRegion> {
  String _announcement = '';

  /// The text currently held by the live node. Visible for tests.
  @visibleForTesting
  String get announcement => _announcement;

  /// Speaks [text]. No-op when disabled or when nothing changed.
  void announce(String text) {
    if (!widget.enabled) return;
    final next = text.trim();
    if (next.isEmpty || next == _announcement) return;
    if (!mounted) return;
    setState(() => _announcement = next);
  }

  @override
  Widget build(BuildContext context) {
    return BeuiTranscriptScope(
      announce: announce,
      child: Semantics(
        container: true,
        label: widget.label,
        explicitChildNodes: true,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            // One node, one transparent pixel, no hit testing. Only its label
            // moves.
            //
            // 1×1 rather than 0×0 deliberately: Flutter drops semantics nodes
            // with an empty rect during tree compilation, so a zero-size live
            // region is silently never delivered to the platform. One pixel in
            // the corner of a transcript is not perceptible and is the
            // difference between announcing and not.
            if (_announcement.isNotEmpty)
              Positioned(
                left: 0,
                top: 0,
                width: 1,
                height: 1,
                child: IgnorePointer(
                  child: Semantics(
                    liveRegion: true,
                    label: _announcement,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
