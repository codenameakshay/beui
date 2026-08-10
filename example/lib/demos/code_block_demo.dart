import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiCodeBlock], mirroring the source
/// `agents/code-block.preview.tsx` exactly: one streaming TypeScript block in a
/// `relative h-[340px] w-full max-w-xl` frame, with the ghost `Replay` control
/// pinned to `bottom-0 left-0`.
///
/// The source preview ships that single card and nothing else, so this route
/// shows one. (Static / no-line-number / wrapping blocks are widget options,
/// not preview states.)
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
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final complete = _visible >= _lines.length;
    final code = _lines.take(_visible).join('\n');

    return Align(
      child: SizedBox(
        // source preview: `relative h-[340px] w-full max-w-xl` (576).
        width: 576,
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
              child: _ReplayButton(onPressed: _replay, colors: colors),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ghost "Replay" control matching the source preview's
/// `rounded-full px-2 py-1 text-xs font-medium text-muted-foreground` button.
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
        borderRadius: BorderRadius.circular(999),
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
              const SizedBox(width: 6),
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
