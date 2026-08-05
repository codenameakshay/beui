import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for the agent loading-states suite —
/// [BeuiThinkingShimmer], [BeuiAgentProgress], and [BeuiReasoningText].
Widget loadingStatesDemo(BuildContext context) => const _LoadingStatesDemo();

class _LoadingStatesDemo extends StatelessWidget {
  const _LoadingStatesDemo();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel(colors, 'Thinking shimmer'),
              const SizedBox(height: 12),
              const BeuiThinkingShimmer(
                text: 'Thinking…',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              _sectionLabel(colors, 'Agent progress'),
              const SizedBox(height: 12),
              const BeuiAgentProgress(
                label: 'Churning',
                initialSeconds: 151.6,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              _sectionLabel(colors, 'Reasoning text'),
              const SizedBox(height: 16),
              for (final example in _reasoningExamples) ...[
                _sectionLabel(colors, example.label, small: true),
                const SizedBox(height: 8),
                BeuiReasoningText(
                  variant: example.variant,
                  phrases: example.phrases,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BeuiColors colors, String label, {bool small = false}) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: small ? 11 : 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.1,
        color: colors.mutedForeground.withValues(alpha: small ? 0.6 : 0.85),
      ),
    );
  }
}

class _ReasoningExample {
  const _ReasoningExample({
    required this.label,
    required this.variant,
    required this.phrases,
  });

  final String label;
  final BeuiReasoningTextVariant variant;
  final List<String> phrases;
}

const _reasoningExamples = <_ReasoningExample>[
  _ReasoningExample(
    label: 'Cascade',
    variant: BeuiReasoningTextVariant.cascade,
    phrases: [
      'Thinking',
      'Reading the request',
      'Working through the details',
      'Preparing the answer',
    ],
  ),
  _ReasoningExample(
    label: 'Swap',
    variant: BeuiReasoningTextVariant.swap,
    phrases: [
      'Thinking',
      'Reading the request',
      'Working through the details',
      'Preparing the answer',
    ],
  ),
  _ReasoningExample(
    label: 'Scramble',
    variant: BeuiReasoningTextVariant.scramble,
    phrases: ['Thinking', 'Searching', 'Reasoning', 'Composing'],
  ),
];
