import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiApprovalCard] — mirrors the source previews:
/// multi-step questions + simple review-and-approve, each with Replay.
Widget approvalCardDemo(BuildContext context) => const _ApprovalCardDemo();

const _questions = <BeuiApprovalCardQuestion>[
  BeuiApprovalCardQuestion(
    id: 'scope',
    title: 'How focused should the first release be?',
    options: [
      BeuiApprovalCardOption(value: 'focused', label: 'A focused starter set'),
      BeuiApprovalCardOption(value: 'broad', label: 'A broader collection'),
      BeuiApprovalCardOption(
        value: 'flagship',
        label: 'One flagship experience',
      ),
    ],
    allowCustom: true,
    customPlaceholder: 'Describe another scope…',
  ),
  BeuiApprovalCardQuestion(
    id: 'checks',
    title: 'Which checks should block publishing?',
    description:
        'Select every check the agent must pass before it can continue.',
    multiple: true,
    options: [
      BeuiApprovalCardOption(value: 'types', label: 'Type safety'),
      BeuiApprovalCardOption(value: 'accessibility', label: 'Accessibility'),
      BeuiApprovalCardOption(value: 'registry', label: 'Registry validation'),
    ],
  ),
  BeuiApprovalCardQuestion(
    id: 'preserve',
    title: 'Anything the agent should preserve?',
    allowCustom: true,
    customPlaceholder: 'Add a final constraint…',
  ),
];

class _ApprovalCardDemo extends StatelessWidget {
  const _ApprovalCardDemo();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    // Sizes to its content instead of demanding a bounded height: the gallery
    // lays demos out inside a SingleChildScrollView, where an ordinary
    // ListView asserts and the preview renders nothing. Scrolling is left to
    // that outer view rather than nesting a second scrollable.
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      children: [
        Text(
          'Questions',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.mutedForeground,
          ),
        ),
        const SizedBox(height: 12),
        const _QuestionPreview(),
        const SizedBox(height: 40),
        Text(
          'Review and approve',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.mutedForeground,
          ),
        ),
        const SizedBox(height: 12),
        const _ReviewPreview(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Question flow preview
// ---------------------------------------------------------------------------

class _QuestionPreview extends StatefulWidget {
  const _QuestionPreview();

  @override
  State<_QuestionPreview> createState() => _QuestionPreviewState();
}

class _QuestionPreviewState extends State<_QuestionPreview> {
  int _run = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 512),
        child: SizedBox(
          height: 470,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: _QuestionFlow(key: ValueKey<int>(_run)),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                child: _ReplayButton(
                  colors: colors,
                  onPressed: () => setState(() => _run += 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionFlow extends StatefulWidget {
  const _QuestionFlow({super.key});

  @override
  State<_QuestionFlow> createState() => _QuestionFlowState();
}

class _QuestionFlowState extends State<_QuestionFlow> {
  BeuiApprovalCardStatus _status = BeuiApprovalCardStatus.pending;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _submit(BeuiApprovalCardAnswers _) {
    setState(() => _status = BeuiApprovalCardStatus.submitting);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      setState(() => _status = BeuiApprovalCardStatus.answered);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BeuiApprovalCard(
      questions: _questions,
      status: _status,
      onSubmit: _submit,
      result: const Text('Three responses sent to the agent.'),
    );
  }
}

// ---------------------------------------------------------------------------
// Review / approve preview
// ---------------------------------------------------------------------------

class _ReviewPreview extends StatefulWidget {
  const _ReviewPreview();

  @override
  State<_ReviewPreview> createState() => _ReviewPreviewState();
}

class _ReviewPreviewState extends State<_ReviewPreview> {
  int _run = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 512),
        child: SizedBox(
          height: 360,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: _ReviewFlow(key: ValueKey<int>(_run)),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                child: _ReplayButton(
                  colors: colors,
                  onPressed: () => setState(() => _run += 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewFlow extends StatefulWidget {
  const _ReviewFlow({super.key});

  @override
  State<_ReviewFlow> createState() => _ReviewFlowState();
}

class _ReviewFlowState extends State<_ReviewFlow> {
  BeuiApprovalCardStatus _status = BeuiApprovalCardStatus.pending;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _finish(BeuiApprovalCardStatus next) {
    setState(() => _status = BeuiApprovalCardStatus.submitting);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _status = next);
    });
  }

  String get _resultText {
    return switch (_status) {
      BeuiApprovalCardStatus.approved => 'Publishing was approved.',
      BeuiApprovalCardStatus.changesRequested =>
        'The agent will wait for revision notes.',
      BeuiApprovalCardStatus.rejected => 'Publishing was declined.',
      _ => 'Publishing was declined.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return BeuiApprovalCard(
      title: 'Publish the component update?',
      description:
          'The agent has prepared the release and is waiting for your decision.',
      status: _status,
      onApprove: () => _finish(BeuiApprovalCardStatus.approved),
      onRequestChanges: () => _finish(BeuiApprovalCardStatus.changesRequested),
      onReject: () => _finish(BeuiApprovalCardStatus.rejected),
      result: Text(_resultText),
      child: _MetaList(colors: colors),
    );
  }
}

class _MetaList extends StatelessWidget {
  const _MetaList({required this.colors});

  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    final rows = const [
      ('Release', 'approval-card', true),
      ('Checks', '4 passed', false),
      ('Visibility', 'Public registry', false),
    ];

    // Source markup: `<dl class="grid gap-1 text-xs">` with each row
    // `flex items-center justify-between gap-4 py-1` — 12/16 text plus py-1
    // makes a 24px row, gap-1 (4px) between rows.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, (label, value, mono)) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: 4), // gap-1
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4), // py-1
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      height: 16 / 12, // text-xs leading
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
                const SizedBox(width: 16), // gap-4
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    fontFamily: mono ? 'monospace' : null,
                    color: colors.foreground.withValues(alpha: 0.80),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Replay chrome
// ---------------------------------------------------------------------------

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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: colors.foreground,
      ),
    );
  }
}
