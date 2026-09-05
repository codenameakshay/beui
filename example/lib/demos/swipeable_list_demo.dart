import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiSwipeableList] — mirrors
/// `swipeable-list.preview.tsx`: a "Priority queue" shell wrapping four rows
/// that reveal Done/Pin on the left and Later/Trash on the right.
Widget swipeableListDemo(BuildContext context) => const _SwipeableListDemo();

const _leftActions = [
  BeuiSwipeAction(
    id: 'done',
    label: 'Done',
    icon: LucideIcons.check,
    tone: BeuiSwipeActionTone.success,
  ),
  BeuiSwipeAction(
    id: 'pin',
    label: 'Pin',
    icon: LucideIcons.pin,
    tone: BeuiSwipeActionTone.primary,
  ),
];

const _rightActions = [
  BeuiSwipeAction(
    id: 'later',
    label: 'Later',
    icon: LucideIcons.clock_3,
    tone: BeuiSwipeActionTone.warning,
  ),
  BeuiSwipeAction(
    id: 'trash',
    label: 'Trash',
    icon: LucideIcons.trash,
    tone: BeuiSwipeActionTone.danger,
  ),
];

const _seed = <(String, String, String, String, IconData)>[
  (
    'brief',
    'Launch brief',
    'Finalize the announcement copy',
    '9:41',
    LucideIcons.file_text,
  ),
  (
    'feedback',
    'Client feedback',
    'Three comments need a response',
    '11:08',
    LucideIcons.mail,
  ),
  (
    'review',
    'Design review',
    'Check spacing before handoff',
    '13:20',
    LucideIcons.user_round,
  ),
  (
    'incident',
    'Flagged run',
    'Retry queue has one failed job',
    'Now',
    LucideIcons.flag,
  ),
];

class _SwipeableListDemo extends StatefulWidget {
  const _SwipeableListDemo();

  @override
  State<_SwipeableListDemo> createState() => _SwipeableListDemoState();
}

class _SwipeableListDemoState extends State<_SwipeableListDemo> {
  List<String> _ids = [for (final s in _seed) s.$1];
  String _lastAction = 'Ready';

  /// `grid h-10 w-10 place-items-center rounded-xl border bg-background`.
  Widget _leading(IconData icon, BeuiColors colors) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: colors.background,
      border: Border.all(color: colors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, size: 16, color: colors.mutedForeground),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final items = [
      for (final (id, title, description, meta, icon) in _seed)
        if (_ids.contains(id))
          BeuiSwipeableListItem(
            id: id,
            title: title,
            description: description,
            meta: meta,
            leading: _leading(icon, colors),
            leftActions: _leftActions,
            rightActions: _rightActions,
          ),
    ];

    return Center(
      child: ConstrainedBox(
        // max-w-sm inside a `min-h-96` centering row.
        constraints: const BoxConstraints(maxWidth: 384, minHeight: 384),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(12), // p-3
            decoration: BoxDecoration(
              color: colors.background,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(32), // rounded-[2rem]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12), // px-1 mb-3
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Priority queue',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.foreground,
                              ),
                            ),
                            Text(
                              _lastAction,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _ResetButton(
                        colors: colors,
                        onPressed: () => setState(() {
                          _ids = [for (final s in _seed) s.$1];
                          _lastAction = 'Queue restored';
                        }),
                      ),
                    ],
                  ),
                ),
                BeuiSwipeableList(
                  items: items,
                  onAction: (item, action, _) => setState(() {
                    _lastAction = '${action.label} · ${item.title}';
                    if (action.id == 'trash') {
                      _ids = [..._ids]..remove(item.id);
                    }
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 0), // mt-3 px-1
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${items.length} open',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.mutedForeground,
                        ),
                      ),
                      Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.colors, required this.onPressed});

  final BeuiColors colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 32, // h-8
        padding: const EdgeInsets.symmetric(horizontal: 12), // px-3
        decoration: BoxDecoration(
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6, // gap-1.5
          children: [
            Icon(
              LucideIcons.rotate_ccw,
              size: 14,
              color: colors.mutedForeground,
            ),
            Text(
              'Reset',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
