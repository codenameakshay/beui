import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiMorphPopover] — a panel that morphs open out of the
/// trigger corner (the morph variant of popover). Mirrors the source's
/// `MorphPopoverPreview`: an "Options" trigger revealing an action menu.
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
    (LucideIcons.trash_2, 'Delete'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    Widget trigger(String label) => Container(
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
            label,
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

    Widget menu(void Function() onPick) => SizedBox(
      width: 192, // w-48
      child: Padding(
        padding: const EdgeInsets.all(6), // p-1.5
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (icon, label) in _actions)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onPick,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Tap to morph the panel out of the corner (Esc / tap outside to close):',
        ),
        const SizedBox(height: 24),
        BeuiMorphPopover(
          open: _open,
          onOpenChange: (v) => setState(() => _open = v),
          align: BeuiMorphPopoverAlign.start,
          content: menu(() => setState(() => _open = false)),
          child: trigger('Options'),
        ),
        const SizedBox(height: 120),
        const Text('Opens above, end-aligned (uncontrolled):'),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: BeuiMorphPopover(
            side: BeuiMorphPopoverSide.top,
            align: BeuiMorphPopoverAlign.end,
            content: menu(() {}),
            child: trigger('Above'),
          ),
        ),
      ],
    );
  }
}
