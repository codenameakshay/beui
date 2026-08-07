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

  Future<void> _submit(BeuiFeedbackData data) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    _attempts += 1;
    if (_attempts == 1) {
      throw StateError('Preview submission failed');
    }
    debugPrint('feedback received: ${data.message}');
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
          // px-5 py-3; `width: infinity` so the divider spans the card the way
          // a block-level div does, instead of shrink-wrapping the pill.
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          // `Align` loosens the tight width the full-bleed header hands down —
          // without it the `w-24` pill enforces against a tight 408px and goes
          // full-bleed.
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              height: 10,
              width: 96,
              decoration: BoxDecoration(
                color: colors.mutedForeground.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(306), // w-3/4 of the 408px content box
              const SizedBox(height: 12),
              bar(204), // w-1/2
              const SizedBox(height: 12),
              Container(
                height: 96,
                decoration: BoxDecoration(
                  color: colors.mutedForeground.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 12),
              bar(272), // w-2/3
            ],
          ),
        ),
      ],
    );

    return Center(
      child: ConstrainedBox(
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
                  Positioned.fill(child: BeuiFeedbackWidget(onSubmit: _submit)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
