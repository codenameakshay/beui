import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiMorphPopover] — mirrors the source
/// `popover-morph.preview.tsx`: an "Options" trigger whose panel morphs open
/// out of the nearest corner, carrying four actions.
Widget popoverMorphDemo(BuildContext context) => const _PopoverMorphDemo();

class _PopoverMorphDemo extends StatefulWidget {
  const _PopoverMorphDemo();

  @override
  State<_PopoverMorphDemo> createState() => _PopoverMorphDemoState();
}

class _PopoverMorphDemoState extends State<_PopoverMorphDemo> {
  bool _open = false;

  static const _actions = <(IconData, String)>[
    (LucideIcons.pencil, 'Edit'),
    (LucideIcons.copy, 'Duplicate'),
    (LucideIcons.share_2, 'Share'),
    (LucideIcons.trash, 'Delete'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    // Source trigger: h-10 gap-2 rounded-xl border bg-background px-4 text-sm
    // font-medium, with a muted chevron.
    final trigger = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Options',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.foreground,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            LucideIcons.chevron_down,
            size: 16,
            color: colors.mutedForeground,
          ),
        ],
      ),
    );

    // Source content: w-48 p-1.5, rows gap-2.5 rounded-lg px-2.5 py-2 text-sm.
    final menu = SizedBox(
      width: 192,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (icon, label) in _actions)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _open = false),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: colors.mutedForeground),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return Center(
      child: BeuiMorphPopover(
        open: _open,
        onOpenChange: (v) => setState(() => _open = v),
        align: BeuiMorphPopoverAlign.start,
        content: menu,
        child: trigger,
      ),
    );
  }
}
