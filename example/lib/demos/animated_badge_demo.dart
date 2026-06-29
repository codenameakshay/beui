import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery entry for [BeuiAnimatedBadge] — replicates the source
/// `animated-badge.preview.tsx`: a hero badge that cycles through statuses every
/// 1.6s (icon + color animate, the loader pulses), plus a static grid showing
/// every status at the small size.
Widget animatedBadgeDemo(BuildContext context) => const _AnimatedBadgeDemo();

class _AnimatedBadgeDemo extends StatefulWidget {
  const _AnimatedBadgeDemo();

  @override
  State<_AnimatedBadgeDemo> createState() => _AnimatedBadgeDemoState();
}

class _AnimatedBadgeDemoState extends State<_AnimatedBadgeDemo> {
  // The source preview cycle: loading → success → warning → danger.
  static const _cycle = <(BeuiAnimatedBadgeStatus, String)>[
    (BeuiAnimatedBadgeStatus.loading, 'Syncing'),
    (BeuiAnimatedBadgeStatus.success, 'Synced'),
    (BeuiAnimatedBadgeStatus.warning, 'Review'),
    (BeuiAnimatedBadgeStatus.danger, 'Failed'),
  ];

  int _active = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (mounted) setState(() => _active = (_active + 1) % _cycle.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final (status, label) = _cycle[_active];

    Widget caption(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
          color: colors.mutedForeground,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        caption('Auto-cycles status — icon + color animate, loader pulses'),
        SizedBox(
          height: 64,
          child: Align(
            alignment: Alignment.centerLeft,
            child: BeuiAnimatedBadge(status: status, label: label),
          ),
        ),
        const SizedBox(height: 32),
        caption('Every status (small)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            BeuiAnimatedBadge(
              status: BeuiAnimatedBadgeStatus.neutral,
              size: BeuiAnimatedBadgeSize.sm,
              label: 'Queued',
            ),
            BeuiAnimatedBadge(
              status: BeuiAnimatedBadgeStatus.info,
              size: BeuiAnimatedBadgeSize.sm,
              label: 'Live',
            ),
            BeuiAnimatedBadge(
              status: BeuiAnimatedBadgeStatus.loading,
              size: BeuiAnimatedBadgeSize.sm,
              label: 'Indexing',
            ),
            BeuiAnimatedBadge(
              status: BeuiAnimatedBadgeStatus.success,
              size: BeuiAnimatedBadgeSize.sm,
              label: 'Verified',
            ),
            BeuiAnimatedBadge(
              status: BeuiAnimatedBadgeStatus.warning,
              size: BeuiAnimatedBadgeSize.sm,
              label: 'Pending',
            ),
            BeuiAnimatedBadge(
              status: BeuiAnimatedBadgeStatus.danger,
              size: BeuiAnimatedBadgeSize.sm,
              label: 'Blocked',
            ),
          ],
        ),
      ],
    );
  }
}
