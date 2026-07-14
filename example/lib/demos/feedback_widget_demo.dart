import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiFeedbackWidget] — the corner capsule that morphs from
/// a trigger into a feedback form, then celebrates on success.
///
/// Mirrors the source `feedback-widget.preview.tsx`: a faux app surface with the
/// widget anchored bottom-right, and an `onSubmit` that fails on the first
/// attempt (routing to the retry view) before succeeding.
Widget feedbackWidgetDemo(BuildContext context) => const _FeedbackWidgetDemo();

class _FeedbackWidgetDemo extends StatefulWidget {
  const _FeedbackWidgetDemo();

  @override
  State<_FeedbackWidgetDemo> createState() => _FeedbackWidgetDemoState();
}

class _FeedbackWidgetDemoState extends State<_FeedbackWidgetDemo> {
  int _attempts = 0;
  String? _lastMessage;

  Future<void> _submit(BeuiFeedbackData data) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    _attempts += 1;
    if (_attempts == 1) {
      throw StateError('Preview submission failed');
    }
    if (mounted) setState(() => _lastMessage = data.message);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    Widget bar(double width) => Container(
      height: 10,
      width: width,
      decoration: BoxDecoration(
        color: colors.mutedForeground.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
    );

    // Faux app surface so the corner trigger has something to sit on.
    final fauxApp = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Container(
            height: 10,
            width: 96,
            decoration: BoxDecoration(
              color: colors.mutedForeground.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(220),
              const SizedBox(height: 12),
              bar(150),
              const SizedBox(height: 12),
              Container(
                height: 96,
                decoration: BoxDecoration(
                  color: colors.mutedForeground.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 12),
              bar(180),
            ],
          ),
        ),
      ],
    );

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: SizedBox(
              height: 320,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(child: fauxApp),
                      Positioned.fill(
                        child: BeuiFeedbackWidget(onSubmit: _submit),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _lastMessage == null
                ? 'Open the corner trigger and submit feedback…'
                : 'Received: $_lastMessage',
            style: TextStyle(fontSize: 13, color: colors.mutedForeground),
          ),
        ],
      ),
    );
  }
}
