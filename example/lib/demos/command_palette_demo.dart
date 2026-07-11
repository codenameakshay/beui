import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiCommandPalette] — press ⌘K/Ctrl+K or the button.
Widget commandPaletteDemo(BuildContext context) => const _PaletteDemo();

class _PaletteDemo extends StatefulWidget {
  const _PaletteDemo();

  @override
  State<_PaletteDemo> createState() => _PaletteDemoState();
}

class _PaletteDemoState extends State<_PaletteDemo> {
  bool _open = false;
  String _last = '—';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    void run(String what) => setState(() => _last = what);
    return BeuiCommandPalette(
      open: _open,
      onOpenChange: (v) => setState(() => _open = v),
      items: [
        BeuiCommandItem(
          id: 'new-file',
          label: 'New file',
          group: 'Actions',
          hint: '⌘N',
          icon: LucideIcons.file_text,
          onSelect: () => run('New file'),
        ),
        BeuiCommandItem(
          id: 'new-folder',
          label: 'New folder',
          group: 'Actions',
          icon: LucideIcons.folder_closed,
          onSelect: () => run('New folder'),
        ),
        BeuiCommandItem(
          id: 'settings',
          label: 'Open settings',
          group: 'Actions',
          hint: '⌘,',
          icon: LucideIcons.settings,
          onSelect: () => run('Open settings'),
        ),
        BeuiCommandItem(
          id: 'github',
          label: 'GitHub repository',
          group: 'Links',
          keywords: const ['repo', 'source'],
          icon: LucideIcons.link,
          onSelect: () => run('GitHub repository'),
        ),
        BeuiCommandItem(
          id: 'docs',
          label: 'Documentation',
          group: 'Links',
          icon: LucideIcons.book_open,
          onSelect: () => run('Documentation'),
        ),
      ],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BeuiButton(
              onPressed: () => setState(() => _open = true),
              child: const Text('Open palette (⌘K)'),
            ),
            const SizedBox(height: 16),
            Text(
              'Last command: $_last',
              style: TextStyle(color: colors.mutedForeground, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
