import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import '../explorer/widgets.dart';

/// Gallery route for [BeuiCodeBlock], mirroring the source
/// `agents/code-block.preview.tsx` exactly: one streaming TypeScript block in a
/// `relative h-[340px] w-full max-w-xl` frame, with the ghost `Replay` control
/// pinned to `bottom-0 left-0`.
///
/// The source preview ships that single card, so this route leads with it.
/// Below it sits a second, static block exercising `wrap: true` — a widget
/// option rather than a preview state, but worth modelling since it is the
/// only way a wide line stays fully on screen.
Widget codeBlockDemo(BuildContext context) => const _CodeBlockDemo();

class _CodeBlockDemo extends StatefulWidget {
  const _CodeBlockDemo();

  @override
  State<_CodeBlockDemo> createState() => _CodeBlockDemoState();
}

class _CodeBlockDemoState extends State<_CodeBlockDemo> {
  static const _lines = <String>[
    'import { generateText } from "ai";',
    '',
    'export async function summarize(input: string) {',
    '  const { text } = await generateText({',
    '    model: "openai/gpt-5",',
    r'    prompt: `Summarize this clearly: ${input}`,',
    '  });',
    '',
    '  return {',
    '    text,',
    '    generatedAt: new Date().toISOString(),',
    '  };',
    '}',
  ];

  // Deliberately wide: with `wrap: true` this stays fully on screen instead
  // of requiring horizontal scroll.
  static const _wrapCode =
      'const summary = await generateText({ model: "openai/gpt-5", '
      r'prompt: `Summarize this clearly, preserving every citation and '
      r'footnote reference exactly as written: ${input}` });';

  int _visible = 1;
  int _run = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startStream() {
    _timer?.cancel();
    setState(() => _visible = 1);
    _timer = Timer.periodic(const Duration(milliseconds: 260), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_visible >= _lines.length) {
        t.cancel();
        setState(() {}); // flip status to complete
        return;
      }
      setState(() => _visible++);
    });
  }

  void _replay() {
    setState(() => _run++);
    _startStream();
  }

  @override
  Widget build(BuildContext context) {
    final complete = _visible >= _lines.length;
    final code = _lines.take(_visible).join('\n');

    return Align(
      child: SizedBox(
        // source preview: `relative h-[340px] w-full max-w-xl` (576).
        width: 576,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 340,
              child: Stack(
                children: [
                  BeuiCodeBlock(
                    key: ValueKey(_run),
                    code: code,
                    filename: 'summarize.ts',
                    language: BeuiCodeLanguage.typescript,
                    status: complete
                        ? BeuiCodeBlockStatus.complete
                        : BeuiCodeBlockStatus.streaming,
                    highlightLines: const [4, 5, 6, 7],
                    maxHeight: 224,
                  ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: ReplayButton(onPressed: _replay),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Static, non-streaming block demonstrating `wrap: true`: the long
            // line soft-wraps instead of requiring horizontal scroll.
            const BeuiCodeBlock(
              code: _wrapCode,
              filename: 'summarize.ts',
              language: BeuiCodeLanguage.typescript,
              wrap: true,
              maxHeight: 160,
            ),
          ],
        ),
      ),
    );
  }
}
