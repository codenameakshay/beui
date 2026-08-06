import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiCommandPalette] — mirrors
/// `command-palette.preview.tsx`: a trigger pill plus the ⌘J / Ctrl J hint.
Widget commandPaletteDemo(BuildContext context) => const _PaletteDemo();

class _PaletteDemo extends StatefulWidget {
  const _PaletteDemo();

  @override
  State<_PaletteDemo> createState() => _PaletteDemoState();
}

class _PaletteDemoState extends State<_PaletteDemo> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return BeuiCommandPalette(
      open: _open,
      onOpenChange: (v) => setState(() => _open = v),
      shortcut: 'j',
      items: [
        BeuiCommandItem(
          id: 'home',
          label: 'Go to Home',
          group: 'Navigation',
          hint: 'G H',
          icon: LucideIcons.house,
          onSelect: () {},
        ),
        BeuiCommandItem(
          id: 'profile',
          label: 'Open profile',
          group: 'Navigation',
          hint: 'G P',
          icon: LucideIcons.user,
          onSelect: () {},
        ),
        BeuiCommandItem(
          id: 'settings',
          label: 'Settings',
          group: 'Navigation',
          icon: LucideIcons.settings,
          onSelect: () {},
        ),
        BeuiCommandItem(
          id: 'new-doc',
          label: 'Create document',
          group: 'Actions',
          hint: '⌘ N',
          icon: LucideIcons.file_text,
          onSelect: () {},
        ),
        BeuiCommandItem(
          id: 'new-project',
          label: 'New project',
          group: 'Actions',
          hint: '⌘ ⇧ N',
          icon: LucideIcons.plus,
          onSelect: () {},
        ),
      ],
      child: Center(
        child: Column(
          // Source wrapper: `flex flex-col items-start gap-3`.
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            _TriggerPill(
              colors: colors,
              onPressed: () => setState(() => _open = true),
            ),
            _HintLine(colors: colors),
          ],
        ),
      ),
    );
  }
}

/// `h-10 rounded-full border border-border bg-card px-5 text-sm font-medium`.
class _TriggerPill extends StatelessWidget {
  const _TriggerPill({required this.colors, required this.onPressed});

  final BeuiColors colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: colors.card,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(999),
        ),
        // `inline-flex` — the pill hugs its label instead of filling the row.
        child: Center(
          widthFactor: 1,
          child: Text(
            'Open command palette',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.foreground,
            ),
          ),
        ),
      ),
    ),
  );
}

class _HintLine extends StatelessWidget {
  const _HintLine({required this.colors});

  final BeuiColors colors;

  Widget _kbd(String label, {double trailing = 4}) => Container(
    margin: EdgeInsets.only(left: 4, right: trailing),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: colors.card,
      border: Border.all(color: colors.border),
      borderRadius: BorderRadius.circular(4), // rounded
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, color: colors.foreground),
    ),
  );

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: TextStyle(fontSize: 14, color: colors.mutedForeground),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Press'),
        _kbd('⌘ J'),
        const Text('(or'),
        // Source: `<kbd>Ctrl J</kbd>) to open.` — no space before the paren.
        _kbd('Ctrl J', trailing: 0),
        const Text(') to open.'),
      ],
    ),
  );
}
