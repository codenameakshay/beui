import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import 'agents_replay_button.dart';

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
      Timer(_interval * _diffLines.length + _completeDelay, () {
        if (!mounted) return;
        setState(() => _status = BeuiFileDiffStatus.complete);
      }),
    );
  }

  void _replay() {
    setState(() {
      _run++;
    });
    _startStream();
  }

  @override
  Widget build(BuildContext context) {
    final lines = _diffLines.take(_visible).toList(growable: false);

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
                copyText: _diffLines.map((line) => line.content).join('\n'),
                maxHeight: 150,
                language: BeuiCodeLanguage.typescript,
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: AgentReplayButton(onPressed: _replay, pill: false),
            ),
          ],
        ),
      ),
    );
  }
}
