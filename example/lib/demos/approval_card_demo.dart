import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import '../explorer/widgets.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Questions'),
          const SizedBox(height: 12),
          const _QuestionPreview(),
          const SizedBox(height: 40),
          const SectionLabel('Review and approve'),
          const SizedBox(height: 12),
          const _ReviewPreview(),
          const SizedBox(height: 40),
          const SectionLabel('Header trigger'),
          const SizedBox(height: 12),
          const _HeaderTriggerPreview(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header trigger invariant
// ---------------------------------------------------------------------------

/// Two cards that look almost alike and behave deliberately differently.
///
/// The first has an `expandedChild`, so the *whole header row* toggles it —
/// not just a 20×20 chevron. The second has only a `child` and a
/// `headerAction`, so its header is completely inert: no button semantics, no
/// keyboard stop, and no hidden second control lurking under the action.
class _HeaderTriggerPreview extends StatelessWidget {
  const _HeaderTriggerPreview();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final agent = BeuiAgentTheme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 512),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BeuiApprovalCard(
              title: 'Expandable — tap anywhere on this header',
              description: 'The row is the control.',
              compactChild: Text(
                'Summary only.',
                style: agent.typography.description.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
              expandedChild: Text(
                'The full body, revealed by the header trigger.',
                style: agent.typography.description.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
              onApprove: () {},
              onReject: () {},
            ),
            const SizedBox(height: 16),
            BeuiApprovalCard(
              title: 'Inert header — only the action is a control',
              description: 'No expandedChild, so the row stays plain content.',
              headerAction: IconButton(
                tooltip: 'Edit',
                visualDensity: VisualDensity.compact,
                onPressed: () {},
                icon: Icon(agent.icons.edit, size: 16),
              ),
              onApprove: () {},
              onReject: () {},
              child: Text(
                'Tapping this header does nothing at all.',
                style: agent.typography.description.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
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
                child: ReplayButton(onPressed: () => setState(() => _run += 1)),
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
                child: ReplayButton(onPressed: () => setState(() => _run += 1)),
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

  static const _rows = [
    ('Release', 'approval-card', true),
    ('Checks', '4 passed', false),
    ('Visibility', 'Public registry', false),
  ];

  @override
  Widget build(BuildContext context) {
    // Source markup: `<dl class="grid gap-1 text-xs">` with each row
    // `flex items-center justify-between gap-4 py-1` — 12/16 text plus py-1
    // makes a 24px row, gap-1 (4px) between rows.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, (label, value, mono)) in _rows.indexed) ...[
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
