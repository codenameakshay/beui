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
    BeuiFileDiffLine(id: '5', oldLine: 20, newLine: 21, content: '}'),
  ];

  static const _interval = Duration(milliseconds: 360);
  static const _startDelay = Duration(milliseconds: 180);
  static const _completeDelay = Duration(milliseconds: 480);

  int _visible = 0;
  int _run = 0;
  BeuiFileDiffStatus _status = BeuiFileDiffStatus.streaming;
  final List<Timer> _timers = [];

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
    setState(() => _run++);
    _startStream();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final lines = _diffLines.take(_visible).toList(growable: false);
    final copyText = _diffLines.map((l) => l.content).join('\n');

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
                copyText: copyText,
                maxHeight: 150,
                language: BeuiCodeLanguage.typescript,
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
