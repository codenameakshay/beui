import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Gallery route for [BeuiStreamingResponse] — character-streamed response
/// with completion actions, sources disclosure, and a Replay control. Mirrors
/// the source `streaming-response.preview.tsx`.
Widget streamingResponseDemo(BuildContext context) =>
    const _StreamingResponseDemo();

// ---------------------------------------------------------------------------
// Stream script (source PIECES / RESPONSE_MARKDOWN)
// ---------------------------------------------------------------------------

const _pieces = <String>[
  'A streaming response can link directly to ',
  "Motion's React guide",
  ' while the rest of the answer continues to arrive.',
  'The same response can preserve useful structure:',
  'Links stay interactive as nearby text streams',
  'Lists keep their spacing and hierarchy',
  'Code remains readable without shifting the response',
  'Set ',
  'aria-busy',
  ' while new content is still arriving.',
  'const status = complete ? "ready" : "streaming";',
];

final _starts = () {
  final starts = <int>[];
  var total = 0;
  for (final p in _pieces) {
    starts.add(total);
    total += p.length;
  }
  return starts;
}();

final _responseLength = _pieces.fold<int>(0, (t, p) => t + p.length);

const _responseMarkdown =
    r'''A streaming response can link directly to [Motion's React guide](https://motion.dev/docs/react) while the rest of the answer continues to arrive.

The same response can preserve useful structure:

- Links stay interactive as nearby text streams
- Lists keep their spacing and hierarchy
- Code remains readable without shifting the response

Set `aria-busy` while new content is still arriving.

```tsx
const status = complete ? "ready" : "streaming";
```''';

const _charactersPerSecond = 110;

const _sources = <BeuiCitationItem>[
  BeuiCitationItem(
    id: 'motion-react',
    title: Text('Motion for React'),
    domain: Text('motion.dev'),
    url: 'https://motion.dev/docs/react',
  ),
  BeuiCitationItem(
    id: 'aria-busy',
    title: Text('ARIA live regions'),
    domain: Text('developer.mozilla.org'),
    url:
        'https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-busy',
  ),
  BeuiCitationItem(
    id: 'react-rendering',
    title: Text('Rendering elements'),
    domain: Text('react.dev'),
    url: 'https://react.dev/learn/conditional-rendering',
  ),
];

// ---------------------------------------------------------------------------
// Shell
// ---------------------------------------------------------------------------

class _StreamingResponseDemo extends StatefulWidget {
  const _StreamingResponseDemo();

  @override
  State<_StreamingResponseDemo> createState() => _StreamingResponseDemoState();
}

/// How the demonstrated stream ends.
///
/// C20/C32: `error` was reachable only from a unit test and `stopped` did not
/// exist, so the gallery — the de-facto documentation — showed a response that
/// could only ever succeed, while the demo copy talked about recovery.
enum _Outcome {
  /// Streams to the end and completes.
  complete,

  /// Fails partway through: destructive notice plus an inline retry.
  error,

  /// The reader stops it: neutral notice plus an inline continue.
  stopped,
}

class _StreamingResponseDemoState extends State<_StreamingResponseDemo> {
  int _run = 0;
  _Outcome _outcome = _Outcome.complete;

  void _replay([_Outcome? outcome]) {
    setState(() {
      if (outcome != null) _outcome = outcome;
      _run++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return Align(
      child: SizedBox(
        // source preview: `relative h-[500px] w-full max-w-xl` (576).
        width: 576,
        height: 500,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                // source preview container has no inset; the response is
                // flush inside `w-full max-w-xl`.
                padding: const EdgeInsets.only(bottom: 48),
                child: _ResponseDemo(
                  key: ValueKey<int>(_run),
                  outcome: _outcome,
                  onReplay: _replay,
                ),
              ),
            ),
            PositionedDirectional(
              start: 0,
              bottom: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ReplayButton(colors: colors, onPressed: _replay),
                  const SizedBox(width: 12),
                  for (final o in _Outcome.values)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: _OutcomeChip(
                        label: switch (o) {
                          _Outcome.complete => 'Completes',
                          _Outcome.error => 'Fails',
                          _Outcome.stopped => 'Stopped',
                        },
                        selected: _outcome == o,
                        colors: colors,
                        onPressed: () => _replay(o),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selects which ending the demo plays. A real control, with the full
/// contract — the gallery should model what it documents.
class _OutcomeChip extends StatefulWidget {
  const _OutcomeChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final BeuiColors colors;
  final VoidCallback onPressed;

  @override
  State<_OutcomeChip> createState() => _OutcomeChipState();
}

class _OutcomeChipState extends State<_OutcomeChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 28),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: widget.selected
                  ? colors.foreground
                  : (_hovered ? colors.secondary : colors.muted),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                height: 16 / 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
                color: widget.selected
                    ? colors.background
                    : colors.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplayButton extends StatelessWidget {
  const _ReplayButton({required this.colors, required this.onPressed});

  final BeuiColors colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6), // rounded-md
        hoverColor: colors.muted,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.rotate_ccw,
                size: 12,
                color: colors.mutedForeground,
              ),
              const SizedBox(width: 6), // gap-1.5
              Text(
                'Replay',
                style: TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0, // tracking-normal
                  color: colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Streamed response
// ---------------------------------------------------------------------------

class _ResponseDemo extends StatefulWidget {
  const _ResponseDemo({
    required this.onReplay,
    required this.outcome,
    super.key,
  });

  final VoidCallback onReplay;
  final _Outcome outcome;

  @override
  State<_ResponseDemo> createState() => _ResponseDemoState();
}

class _ResponseDemoState extends State<_ResponseDemo> {
  int _cursor = 0;
  bool _complete = false;
  Timer? _tick;
  Timer? _completeTimer;

  /// Fraction of the answer produced before a non-complete outcome lands.
  static const double _cutAt = 0.6;

  bool get _cuts => widget.outcome != _Outcome.complete;
  int get _target =>
      _cuts ? (_responseLength * _cutAt).floor() : _responseLength;

  BeuiStreamingResponseStatus get _status {
    if (!_complete) return BeuiStreamingResponseStatus.streaming;
    return switch (widget.outcome) {
      _Outcome.complete => BeuiStreamingResponseStatus.complete,
      _Outcome.error => BeuiStreamingResponseStatus.error,
      _Outcome.stopped => BeuiStreamingResponseStatus.stopped,
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _arm());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _completeTimer?.cancel();
    super.dispose();
  }

  void _arm() {
    if (!mounted) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    _tick?.cancel();
    _completeTimer?.cancel();

    if (reduce) {
      setState(() {
        _cursor = _target;
        _complete = true;
      });
      return;
    }

    setState(() {
      _cursor = 0;
      _complete = false;
    });

    final target = _target;
    final startedAt = DateTime.now();
    // ~60fps ticker approximating requestAnimationFrame + chars/sec.
    _tick = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      final next = (elapsed / 1000 * _charactersPerSecond).floor().clamp(
        0,
        target,
      );
      if (next != _cursor) {
        setState(() => _cursor = next);
      }
      if (next >= target) {
        _tick?.cancel();
        // A failure or a stop lands immediately; only a clean completion has
        // the settle beat before the actions appear.
        _completeTimer = Timer(Duration(milliseconds: _cuts ? 0 : 450), () {
          if (mounted) setState(() => _complete = true);
        });
      }
    });
  }

  String _reveal(int index) {
    final start = _starts[index];
    final piece = _pieces[index];
    final take = (_cursor - start).clamp(0, piece.length);
    return piece.substring(0, take);
  }

  bool _started(int index) => _cursor > _starts[index];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final mono = TextStyle(
      // The source's prose styles resolve `code`/`pre` to `font-mono`, the
      // generic family — not a named face.
      fontFamily: 'monospace',
      fontSize: 12.6, // text-[0.9em] of 14
      letterSpacing: 0, // tracking-normal
      color: colors.foreground.withValues(alpha: 0.9),
    );

    return BeuiStreamingResponse(
      status: _status,
      copyText: _responseMarkdown,
      // Feeds the transcript's live region at sentence boundaries. Here there
      // is no scroller above, so the response announces through its own node.
      announceText: _responseMarkdown.substring(
        0,
        _cursor.clamp(0, _responseMarkdown.length),
      ),
      onRetry: widget.onReplay,
      onContinue: widget.onReplay,
      errorMessage: 'The model stopped responding',
      stoppedMessage: 'You stopped this response',
      sources: _sources,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // p1: link + surrounding text
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: _reveal(0)),
                if (_started(1))
                  TextSpan(
                    text: _reveal(1),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: colors.foreground.withValues(alpha: 0.9),
                      color: colors.foreground.withValues(alpha: 0.9),
                    ),
                  ),
                TextSpan(text: _reveal(2)),
              ],
            ),
          ),
          if (_started(3)) ...[
            const SizedBox(height: 12), // p+p mt-3
            Text(_reveal(3)),
          ],
          if (_started(4)) ...[
            const SizedBox(height: 12),
            // `list-disc pl-5`: the marker lives inside the 20px padding,
            // so the item text — not the marker — starts at x=20.
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Bullet(text: _reveal(4), colors: colors),
                if (_started(5)) ...[
                  const SizedBox(height: 4), // space-y-1
                  _Bullet(text: _reveal(5), colors: colors),
                ],
                if (_started(6)) ...[
                  const SizedBox(height: 4),
                  _Bullet(text: _reveal(6), colors: colors),
                ],
              ],
            ),
          ],
          if (_started(7)) ...[
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: _reveal(7)),
                  if (_started(8))
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.muted,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(_reveal(8), style: mono),
                      ),
                    ),
                  TextSpan(text: _reveal(9)),
                ],
              ),
            ),
          ],
          if (_started(10)) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12), // p-3
              decoration: BoxDecoration(
                color: colors.muted.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12), // rounded-xl
                border: Border.all(color: colors.border),
              ),
              child: Text(_reveal(10), style: mono),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, required this.colors});

  final String text;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 14,
      height: 24 / 14,
      letterSpacing: 0,
      color: colors.foreground.withValues(alpha: 0.9),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // `list-disc` paints a 5px ::marker disc, not a bullet glyph: a `•`
        // in the body face lands ~4px right of it and reads a pixel small.
        SizedBox(
          width: 20, // pl-5 marker gutter
          height: 24, // leading-6 line box, so the disc centres on the line
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: style.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 24 / 14,
              letterSpacing: 0,
              color: colors.foreground.withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
    );
  }
}
