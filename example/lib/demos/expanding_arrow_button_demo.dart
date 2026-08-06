import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for the expanding-arrow CTA suite — a faithful port of the
/// three preview bands on the source's `motion/expanding-arrow-button` page:
/// [BeuiExpandingArrowButton] on its own, then the two
/// [BeuiHoldActionButton] fills with their shared `h-4 text-xs` status line,
/// then [BeuiSlideActionButton] with its own status line. Every string, the
/// `gap-3` (12px) rhythm and the 1800ms status reset come from the source.
Widget expandingArrowButtonDemo(BuildContext context) =>
    const _ExpandingArrowButtonDemo();

class _ExpandingArrowButtonDemo extends StatefulWidget {
  const _ExpandingArrowButtonDemo();

  @override
  State<_ExpandingArrowButtonDemo> createState() =>
      _ExpandingArrowButtonDemoState();
}

class _ExpandingArrowButtonDemoState extends State<_ExpandingArrowButtonDemo> {
  bool _confirmed = false; // hold band
  bool _continued = false; // slide band

  void _flash(void Function(bool) set) {
    set(true);
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) set(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    // `p.h-4 text-xs text-muted-foreground`
    Widget status(String text) => SizedBox(
      height: 16,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 16 / 12,
          color: colors.mutedForeground,
        ),
      ),
    );

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── ExpandingArrowButtonPreview ────────────────────────────────
          const BeuiExpandingArrowButton(child: Text('Book a demo')),
          const SizedBox(height: 64),

          // ── HoldActionButtonPreview — `flex-col items-center gap-3` ────
          BeuiHoldActionButton(
            onHoldComplete: () => _flash((v) => setState(() => _confirmed = v)),
            child: const Text('Hold for vertical fill'),
          ),
          const SizedBox(height: 12), // gap-3
          BeuiHoldActionButton(
            direction: BeuiHoldActionDirection.horizontal,
            onHoldComplete: () => _flash((v) => setState(() => _confirmed = v)),
            child: const Text('Hold for horizontal fill'),
          ),
          const SizedBox(height: 12),
          status(_confirmed ? 'Action confirmed' : 'Release early to cancel'),
          const SizedBox(height: 64),

          // ── SlideActionButtonPreview — `flex-col items-center gap-3` ───
          BeuiSlideActionButton(
            completeLabel: const Text('Ready'),
            onComplete: () => _flash((v) => setState(() => _continued = v)),
            child: const Text('Slide to continue'),
          ),
          const SizedBox(height: 12),
          status(_continued ? 'Action completed' : 'Drag the arrow to the end'),
        ],
      ),
    );
  }
}
