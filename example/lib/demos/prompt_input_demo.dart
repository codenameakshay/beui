import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import 'provider_favicon.dart'
    if (dart.library.js_interop) 'provider_favicon_web.dart';

/// Gallery route for [BeuiPromptInput] — mirrors the source preview:
/// models + actions + simulated loading send/stop + status notice.
Widget promptInputDemo(BuildContext context) => const _PromptInputDemo();

const _models = <BeuiPromptModel>[
  BeuiPromptModel(
    value: 'gpt-5.2',
    label: 'GPT-5.2',
    icon: _ModelLogo('https://openai.com'),
  ),
  BeuiPromptModel(
    value: 'claude-sonnet-4',
    label: 'Claude Sonnet 4',
    icon: _ModelLogo('https://www.anthropic.com'),
  ),
  BeuiPromptModel(
    value: 'gemini-3.6-flash',
    label: 'Gemini 3.6 Flash',
    icon: _ModelLogo('https://deepmind.google'),
  ),
  BeuiPromptModel(
    value: 'grok-4.5',
    label: 'Grok 4.5',
    icon: _ModelLogo('https://x.ai'),
  ),
  BeuiPromptModel(
    value: 'mistral-large-3',
    label: 'Mistral Large 3',
    icon: _ModelLogo('https://mistral.ai'),
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

    // source preview: `flex h-[360px] w-full max-w-xl flex-col justify-center`
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 576),
        child: SizedBox(
          height: 360,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                  });
                },
              ),
              // source preview: `h-8 px-2 pt-2 text-xs text-muted-foreground`
              SizedBox(
                height: 32,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: _PromptNotice(
                    status: status,
                    identity: _sent ?? _notice,
                    color: colors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelLogo extends StatelessWidget {
  const _ModelLogo(this.url);

  final String url;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: SizedBox(
      width: 16,
      height: 16,
      child: providerFavicon(
        beuiFaviconUrl(url)!,
        const Icon(LucideIcons.bot, size: 16),
      ),
    ),
  );
}

class _PromptNotice extends StatefulWidget {
  const _PromptNotice({
    required this.status,
    required this.identity,
    required this.color,
  });

  final String? status;
  final String? identity;
  final Color color;

  @override
  State<_PromptNotice> createState() => _PromptNoticeState();
}

class _PromptNoticeState extends State<_PromptNotice> {
  String? _visible;
  String? _identity;
  bool _shown = false;
  Timer? _exit;

  @override
  void initState() {
    super.initState();
    _visible = widget.status;
    _identity = widget.identity;
    _shown = _visible != null;
  }

  @override
  void didUpdateWidget(_PromptNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity == widget.identity) return;
    _exit?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) {
      _visible = widget.status;
      _identity = widget.identity;
      _shown = _visible != null;
    } else if (_visible != null) {
      _shown = false;
      _exit = Timer(const Duration(milliseconds: 180), _mountNext);
    } else {
      _mountNext();
    }
  }

  void _mountNext() {
    if (!mounted) return;
    setState(() {
      _visible = widget.status;
      _identity = widget.identity;
      _shown = false;
    });
    if (_visible != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _shown = true);
      });
    }
  }

  @override
  void dispose() {
    _exit?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (_visible == null) return const SizedBox.shrink();
    final text = Align(
      alignment: Alignment.topLeft,
      child: Text(
        _visible!,
        style: TextStyle(
          fontSize: 12,
          height: 16 / 12,
          letterSpacing: 0,
          color: widget.color,
        ),
      ),
    );
    if (reduce) return text;
    return TweenAnimationBuilder<double>(
      key: ValueKey(_identity),
      tween: Tween(begin: 0, end: _shown ? 1 : 0),
      duration: const Duration(milliseconds: 180),
      curve: beuiEaseOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, _shown ? 3 * (1 - value) : 0),
          child: child,
        ),
      ),
      child: text,
    );
  }
}
