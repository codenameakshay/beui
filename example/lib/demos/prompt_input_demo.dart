import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiPromptInput] — mirrors the source preview:
/// models + actions + simulated loading send/stop + status notice.
Widget promptInputDemo(BuildContext context) => const _PromptInputDemo();

const _models = <BeuiPromptModel>[
  BeuiPromptModel(
    value: 'gpt-5.2',
    label: 'GPT-5.2',
    icon: Icon(LucideIcons.bot),
  ),
  BeuiPromptModel(
    value: 'claude-sonnet-4',
    label: 'Claude Sonnet 4',
    icon: Icon(LucideIcons.bot),
  ),
  BeuiPromptModel(
    value: 'gemini-3.6-flash',
    label: 'Gemini 3.6 Flash',
    icon: Icon(LucideIcons.bot),
  ),
  BeuiPromptModel(
    value: 'grok-4.5',
    label: 'Grok 4.5',
    icon: Icon(LucideIcons.bot),
  ),
  BeuiPromptModel(
    value: 'mistral-large-3',
    label: 'Mistral Large 3',
    icon: Icon(LucideIcons.bot),
  ),
];

const _actions = <BeuiPromptAction>[
  BeuiPromptAction(
    value: 'image',
    label: 'Attach image',
    description: 'Add a screenshot or visual reference.',
    icon: Icon(LucideIcons.image_plus),
  ),
  BeuiPromptAction(
    value: 'skill',
    label: 'Use a skill',
    description: 'Give the agent a specialized workflow.',
    icon: Icon(LucideIcons.puzzle),
  ),
  BeuiPromptAction(
    value: 'context',
    label: 'Add context',
    description: 'Include a file with supporting details.',
    icon: Icon(LucideIcons.file_text),
  ),
];

class _PromptInputDemo extends StatefulWidget {
  const _PromptInputDemo();

  @override
  State<_PromptInputDemo> createState() => _PromptInputDemoState();
}

class _PromptInputDemoState extends State<_PromptInputDemo> {
  Timer? _timer;
  bool _loading = false;
  String? _sent;
  String? _notice;
  String _model = 'gpt-5.2';

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _submit(String prompt, String? model) {
    setState(() {
      _sent = null;
      _notice = null;
      _loading = true;
    });
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _sent = prompt;
      });
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final status = _sent != null
        ? 'Prompt sent to the selected model.'
        : _notice;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BeuiPromptInput(
                models: _models,
                actions: _actions,
                defaultModel: 'gpt-5.2',
                model: _model,
                onModelChange: (m) => setState(() => _model = m),
                defaultValue:
                    'Review the current implementation and suggest the next improvement.',
                loading: _loading,
                onSubmit: _submit,
                onStop: _stop,
                onAction: (action) {
                  BeuiPromptAction? selected;
                  for (final a in _actions) {
                    if (a.value == action) {
                      selected = a;
                      break;
                    }
                  }
                  setState(() {
                    _notice = selected != null
                        ? '${selected.label} selected.'
                        : null;
                    _sent = null;
                  });
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 24,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: beuiEaseOut,
                    child: status == null
                        ? const SizedBox.shrink()
                        : Text(
                            key: ValueKey(status),
                            status,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.mutedForeground,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Model: $_model · Enter to send · Shift+Enter for newline',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.mutedForeground.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
