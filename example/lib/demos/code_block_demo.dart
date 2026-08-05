import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiCodeBlock] — streaming follow, highlight lines,
/// copy feedback, and a static sample.
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Streaming',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _replay,
                  icon: const Icon(LucideIcons.rotate_ccw, size: 12),
                  label: const Text('Replay'),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.mutedForeground,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Static · JSON',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              const BeuiCodeBlock(
                code: '''{
  "model": "gpt-5",
  "temperature": 0.2,
  "stream": true
}''',
                filename: 'config.json',
                language: BeuiCodeLanguage.json,
                maxHeight: 160,
              ),
              const SizedBox(height: 32),
              Text(
                'No line numbers · wrap',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              const BeuiCodeBlock(
                code:
                    'curl -X POST https://api.example.com/v1/chat '
                    r'-H "Authorization: Bearer $TOKEN"',
                language: BeuiCodeLanguage.bash,
                showLineNumbers: false,
                wrap: true,
                maxHeight: 120,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
