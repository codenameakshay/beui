import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

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

class _StreamingResponseDemoState extends State<_StreamingResponseDemo> {
  int _run = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 576), // max-w-xl
        child: SizedBox(
          height: 500,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
                  child: _ResponseDemo(
                    key: ValueKey<int>(_run),
                    onReplay: () => setState(() => _run++),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                bottom: 8,
                child: _ReplayButton(
                  colors: colors,
                  onPressed: () => setState(() => _run++),
                ),
              ),
            ],
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
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        LucideIcons.rotate_ccw,
        size: 12,
        color: colors.mutedForeground,
      ),
      label: Text(
        'Replay',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colors.mutedForeground,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: colors.mutedForeground,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Streamed response
// ---------------------------------------------------------------------------

class _ResponseDemo extends StatefulWidget {
  const _ResponseDemo({required this.onReplay, super.key});

  final VoidCallback onReplay;

  @override
  State<_ResponseDemo> createState() => _ResponseDemoState();
}

class _ResponseDemoState extends State<_ResponseDemo> {
  int _cursor = 0;
  bool _complete = false;
  Timer? _tick;
  Timer? _completeTimer;

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
        _cursor = _responseLength;
        _complete = true;
      });
      return;
    }

    setState(() {
      _cursor = 0;
      _complete = false;
    });

    final startedAt = DateTime.now();
    // ~60fps ticker approximating requestAnimationFrame + chars/sec.
    _tick = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      final next = (elapsed / 1000 * _charactersPerSecond).floor().clamp(
        0,
        _responseLength,
      );
      if (next != _cursor) {
        setState(() => _cursor = next);
      }
      if (next >= _responseLength) {
        _tick?.cancel();
        _completeTimer = Timer(const Duration(milliseconds: 450), () {
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
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: const ['monospace'],
      fontSize: 12.6, // text-[0.9em] of 14
      color: colors.foreground.withValues(alpha: 0.9),
    );

    return BeuiStreamingResponse(
      status: _complete
          ? BeuiStreamingResponseStatus.complete
          : BeuiStreamingResponseStatus.streaming,
      copyText: _responseMarkdown,
      onRetry: widget.onReplay,
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
            Padding(
              padding: const EdgeInsets.only(left: 20), // pl-5
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Bullet(text: _reveal(4), colors: colors),
                  if (_started(5)) ...[
                    const SizedBox(height: 4),
                    _Bullet(text: _reveal(5), colors: colors),
                  ],
                  if (_started(6)) ...[
                    const SizedBox(height: 4),
                    _Bullet(text: _reveal(6), colors: colors),
                  ],
                ],
              ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '•  ',
          style: TextStyle(
            fontSize: 14,
            height: 24 / 14,
            color: colors.foreground.withValues(alpha: 0.9),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 24 / 14,
              color: colors.foreground.withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
    );
  }
}
