import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiFileDiff], mirroring the source
/// `agents/file-diff.preview.tsx` exactly: five diff rows streamed at the
/// shared `useToolResultDemo(5, 360)` cadence inside a
/// `relative h-[300px] w-full max-w-lg` frame, with the ghost `Replay` control
/// pinned to `bottom-0 left-0`. The disclosure collapses itself once the run
/// completes (`collapseOnComplete`), so the settled state is the header alone.
Widget fileDiffDemo(BuildContext context) => const _FileDiffDemo();

class _FileDiffDemo extends StatefulWidget {
  const _FileDiffDemo();

  @override
  State<_FileDiffDemo> createState() => _FileDiffDemoState();
}

class _FileDiffDemoState extends State<_FileDiffDemo> {
  static const _diffLines = <BeuiFileDiffLine>[
    BeuiFileDiffLine(
      id: '1',
      oldLine: 18,
      newLine: 18,
      content: 'export async function runTask() {',
    ),
    BeuiFileDiffLine(
      id: '2',
      type: BeuiFileDiffLineType.removed,
      oldLine: 19,
      content: '  return execute(task);',
    ),
    BeuiFileDiffLine(
      id: '3',
      type: BeuiFileDiffLineType.added,
      newLine: 19,
      content: '  const result = await execute(task);',
    ),
    BeuiFileDiffLine(
      id: '4',
      type: BeuiFileDiffLineType.added,
      newLine: 20,
      content: '  return normalize(result);',
    ),
    // A discontinuous jump from line 20/21 to 40/41 — the widget infers a
    // 20-line hidden context gap from this, rendered as an "Expand N hidden
    // lines" separator between the two rows.
    BeuiFileDiffLine(id: '5', oldLine: 40, newLine: 41, content: '}'),
  ];

  static const _interval = Duration(milliseconds: 360);
  static const _startDelay = Duration(milliseconds: 180);
  static const _completeDelay = Duration(milliseconds: 480);

  int _visible = 0;
  int _run = 0;
  BeuiFileDiffStatus _status = BeuiFileDiffStatus.streaming;
  final List<Timer> _timers = [];

  // The consumer owns the file; the widget only detects the gap. These rows
  // are generated on demand when the reader expands the hunk separator, and
  // spliced back in right after the row the gap follows.
  final List<BeuiFileDiffLine> _extraContext = [];
  String? _extraContextAfterId;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  void _cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  void _startStream() {
    _cancelTimers();
    setState(() {
      _visible = 0;
      _status = BeuiFileDiffStatus.streaming;
    });

    for (var i = 0; i < _diffLines.length; i++) {
      final index = i;
      _timers.add(
        Timer(_startDelay + _interval * index, () {
          if (!mounted) return;
          setState(() => _visible = index + 1);
        }),
      );
    }
    _timers.add(
      Timer(
        _startDelay +
            _interval * _diffLines.length +
            _completeDelay -
            _startDelay,
        () {
          if (!mounted) return;
          setState(() => _status = BeuiFileDiffStatus.complete);
        },
      ),
    );
  }

  void _replay() {
    setState(() {
      _run++;
      _extraContext.clear();
      _extraContextAfterId = null;
    });
    _startStream();
  }

  /// The consumer owns the file; the widget only detects the gap — it hands
  /// back a [BeuiFileDiffHunkGap] describing what's missing and leaves
  /// fetching / generating the real lines to us.
  void _expandContext(BeuiFileDiffHunkGap gap) {
    final afterOld = gap.after.oldLine;
    final afterNew = gap.after.newLine;
    final generated = <BeuiFileDiffLine>[
      for (var i = 0; i < gap.hiddenCount; i++)
        BeuiFileDiffLine(
          id: 'ctx-${gap.before.id}-$i',
          content: '  // ...',
          oldLine: afterOld == null ? null : afterOld - gap.hiddenCount + i,
          newLine: afterNew == null ? null : afterNew - gap.hiddenCount + i,
        ),
    ];
    setState(() {
      _extraContextAfterId = gap.before.id;
      _extraContext
        ..clear()
        ..addAll(generated);
    });
  }

  /// [_diffLines] with any expanded [_extraContext] spliced back in right
  /// after the row the gap followed.
  List<BeuiFileDiffLine> get _mergedLines {
    if (_extraContext.isEmpty) return _diffLines;
    final merged = <BeuiFileDiffLine>[];
    for (final line in _diffLines) {
      merged.add(line);
      if (line.id == _extraContextAfterId) merged.addAll(_extraContext);
    }
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    // While streaming, reveal rows progressively from the raw list; once the
    // full diff has arrived, fold in any expanded context.
    final lines = _visible >= _diffLines.length
        ? _mergedLines
        : _diffLines.take(_visible).toList(growable: false);

    return Align(
      child: SizedBox(
        // source preview: `relative h-[300px] w-full max-w-lg` (512).
        width: 512,
        height: 300,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: BeuiFileDiff(
                key: ValueKey(_run),
                file: 'src/runner.ts',
                lines: lines,
                status: _status,
                // copyText now defaults to the widget's own serialised diff,
                // so there is no reason to hand-roll it here.
                maxHeight: 150,
                language: BeuiCodeLanguage.typescript,
                onExpandContext: _expandContext,
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: _ReplayButton(onPressed: _replay, colors: colors),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ghost "Replay" control matching the source preview's
/// `rounded-md px-2 py-1 text-xs font-medium text-muted-foreground` button.
class _ReplayButton extends StatelessWidget {
  const _ReplayButton({required this.onPressed, required this.colors});

  final VoidCallback onPressed;
  final BeuiColors colors;

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
