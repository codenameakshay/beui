import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery entry for [BeuiAnimatedBadge] — a faithful port of the source
/// `animated-badge.preview.tsx`: `flex flex-col items-center gap-6` holding a
/// hero badge in an `h-16` box that cycles status every 1.6s, then a
/// `grid sm:grid-cols-3 gap-2` of every status at the small size.
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

  // The `sm:grid-cols-3` grid, row-major.
  static const _grid = <List<(BeuiAnimatedBadgeStatus, String)>>[
    [
      (BeuiAnimatedBadgeStatus.neutral, 'Queued'),
      (BeuiAnimatedBadgeStatus.info, 'Live'),
      (BeuiAnimatedBadgeStatus.loading, 'Indexing'),
    ],
    [
      (BeuiAnimatedBadgeStatus.success, 'Verified'),
      (BeuiAnimatedBadgeStatus.warning, 'Pending'),
      (BeuiAnimatedBadgeStatus.danger, 'Blocked'),
    ],
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
    final (status, label) = _cycle[_active];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // `flex h-16 items-center justify-center`
        SizedBox(
          height: 64,
          child: Center(
            child: BeuiAnimatedBadge(status: status, label: label),
          ),
        ),
        const SizedBox(height: 24), // gap-6
        // `grid sm:grid-cols-3 gap-2` — 1fr tracks, so every cell is the same
        // width and each badge stretches to fill it.
        IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < _grid.length; r++) ...[
                if (r > 0) const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var c = 0; c < _grid[r].length; c++) ...[
                      if (c > 0) const SizedBox(width: 8),
                      Expanded(
                        child: BeuiAnimatedBadge(
                          status: _grid[r][c].$1,
                          size: BeuiAnimatedBadgeSize.sm,
                          label: _grid[r][c].$2,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
