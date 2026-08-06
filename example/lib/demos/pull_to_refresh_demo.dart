import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiPullToRefresh] — phone-like activity feed that
/// inserts a "You're all caught up" row after a ~900ms refresh.
Widget pullToRefreshDemo(BuildContext context) => const _PullToRefreshDemo();

class _FeedItem {
  const _FeedItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.detail,
    required this.time,
  });

  final int id;
  final IconData icon;
  final String title;
  final String detail;
  final String time;
}

const _initialUpdates = <_FeedItem>[
  _FeedItem(
    id: 1,
    icon: LucideIcons.git_pull_request,
    title: 'Motion review approved',
    detail: 'The pull request is ready to merge.',
    time: '4m',
  ),
  _FeedItem(
    id: 2,
    icon: LucideIcons.message_circle,
    title: 'New component feedback',
    detail: 'The spring feels much closer to native now.',
    time: '18m',
  ),
  _FeedItem(
    id: 3,
    icon: LucideIcons.circle_check,
    title: 'Registry checks passed',
    detail: 'All component files resolved successfully.',
    time: '31m',
  ),
  _FeedItem(
    id: 4,
    icon: LucideIcons.bell,
    title: 'Preview deployed',
    detail: 'The latest build is ready to inspect.',
    time: '1h',
  ),
  _FeedItem(
    id: 5,
    icon: LucideIcons.message_circle,
    title: 'Docs comment resolved',
    detail: 'The usage example now covers async refreshes.',
    time: '2h',
  ),
];

class _PullToRefreshDemo extends StatefulWidget {
  const _PullToRefreshDemo();

  @override
  State<_PullToRefreshDemo> createState() => _PullToRefreshDemoState();
}

class _PullToRefreshDemoState extends State<_PullToRefreshDemo> {
  int _refreshCount = 0;
  int? _latestUpdate;

  List<_FeedItem> get _updates {
    if (_latestUpdate == null) return _initialUpdates;
    return [
      _FeedItem(
        id: _latestUpdate!,
        icon: LucideIcons.bell,
        title: "You're all caught up",
        detail: 'The activity feed was refreshed just now.',
        time: 'now',
      ),
      ..._initialUpdates,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 384), // max-w-sm
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(32), // rounded-[2rem]
              border: Border.all(color: colors.border),
              // `shadow-2xl` = 0 25px 50px -12px rgb(0 0 0 / 0.25). Tailwind
              // shadows are always black; tinting with `foreground` turned this
              // into a white halo in the dark theme.
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 50,
                  spreadRadius: -12,
                  offset: Offset(0, 25),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: SizedBox(
                height: 480, // h-[30rem]
                child: BeuiPullToRefresh(
                  semanticLabel: 'Activity feed',
                  onRefresh: () async {
                    await Future<void>.delayed(
                      const Duration(milliseconds: 900),
                    );
                    if (!mounted) return;
                    setState(() {
                      _refreshCount += 1;
                      _latestUpdate = DateTime.now().millisecondsSinceEpoch;
                    });
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Sticky-style header (source sticky top-0).
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.background.withValues(alpha: 0.9),
                          border: Border(
                            bottom: BorderSide(color: colors.border),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Activity',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: colors.foreground,
                                        fontSize: 16,
                                        height: 24 / 16, // base leading
                                      ),
                                    ),
                                    Text(
                                      'Pull down to check for updates',
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 16 / 12, // text-xs
                                        color: colors.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colors.muted,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    _refreshCount > 0
                                        ? '$_refreshCount refreshed'
                                        : 'live',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      color: colors.mutedForeground,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Source list container: `px-2 pb-3`.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < _updates.length; i++) ...[
                              if (i > 0)
                                Divider(height: 1, color: colors.border),
                              _FeedRow(item: _updates[i], colors: colors),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.item, required this.colors});

  final _FeedItem item;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
              // `shadow-sm` = 0 1px 2px 0 rgb(0 0 0 / 0.05) — black, not tinted.
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(item.icon, size: 16, color: colors.mutedForeground),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14, // text-sm
                          fontWeight: FontWeight.w500,
                          color: colors.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      item.time,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.detail,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.625, // leading-relaxed
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
