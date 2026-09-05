import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import '../explorer/widgets.dart';

/// Gallery route for the agent loading-states suite —
/// [BeuiThinkingShimmer], [BeuiAgentProgress], and [BeuiReasoningText].
Widget loadingStatesDemo(BuildContext context) => const _LoadingStatesDemo();

class _LoadingStatesDemo extends StatelessWidget {
  const _LoadingStatesDemo();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Thinking shimmer'),
              const SizedBox(height: 12),
              const BeuiThinkingShimmer(
                text: 'Thinking…',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              const SectionLabel('Agent progress'),
              const SizedBox(height: 12),
              const BeuiAgentProgress(
                label: 'Churning',
                initialSeconds: 151.6,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              const SectionLabel('Reasoning text'),
              const SizedBox(height: 16),
              for (final example in _reasoningExamples) ...[
                SectionLabel(example.label),
                const SizedBox(height: 8),
                BeuiReasoningText(
                  variant: example.variant,
                  phrases: example.phrases,
                  // `text-base leading-7` — the component sets no type of its
                  // own, so the preview's line box is what the site shows.
                  // Without it the three variants pitch 71px apart where the
                  // site pitches them 76-77.
                  style: const TextStyle(fontSize: 16, height: 28 / 16),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
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
